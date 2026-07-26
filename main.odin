package breakout

import "core:log"
import "core:os"
import b2 "vendor:box2d"
import rl "vendor:raylib"

DT :: 1.0 / 60.0
SUB_STEP_COUNT :: 8 // Box2D

run :: proc() -> bool {
	rl.SetTraceLogLevel(.ERROR)
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Breakout!")
	defer rl.CloseWindow()

	rl.SetTargetFPS(75)

	game_init() or_return
	defer game_shutdown()

	Game_Loop()

	return true
}

check_contact_events :: proc(world_id: b2.WorldId) {
	events := b2.World_GetContactEvents(world_id)

	for i in 0 ..< events.hitCount {
		hit := events.hitEvents[i]

		entity_a := get_entity(b2.Shape_GetUserData(hit.shapeIdA))
		if entity_a != nil && entity_a.hit != nil do entity_a.hit(entity_a, hit)

		entity_b := get_entity(b2.Shape_GetUserData(hit.shapeIdB))
		if entity_b != nil && entity_b.hit != nil do entity_b.hit(entity_b, hit)
	}
}

check_sensor_events :: proc(world_id: b2.WorldId) {
	events := b2.World_GetSensorEvents(world_id)
	for i in 0 ..< events.beginCount {
		game_update_state(.GameOver)
	}
}


main :: proc() {
	context.logger = log.create_console_logger()

	if !run() {
		os.exit(1)
	}
}
