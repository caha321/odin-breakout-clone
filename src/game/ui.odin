package game

import "core:fmt"
import rl "vendor:raylib"

import "../engine"
import "../engine/ui"

UI_FONT_SIZE :: 50
UI_FONT_SPACING :: 1
UI_FONT_COLOR :: rl.WHITE


UI :: struct {
	score_counter: ui.Counter,
	combo_counter: ui.Counter,
	time_counter:  ui.Counter,
	ball_counter:  ui.Counter,
	block_counter: ui.Counter,
}

UI_Init :: proc(self: ^UI) {
	self.score_counter = ui.Counter_Create(
		UI_FONT_COLOR,
		&g.font,
		UI_FONT_SIZE,
		on_increase = {ui.Effect_Pulse{color = rl.GREEN}},
		on_decrease = {ui.Effect_Pulse{color = rl.RED}},
	)

	self.combo_counter = ui.Counter_Create(
		UI_FONT_COLOR,
		&g.font,
		UI_FONT_SIZE,
		on_increase = {ui.Effect_Pop{}, ui.Effect_Pulse{color = rl.GREEN}},
		on_decrease = {
			ui.Effect_Shake{duration = 1, strength = 2},
			ui.Effect_Pulse{color = rl.RED},
		},
	)

	self.time_counter = ui.Counter_Create(
		UI_FONT_COLOR,
		&g.font,
		UI_FONT_SIZE,
		on_increase = {ui.Effect_Pop{amount = 1.1}, ui.Effect_Pulse{color = rl.GRAY}},
		change_granularity = 1000, // value is ms, but only apply effects each second
	)

	self.ball_counter = ui.Counter_Create(
		UI_FONT_COLOR,
		&g.font,
		UI_FONT_SIZE,
		on_increase = {ui.Effect_Pop{}, ui.Effect_Pulse{color = rl.GREEN}},
		on_decrease = {
			ui.Effect_Shake{duration = 1, strength = 3},
			ui.Effect_Pulse{color = rl.RED},
		},
	)

	self.block_counter = ui.Counter_Create(
		UI_FONT_COLOR,
		&g.font,
		UI_FONT_SIZE,
		on_decrease = {
			ui.Effect_Shake{duration = .25, strength = 2},
			ui.Effect_Pulse{color = rl.GREEN},
		},
	)
}

UI_Update :: proc(self: ^UI, dt: f32) {
	ui.Counter_Update(&self.score_counter, g.player.score, dt)
	ui.Counter_Update(&self.combo_counter, g.player.combo_multiplier, dt)
	ui.Counter_Update(&self.time_counter, i32(g.player.elapsed_time * 1000), dt)
	ui.Counter_Update(&self.ball_counter, g.remaining_balls, dt)
	ui.Counter_Update(&self.block_counter, g.remaining_blocks, dt)
}

UI_Draw :: proc(self: ^UI) {
	BORDER_WIDTH: f32 = ((ARENA_HALF_WIDTH + WALL_HALF_THICKNESS * 2) * engine.camera.zoom / 2)
	BORDER_COLOR :: rl.Color{0, 0, 0, 192}

	UI_TEXT_Y :: 10
	UI_TEXT_X_BORDER_LEFT :: 10
	UI_TEXT_X_BORDER_RIGHT := BORDER_WIDTH + (ARENA_HALF_WIDTH * 2 * engine.camera.zoom)
	UI_TEXT_X_OFFSET := BORDER_WIDTH - 30

	// borders
	rl.DrawRectangle(0, 0, i32(BORDER_WIDTH), engine.screen.height, BORDER_COLOR) // Left
	rl.DrawRectangleRec(
		rl.Rectangle {
			f32(engine.screen.width) - BORDER_WIDTH,
			0,
			BORDER_WIDTH,
			f32(engine.screen.height),
		},
		BORDER_COLOR,
	) // Right


	text_y: f32 = UI_TEXT_Y
	rl.DrawTextEx(
		g.font,
		"SCORE",
		{UI_TEXT_X_BORDER_LEFT, text_y},
		UI_FONT_SIZE,
		UI_FONT_SPACING,
		UI_FONT_COLOR,
	)
	ui.Counter_Draw(
		&self.score_counter,
		{UI_TEXT_X_BORDER_LEFT + UI_TEXT_X_OFFSET, text_y},
		"%5d",
		.Right,
	)

	text_y += UI_FONT_SIZE
	rl.DrawTextEx(
		g.font,
		"COMBO",
		{UI_TEXT_X_BORDER_LEFT, text_y},
		UI_FONT_SIZE,
		UI_FONT_SPACING,
		UI_FONT_COLOR,
	)
	ui.Counter_Draw(
		&self.combo_counter,
		{UI_TEXT_X_BORDER_LEFT + UI_TEXT_X_OFFSET, text_y},
		"%dX",
		.Right,
	)

	text_y += UI_FONT_SIZE
	rl.DrawTextEx(
		g.font,
		"BALLS",
		{UI_TEXT_X_BORDER_LEFT, text_y},
		UI_FONT_SIZE,
		UI_FONT_SPACING,
		UI_FONT_COLOR,
	)
	ui.Counter_Draw(
		&self.ball_counter,
		{UI_TEXT_X_BORDER_LEFT + UI_TEXT_X_OFFSET, text_y},
		"%2d",
		.Right,
	)

	text_y += UI_FONT_SIZE
	rl.DrawTextEx(
		g.font,
		"BLOCKS",
		{UI_TEXT_X_BORDER_LEFT, text_y},
		UI_FONT_SIZE,
		UI_FONT_SPACING,
		UI_FONT_COLOR,
	)
	ui.Counter_Draw(
		&self.block_counter,
		{UI_TEXT_X_BORDER_LEFT + UI_TEXT_X_OFFSET, text_y},
		"%2d",
		.Right,
	)

	text_y += UI_FONT_SIZE
	rl.DrawTextEx(
		g.font,
		"TIME",
		{UI_TEXT_X_BORDER_LEFT, text_y},
		UI_FONT_SIZE,
		UI_FONT_SPACING,
		UI_FONT_COLOR,
	)
	ui.Counter_DrawTime(
		&self.time_counter,
		{UI_TEXT_X_BORDER_LEFT + UI_TEXT_X_OFFSET, text_y},
		.Right,
	)


	rl.DrawTextEx(
		g.font,
		fmt.ctprintf(
			"FPS: %d\nFrame: %d\n\nUpdate: %.4f ms\nRender: %.4f ms\n\n#Entities: %d\n#Ent. Backg.: %d\n\nCombo Time Left: %.1f",
			rl.GetFPS(),
			g.tick_count,
			g.update_time_ms,
			g.render_time_ms,
			len(g.entity_pool.slots) - len(g.entity_pool.free_list),
			len(g.entity_pool_background.slots) - len(g.entity_pool_background.free_list),
			Player_ComboTimeRemaining(g.player),
		),
		{UI_TEXT_X_BORDER_RIGHT, 10},
		20,
		UI_FONT_SPACING,
		rl.WHITE,
	)

	switch g.state {
	case .New:
		font_size :: 100
		text: cstring = "Press SPACE to start"
		text_width := rl.MeasureTextEx(g.font, text, font_size, UI_FONT_SPACING).x
		rl.DrawTextEx(
			g.font,
			text,
			{(f32(engine.screen.width) - text_width) / 2, (f32(engine.screen.height) / 2) + 70},
			font_size,
			UI_FONT_SPACING,
			rl.GRAY,
		)
	case .Running:
		break
	case .Paused:
		font_size :: 100
		text: cstring = "Press SPACE to continue"
		text_width := rl.MeasureTextEx(g.font, text, font_size, UI_FONT_SPACING).x
		rl.DrawTextEx(
			g.font,
			text,
			{(f32(engine.screen.width) - text_width) / 2, (f32(engine.screen.height) / 2) + 70},
			font_size,
			UI_FONT_SPACING,
			rl.GRAY,
		)
	case .GameOver:
		font_size :: 150
		text: cstring = "GAME OVER"
		text_width := rl.MeasureTextEx(g.font, text, font_size, UI_FONT_SPACING).x
		rl.DrawTextEx(
			g.font,
			text,
			{(f32(engine.screen.width) - text_width) / 2, (f32(engine.screen.height) / 2)},
			font_size,
			UI_FONT_SPACING,
			rl.GRAY,
		)
	}
}
