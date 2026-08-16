package ui

import rl "vendor:raylib"

DEFAULT_BG_COLOR :: rl.Color{64, 64, 64, 128}


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
