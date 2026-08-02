package game

import "base:intrinsics"
import "core:log"
import "core:time"
import b2 "vendor:box2d"
import rl "vendor:raylib"

import "../engine"

DT :: 1.0 / 60.0
SUB_STEP_COUNT :: 4 // Box2D

Game_State :: enum {
	New,
	Running,
	Paused,
	GameOver,
}

Game :: struct {
	state:                  Game_State,
	score:                  i32,
	lives:                  i32, // TODO
	textures:               [Texture]rl.Texture2D,
	sounds:                 [Sound]rl.Sound,
	music:                  [Music]rl.Music,
	entity_pool:            engine.Pool(Entity),
	entity_pool_background: engine.Pool(Entity),
	remaining_balls:        i32,
	remaining_blocks:       i32,
	ball_speed:             f32,
	elapsed_time:           f32, // accumulates frame times while game is running
	// physics stuff
	world_id:               b2.WorldId,
	world_id_background:    b2.WorldId,
	draw_b2_debug:          bool,
	accumulated_time:       f32,
	// perf stats
	update_time_ms:         f64,
	render_time_ms:         f64,
}

g: ^Game

game_init :: proc() -> bool {
	rl.InitAudioDevice()

	g = new(Game)
	g.entity_pool.on_remove = Entity_Destroy
	g.entity_pool_background.on_remove = Entity_Destroy
	load_assets() or_return
	game_update_state(.New)

	return true
}

Game_Run :: proc() -> bool {
	game_init() or_return
	defer game_shutdown()

	rl.PlayMusicStream(g.music[.Game])
	rl.SetMusicVolume(g.music[.Game], 0.4) // TODI via Options menu

	for !rl.WindowShouldClose() {
		Game_Update()
		Game_Render()

		free_all(context.temp_allocator)
	}

	return true
}


// Restart game, resets all state to initial values
game_restart :: proc() {
	g.score = 0
	g.elapsed_time = 0
	g.ball_speed = BALL_SPEED_INITIAL
	game_clear_entities()
	g.remaining_balls = 0
	g.remaining_blocks = 0

	g.world_id = World_Create(gravity = {0, 0})
	create_bounds(g.world_id, true)
	g.world_id_background = World_Create(gravity = {0, -10})
	create_bounds(g.world_id_background, false)


	Paddle_Create()
	Ball_Create({0, 0})
	blocks_create()
}

game_clear_entities :: proc() {
	engine.Pool_Clear(&g.entity_pool)
	engine.Pool_Clear(&g.entity_pool_background)

	if b2.World_IsValid(g.world_id) do b2.DestroyWorld(g.world_id)
	if b2.World_IsValid(g.world_id_background) do b2.DestroyWorld(g.world_id_background)
}

game_shutdown :: proc() {
	game_clear_entities()
	engine.Pool_Delete(g.entity_pool)
	engine.Pool_Delete(g.entity_pool_background)

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

	for rl_music, music in g.music {
		if rl.IsMusicValid(rl_music) {
			log.info("Unloading Music:", music)
			rl.UnloadMusicStream(rl_music)
		}
	}

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
	when ODIN_DEBUG {
		if rl.IsKeyPressed(.F5) {
			intrinsics.debug_trap()
		}
	}
}

Game_Update :: proc() {
	update_start := time.tick_now()

	Game_Handle_Input()
	rl.UpdateMusicStream(g.music[.Game])

	frame_time := rl.GetFrameTime()
	UI_Update(frame_time)

	if g.state == .Running {
		g.accumulated_time += frame_time
		g.elapsed_time += frame_time
	}

	for g.accumulated_time >= DT {
		for &slot in g.entity_pool.slots {
			if !engine.slot_valid(slot.generation) do continue
			Entity_Update(&slot.value, DT)
		}
		b2.World_Step(g.world_id, DT, SUB_STEP_COUNT)
		b2.World_Step(g.world_id_background, DT, SUB_STEP_COUNT)

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

		entity, ok := engine.Pool_Get(g.entity_pool, hit.shapeIdA)
		if ok do Entity_Hit(entity, hit)

		entity, ok = engine.Pool_Get(g.entity_pool, hit.shapeIdB)
		if ok do Entity_Hit(entity, hit)
	}

	for i in 0 ..< events.beginCount { 	// contact begin events
		event := events.beginEvents[i]

		entity_a := engine.Pool_Get(g.entity_pool, event.shapeIdA) or_continue
		entity_b := engine.Pool_Get(g.entity_pool, event.shapeIdB) or_continue

		try_attach_ball(entity_a, entity_b)
		try_attach_ball(entity_b, entity_a)
	}
}

check_sensor_events :: proc() {
	events := b2.World_GetSensorEvents(g.world_id)
	for i in 0 ..< events.beginCount {
		event := events.beginEvents[i]

		sensor_entity, ok := engine.Pool_Get(g.entity_pool, event.sensorShapeId)
		if !ok {
			log.warn("Could not get entity for sensor shape", event.sensorShapeId)
			continue
		}
		visitor_entity: ^Entity
		visitor_entity, ok = engine.Pool_Get(g.entity_pool, event.visitorShapeId)
		if !ok {
			log.warn("Could not get entity for visitor shape", event.visitorShapeId)
			continue
		}

		#partial switch &v in visitor_entity.variant {
		case Ball:
			if sensor_entity.variant != nil do break // ground sensor is nil
			g.remaining_balls -= 1
			engine.Pool_Remove(&g.entity_pool, event.visitorShapeId)
			// only play sound if it does not overlap with game over sound
			if g.remaining_balls > 0 do rl.PlaySound(g.sounds[.BallLost])

		case Paddle:
			powerup: Powerup
			powerup, ok = sensor_entity.variant.(Powerup)
			if !ok do break

			Paddle_ApplyPowerup(visitor_entity, &v, powerup.kind)
			rl.PlaySound(g.sounds[.PowerupCollected])
			engine.Pool_Remove(&g.entity_pool, event.sensorShapeId) // powerup is the sensor

		case Powerup:
			if sensor_entity.variant != nil do break // ground sensor is nil
			// clean up missed powerups
			engine.Pool_Remove(&g.entity_pool, event.visitorShapeId) // powerup is the visitor
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
	rl.ClearBackground(rl.BEIGE)

	// draw background first
	for &slot in g.entity_pool_background.slots {
		if !engine.slot_valid(slot.generation) do continue
		Entity_Draw(&slot.value)
	}

	for &slot in g.entity_pool.slots {
		if !engine.slot_valid(slot.generation) do continue
		Entity_Draw(&slot.value)
	}

	ui_draw()

	if g.draw_b2_debug {
		b2.World_Draw(g.world_id_background, &debug_draw)
		b2.World_Draw(g.world_id, &debug_draw)
	}


	g.render_time_ms = time.duration_milliseconds(time.tick_since(render_start))
}


Game_AddEntity :: proc(entity: Entity) {
	assert(b2.IsValid(entity.body_id))

	if b2.Body_GetWorld(entity.body_id) == g.world_id {
		// inventory
		#partial switch v in entity.variant {
		case Ball:
			g.remaining_balls += 1
		case Block:
			g.remaining_blocks += 1
		}

		engine.Pool_Add(&g.entity_pool, entity)
		log.debug("Added entity to main pool", entity.body_id)
	} else {
		engine.Pool_Add(&g.entity_pool_background, entity)
		log.debug("Added entity to background pool", entity.body_id)
	}
}
