package game

import "core:log"
import "core:math/linalg"
import "core:math/rand"
import b2 "vendor:box2d"
import rl "vendor:raylib"

import "../engine"

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
	shape_def.filter.categoryBits = u64(Category_Flags{.Foreground})
	//shape_def.filter.maskBits = u64(Category_Flags{.Foreground})
	_ = b2.CreatePolygonShape(body_id, shape_def, &box)

	Game_AddEntity(
		{
			body_id = body_id,
			render_data = {
				texture = g.textures[block_kind_to_texture[kind]],
				shape = engine.RenderShape_Rectangle {
					width = BLOCK_HALF_WIDTH * 2,
					height = BLOCK_HALF_HEIGHT * 2,
				},
				tint = rl.WHITE,
			},
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
	if variant.health <= 0 {
		log.warn("Tryed to draw a dead block. skipping")
		return
	}

	rt := engine.get_render_transform_static(b2.Body_GetTransform(entity.body_id))
	engine.render(entity.render_data, rt)
}

Block_Hit :: proc(entity: ^Entity, variant: ^Block, hit: b2.ContactHitEvent) {
	log.debug("Block hit", entity)
	play_hit_sound(.HitBlock, hit)
	variant.health -= 1
	score := i32(variant.score_hit)
	g.ball_speed += 0.5
	if variant.health <= 0 {
		score += i32(variant.score_destroy)
		position := b2.Body_GetPosition(entity.body_id)
		position.y -= 5
		Block_Break(entity, variant, hit)
		engine.Pool_Remove(&g.entity_pool, entity.body_id)

		if rand.float32() < POWERUP_DROP_CHANCE {
			Powerup_Create(position)
		}

		g.remaining_blocks -= 1
	}
	Player_AddScore(&g.player, score)
}

// break the block into voronoi fragments in the background
Block_Break :: proc(entity: ^Entity, variant: ^Block, hit: b2.ContactHitEvent) {
	if int(variant.kind) > 6 {
		log.error("Cannot fragment invalid block variant", variant)
		return
	}

	seed_count := rand.int_range(7, 15) // TODO vary with hit.approachSpeed ?
	log.debugf("Breaking block into %d fragments...", seed_count)

	fragments := engine.generate_fractures(
		{BLOCK_HALF_WIDTH, BLOCK_HALF_HEIGHT},
		seed_count,
		hit.point,
		entity.body_id,
	)
	defer delete(fragments)

	transform := b2.Body_GetTransform(entity.body_id)

	for frag in fragments {
		world_centroid := transform.p + b2.RotateVector(transform.q, frag.centroid)

		body_def := b2.DefaultBodyDef()
		body_def.type = .dynamicBody
		body_def.position = world_centroid
		body_def.rotation = transform.q
		frag_body := b2.CreateBody(g.world_id, body_def)

		hull := b2.ComputeHull(frag.vertices)
		poly := b2.MakePolygon(hull, 0.0)

		shape_def := b2.DefaultShapeDef()
		shape_def.density = 1.0
		shape_def.material.friction = 0.3
		shape_def.material.restitution = 0.1
		shape_def.filter.categoryBits = u64(Category_Flags{.Background})
		_ = b2.CreatePolygonShape(frag_body, shape_def, &poly)

		//dir := linalg.normalize(frag.centroid)
		b2.Body_ApplyLinearImpulseToCenter(frag_body, -hit.normal * (hit.approachSpeed / 3), true)

		texture := g.textures[block_kind_to_texture[variant.kind]]

		Game_AddEntity(
			{
				body_id = frag_body,
				render_data = {
					texture = texture,
					tint = {255, 255, 255, 64}, // TODO alpha via options,
					shape = engine.RenderShape_Polygon{vertices = frag.vertices, uvs = frag.uvs},
				},
				variant = Fragment{},
			},
		)
	}
}
