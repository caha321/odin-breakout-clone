package breakout

import "core:log"
import b2 "vendor:box2d"
import rl "vendor:raylib"

PADDLE_HALF_WIDTH :: f32(4)
PADDLE_HALF_HEIGHT :: f32(0.8)
PADDLE_X_MAX :: ARENA_HALF_HEIGHT - PADDLE_HALF_WIDTH - 0.5 // keep paddle inside the side walls
PADDLE_Y :: f32(-20) // fixed height in world space

PADDLE_TILT_MAX_ANGLE :: rl.DEG2RAD * 22 // max lean angle
PADDLE_TILT_SENSITIVITY :: f32(0.02) // radians of tilt per unit of vx
PADDLE_TILT_VX_STOP_THRESHOLD :: f32(0.05) // below this speed, considered "stopped"
PADDLE_TILT_ANGULAR_GAIN :: f32(12) // how snappily rotation chases its target

Paddle_Flag :: enum {
	Tilt_Enabled,
	Sticky, // TODO
}

Paddle_Flags :: bit_set[Paddle_Flag]

// TODO Change paddle size via power"up"
Paddle_Size :: enum {
	Normal, // default
	Small,
	Wide,
}

Entity_Extra_Paddle :: struct {
	flags: Paddle_Flags,
	size:  Paddle_Size,
}

Paddle_Create :: proc(size: Paddle_Size = .Normal) {
	body_def := b2.DefaultBodyDef()
	body_def.type = .kinematicBody // moved by player, not by physics forces
	body_def.name = "paddle"
	body_def.position = {0, PADDLE_Y}
	body_id := b2.CreateBody(g.world_id, body_def)

	capsule := paddle_capsule(size)
	shape_def := b2.DefaultShapeDef()
	shape_def.material.friction = 0.3
	shape_def.enableHitEvents = true
	_ = b2.CreateCapsuleShape(body_id, shape_def, &capsule)

	Game_AddEntity(
		{
			body_id = body_id,
			texture = .PaddleBlue,
			extra = Entity_Extra_Paddle{flags = {.Tilt_Enabled}, size = size},
			//v-table
			draw = Paddle_Draw,
			update = Paddle_Update,
			hit = Paddle_Hit,
		},
	)
}

// Call once per fixed physics step, BEFORE b2.World_Step
Paddle_Update :: proc(entity: ^Entity, dt: f32) {
	extra := entity.extra.(Entity_Extra_Paddle)
	target_world := screen_to_world(rl.GetMousePosition())
	target_world.y = PADDLE_Y

	target_world.x = clamp(target_world.x, -PADDLE_X_MAX, PADDLE_X_MAX)

	current_pos := b2.Body_GetPosition(entity.body_id)

	// Drive it via velocity, not by teleporting position directly —
	// this way Box2D's solver sees a real velocity and resolves
	// collisions/pushes against the ball correctly.
	velo := (target_world - current_pos) / dt
	b2.Body_SetLinearVelocity(entity.body_id, velo)

	if .Tilt_Enabled in extra.flags { 	// ---- Tilt logic ----
		target_angle: f32
		if abs(velo.x) > PADDLE_TILT_VX_STOP_THRESHOLD {
			target_angle = clamp(
				-velo.x * PADDLE_TILT_SENSITIVITY,
				-PADDLE_TILT_MAX_ANGLE,
				PADDLE_TILT_MAX_ANGLE,
			)
		} else {
			target_angle = 0
		}

		current_rot := b2.Body_GetRotation(entity.body_id)
		current_angle := b2.Rot_GetAngle(current_rot)
		angle_diff := target_angle - current_angle
		b2.Body_SetAngularVelocity(entity.body_id, angle_diff * PADDLE_TILT_ANGULAR_GAIN)
	}
}

Paddle_Draw :: proc(entity: ^Entity) {
	extra := entity.extra.(Entity_Extra_Paddle)

	pos := b2.Body_GetPosition(entity.body_id)
	rot := b2.Body_GetRotation(entity.body_id)
	angle_deg := rl.RAD2DEG * b2.Rot_GetAngle(rot)
	screen_pos := world_to_screen(pos)

	width := paddle_half_width(extra.size) * 2 * PPM
	height := PADDLE_HALF_HEIGHT * 2 * PPM
	paddle_texture := g.textures[.PaddleBlue]

	source := rl.Rectangle{0, 0, f32(paddle_texture.width), f32(paddle_texture.height)}
	dest := rl.Rectangle{screen_pos.x, screen_pos.y, width, height}
	origin := rl.Vector2{width / 2, height / 2}

	rl.DrawTexturePro(paddle_texture, source, dest, origin, -angle_deg, rl.WHITE)
}

Paddle_Hit :: proc(entity: ^Entity, hit: b2.ContactHitEvent) {
	play_hit_sound(.HitPaddle, hit)
}

Paddle_SetSize :: proc(entity: ^Entity, size: Paddle_Size) {
	log.debug("Setting paddle size to", size)
	extra := &entity.extra.(Entity_Extra_Paddle) // mutate
	extra.size = size

	buffer: [2]b2.ShapeId
	shapes := b2.Body_GetShapes(entity.body_id, buffer[:])
	assert(len(shapes) > 0)

	b2.Shape_SetCapsule(shapes[0], paddle_capsule(size))
}

paddle_capsule :: proc(size: Paddle_Size) -> b2.Capsule {
	half_width := paddle_half_width(size)
	return b2.Capsule {
		center1 = {-half_width + PADDLE_HALF_HEIGHT, 0},
		center2 = {half_width - PADDLE_HALF_HEIGHT, 0},
		radius = PADDLE_HALF_HEIGHT,
	}
}

paddle_half_width :: proc(size: Paddle_Size) -> f32 {
	switch size {
	case .Small:
		return PADDLE_HALF_WIDTH * 0.75
	case .Normal:
		return PADDLE_HALF_WIDTH
	case .Wide:
		return PADDLE_HALF_WIDTH * 1.5
	}
	return PADDLE_HALF_WIDTH
}
