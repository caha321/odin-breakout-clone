package breakout

import b2 "vendor:box2d"
import rl "vendor:raylib"

BACKGROUND_COLOR :: rl.Color{150, 190, 220, 255}

create_bounds :: proc(world_id: b2.WorldId) {
	wall_def := b2.DefaultBodyDef()
	wall_shape_def := b2.DefaultShapeDef()

	ground_def := wall_def
	ground_shape_def := wall_shape_def
	ground_shape_def.isSensor = true
	ground_shape_def.enableSensorEvents = true // shapes that we want to detect also need this set to true
	ground_def.position = {0, -WORLD_SCREEN_HALF_WIDTH}
	ground_id := b2.CreateBody(world_id, ground_def)
	ground_box := b2.MakeBox(WORLD_SCREEN_HALF_WIDTH, 0.5)
	_ = b2.CreatePolygonShape(ground_id, ground_shape_def, &ground_box)

	data := new(User_Data)
	data.sound_hit = .HitWall
	wall_shape_def.userData = data

	// Ceiling
	ceiling_def := wall_def
	ceiling_def.position = {0, WORLD_SCREEN_HALF_HEIGHT}
	ceiling_id := b2.CreateBody(world_id, ceiling_def)
	ceiling_box := b2.MakeBox(WORLD_SCREEN_HALF_WIDTH, 0.5)
	_ = b2.CreatePolygonShape(ceiling_id, wall_shape_def, &ceiling_box)

	// Left wall
	left_def := wall_def
	left_def.position = {-WORLD_SCREEN_HALF_WIDTH, 0}
	left_id := b2.CreateBody(world_id, left_def)
	left_box := b2.MakeBox(0.5, WORLD_SCREEN_HALF_HEIGHT)
	_ = b2.CreatePolygonShape(left_id, wall_shape_def, &left_box)

	// Right wall
	right_def := wall_def
	right_def.position = {WORLD_SCREEN_HALF_WIDTH, 0}
	right_id := b2.CreateBody(world_id, right_def)
	right_box := b2.MakeBox(0.5, WORLD_SCREEN_HALF_HEIGHT)
	_ = b2.CreatePolygonShape(right_id, wall_shape_def, &right_box)
}


World_Create :: proc() {
	world_def := b2.DefaultWorldDef()
	world_def.gravity = {0, 0}
	g.world_id = b2.CreateWorld(world_def)

	create_bounds(g.world_id)
	Paddle_Create(g.world_id)
	Ball_Create(g.world_id)
	blocks_create(g.world_id)
}
