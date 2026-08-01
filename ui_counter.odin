package breakout

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

// The "Pop" effect scales the counter's rendered text up momentarily when its
// value changes, then eases back down to normal size
Effect_Pop :: struct {
	_scale: f32, // DO NOT SET MANUALLY. Current scale multiplier applied to font size
	amount: f32, // Scale to jump to the instant the counter's value changes. 1.4 means 40%
	speed:  f32, // How quickly `scale` eases back toward 1.0. Higher values settle faster
}

// The "Pulse" effect fades the counter's color from `color` back to the
// counter's base color over time
Effect_Pulse :: struct {
	_progress: f32, // DO NOT SET MANUALLY. Fade progress 0->1
	speed:     f32, // How quickly the effect settles. Higher values settle faster
	color:     rl.Color, // The flash color
}

// The "Shake" effect applies a small random positional jitter to the counter's
// rendered text for a short duration after its value changes.
Effect_Shake :: struct {
	_timer:   f32, // DO NOT SET MANUALLY. Seconds remaining in the current shake.
	duration: f32, // How long, in seconds, the shake lasts after each value change.
	strength: f32, // Maximum jitter offset in pixels
}

Counter_Effect :: union {
	Effect_Pop,
	Effect_Pulse,
	Effect_Shake,
}

Counter :: struct {
	value:                 i32, // DO NOT SET MANUALLY. Current value of the counter
	base_color:            rl.Color,
	font_size:             f32,
	// effects applied on value change
	increase_effects:      [2]Counter_Effect,
	increase_effect_count: u8,
	decrease_effects:      [2]Counter_Effect,
	decrease_effect_count: u8,
	active_is_increase:    bool, // whether increase effects are active
}

Counter_Create :: proc "contextless" (
	base_color: rl.Color,
	font_size: f32,
	on_increase: []Counter_Effect = {},
	on_decrease: []Counter_Effect = {},
) -> Counter {
	counter := Counter {
		base_color = base_color,
		font_size  = font_size,
	}
	for effect, index in on_increase do counter.increase_effects[index] = effect
	counter.increase_effect_count = u8(len(on_increase))
	for effect, index in on_decrease do counter.decrease_effects[index] = effect
	counter.decrease_effect_count = u8(len(on_decrease))

	return counter
}

// Returns a pointer to whichever array is currently active and its count
@(require_results)
Counter_ActiveEffects :: proc(self: ^Counter) -> (effects: ^[2]Counter_Effect, count: u8) {
	if self.active_is_increase {
		return &self.increase_effects, self.increase_effect_count
	}
	return &self.decrease_effects, self.decrease_effect_count
}

Counter_Update :: proc(self: ^Counter, new_value: i32, dt: f32) {
	if new_value > self.value {
		self.active_is_increase = true
	} else if new_value < self.value {
		self.active_is_increase = false
	}

	changed := new_value != self.value
	self.value = new_value

	effects, count := Counter_ActiveEffects(self)
	for index in 0 ..< count {
		switch &v in &effects[index] {
		case Effect_Pop:
			if changed do v._scale = v.amount if v.amount > 0 else 1.4
			v._scale += (1.0 - v._scale) * min(dt * (v.speed if v.speed > 0 else 12), 1)

		case Effect_Pulse:
			if changed do v._progress = 0
			v._progress = min(v._progress + dt * (v.speed if v.speed > 0 else 3), 1)

		case Effect_Shake:
			if changed do v._timer = v.duration
			v._timer = max(v._timer - dt, 0)
		}
	}
}

Text_Align :: enum {
	Left,
	Center,
	Right,
}

Counter_Draw :: proc(self: ^Counter, pos: [2]i32, format: string, align: Text_Align = .Left) {
	shake_offset := rl.Vector2{}
	color := self.base_color
	size := self.font_size
	draw_pos: [2]f32 = {f32(pos.x), f32(pos.y)}

	effects, count := Counter_ActiveEffects(self)
	for index in 0 ..< count {
		switch &v in &effects[index] {
		case Effect_Pop:
			size *= v._scale
		case Effect_Pulse:
			color = rl.ColorLerp(v.color, self.base_color, v._progress)
		case Effect_Shake:
			if v._timer > 0 {
				shake_offset = {
					rand.float32_range(-v.strength, v.strength),
					rand.float32_range(-v.strength, v.strength),
				}
			}
		}
	}

	draw_pos += shake_offset
	text := fmt.ctprintf(format, self.value)
	switch align {
	case .Left:
		break // no change
	case .Center:
		draw_pos.x -= f32(rl.MeasureText(text, i32(size))) / 2
	case .Right:
		draw_pos.x -= f32(rl.MeasureText(text, i32(size)))
	}
	rl.DrawText(text, i32(draw_pos.x), i32(draw_pos.y), i32(size), color)
}
