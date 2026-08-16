package engine

import "core:log"
import rl "vendor:raylib"

play_hit_sound :: proc(
	rl_sound: rl.Sound,
	hit_point: [2]f32,
	approach_speed: f32,
	location := #caller_location,
) {
	if rl.IsSoundValid(rl_sound) {
		volume := clamp(approach_speed / 15.0, 0.0, 1.0) // TODO g.config.audio.hit_sound_volume

		screen_pos := world_to_screen(hit_point)
		pan := clamp((screen_pos.x / f32(screen.width)) * 2 - 1, -1, 1)

		rl.SetSoundPan(rl_sound, pan)
		rl.SetSoundVolume(rl_sound, volume)
		rl.PlaySound(rl_sound)
	} else {
		log.warn("Invalid sound!", location = location)
	}
}
