package game

import "base:intrinsics"
import "core:log"
import "core:time"
import b2 "vendor:box2d"
import rl "vendor:raylib"

import "../engine"
import "../engine/ui"

DT :: 1.0 / 60.0
SUB_STEP_COUNT :: 4 // Box2D

Game_State :: enum {
	New,
	Running,
	Paused,
	GameOver,
}

Game :: struct {
	state:            Game_State,
	config:           Config,
	player:           Player,
	ui:               UI,
	textures:         [Texture]engine.AtlasRegion,
	sounds:           [Sound]rl.Sound,
	music:            [Music]rl.Music,
	font:             rl.Font,
	entity_pool:      engine.Pool(Entity),
	particle_system:  engine.ParticleSystem,
	//
	remaining_balls:  i32,
	remaining_blocks: i32,
	ball_speed:       f32,
	// physics stuff
	world_id:         b2.WorldId,
	draw_b2_debug:    bool,
	accumulated_time: f32,
	tick_count:       u64, // total physics step count
	// perf stats
	update_time_ms:   f64,
	render_time_ms:   f64,
}

g: ^Game

@(private = "file")
game_init :: proc() -> bool {
	rl.InitAudioDevice()

	g = new(Game)
	g.entity_pool.on_remove = Entity_Destroy
	g.particle_system = engine.ParticleSystem_Init(capacity = 200)
	engine.init_atlas()

	load_assets() or_return
	UI_Init(&g.ui)

	game_update_state(.New)
	g.config = engine.Config_Init(CONFIG_FILE_NAME, DEFAULT_CONFIG)

	return true
}

Game_Run :: proc() -> bool {
	game_init() or_return
	defer game_shutdown()

	rl.PlayMusicStream(g.music[.Game])
	rl.SetMusicVolume(g.music[.Game], g.config.audio.music_volume)

	for !rl.WindowShouldClose() {
		Game_Update()
		Game_Render()

		free_all(context.temp_allocator)
	}

	return true
}


// Restart game, resets all state to initial values
game_restart :: proc() {
	g.player = Player_Init()
	g.ball_speed = BALL_SPEED_INITIAL
	game_clear_entities()
	g.remaining_balls = 0
	g.remaining_blocks = 0
	g.tick_count = 0

	g.world_id = World_Create(gravity = {0, -10}) // TODO defined by level
	create_bounds(g.world_id)
	Paddle_Create()
	Ball_Create({0, 0})
	blocks_create()
}

game_clear_entities :: proc() {
	engine.Pool_Clear(&g.entity_pool)
	engine.ParticleSystem_Clear(&g.particle_system)

	if b2.World_IsValid(g.world_id) do b2.DestroyWorld(g.world_id)
}

game_shutdown :: proc() {
	game_clear_entities()
	engine.Pool_Delete(g.entity_pool)
	engine.ParticleSystem_Destroy(g.particle_system)
	engine.destory_atlas()

	// for rl_texture, texture in g.textures {
	// 	if rl.IsTextureValid(rl_texture) {
	// 		log.info("Unloading Texture:", texture)
	// 		rl.UnloadTexture(rl_texture)
	// 	}
	// }

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

	engine.Config_Write(g.config, CONFIG_FILE_NAME)

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
	UI_Update(&g.ui, frame_time)
	engine.shake_update(frame_time)

	if g.state == .Running {
		g.accumulated_time += frame_time
		Player_Update(&g.player, frame_time)
	}

	for g.accumulated_time >= DT {
		g.tick_count += 1
		engine.ParticleSystem_Update(&g.particle_system, DT)

		for &slot in g.entity_pool.slots {
			if !engine.slot_valid(slot.generation) do continue
			Entity_Update(&slot.value, DT)
		}

		b2.World_Step(g.world_id, DT, SUB_STEP_COUNT)

		check_sensor_events()
		check_contact_events()

		g.accumulated_time -= DT
	}

	g.update_time_ms = time.duration_milliseconds(time.tick_since(update_start))
}

@(private = "file")
check_contact_events :: proc() {
	events := b2.World_GetContactEvents(g.world_id)

	for i in 0 ..< events.hitCount {
		hit := events.hitEvents[i]

		entity_a := engine.Pool_Get(g.entity_pool, hit.shapeIdA) or_continue
		entity_b := engine.Pool_Get(g.entity_pool, hit.shapeIdB) or_continue

		// entity_a was hit; normal points A -> B (away from A), as Box2D reports it
		Entity_Hit(entity_a, entity_b, hit)

		// entity_b was hit; normal needs to point B -> A instead
		hit_b := hit
		hit_b.normal = -hit.normal
		Entity_Hit(entity_b, entity_a, hit_b)
	}

	for i in 0 ..< events.beginCount { 	// contact begin events
		event := events.beginEvents[i]

		entity_a := engine.Pool_Get(g.entity_pool, event.shapeIdA) or_continue
		entity_b := engine.Pool_Get(g.entity_pool, event.shapeIdB) or_continue

		try_attach_ball(entity_a, entity_b)
		try_attach_ball(entity_b, entity_a)
	}
}

@(private = "file")
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
			if g.remaining_balls > 0 {
				engine.shake_add_trauma(.5)
				rl.PlaySound(g.sounds[.BallLost])
			}

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
		engine.shake_add_trauma(1)
		game_update_state(.GameOver)
	}
}

@(private = "file")
debug_draw := engine.init_debug_draw()

Game_Render :: proc() {
	render_start := time.tick_now()
	rl.BeginDrawing()
	defer rl.EndDrawing()

	engine.draw_background(g.textures[.Background])

	rl.BeginMode2D(engine.camera)

	engine.ParticleSystem_Draw(&g.particle_system)

	#reverse for &slot in g.entity_pool.slots {
		if !engine.slot_valid(slot.generation) do continue
		Entity_Draw(&slot.value)
	}

	if g.draw_b2_debug {
		b2.World_Draw(g.world_id, &debug_draw)
	}

	rl.EndMode2D()

	UI_Draw(&g.ui)

	g.render_time_ms = time.duration_milliseconds(time.tick_since(render_start))
}


Game_AddEntity :: proc(entity: Entity) {
	assert(b2.IsValid(entity.body_id))

	#partial switch v in entity.variant {
	case Ball:
		g.remaining_balls += 1
	case Block:
		g.remaining_blocks += 1
	}

	engine.Pool_Add(&g.entity_pool, entity)
	log.debug("Added entity to pool", entity.body_id)
}
