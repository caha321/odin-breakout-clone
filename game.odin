package breakout

import "core:log"
import "core:time"
import b2 "vendor:box2d"
import rl "vendor:raylib"


Game_State :: enum {
	New,
	Running,
	Paused,
	GameOver,
}

Game :: struct {
	state:            Game_State,
	score:            int,
	lives:            int, // TODO
	textures:         [Texture]rl.Texture2D,
	sounds:           [Sound]rl.Sound,
	entity_pool:      Entity_Pool,
	remaining_balls:  int,
	remaining_blocks: int,
	ball_speed:       f32,
	// physics stuff
	world_id:         b2.WorldId,
	draw_b2_debug:    bool,
	accumulated_time: f32,
	// perf stats
	update_time_ms:   f64,
	render_time_ms:   f64,
}

g: ^Game

game_init :: proc() -> bool {
	rl.InitAudioDevice()

	g = new(Game)
	load_assets() or_return
	game_update_state(.New)

	return true
}


// Restart game, resets all state to initial values
game_restart :: proc() {
	g.score = 0
	g.ball_speed = BALL_SPEED_INITIAL
	game_clear_entities()
	g.remaining_balls = 0
	g.remaining_blocks = 0

	World_Create()
}

game_clear_entities :: proc() {
	Pool_Clear(&g.entity_pool)

	if b2.World_IsValid(g.world_id) do b2.DestroyWorld(g.world_id)
}

game_shutdown :: proc() {
	game_clear_entities()
	Pool_Delete(g.entity_pool)

	for rl_texture, texture in g.textures {
		if rl.IsTextureValid(rl_texture) {
			log.info("Unloading Texture:", texture)
			rl.UnloadTexture(rl_texture)
		}
	}

	for rl_sound, sound in g.sounds {
		if rl.IsSoundValid(rl_sound) {
			log.info("Unloading Sound:", sound)
			rl.UnloadSound(rl_sound)
		}
	}

	if b2.World_IsValid(g.world_id) do b2.DestroyWorld(g.world_id)

	rl.CloseAudioDevice()

	free(g)
}

game_update_state :: proc(state: Game_State) {
	log.debug("Updating game state:", state)

	switch state {
	case .New:
		rl.ShowCursor()
		game_restart()
	case .Running:
		rl.PlaySound(g.sounds[.GameStart])
		rl.HideCursor()
	case .Paused:
		// TODO play sound
		rl.ShowCursor()
	case .GameOver:
		rl.PlaySound(g.sounds[.GameOver])
		rl.ShowCursor()
	}
	g.state = state
}

Game_Handle_Input :: proc() {
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

Game_Update :: proc() {
	update_start := time.tick_now()

	Game_Handle_Input()

	if g.state == .Running {
		g.accumulated_time += rl.GetFrameTime()
	}

	for g.accumulated_time >= DT {
		for &slot in g.entity_pool.slots {
			if !slot.alive do continue
			Entity_Update(&slot.entity, DT)
		}
		b2.World_Step(g.world_id, DT, SUB_STEP_COUNT)

		check_sensor_events()
		check_contact_events()

		g.accumulated_time -= DT
	}

	g.update_time_ms = time.duration_milliseconds(time.tick_since(update_start))
}

check_contact_events :: proc() {
	events := b2.World_GetContactEvents(g.world_id)

	for i in 0 ..< events.hitCount {
		hit := events.hitEvents[i]

		entity, ok := Pool_Get(g.entity_pool, hit.shapeIdA)
		if ok do Entity_Hit(entity, hit)

		entity, ok = Pool_Get(g.entity_pool, hit.shapeIdB)
		if ok do Entity_Hit(entity, hit)
	}
}

check_sensor_events :: proc() {
	events := b2.World_GetSensorEvents(g.world_id)
	for i in 0 ..< events.beginCount {
		event := events.beginEvents[i]

		_, ok := Pool_Get(g.entity_pool, event.visitorShapeId)
		if ok {
			g.remaining_balls -= 1
			Pool_Remove(&g.entity_pool, event.sensorShapeId)
		}
	}

	if g.remaining_balls <= 0 {
		game_update_state(.GameOver)
	}
}

debug_draw := init_debug_draw()

Game_Render :: proc() {
	render_start := time.tick_now()
	// TODO blend stuff
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(BACKGROUND_COLOR)

	for &slot in g.entity_pool.slots {
		if !slot.alive do continue
		Entity_Draw(&slot.entity)
	}
	ui_draw()

	if g.draw_b2_debug do b2.World_Draw(g.world_id, &debug_draw)

	g.render_time_ms = time.duration_milliseconds(time.tick_since(render_start))
}


Game_AddEntity :: proc(entity: Entity) {
	assert(b2.IsValid(entity.body_id))

	// inventory
	#partial switch v in entity.variant {
	case Ball:
		g.remaining_balls += 1
	case Block:
		g.remaining_blocks += 1
	}

	Pool_Add(&g.entity_pool, entity)
}
