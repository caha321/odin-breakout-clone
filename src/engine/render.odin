package engine

import "core:math"
import "core:math/linalg"
import b2 "vendor:box2d"
import rl "vendor:raylib"

Screen :: struct {
	width:           i32,
	height:          i32,
	pixel_per_meter: f32,
}

screen := Screen {
	width           = 1920,
	height          = 1280,
	pixel_per_meter = 20,
}


world_to_screen :: proc "contextless" (p: [2]f32) -> [2]f32 {
	return {
		f32(screen.width) / 2 + p.x * screen.pixel_per_meter,
		f32(screen.height) / 2 - p.y * screen.pixel_per_meter,
	}
}

screen_to_world :: proc "contextless" (p: [2]f32) -> [2]f32 {
	return {
		(p.x - f32(screen.width) / 2) / screen.pixel_per_meter,
		(f32(screen.height) / 2 - p.y) / screen.pixel_per_meter,
	}
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

get_render_transform :: proc {
	get_render_transform_static,
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

render :: proc(rd: RenderData, rt: RenderTransform) {
	source := rl.Rectangle{0, 0, f32(rd.texture.width), f32(rd.texture.height)}
	dest: rl.Rectangle
	origin: rl.Vector2

	switch shape in rd.shape {
	case RenderShape_Circle:
		diameter := shape.diameter * screen.pixel_per_meter // TODO scale via rl camera

		dest = rl.Rectangle{rt.screen_position.x, rt.screen_position.y, diameter, diameter}
		origin = rl.Vector2{diameter / 2, diameter / 2} // center pivot

	case RenderShape_Rectangle:
		width := shape.width * screen.pixel_per_meter // TODO scale via rl camera
		height := shape.height * screen.pixel_per_meter

		dest = rl.Rectangle{rt.screen_position.x, rt.screen_position.y, width, height}
		origin = rl.Vector2{width / 2, height / 2}
	}

	rl.DrawTexturePro(rd.texture, source, dest, origin, -rt.angle_deg, rd.tint)
}
