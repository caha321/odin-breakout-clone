package breakout

import b2 "vendor:box2d"
import rl "vendor:raylib"

BACKGROUND_COLOR :: rl.Color{150, 190, 220, 255}

create_bounds :: proc() {
	wall_def := b2.DefaultBodyDef()
	wall_shape_def := b2.DefaultShapeDef()

	ground_def := wall_def
	ground_shape_def := wall_shape_def
	ground_shape_def.isSensor = true
	ground_shape_def.enableSensorEvents = true // shapes that we want to detect also need this set to true
	ground_def.position = {0, -WORLD_SCREEN_HALF_WIDTH}
	ground_id := b2.CreateBody(g.world_id, ground_def)
	ground_box := b2.MakeBox(WORLD_SCREEN_HALF_WIDTH, 0.5)
	ground_shape_id := b2.CreatePolygonShape(ground_id, ground_shape_def, &ground_box)
	Game_AddEntity({body_id = ground_id, shape_id = ground_shape_id})


	// Ceiling
	ceiling_def := wall_def
	ceiling_def.position = {0, WORLD_SCREEN_HALF_HEIGHT}
	ceiling_id := b2.CreateBody(g.world_id, ceiling_def)
	ceiling_box := b2.MakeBox(WORLD_SCREEN_HALF_WIDTH, 0.5)
	ceiling_shape_id := b2.CreatePolygonShape(ceiling_id, wall_shape_def, &ceiling_box)
	Game_AddEntity({body_id = ceiling_id, shape_id = ceiling_shape_id, hit = Wall_Hit})

	// Left wall
	left_def := wall_def
	left_def.position = {-WORLD_SCREEN_HALF_WIDTH, 0}
	left_id := b2.CreateBody(g.world_id, left_def)
	left_box := b2.MakeBox(0.5, WORLD_SCREEN_HALF_HEIGHT)
	left_shape_id := b2.CreatePolygonShape(left_id, wall_shape_def, &left_box)
	Game_AddEntity({body_id = left_id, shape_id = left_shape_id, hit = Wall_Hit})

	// Right wall
	right_def := wall_def
	right_def.position = {WORLD_SCREEN_HALF_WIDTH, 0}
	right_id := b2.CreateBody(g.world_id, right_def)
	right_box := b2.MakeBox(0.5, WORLD_SCREEN_HALF_HEIGHT)
	right_shape_id := b2.CreatePolygonShape(right_id, wall_shape_def, &right_box)
	Game_AddEntity({body_id = right_id, shape_id = right_shape_id, hit = Wall_Hit})
}


World_Create :: proc() {
	world_def := b2.DefaultWorldDef()
	world_def.gravity = {0, 0}
	g.world_id = b2.CreateWorld(world_def)

	create_bounds()
	Paddle_Create()
	Ball_Create()
	blocks_create()
}

Wall_Hit :: proc(entity: ^Entity, hit: b2.ContactHitEvent) {
	play_hit_sound(.HitWall, hit)
}
