package breakout

import "core:log"
import "core:math/rand"
import b2 "vendor:box2d"
import rl "vendor:raylib"

Block_Kind :: enum u8 {
	Red,
	Blue,
	Green,
	Purple,
	Grey,
	Yellow,
}

Block :: struct {
	kind:          Block_Kind,
	health:        i8, // <= 0 means dead
	score_hit:     i8,
	score_destroy: i8,
}

BLOCK_ROWS :: 5
BLOCK_COLS :: 7

BLOCK_HALF_WIDTH :: 3
BLOCK_HALF_HEIGHT :: 1.5
BLOCK_TOP_Y :: 20

blocks_create :: proc() {
	row_kinds := [BLOCK_ROWS]Block_Kind{.Red, .Green, .Purple, .Grey, .Yellow}
	row_scores := [BLOCK_ROWS]i8{20, 15, 10, 5, 1}

	total_width := f32(BLOCK_COLS) * (BLOCK_HALF_WIDTH * 2) - BLOCK_HALF_WIDTH
	start_x := -total_width / 2

	for row in 0 ..< BLOCK_ROWS {
		for col in 0 ..< BLOCK_COLS {
			x := start_x + f32(col) * (BLOCK_HALF_WIDTH * 2) + BLOCK_HALF_WIDTH / 2
			y := BLOCK_TOP_Y - f32(row) * (BLOCK_HALF_HEIGHT * 2)

			Block_Create(position = {x, y}, kind = row_kinds[row], score = row_scores[row])
		}
	}
}

Block_Create :: proc(position: [2]f32, kind: Block_Kind, score: i8) {
	body_def := b2.DefaultBodyDef()
	body_def.name = "block"
	body_def.type = .staticBody
	body_def.position = position
	body_id := b2.CreateBody(g.world_id, body_def)

	box := b2.MakeBox(BLOCK_HALF_WIDTH, BLOCK_HALF_HEIGHT)
	shape_def := b2.DefaultShapeDef()
	shape_def.enableHitEvents = true
	shape_def.material.friction = 0.1
	shape_def.material.restitution = 1.0 // bricks bounce the ball cleanly, like the paddle
	_ = b2.CreatePolygonShape(body_id, shape_def, &box)

	Game_AddEntity(
		{
			body_id = body_id,
			variant = Block{health = 1, score_hit = 1, score_destroy = score, kind = kind},
		},
	)
}

@(private = "file")
block_kind_to_texture := [Block_Kind]Texture {
	.Red    = .BlockRed,
	.Blue   = .BlockBlue,
	.Green  = .BlockGreen,
	.Purple = .BlockPurple,
	.Grey   = .BlockGrey,
	.Yellow = .BlockYellow,
}

Block_Draw :: proc(entity: ^Entity, variant: Block) {
	if variant.health <= 0 do return

	pos := b2.Body_GetPosition(entity.body_id)
	screen_pos := world_to_screen(pos)

	width: f32 = BLOCK_HALF_WIDTH * 2 * PPM
	height: f32 = BLOCK_HALF_HEIGHT * 2 * PPM

	rl_texture := g.textures[block_kind_to_texture[variant.kind]]

	rl.DrawTexturePro(
		rl_texture,
		source = rl.Rectangle{0, 0, f32(rl_texture.width), f32(rl_texture.height)},
		dest = rl.Rectangle{screen_pos.x, screen_pos.y, width, height},
		origin = rl.Vector2{width / 2, height / 2},
		rotation = 0,
		tint = rl.WHITE,
	)
}

Block_Hit :: proc(entity: ^Entity, variant: ^Block, hit: b2.ContactHitEvent) {
	log.debug("Block hit", entity)
	play_hit_sound(.HitBlock, hit)
	variant.health -= 1
	g.score += int(variant.score_hit)
	g.ball_speed += 0.5
	if variant.health <= 0 {
		g.score += int(variant.score_destroy)
		position := b2.Body_GetPosition(entity.body_id)
		position.y -= 5
		Pool_Remove(&g.entity_pool, entity.body_id)

		if rand.float32() < POWERUP_DROP_CHANCE {
			Powerup_Create(position)
		}

		g.remaining_blocks -= 1
	}
}
