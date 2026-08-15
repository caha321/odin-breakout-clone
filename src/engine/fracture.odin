package engine

import "core:math/linalg"
import "core:math/rand"
import b2 "vendor:box2d"
import rl "vendor:raylib"


Fragment_Shape :: struct {
	centroid: b2.Vec2, // offset from block center — where to spawn the body
	vertices: []b2.Vec2, // convex polygon, local to centroid, CCW
	uvs:      []b2.Vec2, // parallel array, texture coords [0,1]
}

// Scatters `count` seed points inside the block using rejection sampling to
// enforce a minimum spacing (a simple approximation of Poisson-disc
// sampling). Even spacing avoids degenerate slivers and near-duplicate
// seeds, which would otherwise produce tiny or zero-area cells.
@(private = "file")
generate_seeds :: proc(half_extents: b2.Vec2, count: int, min_dist: f32) -> []b2.Vec2 {
	seeds := make([dynamic]b2.Vec2, 0, count)
	attempts := 0
	for len(seeds) < count && attempts < count * 50 {
		attempts += 1
		p := b2.Vec2 {
			rand.float32_range(-half_extents.x, half_extents.x),
			rand.float32_range(-half_extents.y, half_extents.y),
		}
		ok := true
		for s in seeds {
			if linalg.distance(s, p) < min_dist {
				ok = false
				break
			}
		}
		if ok do append(&seeds, p)
	}
	return seeds[:]
}

// Generates seeds with density falling off from `impact_local` (impact
// point in block-local space). Seeds are denser near the impact and
// sparser near the edges, mimicking how real fractures radiate outward
// with finer cracking close to the point of contact.
generate_seeds_biased :: proc(
	half_extents: b2.Vec2,
	count: int,
	min_dist: f32,
	impact_local: b2.Vec2,
	falloff_radius: f32,
) -> []b2.Vec2 {
	seeds := make([dynamic]b2.Vec2, 0, count)
	attempts := 0
	max_attempts := count * 200

	for len(seeds) < count && attempts < max_attempts {
		attempts += 1
		p := b2.Vec2 {
			rand.float32_range(-half_extents.x, half_extents.x),
			rand.float32_range(-half_extents.y, half_extents.y),
		}

		// Closer to impact => higher acceptance probability.
		dist := linalg.distance(p, impact_local)
		t := clamp(dist / falloff_radius, 0.0, 1.0)
		accept_prob := 1.0 - t * 0.85 // never fully zero, so far corners still fracture some

		if rand.float32() > accept_prob do continue

		ok := true
		for s in seeds {
			if linalg.distance(s, p) < min_dist {
				ok = false
				break
			}
		}
		if ok do append(&seeds, p)
	}

	// Fallback: if the biased pass starved out (falloff_radius too small
	// relative to block size), top up with uniform seeds so the pattern
	// still has enough sites to look right.
	if len(seeds) < count {
		uniform := generate_seeds(half_extents, count - len(seeds), min_dist)
		for s in uniform do append(&seeds, s)
		delete(uniform)
	}

	return seeds[:]
}

// -- Sutherland-Hodgman clip: keep the side closer to `keep_site` --
// Caller owns the returned dynamic array
@(private = "file")
clip_halfplane :: proc(poly: []b2.Vec2, keep_site, other_site: b2.Vec2) -> [dynamic]b2.Vec2 {
	mid := (keep_site + other_site) * 0.5
	normal := linalg.normalize(other_site - keep_site) // points away from keep_site

	// Signed distance from the bisector line; <= 0 means "on keep_site's side".
	side :: proc(p, mid, normal: b2.Vec2) -> f32 {
		return linalg.dot(p - mid, normal)
	}

	out := make([dynamic]b2.Vec2, 0, len(poly) + 1)
	n := len(poly)
	for i in 0 ..< n {
		cur := poly[i]
		next := poly[(i + 1) % n]
		cur_in := side(cur, mid, normal) <= 0
		next_in := side(next, mid, normal) <= 0

		if cur_in do append(&out, cur)
		if cur_in != next_in {
			// Edge crosses the bisector — insert the intersection point.
			d1 := side(cur, mid, normal)
			d2 := side(next, mid, normal)
			t := d1 / (d1 - d2)
			append(&out, cur + (next - cur) * t)
		}
	}
	return out
}

// Maps a point in block-local space (origin at block center) to normalized [0,1] texture coordinates
@(private = "file")
uv_of :: proc "contextless" (p: b2.Vec2, half_extents: b2.Vec2) -> b2.Vec2 {
	return b2.Vec2 {
		(p.x + half_extents.x) / (2 * half_extents.x),
		1.0 - (p.y + half_extents.y) / (2 * half_extents.y), // flip if it renders upside down
	}
}

// Builds one Voronoi fracture pattern for a rectangular block of the given `half_extents`.
// Generates `seed_count` random seeds, then computes each seed's Voronoi cell via half-plane clipping
// Caller owns the returned dynamic array
@(require_results)
generate_fractures :: proc(
	half_extents: b2.Vec2,
	seed_count: int,
	impact_world: b2.Vec2,
	body_id: b2.BodyId,
) -> [dynamic]Fragment_Shape {
	transform := b2.Body_GetTransform(body_id)
	impact_local := b2.InvTransformPoint(transform, impact_world)

	falloff_radius := (half_extents.x + half_extents.y) * 0.6 // ~60% of block "size"
	min_dist := (half_extents.x + half_extents.y) / f32(seed_count)

	seeds := generate_seeds_biased(
		half_extents,
		seed_count,
		min_dist,
		impact_local,
		falloff_radius,
	)
	defer delete(seeds)

	hw, hh := half_extents.x, half_extents.y
	boundary := []b2.Vec2{{-hw, -hh}, {hw, -hh}, {hw, hh}, {-hw, hh}}

	fragments := make([dynamic]Fragment_Shape, 0, len(seeds))

	// For each seed, carve out its Voronoi cell by clipping the full
	// rectangle against every other seed's bisector in turn.
	for i in 0 ..< len(seeds) {
		cell := make([dynamic]b2.Vec2, len(boundary))
		copy(cell[:], boundary)

		for j in 0 ..< len(seeds) {
			if i == j do continue
			clipped := clip_halfplane(cell[:], seeds[i], seeds[j])
			delete(cell)
			cell = clipped
			if len(cell) == 0 do break // degenerate, seed fully clipped away
		}

		if len(cell) < 3 {
			delete(cell)
			continue
		}

		// Centroid becomes the fragment's spawn position; vertices and UVs
		// are stored relative to it (vertices) and in absolute [0,1]
		// texture space (uvs), computed from block-local positions.
		centroid := b2.Vec2{0, 0}
		for v in cell do centroid += v
		centroid /= f32(len(cell))

		verts := make([]b2.Vec2, len(cell))
		uvs := make([]b2.Vec2, len(cell))
		for v, k in cell {
			verts[k] = v - centroid
			uvs[k] = uv_of(v, half_extents)
		}
		delete(cell)

		append(&fragments, Fragment_Shape{centroid = centroid, vertices = verts, uvs = uvs})
	}

	return fragments
}

@(require_results)
create_fracture_mesh :: proc(vertices_in: [][2]f32, uvs_in: [][2]f32) -> RenderShape_Mesh {
	allocator := rl.MemAllocator() // we need to use this allocator for memory that rl will free
	vertex_count := len(vertices_in)
	triangle_count := vertex_count - 2 // fan triangulation of a convex n-gon

	mesh: rl.Mesh
	mesh.vertexCount = i32(vertex_count)
	mesh.triangleCount = i32(triangle_count)


	mesh_vertices := make([]f32, vertex_count * 3, allocator)
	mesh_texcoords := make([]f32, vertex_count * 2, allocator)
	for i in 0 ..< vertex_count {
		mesh_vertices[i * 3 + 0] = vertices_in[i].x
		mesh_vertices[i * 3 + 1] = vertices_in[i].y
		mesh_vertices[i * 3 + 2] = 0 // raylib meshes are 3D, we don't need it

		mesh_texcoords[i * 2 + 0] = uvs_in[i].x
		mesh_texcoords[i * 2 + 1] = uvs_in[i].y
	}

	// fan indices: (0,1,2), (0,2,3), (0,3,4), ...
	mesh_indices := make([]u16, triangle_count * 3, allocator)
	for i in 0 ..< triangle_count {
		mesh_indices[i * 3 + 0] = 0
		mesh_indices[i * 3 + 1] = u16(i + 1)
		mesh_indices[i * 3 + 2] = u16(i + 2)
	}

	mesh.vertices = raw_data(mesh_vertices)
	mesh.texcoords = raw_data(mesh_texcoords)
	mesh.indices = raw_data(mesh_indices)

	rl.UploadMesh(&mesh, is_dynamic = false) // GPU-resident, not re-uploaded

	return {mesh = mesh}
}
