package breakout

import "core:log"
import b2 "vendor:box2d"
import rl "vendor:raylib"

Block :: struct {
	using entity: Entity,
	health:       int, // <= 0 means dead
	score:        int,
}

BLOCK_ROWS :: 5
BLOCK_COLS :: 10
BLOCK_WIDTH :: 2
BLOCK_HEIGHT :: 1


/*
block_color_score := [Texture]int {
	.Yellow = 2,
	.Green  = 4,
	.Purple = 6,
	.Red    = 8,
	.Blue   = 10,
	.Grey   = 12,
}
*/

blocks: [dynamic]Block


BRICK_ROWS :: 5
BRICK_COLS :: 10
BRICK_WIDTH :: f32(3)
BRICK_HEIGHT :: f32(1.5)
BRICK_SPACING :: f32(1)
BRICK_TOP_Y :: f32(20)

blocks_create :: proc(world_id: b2.WorldId) {
	row_textures := [BRICK_ROWS]Texture {
		.BlockRed,
		.BlockGreen,
		.BlockPurple,
		.BlockGrey,
		.BlockYellow,
	}
	row_scores := [BRICK_ROWS]int{20, 15, 10, 5, 1}

	total_width := f32(BRICK_COLS) * (BRICK_WIDTH + BRICK_SPACING) - BRICK_SPACING
	start_x := -total_width / 2

	for row in 0 ..< BRICK_ROWS {
		for col in 0 ..< BRICK_COLS {
			x := start_x + f32(col) * (BRICK_WIDTH + BRICK_SPACING) + BRICK_WIDTH / 2
			y := BRICK_TOP_Y - f32(row) * (BRICK_HEIGHT + BRICK_SPACING)

			body_def := b2.DefaultBodyDef()
			body_def.type = .staticBody
			body_def.position = {x, y}
			body_id := b2.CreateBody(world_id, body_def)

			box := b2.MakeBox(BRICK_WIDTH / 2, BRICK_HEIGHT / 2)
			shape_def := b2.DefaultShapeDef()
			shape_def.enableHitEvents = true
			shape_def.material.friction = 0.1
			shape_def.material.restitution = 1.0 // bricks bounce the ball cleanly, like the paddle

			data := new(User_Data)
			data.sound_hit = .HitBlock
			data.entity_kind = .Block
			data.entity_id = len(blocks) + 1 // 0 means invalid
			shape_def.userData = data

			shape_id := b2.CreatePolygonShape(body_id, shape_def, &box)
			block := Block {
				body_id   = body_id,
				shape_id  = shape_id,
				user_data = data,
				health    = 1, // TODO
				texture   = row_textures[row],
				score     = row_scores[row],
			}

			append(&blocks, block)
		}
	}
}

block_draw :: proc(block: ^Block) {
	if block.health <= 0 do return
	if block.texture == .NoTexture {
		log.warn("Block with no texture, skipping!")
		return
	}

	pos := b2.Body_GetPosition(block.body_id)
	screen_pos := world_to_screen(pos)

	width: f32 = BLOCK_WIDTH * 2 * PPM
	height: f32 = BLOCK_HEIGHT * 2 * PPM
	rl_texture := g.textures[block.texture]

	rl.DrawTexturePro(
		rl_texture,
		source = rl.Rectangle{0, 0, f32(rl_texture.width), f32(rl_texture.height)},
		dest = rl.Rectangle{screen_pos.x, screen_pos.y, width, height},
		origin = rl.Vector2{width / 2, height / 2},
		rotation = 0,
		tint = rl.WHITE,
	)
}

block_hit :: proc(block: ^Block) {
	block.health -= 1
	if block.health <= 0 && block.user_data != nil {
		log.debug("Destroying block", block)
		g.score += block.score
		b2.DestroyBody(block.body_id)
		//free(block.user_data)
		block.user_data = nil
	}
}
