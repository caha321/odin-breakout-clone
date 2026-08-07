package engine

import "core:math"
import "core:math/linalg"
import b2 "vendor:box2d"
import rl "vendor:raylib"

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

RenderShape :: union {
	RenderShape_Circle,
	RenderShape_Rectangle,
}

RenderData :: struct {
	texture: rl.Texture2D,
	shape:   RenderShape,
	tint:    rl.Color,
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

render_texture :: proc "contextless" (rd: RenderData, rt: RenderTransform) {
	source := rl.Rectangle{0, 0, f32(rd.texture.width), f32(rd.texture.height)}
	dest: rl.Rectangle
	origin: rl.Vector2

	switch shape in rd.shape {
	case RenderShape_Circle:
		diameter := shape.diameter

		dest = rl.Rectangle{rt.screen_position.x, rt.screen_position.y, diameter, diameter}
		origin = rl.Vector2{diameter / 2, diameter / 2} // center pivot

	case RenderShape_Rectangle:
		dest, origin = rectangle_get_dest_origin(shape, rt)
	}

	rl.DrawTexturePro(rd.texture, source, dest, origin, -rt.angle_deg, rd.tint)
}

render :: proc "contextless" (rd: RenderData, rt: RenderTransform) {
	if rl.IsTextureValid(rd.texture) {
		render_texture(rd, rt)
		return
	}
	// else
	switch shape in rd.shape {
	case RenderShape_Circle:
		rl.DrawCircleV(rt.screen_position, shape.diameter / 2, rd.tint)

	case RenderShape_Rectangle:
		dest, origin := rectangle_get_dest_origin(shape, rt)
		rl.DrawRectanglePro(dest, origin, -rt.angle_deg, rd.tint)
	}
}
