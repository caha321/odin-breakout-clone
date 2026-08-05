package game

import b2 "vendor:box2d"
import rl "vendor:raylib"

import "../engine"

ARENA_HALF_WIDTH :: 32
ARENA_HALF_HEIGHT :: 32
WALL_HALF_THICKNESS :: 0.5

Wall :: struct {}

create_ground :: proc(world_id: b2.WorldId) {

	shape_def_foreground := b2.DefaultShapeDef()
	shape_def_foreground.isSensor = true
	shape_def_foreground.enableSensorEvents = true // shapes that we want to detect also need this set to true
	shape_def_foreground.filter.categoryBits = u64(Category_Flags{.Foreground})
	shape_def_foreground.filter.maskBits = u64(Category_Flags{.Foreground})

	shape_def_background := b2.DefaultShapeDef() // ground is solid for background
	shape_def_background.filter.categoryBits = u64(Category_Flags{.Background})
	shape_def_background.filter.maskBits = u64(Category_Flags{.Background})

	body_def := b2.DefaultBodyDef()
	body_def.name = "ground"
	body_def.position = {0, -ARENA_HALF_WIDTH - WALL_HALF_THICKNESS}
	body_id := b2.CreateBody(world_id, body_def)
	polyon := b2.MakeBox(ARENA_HALF_WIDTH, WALL_HALF_THICKNESS)

	_ = b2.CreatePolygonShape(body_id, shape_def_foreground, &polyon)
	_ = b2.CreatePolygonShape(body_id, shape_def_background, &polyon)

	Game_AddEntity({body_id = body_id})
}

create_wall :: proc(
	world_id: b2.WorldId,
	position: b2.Vec2,
	half_width, half_height: f32,
	tint: rl.Color = rl.BLACK,
	name: cstring = "",
) {
	body_def := b2.DefaultBodyDef()
	shape_def := b2.DefaultShapeDef()
	shape_def.filter.categoryBits = u64(Category_Flags{.Foreground})

	body_def.name = name
	body_def.position = position
	body_id := b2.CreateBody(g.world_id, body_def)
	polygon := b2.MakeBox(half_width, half_height)

	_ = b2.CreatePolygonShape(body_id, shape_def, &polygon)

	Game_AddEntity(
		{
			body_id = body_id,
			variant = Wall{},
			render_data = {
				tint = tint,
				shape = engine.RenderShape_Rectangle {
					width = half_width * 2,
					height = half_height * 2,
				},
			},
		},
	)
}

create_bounds :: proc(world_id: b2.WorldId) {
	create_ground(world_id)
	create_wall(
		world_id,
		{0, ARENA_HALF_HEIGHT},
		ARENA_HALF_WIDTH,
		WALL_HALF_THICKNESS,
		name = "ceiling",
	)
	create_wall(
		world_id,
		{-ARENA_HALF_WIDTH, 0},
		WALL_HALF_THICKNESS,
		ARENA_HALF_HEIGHT,
		name = "wall left",
	)
	create_wall(
		world_id,
		{ARENA_HALF_WIDTH, 0},
		WALL_HALF_THICKNESS,
		ARENA_HALF_HEIGHT,
		name = "wall right",
	)
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
