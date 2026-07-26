package breakout

import b2 "vendor:box2d"
import rl "vendor:raylib"

BACKGROUND_COLOR :: rl.Color{150, 190, 220, 255}

SCREEN_HEIGHT :: 1280
SCREEN_WIDTH :: 1920
PPM :: 20


world_to_screen :: proc "c" (p: [2]f32) -> [2]f32 {
	return {f32(SCREEN_WIDTH) / 2 + p.x * PPM, f32(SCREEN_HEIGHT) / 2 - p.y * PPM}
}

screen_to_world :: proc "c" (p: [2]f32) -> [2]f32 {
	return {(p.x - f32(SCREEN_WIDTH) / 2) / PPM, (f32(SCREEN_HEIGHT) / 2 - p.y) / PPM}
}


ARENA_HALF_WIDTH :: 32
ARENA_HALF_HEIGHT :: 32
WALL_THICKNESS :: 0.5

create_bounds :: proc() {
	wall_def := b2.DefaultBodyDef()
	wall_shape_def := b2.DefaultShapeDef()

	ground_def := wall_def
	ground_def.name = "ground"
	ground_shape_def := wall_shape_def
	ground_shape_def.isSensor = true
	ground_shape_def.enableSensorEvents = true // shapes that we want to detect also need this set to true
	ground_def.position = {0, -ARENA_HALF_WIDTH}
	ground_id := b2.CreateBody(g.world_id, ground_def)
	ground_box := b2.MakeBox(ARENA_HALF_WIDTH, WALL_THICKNESS)
	_ = b2.CreatePolygonShape(ground_id, ground_shape_def, &ground_box)
	Game_AddEntity({body_id = ground_id})


	// Ceiling
	ceiling_def := wall_def
	ceiling_def.name = "ceiling"
	ceiling_def.position = {0, ARENA_HALF_HEIGHT}
	ceiling_id := b2.CreateBody(g.world_id, ceiling_def)
	ceiling_box := b2.MakeBox(ARENA_HALF_WIDTH, WALL_THICKNESS)
	_ = b2.CreatePolygonShape(ceiling_id, wall_shape_def, &ceiling_box)
	Game_AddEntity({body_id = ceiling_id, hit = Wall_Hit})

	// Left wall
	left_def := wall_def
	left_def.name = "wall left"
	left_def.position = {-ARENA_HALF_WIDTH, 0}
	left_id := b2.CreateBody(g.world_id, left_def)
	left_box := b2.MakeBox(WALL_THICKNESS, ARENA_HALF_HEIGHT)
	_ = b2.CreatePolygonShape(left_id, wall_shape_def, &left_box)
	Game_AddEntity({body_id = left_id, hit = Wall_Hit})

	// Right wall
	right_def := wall_def
	right_def.name = "wall right"
	right_def.position = {ARENA_HALF_WIDTH, 0}
	right_id := b2.CreateBody(g.world_id, right_def)
	right_box := b2.MakeBox(WALL_THICKNESS, ARENA_HALF_HEIGHT)
	_ = b2.CreatePolygonShape(right_id, wall_shape_def, &right_box)
	Game_AddEntity({body_id = right_id, hit = Wall_Hit})
}


World_Create :: proc() {
	world_def := b2.DefaultWorldDef()
	world_def.gravity = {0, 0}
	g.world_id = b2.CreateWorld(world_def)

	create_bounds()
	Paddle_Create()
	Ball_Create({-5, 0})
	Ball_Create({0, 0})
	Ball_Create({5, 0})
	blocks_create()
}

Wall_Hit :: proc(entity: ^Entity, hit: b2.ContactHitEvent) {
	play_hit_sound(.HitWall, hit)
}
