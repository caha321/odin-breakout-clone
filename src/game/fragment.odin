package game

import b2 "vendor:box2d"
import rl "vendor:raylib/"
import gl "vendor:raylib/rlgl"

import "../engine"

Fragment :: struct {
	texture:  Texture,
	vertices: []b2.Vec2, // local to body origin — same verts used for the physics shape
	uvs:      []b2.Vec2,
}

// TODO batch: group fragments by texture and draw all in same batch
Fragment_Draw :: proc(entity: ^Entity, variant: Fragment) {
	gl.Begin(gl.TRIANGLES)
	defer gl.End()

	rl_texture := g.textures[variant.texture]
	gl.SetTexture(rl_texture.id)
	defer gl.SetTexture(0)

	transform := b2.Body_GetTransform(entity.body_id)

	world :: proc(local: b2.Vec2, transform: b2.Transform) -> b2.Vec2 {
		return engine.world_to_screen(b2.TransformPoint(transform, local))
	}

	n := len(variant.vertices)
	if n < 3 do return

	v0 := world(variant.vertices[0], transform)
	uv0 := variant.uvs[0]

	for i in 1 ..< n - 1 {
		v1 := world(variant.vertices[i], transform)
		v2 := world(variant.vertices[i + 1], transform)
		uv1 := variant.uvs[i]
		uv2 := variant.uvs[i + 1]

		gl.Color4ub(255, 255, 255, 128) // half transparent because so its less distracting (background)
		gl.TexCoord2f(uv0.x, uv0.y); gl.Vertex2f(v0.x, v0.y)
		gl.TexCoord2f(uv1.x, uv1.y); gl.Vertex2f(v1.x, v1.y)
		gl.TexCoord2f(uv2.x, uv2.y); gl.Vertex2f(v2.x, v2.y)
	}
}
