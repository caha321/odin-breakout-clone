package breakout

import "core:fmt"
import rl "vendor:raylib"


ui_draw :: proc() {
	// c=c string, t=temporary
	score_text := fmt.ctprintf(
		"SCORE: %4d  #BALLS: %2d  #BLOCKS: %3d",
		g.score,
		//int(g.ball_speed),
		g.remaining_balls,
		g.remaining_blocks,
	)
	rl.DrawText(score_text, 10, 10, 40, rl.WHITE)

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
