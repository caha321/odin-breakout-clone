package ui

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

FONT_SPACING :: 1

// The "Pop" effect scales the counter's rendered text up momentarily when its
// value changes, then eases back down to normal size
Effect_Pop :: struct {
	_scale: f32, // DO NOT SET MANUALLY. Current scale multiplier applied to font size
	amount: f32, // Scale to jump to the instant the counter's value changes. Default 1.4 means 40%
	speed:  f32, // How quickly `scale` eases back toward 1.0. Default 12.0; Higher values settle faster
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
	font:                  ^rl.Font,
	font_size:             f32,
	// effects applied on value change
	increase_effects:      [2]Counter_Effect,
	increase_effect_count: u8,
	decrease_effects:      [2]Counter_Effect,
	decrease_effect_count: u8,
	active_is_increase:    bool, // whether increase effects are active
	change_granularity:    i32, // effects trigger only when value/granularity changes; 0 or 1 = every change (default)
}

Counter_Create :: proc "contextless" (
	base_color: rl.Color,
	font: ^rl.Font,
	font_size: f32,
	on_increase: []Counter_Effect = {},
	on_decrease: []Counter_Effect = {},
	change_granularity: i32 = 1,
) -> Counter {
	counter := Counter {
		base_color         = base_color,
		font               = font,
		font_size          = font_size,
		change_granularity = change_granularity,
	}
	for effect, index in on_increase do counter.increase_effects[index] = effect
	counter.increase_effect_count = u8(len(on_increase))
	for effect, index in on_decrease do counter.decrease_effects[index] = effect
	counter.decrease_effect_count = u8(len(on_decrease))

	return counter
}

// Returns a pointer to whichever array is currently active and its count
@(require_results)
Counter_ActiveEffects :: proc "contextless" (
	self: ^Counter,
) -> (
	effects: ^[2]Counter_Effect,
	count: u8,
) {
	if self.active_is_increase {
		return &self.increase_effects, self.increase_effect_count
	}
	return &self.decrease_effects, self.decrease_effect_count
}

Counter_Update :: proc "contextless" (self: ^Counter, new_value: i32, dt: f32) {
	granularity := self.change_granularity if self.change_granularity > 0 else 1
	old_bucket := self.value / granularity
	new_bucket := new_value / granularity

	if new_value > self.value {
		self.active_is_increase = true
	} else if new_value < self.value {
		self.active_is_increase = false
	}

	changed := new_bucket != old_bucket
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

@(private = "file")
Counter_ComputeDrawState :: proc(
	self: ^Counter,
) -> (
	size: f32,
	color: rl.Color,
	shake_offset: rl.Vector2,
) {
	color = self.base_color
	size = self.font_size

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
	return
}

@(private = "file")
Counter_DrawText :: proc(
	self: ^Counter,
	text: cstring,
	pos: [2]f32,
	font_size: f32,
	color: rl.Color,
	shake_offset: rl.Vector2,
	align: Text_Align,
) {
	draw_pos: [2]f32 = pos + shake_offset

	assert(self.font != nil)

	switch align {
	case .Left:
		break
	case .Center:
		draw_pos.x -= rl.MeasureTextEx(self.font^, text, font_size, FONT_SPACING).x / 2
	case .Right:
		draw_pos.x -= rl.MeasureTextEx(self.font^, text, font_size, FONT_SPACING).x
	}
	rl.DrawTextEx(self.font^, text, draw_pos, font_size, FONT_SPACING, color)
}

Counter_Draw :: proc(self: ^Counter, pos: [2]f32, format: string, align: Text_Align = .Left) {
	size, color, shake_offset := Counter_ComputeDrawState(self)
	text := fmt.ctprintf(format, self.value)
	Counter_DrawText(self, text, pos, size, color, shake_offset, align)
}

// Treats self.value as total milliseconds and draws it as mm:ss.mmm
Counter_DrawTime :: proc(self: ^Counter, pos: [2]f32, align: Text_Align = .Left) {
	size, color, shake_offset := Counter_ComputeDrawState(self)

	total_ms := self.value
	minutes := total_ms / 60000
	seconds := (total_ms / 1000) % 60
	milliseconds := total_ms % 1000

	text: cstring
	if minutes > 0 {
		text = fmt.ctprintf("%d:%02d.%03d", minutes, seconds, milliseconds)
	} else {
		text = fmt.ctprintf("%d.%03d", seconds, milliseconds)
	}
	Counter_DrawText(self, text, pos, size, color, shake_offset, align)
}
