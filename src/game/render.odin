package game


SCREEN_HEIGHT :: 1280
SCREEN_WIDTH :: 1920
PPM :: 20


world_to_screen :: proc "c" (p: [2]f32) -> [2]f32 {
	return {f32(SCREEN_WIDTH) / 2 + p.x * PPM, f32(SCREEN_HEIGHT) / 2 - p.y * PPM}
}

screen_to_world :: proc "c" (p: [2]f32) -> [2]f32 {
	return {(p.x - f32(SCREEN_WIDTH) / 2) / PPM, (f32(SCREEN_HEIGHT) / 2 - p.y) / PPM}
}
