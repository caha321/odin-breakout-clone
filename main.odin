package breakout

import "core:log"
import "core:os"
import b2 "vendor:box2d"
import rl "vendor:raylib"

handle_input :: proc() {
	switch g.state {
	case .New:
		if rl.IsKeyPressed(.SPACE) {
			game_update_state(.Running)
		}
	case .Running:
		if rl.IsKeyPressed(.SPACE) {
			game_update_state(.Paused)
		}
	case .Paused:
		if rl.IsKeyPressed(.SPACE) {
			game_update_state(.Running)
		}
	case .GameOver:
		if rl.IsKeyPressed(.SPACE) {
			game_update_state(.New)
		}
	}

	if rl.IsKeyPressed(.F1) do g.draw_b2_debug = !g.draw_b2_debug
}

run :: proc() -> bool {
	rl.SetTraceLogLevel(.ERROR)
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Breakout!")
	defer rl.CloseWindow()

	rl.SetTargetFPS(75)

	game_init() or_return
	defer game_shutdown()


	debug_draw := init_debug_draw()

	DT :: 1.0 / 60.0
	SUB_STEP_COUNT :: i32(8)

	accumulated_time: f32

	game_loop: for !rl.WindowShouldClose() {
		handle_input()

		if g.state == .Running {
			accumulated_time += rl.GetFrameTime()
		}

		for accumulated_time >= DT {
			for &entity in g.entities {
				if entity.update != nil do entity.update(&entity, DT)
			}

			b2.World_Step(g.world_id, DT, SUB_STEP_COUNT)

			check_sensor_events(g.world_id)
			check_contact_events(g.world_id)

			accumulated_time -= DT
		}

		// TODO blend stuff

		rl.BeginDrawing()
		rl.ClearBackground(BACKGROUND_COLOR)

		for &entity in g.entities {
			if entity.draw != nil do entity.draw(&entity)
		}

		ui_draw()

		if g.draw_b2_debug do b2.World_Draw(g.world_id, &debug_draw)

		rl.EndDrawing()
	}

	return true
}

check_contact_events :: proc(world_id: b2.WorldId) {
	events := b2.World_GetContactEvents(world_id)

	for i in 0 ..< events.hitCount {
		hit := events.hitEvents[i]

		// TODO use v-table instead
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

		if sd_a.entity_kind == .Block do Block_Hit(&g.entities[sd_a.entity_id - 1])
		else if sd_b.entity_kind == .Block do Block_Hit(&g.entities[sd_b.entity_id - 1])
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
