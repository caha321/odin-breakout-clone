package engine

import "core:math"
import "core:math/linalg"
import b2 "vendor:box2d"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

Screen :: struct {
	width:  i32,
	height: i32,
}

screen := Screen{}
camera := rl.Camera2D{}

run :: proc(width, height: i32, zoom_world: f32, run_proc: proc() -> bool) -> bool {
	rl.SetTraceLogLevel(.WARNING)
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(width, height, "Break the Blocks!")

	screen.width = width
	screen.height = height

	camera = rl.Camera2D {
		offset   = {f32(screen.width) / 2, f32(screen.height) / 2}, // world origin -> screen center
		target   = {0, 0}, // world point at screen center
		rotation = 0,
		zoom     = f32(screen.height) / zoom_world,
	}

	defer rl.CloseWindow()

	rl.SetTargetFPS(75)

	return run_proc()
}


world_to_screen :: #force_inline proc "contextless" (p: [2]f32) -> [2]f32 {
	return {p.x, -p.y} // rl y is opposite direction than box2d
}

screen_to_world :: #force_inline proc "contextless" (p: [2]f32) -> [2]f32 {
	world := rl.GetScreenToWorld2D(p, camera)
	return {world.x, -world.y}
}


// Result of interpolating a transform, ready for rendering.
RenderTransform :: struct {
	screen_position: [2]f32,
	angle_deg:       f32,
}

// Interpolates between two Box2D transforms and returns a render-ready screen position + angle.
// `alpha` is expected in [0, 1].
get_render_transform_blended :: proc "contextless" (
	prev, curr: b2.Transform,
	alpha: f32,
) -> RenderTransform {
	pos := linalg.lerp(prev.p, curr.p, alpha)

	rot_vec := linalg.lerp([2]f32{prev.q.c, prev.q.s}, [2]f32{curr.q.c, curr.q.s}, alpha)
	rot_vec = linalg.normalize(rot_vec)
	angle_deg := math.to_degrees(math.atan2(rot_vec.y, rot_vec.x))

	return RenderTransform{screen_position = world_to_screen(pos), angle_deg = angle_deg}
}

get_render_transform_static :: proc "contextless" (transform: b2.Transform) -> RenderTransform {
	return RenderTransform {
		screen_position = world_to_screen(transform.p),
		angle_deg = math.to_degrees(b2.Rot_GetAngle(transform.q)),
	}
}

get_render_transform_static_particle :: proc "contextless" (
	position: [2]f32,
	angle_deg: f32,
) -> RenderTransform {
	return RenderTransform{screen_position = world_to_screen(position), angle_deg = angle_deg}
}

get_render_transform :: proc {
	get_render_transform_static,
	get_render_transform_static_particle,
	get_render_transform_blended,
}

RenderShape_Circle :: struct {
	diameter: f32,
}

RenderShape_Rectangle :: struct {
	width:  f32, // unscaled world
	height: f32,
}

RenderShape_Polygon :: struct {
	vertices: [][2]f32, // local to body origin — same verts used for the physics shape
	uvs:      [][2]f32,
}

RenderShape_Mesh :: struct {
	mesh: rl.Mesh,
}

RenderShape :: union {
	RenderShape_Circle,
	RenderShape_Rectangle,
	RenderShape_Polygon,
	RenderShape_Mesh,
}

RenderData :: struct {
	atlas_region: AtlasRegion,
	shape:        RenderShape,
	tint:         rl.Color,
	blend:        rl.BlendMode,
}

RenderData_Destroy :: proc(rd: RenderData) {
	#partial switch shape in rd.shape {
	case RenderShape_Polygon:
		delete(shape.uvs)
		delete(shape.vertices)
	case RenderShape_Mesh:
		rl.UnloadMesh(shape.mesh)
	}
}

@(private = "file")
rectangle_get_dest_origin :: #force_inline proc "contextless" (
	shape: RenderShape_Rectangle,
	rt: RenderTransform,
) -> (
	dest: rl.Rectangle,
	origin: rl.Vector2,
) {
	width := shape.width
	height := shape.height

	dest = rl.Rectangle{rt.screen_position.x, rt.screen_position.y, width, height}
	origin = rl.Vector2{width / 2, height / 2}
	return
}

render_texture_circle :: proc "contextless" (
	rd: RenderData,
	shape: RenderShape_Circle,
	rt: RenderTransform,
) {
	//source := rl.Rectangle{0, 0, f32(rd.texture.width), f32(rd.texture.height)}
	dest := rl.Rectangle {
		rt.screen_position.x,
		rt.screen_position.y,
		shape.diameter,
		shape.diameter,
	}
	origin := rl.Vector2{shape.diameter / 2, shape.diameter / 2} // center pivot

	rl.BeginBlendMode(rd.blend) // TODO
	rl.DrawTexturePro(
		g_atlas_texture,
		cast(rl.Rectangle)rd.atlas_region,
		dest,
		origin,
		-rt.angle_deg,
		rd.tint,
	)
	rl.EndBlendMode()
}

render_texture_rectangle :: proc "contextless" (
	rd: RenderData,
	shape: RenderShape_Rectangle,
	rt: RenderTransform,
) {
	//source := rl.Rectangle{0, 0, f32(rd.texture.width), f32(rd.texture.height)}
	dest, origin := rectangle_get_dest_origin(shape, rt)

	rl.BeginBlendMode(rd.blend) // TODO
	rl.DrawTexturePro(
		g_atlas_texture,
		cast(rl.Rectangle)rd.atlas_region,
		dest,
		origin,
		-rt.angle_deg,
		rd.tint,
	)
	rl.EndBlendMode()
}

// Pushes the rlgl matrix stack and applies rt (rotate Z -> flip Y -> translate),
// converting Box2D's Y-up world space to screen's Y-down space. Caller must
// call `rlgl.PopMatrix()` when done drawing.
@(private = "file")
push_render_transform :: #force_inline proc "contextless" (rt: RenderTransform) {
	rlgl.PushMatrix()
	rlgl.Translatef(rt.screen_position.x, rt.screen_position.y, z = 0)
	rlgl.Scalef(1, -1, 1) // flip Y: Box2D (Y-up) → screen (Y-down)
	rlgl.Rotatef(rt.angle_deg, x = 0, y = 0, z = 1)
}

render_texture_polygon :: proc "contextless" (
	rd: RenderData,
	shape: RenderShape_Polygon,
	rt: RenderTransform,
) {
	n := len(shape.vertices)
	if n < 3 do return

	push_render_transform(rt)
	defer rlgl.PopMatrix()

	rlgl.Begin(rlgl.TRIANGLES)
	defer rlgl.End()

	rlgl.SetTexture(g_atlas_texture.id)
	defer rlgl.SetTexture(0)

	v0 := shape.vertices[0]
	uv0 := shape.uvs[0]

	for i in 1 ..< n - 1 {
		v1 := shape.vertices[i]
		v2 := shape.vertices[i + 1]
		uv1 := shape.uvs[i]
		uv2 := shape.uvs[i + 1]

		rlgl.Color4ub(rd.tint.r, rd.tint.g, rd.tint.b, rd.tint.a)
		rlgl.TexCoord2f(uv0.x, uv0.y); rlgl.Vertex2f(v0.x, v0.y)
		rlgl.TexCoord2f(uv1.x, uv1.y); rlgl.Vertex2f(v1.x, v1.y)
		rlgl.TexCoord2f(uv2.x, uv2.y); rlgl.Vertex2f(v2.x, v2.y)
	}
}

render_polygon :: proc "contextless" (
	rd: RenderData,
	shape: RenderShape_Polygon,
	rt: RenderTransform,
) {
	n := len(shape.vertices)
	if n < 3 do return

	push_render_transform(rt)
	defer rlgl.PopMatrix()

	rlgl.Begin(rlgl.TRIANGLES)
	defer rlgl.End()

	v0 := shape.vertices[0]

	for i in 1 ..< n - 1 {
		v1 := shape.vertices[i]
		v2 := shape.vertices[i + 1]

		rlgl.Color4ub(rd.tint.r, rd.tint.g, rd.tint.b, rd.tint.a)
		rlgl.Vertex2f(v0.x, v0.y)
		rlgl.Vertex2f(v1.x, v1.y)
		rlgl.Vertex2f(v2.x, v2.y)
	}
}

@(private = "file")
render_transform_to_matrix :: #force_inline proc "contextless" (rt: RenderTransform) -> rl.Matrix {
	translation := rl.MatrixTranslate(rt.screen_position.x, rt.screen_position.y, 0)
	flip_y := rl.MatrixScale(1, -1, 1) // Box2D (Y-up) → screen (Y-down)
	rotation := rl.MatrixRotateZ(rt.angle_deg * rl.DEG2RAD)

	return translation * flip_y * rotation
}

render_mesh :: proc "contextless" (rd: RenderData, shape: RenderShape_Mesh, rt: RenderTransform) {
	material := rl.LoadMaterialDefault()
	material.maps[rl.MaterialMapIndex.ALBEDO].texture = g_atlas_texture
	material.maps[rl.MaterialMapIndex.ALBEDO].color = rd.tint

	transform := render_transform_to_matrix(rt)
	rl.DrawMesh(shape.mesh, material, transform)
}

render :: proc "contextless" (rd: RenderData, rt: RenderTransform) {
	switch shape in rd.shape {
	case RenderShape_Circle:
		if rd.atlas_region.width > 0 {
			render_texture_circle(rd, shape, rt)
		} else {
			rl.DrawCircleV(rt.screen_position, shape.diameter / 2, rd.tint)
		}

	case RenderShape_Rectangle:
		if rd.atlas_region.width > 0 {
			render_texture_rectangle(rd, shape, rt)
		} else {
			dest, origin := rectangle_get_dest_origin(shape, rt)
			rl.DrawRectanglePro(dest, origin, -rt.angle_deg, rd.tint)
		}

	case RenderShape_Polygon:
		if rd.atlas_region.width > 0 {
			render_texture_polygon(rd, shape, rt)
		} else {
			render_polygon(rd, shape, rt)
		}
	case RenderShape_Mesh:
		render_mesh(rd, shape, rt) // TODO
	}
}


draw_background :: proc(atlas_region: AtlasRegion) {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	tw := f32(atlas_region.width)
	th := f32(atlas_region.height)

	// scale so the texture covers the whole screen, cropping the overflow
	scale := max(sw / tw, sh / th)

	dest_w := tw * scale
	dest_h := th * scale

	// center it
	dest := rl.Rectangle {
		x      = (sw - dest_w) * 0.5,
		y      = (sh - dest_h) * 0.5,
		width  = dest_w,
		height = dest_h,
	}

	rl.DrawTexturePro(
		g_atlas_texture,
		cast(rl.Rectangle)atlas_region,
		dest,
		rl.Vector2{0, 0},
		0,
		rl.WHITE,
	)
}
