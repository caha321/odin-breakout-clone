package ui

import rl "vendor:raylib"

Text_Align :: enum {
	Left,
	Center,
	Right,
}

DEFAULT_BG_COLOR :: rl.Color{64, 64, 64, 128}

draw_text_aligned :: proc "contextless" (
	font: rl.Font,
	text: cstring,
	pos: [2]f32,
	font_size: f32,
	color: rl.Color,
	align: Text_Align,
) {
	draw_pos := pos

	switch align {
	case .Left:
		break
	case .Center:
		draw_pos.x -= rl.MeasureTextEx(font, text, font_size, FONT_SPACING).x / 2
	case .Right:
		draw_pos.x -= rl.MeasureTextEx(font, text, font_size, FONT_SPACING).x
	}

	rl.DrawTextEx(font, text, draw_pos, font_size, FONT_SPACING, color)
}

draw_text_with_shadow :: proc "contextless" (
	font: rl.Font,
	text: cstring,
	pos: [2]f32,
	font_size: f32,
	color: rl.Color,
	shadow_color: rl.Color = {0, 0, 0, 180},
	shadow_offset: [2]f32 = {4, 4},
	align: Text_Align = .Left,
) {
	draw_text_aligned(font, text, pos + shadow_offset, font_size, shadow_color, align)
	draw_text_aligned(font, text, pos, font_size, color, align)
}

draw_text_with_background :: proc "contextless" (
	font: rl.Font,
	text: cstring,
	center: [2]f32,
	font_size: f32,
	text_color: rl.Color = rl.WHITE,
	bg_color: rl.Color = DEFAULT_BG_COLOR,
	padding: [2]f32 = {0, 0},
) {
	text_measure := rl.MeasureTextEx(font, text, font_size, FONT_SPACING)

	pos := [2]f32{center.x - text_measure.x / 2, center.y - text_measure.y / 2}

	background_rec := rl.Rectangle {
		pos.x - padding.x,
		pos.y - padding.y,
		text_measure.x + padding.x * 2,
		text_measure.y + padding.y * 2,
	}

	rl.DrawRectangleRec(background_rec, bg_color)
	rl.DrawTextEx(font, text, pos, font_size, FONT_SPACING, text_color)
}
