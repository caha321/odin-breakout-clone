package game

import "core:fmt"
import b2 "vendor:box2d"
import rl "vendor:raylib"

import "../engine/ui"

BORDER_WIDTH :: (ARENA_HALF_WIDTH + WALL_THICKNESS * 2) * PPM / 2
BORDER_COLOR :: rl.BLACK

UI_TEXT_Y :: 10
UI_TEXT_X_BORDER_LEFT :: 10
UI_TEXT_X_BORDER_RIGHT :: BORDER_WIDTH + (ARENA_HALF_WIDTH * 2 * PPM)
UI_TEXT_X_OFFSET :: BORDER_WIDTH - 30

UI_FONT_SIZE :: 40
UI_FONT_COLOR :: rl.WHITE

score_counter := ui.Counter_Create(
	UI_FONT_COLOR,
	UI_FONT_SIZE,
	on_increase = {ui.Effect_Pulse{color = rl.GREEN}},
	on_decrease = {ui.Effect_Pulse{color = rl.RED}},
)

time_counter := ui.Counter_Create(
	UI_FONT_COLOR,
	UI_FONT_SIZE,
	on_increase = {ui.Effect_Pop{}, ui.Effect_Pulse{color = rl.GRAY}},
)

ball_counter := ui.Counter_Create(
	UI_FONT_COLOR,
	UI_FONT_SIZE,
	on_increase = {ui.Effect_Pop{}, ui.Effect_Pulse{color = rl.GREEN}},
	on_decrease = {ui.Effect_Shake{duration = 1, strength = 3}, ui.Effect_Pulse{color = rl.RED}},
)

block_counter := ui.Counter_Create(
	UI_FONT_COLOR,
	UI_FONT_SIZE,
	on_decrease = {
		ui.Effect_Shake{duration = .25, strength = 2},
		ui.Effect_Pulse{color = rl.GREEN},
	},
)

UI_Update :: proc(dt: f32) {
	ui.Counter_Update(&score_counter, g.score, dt)
	ui.Counter_Update(&time_counter, i32(g.elapsed_time), dt)
	ui.Counter_Update(&ball_counter, g.remaining_balls, dt)
	ui.Counter_Update(&block_counter, g.remaining_blocks, dt)
}

ui_draw :: proc() {
	// borders
	rl.DrawRectangle(0, 0, BORDER_WIDTH, SCREEN_HEIGHT, BORDER_COLOR) // Left
	rl.DrawRectangle(SCREEN_WIDTH - BORDER_WIDTH, 0, BORDER_WIDTH, SCREEN_HEIGHT, BORDER_COLOR) // Right


	text_y: i32 = UI_TEXT_Y
	rl.DrawText("SCORE", UI_TEXT_X_BORDER_LEFT, text_y, UI_FONT_SIZE, UI_FONT_COLOR)
	ui.Counter_Draw(
		&score_counter,
		{UI_TEXT_X_BORDER_LEFT + UI_TEXT_X_OFFSET, text_y},
		"%5d",
		.Right,
	)

	text_y += UI_FONT_SIZE
	rl.DrawText("BALLS", UI_TEXT_X_BORDER_LEFT, text_y, UI_FONT_SIZE, UI_FONT_COLOR)
	ui.Counter_Draw(
		&ball_counter,
		{UI_TEXT_X_BORDER_LEFT + UI_TEXT_X_OFFSET, text_y},
		"%2d",
		.Right,
	)

	text_y += UI_FONT_SIZE
	rl.DrawText("BLOCKS", UI_TEXT_X_BORDER_LEFT, text_y, UI_FONT_SIZE, UI_FONT_COLOR)
	ui.Counter_Draw(
		&block_counter,
		{UI_TEXT_X_BORDER_LEFT + UI_TEXT_X_OFFSET, text_y},
		"%2d",
		.Right,
	)

	text_y += UI_FONT_SIZE
	rl.DrawText("TIME", UI_TEXT_X_BORDER_LEFT, text_y, UI_FONT_SIZE, UI_FONT_COLOR)
	ui.Counter_Draw(
		&time_counter,
		{UI_TEXT_X_BORDER_LEFT + UI_TEXT_X_OFFSET, text_y},
		"%3d",
		.Right,
	)


	rl.DrawText(
		fmt.ctprintf(
			"FPS: %d\nUpdate: %.4f ms\nRender: %.4f ms\n\n#Entities: %d\nb2 Bytes: %d",
			rl.GetFPS(),
			g.update_time_ms,
			g.render_time_ms,
			len(g.entity_pool.slots) - len(g.entity_pool.free_list),
			b2.GetByteCount(),
		),
		UI_TEXT_X_BORDER_RIGHT,
		10,
		20,
		rl.WHITE,
	)

	switch g.state {
	case .New:
		font_size: i32 = 50
		text: cstring = "Press SPACE to start"
		text_width := rl.MeasureText(text, font_size)
		rl.DrawText(
			text = text,
			posX = (SCREEN_WIDTH - text_width) / 2,
			posY = (SCREEN_HEIGHT / 2) + 70,
			fontSize = font_size,
			color = rl.WHITE,
		)
	case .Running:
		break
	case .Paused:
		font_size: i32 = 50
		text: cstring = "Press SPACE to continue"
		text_width := rl.MeasureText(text, font_size)
		rl.DrawText(
			text = text,
			posX = (SCREEN_WIDTH - text_width) / 2,
			posY = (SCREEN_HEIGHT / 2) + 70,
			fontSize = font_size,
			color = rl.WHITE,
		)
	case .GameOver:
		font_size: i32 = 75
		text: cstring = "GAME OVER"
		text_width := rl.MeasureText(text, font_size)
		rl.DrawText(
			text = text,
			posX = (SCREEN_WIDTH - text_width) / 2,
			posY = (SCREEN_HEIGHT / 2),
			fontSize = font_size,
			color = rl.WHITE,
		)
	}
}
