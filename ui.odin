package breakout

import "core:fmt"
import rl "vendor:raylib"


BORDER_WIDTH :: (ARENA_HALF_WIDTH + WALL_THICKNESS * 2) * PPM / 2
BORDER_COLOR :: rl.BLACK

BORDER_RIGHT_TEXT_X :: BORDER_WIDTH + (ARENA_HALF_WIDTH * 2 * PPM)


ui_draw :: proc() {
	// borders
	rl.DrawRectangle(0, 0, BORDER_WIDTH, SCREEN_HEIGHT, BORDER_COLOR) // Left
	rl.DrawRectangle(SCREEN_WIDTH - BORDER_WIDTH, 0, BORDER_WIDTH, SCREEN_HEIGHT, BORDER_COLOR) // Right

	rl.DrawText(
		fmt.ctprintf(
			"SCORE: %5d\nLIVES: %2d\n\nB.SPEED: %3d\n\nR.BALLS: %2d\nR.BLOCKS: %3d",
			g.score,
			g.lives,
			int(g.ball_speed),
			g.remaining_balls,
			g.remaining_blocks,
		),
		10,
		10,
		40,
		rl.WHITE,
	)

	rl.DrawText(
		fmt.ctprintf(
			"FPS: %d\nUpdate: %.4f ms\nRender: %.4f ms\n\n#Entities: %d",
			rl.GetFPS(),
			g.update_time_ms,
			g.render_time_ms,
			len(g.entity_pool.slots) - len(g.entity_pool.free_list),
		),
		BORDER_RIGHT_TEXT_X,
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

	free_all(context.temp_allocator)
}
