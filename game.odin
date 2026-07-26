package breakout

import "core:log"
import b2 "vendor:box2d"
import rl "vendor:raylib"


// all available sounds in the game
Sound :: enum {
	NoSound,
	HitBlock,
	HitPaddle,
	HitWall,
	GameStart,
	GameOver,
}

// all available textures in the game
Texture :: enum {
	NoTexture,
	BallGrey,
	PaddleBlue,
	BlockBlue,
	BlockGreen,
	BlockGrey,
	BlockPurple,
	BlockRed,
	BlockYellow,
}

Game_State :: enum {
	New,
	Running,
	Paused,
	GameOver,
}

Game :: struct {
	state:         Game_State,
	score:         int,
	textures:      [Texture]rl.Texture2D,
	sounds:        [Sound]rl.Sound,
	entities:      [dynamic]Entity,
	ball_speed:    f32,
	world_id:      b2.WorldId,
	draw_b2_debug: bool,
}

g: ^Game

game_init :: proc() -> bool {
	rl.InitAudioDevice()

	g = new(Game)
	game_load_assets() or_return
	game_update_state(.New)

	return true
}

game_load_assets :: proc() -> bool {
	load_texture("assets/ballGrey.png", .BallGrey) or_return
	load_texture("assets/paddleBlu.png", .PaddleBlue) or_return

	load_texture("assets/element_blue_rectangle.png", .BlockBlue) or_return
	load_texture("assets/element_green_rectangle.png", .BlockGreen) or_return
	load_texture("assets/element_grey_rectangle.png", .BlockGrey) or_return
	load_texture("assets/element_purple_rectangle.png", .BlockPurple) or_return
	load_texture("assets/element_red_rectangle.png", .BlockRed) or_return
	load_texture("assets/element_yellow_rectangle.png", .BlockYellow) or_return

	load_sound("assets/impactTin_medium_001.ogg", .HitBlock) or_return
	load_sound("assets/impactPlate_medium_000.ogg", .HitPaddle) or_return
	load_sound("assets/impactMetal_medium_004.ogg", .HitWall) or_return
	load_sound("assets/jingles_PIZZI02.ogg", .GameStart) or_return
	load_sound("assets/jingles_PIZZI01.ogg", .GameOver) or_return

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

load_texture :: proc(file_name: cstring, texture: Texture) -> bool {
	rl_texture := rl.LoadTexture(file_name)
	if rl_texture.id <= 0 {
		log.error("Could not load texture:", file_name)
		return false
	}
	log.info("Loading Texture:", file_name, "as", texture)
	g.textures[texture] = rl_texture
	return true
}

load_sound :: proc(file_name: cstring, sound: Sound) -> bool {
	rl_sound := rl.LoadSound(file_name)
	if !rl.IsSoundValid(rl_sound) {
		log.error("Could not load sound:", file_name)
		return false
	}
	log.info("Loaded Sound:", file_name, "as", sound)
	g.sounds[sound] = rl_sound
	return true
}
