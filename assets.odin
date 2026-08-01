package breakout

import "core:fmt"
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
	BallLost,
	PowerupCollected,
}

// all available textures in the game
Texture :: enum {
	NoTexture,
	BallGrey,
	BallBlue,
	PaddleBlue,
	BlockBlue,
	BlockGreen,
	BlockGrey,
	BlockPurple,
	BlockRed,
	BlockYellow,
}

Music :: enum {
	NoMusic,
	Game,
}

load_assets :: proc() -> bool {
	load_texture("ballGrey.png", .BallGrey) or_return
	load_texture("ballBlue.png", .BallBlue) or_return
	load_texture("paddleBlu.png", .PaddleBlue) or_return

	load_texture("element_blue_rectangle.png", .BlockBlue) or_return
	load_texture("element_green_rectangle.png", .BlockGreen) or_return
	load_texture("element_grey_rectangle.png", .BlockGrey) or_return
	load_texture("element_purple_rectangle.png", .BlockPurple) or_return
	load_texture("element_red_rectangle.png", .BlockRed) or_return
	load_texture("element_yellow_rectangle.png", .BlockYellow) or_return

	load_sound("impactTin_medium_001.ogg", .HitBlock) or_return
	load_sound("impactPlate_medium_000.ogg", .HitPaddle) or_return
	load_sound("impactMetal_medium_004.ogg", .HitWall) or_return
	load_sound("jingles_PIZZI02.ogg", .GameStart) or_return
	load_sound("jingles_PIZZI01.ogg", .GameOver) or_return
	load_sound("lowDown.ogg", .BallLost) or_return
	load_sound("powerUp2.ogg", .PowerupCollected) or_return

	load_music("397 [Misc Extras] bgm_space_upbeat_F.ogg", .Game) or_return

	return true
}


load_texture :: proc(file_name: cstring, texture: Texture) -> bool {
	file_name := fmt.ctprintf("assets/textures/%s", file_name)
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
	file_name := fmt.ctprintf("assets/sounds/%s", file_name)
	rl_sound := rl.LoadSound(file_name)
	if !rl.IsSoundValid(rl_sound) {
		log.error("Could not load sound:", file_name)
		return false
	}
	log.info("Loaded Sound:", file_name, "as", sound)
	g.sounds[sound] = rl_sound
	return true
}

load_music :: proc(file_name: cstring, music: Music) -> bool {
	file_name := fmt.ctprintf("assets/music/%s", file_name)
	rl_music := rl.LoadMusicStream(file_name)
	if !rl.IsMusicValid(rl_music) {
		log.error("Could not load music:", file_name)
		return false
	}
	log.info("Loaded Music:", file_name, "as", music)
	g.music[music] = rl_music
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
