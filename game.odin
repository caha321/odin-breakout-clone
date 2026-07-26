package breakout

import "core:log"
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
	entities:         [dynamic]Entity,
	remaining_balls:  int,
	remaining_blocks: int,
	ball_speed:       f32,
	// physics stuff
	world_id:         b2.WorldId,
	draw_b2_debug:    bool,
	accumulated_time: f32,
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
	for &entity in g.entities {
		Entity_Destroy(&entity)
	}
	clear(&g.entities)

	if b2.World_IsValid(g.world_id) do b2.DestroyWorld(g.world_id)
}

game_shutdown :: proc() {
	game_clear_entities()

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

	// TODO how to delete g?
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
	if g.state == .Running {
		g.accumulated_time += rl.GetFrameTime()
	}

	for g.accumulated_time >= DT {
		for &entity in g.entities {
			if entity.update != nil do entity.update(&entity, DT)
		}

		b2.World_Step(g.world_id, DT, SUB_STEP_COUNT)

		check_sensor_events(g.world_id)
		check_contact_events(g.world_id)

		g.accumulated_time -= DT
	}
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
		event := events.beginEvents[i]

		entity := get_entity(b2.Shape_GetUserData(event.visitorShapeId))
		if entity != nil {
			g.remaining_balls -= 1
			Entity_Destroy(entity)
		}
	}

	if g.remaining_balls <= 0 {
		game_update_state(.GameOver)
	}
}

Game_Loop :: proc() {
	debug_draw := init_debug_draw()

	for !rl.WindowShouldClose() {
		Game_Handle_Input()
		Game_Update()

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
}

Game_AddEntity :: proc(entity: Entity) {
	assert(b2.IsValid(entity.body_id))
	assert(b2.IsValid(entity.shape_id))

	entity_id := entity_index_to_userdata(len(g.entities))
	b2.Shape_SetUserData(entity.shape_id, entity_id)

	// inventory

	#partial switch extra in entity.extra {
	case Entity_Extra_Ball:
		g.remaining_balls += 1
	case Entity_Extra_Block:
		g.remaining_blocks += 1
	}

	append(&g.entities, entity)
}
