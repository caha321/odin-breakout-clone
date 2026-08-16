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
		"SCORE",
		UI_FONT_COLOR,
		&g.font,
		UI_FONT_SIZE,
		on_increase = {ui.Effect_Pulse{color = rl.GREEN}},
		on_decrease = {ui.Effect_Pulse{color = rl.RED}},
	)

	self.combo_counter = ui.Counter_Create(
		"COMBO",
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
		"TIME",
		UI_FONT_COLOR,
		&g.font,
		UI_FONT_SIZE,
		on_increase = {ui.Effect_Pop{amount = 1.1}, ui.Effect_Pulse{color = rl.GRAY}},
		change_granularity = 1000, // value is ms, but only apply effects each second
	)

	self.ball_counter = ui.Counter_Create(
		"#BALLS",
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
		"#BLOCKS",
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

	UI_TEXT_Y :: 5
	UI_TEXT_X_START := BORDER_WIDTH + (WALL_HALF_THICKNESS * 2 * engine.camera.zoom) + 50 // TODO
	UI_TEXT_X_BORDER_RIGHT := BORDER_WIDTH + (ARENA_HALF_WIDTH * 2 * engine.camera.zoom)
	//UI_TEXT_X_OFFSET := BORDER_WIDTH
	UI_COUNTER_OFFSET :: 200

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


	text_x: f32 = UI_TEXT_X_START
	ui.Counter_Draw(&self.score_counter, {text_x, UI_TEXT_Y}, "%5d", .Center)

	text_x += UI_COUNTER_OFFSET
	ui.Counter_Draw(&self.combo_counter, {text_x, UI_TEXT_Y}, "%dX", .Center)

	text_x += UI_COUNTER_OFFSET
	ui.Counter_Draw(&self.ball_counter, {text_x, UI_TEXT_Y}, "%2d", .Center)

	text_x += UI_COUNTER_OFFSET
	ui.Counter_Draw(&self.block_counter, {text_x, UI_TEXT_Y}, "%2d", .Center)

	text_x += UI_COUNTER_OFFSET
	ui.Counter_DrawTime(&self.time_counter, {text_x, UI_TEXT_Y}, .Center)


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
		ui.draw_text_with_background(
			g.font,
			"Press SPACE to start",
			{f32(engine.screen.width) / 2, f32(engine.screen.height) / 2 + 70},
			font_size = 100,
		)
	case .Running:
		break
	case .Paused:
		ui.draw_text_with_background(
			g.font,
			"Press SPACE to continue",
			{f32(engine.screen.width) / 2, f32(engine.screen.height) / 2 + 70},
			font_size = 100,
		)
	case .GameOver:
		ui.draw_text_with_background(
			g.font,
			"GAME OVER",
			{f32(engine.screen.width) / 2, f32(engine.screen.height) / 2},
			font_size = 150,
		)
	}
}
