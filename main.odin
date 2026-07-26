package breakout

import "core:log"
import "core:os"
import rl "vendor:raylib"

DT :: 1.0 / 60.0
SUB_STEP_COUNT :: 4 // Box2D

run :: proc() -> bool {
	rl.SetTraceLogLevel(.WARNING)
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Breakout!")
	defer rl.CloseWindow()

	rl.SetTargetFPS(75)

	game_init() or_return
	defer game_shutdown()

	for !rl.WindowShouldClose() {
		Game_Update()
		Game_Render()
	}

	return true
}


main :: proc() {
	context.logger = log.create_console_logger()

	if !run() {
		os.exit(1)
	}
}
