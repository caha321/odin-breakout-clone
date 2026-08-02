package game

COMBO_TIME_WINDOW :: 1 // in seconds
COMBO_MULTIPLIER_MAX :: 32 // max multiplier, otherwise the score gets crazy with multiple balls

Player :: struct {
	score:            i32,
	combo_multiplier: i32,
	combo_time_start: f32,
	lives:            i32, // TODO
	elapsed_time:     f32, // accumulates frame times while game is running
}

Player_Init :: proc "contextless" (lives: i32 = 3) -> Player {
	return Player{combo_multiplier = 1, combo_time_start = -1000, lives = lives}
}

// adds given score, multiplied by current combo multiplier
Player_AddScore :: proc "contextless" (self: ^Player, score: i32) {
	if Player_ComboTimeRemaining(self^) > 0 {
		self.combo_multiplier = min(self.combo_multiplier * 2, COMBO_MULTIPLIER_MAX)
	}
	self.score += score * self.combo_multiplier
	self.combo_time_start = self.elapsed_time
}

Player_ComboTimeRemaining :: #force_inline proc "contextless" (self: Player) -> f32 {
	return max((self.combo_time_start + COMBO_TIME_WINDOW) - self.elapsed_time, 0)
}

// called once per frame
Player_Update :: #force_inline proc "contextless" (self: ^Player, dt: f32) {
	self.elapsed_time += dt
	if Player_ComboTimeRemaining(self^) <= 0 do self.combo_multiplier = 1
}
