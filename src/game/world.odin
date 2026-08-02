package game

import b2 "vendor:box2d"


ARENA_HALF_WIDTH :: 32
ARENA_HALF_HEIGHT :: 32
WALL_THICKNESS :: 0.5

Wall :: struct {}

create_ground :: proc(world_id: b2.WorldId, sensor: bool) {
	ground_def := b2.DefaultBodyDef()
	ground_def.name = "ground"
	ground_shape_def := b2.DefaultShapeDef()
	if sensor {
		ground_shape_def.isSensor = true
		ground_shape_def.enableSensorEvents = true // shapes that we want to detect also need this set to true
	}
	ground_def.position = {0, -ARENA_HALF_WIDTH}
	ground_id := b2.CreateBody(world_id, ground_def)
	ground_box := b2.MakeBox(ARENA_HALF_WIDTH, WALL_THICKNESS)
	_ = b2.CreatePolygonShape(ground_id, ground_shape_def, &ground_box)
	Game_AddEntity({body_id = ground_id})
}

create_bounds :: proc(world_id: b2.WorldId, ground_sensor: bool) {
	wall_def := b2.DefaultBodyDef()
	wall_shape_def := b2.DefaultShapeDef()

	create_ground(world_id, sensor = ground_sensor)

	// Ceiling
	ceiling_def := wall_def
	ceiling_def.name = "ceiling"
	ceiling_def.position = {0, ARENA_HALF_HEIGHT}
	ceiling_id := b2.CreateBody(world_id, ceiling_def)
	ceiling_box := b2.MakeBox(ARENA_HALF_WIDTH, WALL_THICKNESS)
	_ = b2.CreatePolygonShape(ceiling_id, wall_shape_def, &ceiling_box)
	Game_AddEntity({body_id = ceiling_id, variant = Wall{}})

	// Left wall
	left_def := wall_def
	left_def.name = "wall left"
	left_def.position = {-ARENA_HALF_WIDTH, 0}
	left_id := b2.CreateBody(world_id, left_def)
	left_box := b2.MakeBox(WALL_THICKNESS, ARENA_HALF_HEIGHT)
	_ = b2.CreatePolygonShape(left_id, wall_shape_def, &left_box)
	Game_AddEntity({body_id = left_id, variant = Wall{}})

	// Right wall
	right_def := wall_def
	right_def.name = "wall right"
	right_def.position = {ARENA_HALF_WIDTH, 0}
	right_id := b2.CreateBody(world_id, right_def)
	right_box := b2.MakeBox(WALL_THICKNESS, ARENA_HALF_HEIGHT)
	_ = b2.CreatePolygonShape(right_id, wall_shape_def, &right_box)
	Game_AddEntity({body_id = right_id, variant = Wall{}})
}


@(require_results)
World_Create :: proc(gravity: [2]f32) -> b2.WorldId {
	world_def := b2.DefaultWorldDef()
	world_def.gravity = gravity
	world_id := b2.CreateWorld(world_def)
	return world_id
}

Wall_Hit :: proc(entity: ^Entity, hit: b2.ContactHitEvent) {
	play_hit_sound(.HitWall, hit)
}
