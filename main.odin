package breakout

import "core:log"
import "core:os"
import b2 "vendor:box2d"
import rl "vendor:raylib"

run :: proc() -> bool {
	rl.SetTraceLogLevel(.ERROR)
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Breakout!")
	defer rl.CloseWindow()

	rl.SetTargetFPS(75)

	game_init() or_return
	defer game_shutdown()


	world_def := b2.DefaultWorldDef()
	world_def.gravity = {0, 0}
	world_id := b2.CreateWorld(world_def)
	defer b2.DestroyWorld(world_id)

	create_bounds(world_id)
	paddle_create(world_id)
	ball_create(world_id)
	blocks_create(world_id)

	//

	debug_draw := init_debug_draw()

	DT :: 1.0 / 60.0
	SUB_STEP_COUNT :: i32(8)

	accumulated_time: f32

	game_loop: for !rl.WindowShouldClose() {

		switch g.state {
		case .New:
			if rl.IsKeyPressed(.SPACE) {
				game_update_state(.Running)
			}
		case .Running:
			accumulated_time += rl.GetFrameTime()
		case .GameOver:
			if rl.IsKeyPressed(.SPACE) {
				game_restart()
			}
		}

		if rl.IsKeyPressed(.F1) do g.draw_b2_debug = !g.draw_b2_debug

		for accumulated_time >= DT {
			paddle_update(DT) // move paddle BEFORE stepping physics

			// normalize ball speed
			vel := b2.Body_GetLinearVelocity(ball_id)
			speed := b2.Length(vel)
			if speed > 0 {
				b2.Body_SetLinearVelocity(ball_id, vel * (g.ball_speed / speed))
			}

			b2.World_Step(world_id, DT, SUB_STEP_COUNT)

			check_sensor_events(world_id)
			check_contact_events(world_id)

			accumulated_time -= DT
		}

		// TODO blend stuff

		rl.BeginDrawing()
		rl.ClearBackground(BACKGROUND_COLOR)

		for &block in blocks {
			block_draw(&block)
		}
		ball_draw()
		paddle_draw()

		ui_draw()

		if g.draw_b2_debug do b2.World_Draw(world_id, &debug_draw)

		rl.EndDrawing()
	}

	return true
}

check_contact_events :: proc(world_id: b2.WorldId) {
	events := b2.World_GetContactEvents(world_id)

	for i in 0 ..< events.hitCount {
		hit := events.hitEvents[i]

		sd_a := cast(^User_Data)b2.Shape_GetUserData(hit.shapeIdA)
		sd_b := cast(^User_Data)b2.Shape_GetUserData(hit.shapeIdB)

		sound: Sound
		if sd_a.sound_hit != .NoSound do sound = sd_a.sound_hit
		else if sd_b.sound_hit != .NoSound do sound = sd_b.sound_hit

		if sound != .NoSound {
			// approachSpeed tells you how hard the impact was —
			// use it to scale volume/pitch for a more natural feel
			volume := clamp(hit.approachSpeed / 15.0, 0.2, 1.0)
			rl_sound := g.sounds[sound]
			pan := clamp(hit.point.x / WORLD_SCREEN_HALF_WIDTH, -1, 1)
			//log.debug("Volume:", volume, "Pan:", pan)

			rl.SetSoundPan(rl_sound, pan)
			rl.SetSoundVolume(rl_sound, volume)
			rl.PlaySound(rl_sound)
		}

		if sd_a.entity_kind == .Block do block_hit(&blocks[sd_a.entity_id - 1])
		else if sd_b.entity_kind == .Block do block_hit(&blocks[sd_b.entity_id - 1])
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
