package engine

import "core:fmt"
import "core:log"
import rl "vendor:raylib"

load_texture :: proc(file_name: cstring) -> (rl_texture: rl.Texture2D, ok: bool) {
	full_path := fmt.ctprintf("assets/textures/%s", file_name)
	rl_texture = rl.LoadTexture(full_path)
	if !rl.IsTextureValid(rl_texture) {
		log.error("Could not load texture", full_path)
		return {}, false
	}
	log.info("Successfully loaded texture", full_path)
	return rl_texture, true
}

load_sound :: proc(file_name: cstring) -> (rl_sound: rl.Sound, ok: bool) {
	full_path := fmt.ctprintf("assets/sounds/%s", file_name)
	rl_sound = rl.LoadSound(full_path)
	if !rl.IsSoundValid(rl_sound) {
		log.error("Could not load sound", full_path)
		return {}, false
	}
	log.info("Successfully loaded sound", full_path)
	return rl_sound, true
}

load_music :: proc(file_name: cstring) -> (rl_music: rl.Music, ok: bool) {
	full_path := fmt.ctprintf("assets/music/%s", file_name)
	rl_music = rl.LoadMusicStream(full_path)
	if !rl.IsMusicValid(rl_music) {
		log.error("Could not load music", full_path)
		return {}, false
	}
	log.info("Successfully loaded music", full_path)
	return rl_music, true
}
