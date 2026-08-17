package game

import b2 "vendor:box2d"
import rl "vendor:raylib"

import "../engine"

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
	Background,
	ParticleCircle5,
	// Powerups
	PowerupExtraBall,
	PowerupPaddleSmall,
	PowerupPaddleWide,
	PowerupPaddleSticky,
	PowerupPaddleTilt,
}

Music :: enum {
	NoMusic,
	Game,
}

load_assets :: proc() -> bool {
	// font is required by powerup texture generation
	g.font = rl.LoadFontEx("assets/DepartureMono-Regular.otf", 128, nil, 0)
	if !rl.IsFontValid(g.font) do return false

	// textures
	g.textures[.BallGrey] = engine.load_texture("ballGrey.png") or_return
	g.textures[.BallBlue] = engine.load_texture("ballBlue.png") or_return
	g.textures[.PaddleBlue] = engine.load_texture("paddleBlu.png") or_return

	g.textures[.BlockBlue] = engine.load_texture("element_blue_rectangle.png") or_return
	g.textures[.BlockGreen] = engine.load_texture("element_green_rectangle.png") or_return
	g.textures[.BlockGrey] = engine.load_texture("element_grey_rectangle.png") or_return
	g.textures[.BlockPurple] = engine.load_texture("element_purple_rectangle.png") or_return
	g.textures[.BlockRed] = engine.load_texture("element_red_rectangle.png") or_return
	g.textures[.BlockYellow] = engine.load_texture("element_yellow_rectangle.png") or_return

	g.textures[.Background] = engine.load_texture("backgroundEmpty.png") or_return

	g.textures[.ParticleCircle5] = engine.load_texture("particles/circle_05.png") or_return

	create_powerup_textures() or_return

	engine.build_atlas() or_return

	// sounds
	g.sounds[.HitBlock] = engine.load_sound("impactTin_medium_001.ogg") or_return
	g.sounds[.HitPaddle] = engine.load_sound("impactPlate_medium_000.ogg") or_return
	g.sounds[.HitWall] = engine.load_sound("impactMetal_medium_004.ogg") or_return
	g.sounds[.GameStart] = engine.load_sound("jingles_PIZZI02.ogg") or_return
	g.sounds[.GameOver] = engine.load_sound("jingles_PIZZI01.ogg") or_return
	g.sounds[.BallLost] = engine.load_sound("lowDown.ogg") or_return
	g.sounds[.PowerupCollected] = engine.load_sound("powerUp2.ogg") or_return

	// music
	g.music[.Game] = engine.load_music("397 [Misc Extras] bgm_space_upbeat_F.ogg") or_return

	return true
}


play_hit_sound :: #force_inline proc(
	sound: Sound,
	hit: b2.ContactHitEvent,
	location := #caller_location,
) {
	engine.play_hit_sound(g.sounds[sound], hit.point, hit.approachSpeed, location = location)
}
