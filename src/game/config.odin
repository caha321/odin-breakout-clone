package game

ConfigAudio :: struct {
	hit_sound_volume: f32,
	music_volume:     f32,
}

Config :: struct {
	audio: ConfigAudio,
}

DEFAULT_CONFIG :: Config {
	audio = {hit_sound_volume = 1, music_volume = .4},
}

CONFIG_FILE_NAME :: "config.json"
