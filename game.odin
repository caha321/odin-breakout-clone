package breakout

import "core:log"
import b2 "vendor:box2d"
import rl "vendor:raylib"

EntityKind :: enum {
	Unknown,
	Ball,
	Paddle,
	Block,
	Wall,
}

// used as user data in b2 shapes
User_Data :: struct {
	sound_hit:   Sound,
	entity_kind: EntityKind,
	entity_id:   uint, // must be > 0 to be valid
}


Entity :: struct {
	kind:      EntityKind,
	body_id:   b2.BodyId,
	shape_id:  b2.ShapeId,
	user_data: ^User_Data, // b2 userdata, owned by the entity
	texture:   Texture,
}


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
	GameOver,
}

Game :: struct {
	state:         Game_State,
	score:         int,
	textures:      [Texture]rl.Texture2D,
	sounds:        [Sound]rl.Sound,
	ball_speed:    f32,
	draw_b2_debug: bool,
}

g: ^Game

game_init :: proc() -> bool {
	g = new(Game)

	game_restart()

	rl.InitAudioDevice()

	game_load_assets() or_return

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
	game_update_state(.New)
	g.ball_speed = BALL_SPEED_INITIAL
}

game_shutdown :: proc() {
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

	rl.CloseAudioDevice()

	// TODO how to delete g?
}

game_update_state :: proc(state: Game_State) {
	if state == g.state {
		log.warn("Not updating game state")
		return
	}
	log.debug("Updating game state:", state)

	switch state {
	case .New:
		rl.ShowCursor()
	case .Running:
		rl.PlaySound(g.sounds[.GameStart])
		rl.HideCursor()
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
