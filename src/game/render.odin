package game

import "core:math"
import "core:math/linalg"
import b2 "vendor:box2d"

SCREEN_HEIGHT :: 1280
SCREEN_WIDTH :: 1920
PPM :: 20


world_to_screen :: proc "contextless" (p: [2]f32) -> [2]f32 {
	return {f32(SCREEN_WIDTH) / 2 + p.x * PPM, f32(SCREEN_HEIGHT) / 2 - p.y * PPM}
}

screen_to_world :: proc "contextless" (p: [2]f32) -> [2]f32 {
	return {(p.x - f32(SCREEN_WIDTH) / 2) / PPM, (f32(SCREEN_HEIGHT) / 2 - p.y) / PPM}
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
