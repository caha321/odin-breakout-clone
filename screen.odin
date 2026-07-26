package breakout

SCREEN_HEIGHT :: 1080
SCREEN_WIDTH :: 1080
PPM :: 20.0

WORLD_SCREEN_HALF_WIDTH :: SCREEN_WIDTH / (2 * PPM)
WORLD_SCREEN_HALF_HEIGHT :: SCREEN_HEIGHT / (2 * PPM)

world_to_screen :: proc "c" (p: [2]f32) -> [2]f32 {
	return {f32(SCREEN_WIDTH) / 2 + p.x * PPM, f32(SCREEN_HEIGHT) / 2 - p.y * PPM}
}

screen_to_world :: proc "c" (p: [2]f32) -> [2]f32 {
	return {(p.x - f32(SCREEN_WIDTH) / 2) / PPM, (f32(SCREEN_HEIGHT) / 2 - p.y) / PPM}
}
