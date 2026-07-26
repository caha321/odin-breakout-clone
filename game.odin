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
	textures:         [Texture]rl.Texture2D,
	sounds:           [Sound]rl.Sound,
	entities:         [dynamic]Entity,
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

	append(&g.entities, entity)
}
