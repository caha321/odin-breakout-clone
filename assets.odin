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

load_assets :: proc() -> bool {
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

play_hit_sound :: proc(sound: Sound, hit: b2.ContactHitEvent) {
	rl_sound := g.sounds[sound]
	if rl.IsSoundValid(rl_sound) {
		volume := clamp(hit.approachSpeed / 15.0, 0.2, 1.0)
		pan := clamp(hit.point.x / ARENA_HALF_WIDTH, -1, 1)

		rl.SetSoundPan(rl_sound, pan)
		rl.SetSoundVolume(rl_sound, volume)
		rl.PlaySound(rl_sound)
	} else {
		log.warn("Invalid sound!", sound)
	}
}
