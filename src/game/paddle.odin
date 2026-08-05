package game

import "core:log"
import b2 "vendor:box2d"
import rl "vendor:raylib"

import "../engine"

PADDLE_HALF_WIDTH :: f32(4)
PADDLE_HALF_HEIGHT :: f32(0.8)
PADDLE_Y :: f32(-20) // fixed height in world space

PADDLE_TILT_MAX_ANGLE :: rl.DEG2RAD * 22 // max lean angle
PADDLE_TILT_SENSITIVITY :: f32(0.02) // radians of tilt per unit of vx
PADDLE_TILT_VX_STOP_THRESHOLD :: f32(0.05) // below this speed, considered "stopped"
PADDLE_TILT_ANGULAR_GAIN :: f32(12) // how snappily rotation chases its target

Paddle_Flag :: enum u8 {
	Tilt_Enabled,
	Sticky,
}
Paddle_Flags :: bit_set[Paddle_Flag]

Paddle_Size :: enum u8 {
	Normal, // default
	Small,
	Wide,
}

Paddle :: struct {
	flags: Paddle_Flags,
	size:  Paddle_Size,
}

Paddle_Create :: proc() {
	body_def := b2.DefaultBodyDef()
	body_def.type = .kinematicBody // moved by player, not by physics forces
	body_def.name = "paddle"
	body_def.position = {0, PADDLE_Y}
	body_id := b2.CreateBody(g.world_id, body_def)

	capsule := paddle_capsule(.Normal)
	shape_def := b2.DefaultShapeDef()
	shape_def.material.friction = 0.3
	shape_def.enableHitEvents = true
	shape_def.enableContactEvents = true // for sticky
	shape_def.enableSensorEvents = true // for powerups
	shape_def.filter.categoryBits = u64(Category_Flags{.Foreground})
	//shape_def.filter.maskBits = u64(Category_Flags{.Foreground})
	_ = b2.CreateCapsuleShape(body_id, shape_def, &capsule)

	variant := Paddle{}

	Game_AddEntity(
		{
			body_id = body_id,
			variant = variant,
			render_data = {
				texture = g.textures[.PaddleBlue],
				shape = engine.RenderShape_Rectangle {
					width = paddle_half_width(variant.size) * 2,
					height = PADDLE_HALF_HEIGHT * 2,
				},
				tint = rl.WHITE,
			},
		},
	)
}

// Call once per fixed physics step, BEFORE b2.World_Step
Paddle_Update :: proc(self: ^Entity, variant: Paddle, dt: f32) {
	target_world := engine.screen_to_world(rl.GetMousePosition())
	target_world.y = PADDLE_Y

	x_max := paddle_x_max(variant.size)
	target_world.x = clamp(target_world.x, -x_max, x_max)

	current_pos := b2.Body_GetPosition(self.body_id)

	// Drive it via velocity, not by teleporting position directly —
	// this way Box2D's solver sees a real velocity and resolves
	// collisions/pushes against the ball correctly.
	velo := (target_world - current_pos) / dt
	b2.Body_SetLinearVelocity(self.body_id, velo)

	self.previous_transform = b2.Body_GetTransform(self.body_id)

	if .Tilt_Enabled in variant.flags { 	// ---- Tilt logic ----
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

		current_angle := b2.Rot_GetAngle(self.previous_transform.q)
		angle_diff := target_angle - current_angle
		b2.Body_SetAngularVelocity(self.body_id, angle_diff * PADDLE_TILT_ANGULAR_GAIN)
	}
}

Paddle_Draw :: proc(self: ^Entity) {
	// background paddle is just for interacting with fragments
	rt := engine.get_render_transform_blended(
		self.previous_transform,
		b2.Body_GetTransform(self.body_id),
		alpha = g.accumulated_time / DT,
	)

	engine.render(self.render_data, rt)
}

Paddle_Hit :: proc(entity: ^Entity, hit: b2.ContactHitEvent) {
	play_hit_sound(.HitPaddle, hit)
}

Paddle_SetSize :: proc(entity: ^Entity, variant: ^Paddle, size: Paddle_Size) {
	log.debug("Setting paddle size to", size)
	variant.size = size

	buffer: [2]b2.ShapeId
	shapes := b2.Body_GetShapes(entity.body_id, buffer[:])
	assert(len(shapes) > 0)

	b2.Shape_SetCapsule(shapes[0], paddle_capsule(size))
	entity.render_data.shape = engine.RenderShape_Rectangle {
		width  = paddle_half_width(variant.size) * 2,
		height = PADDLE_HALF_HEIGHT * 2,
	}
}

Paddle_ApplyPowerup :: proc(entity: ^Entity, variant: ^Paddle, powerup: Powerup_Kind) {
	log.debug("Applying", powerup)

	switch powerup {
	case .PaddleSmall:
		Paddle_SetSize(entity, variant, .Small)
	case .PaddleWide:
		Paddle_SetSize(entity, variant, .Wide)
	case .ExtraBall:
		position := b2.Body_GetPosition(entity.body_id)
		position.y += 5
		Ball_Create(position, kind = .Blue)
	case .PaddleSticky:
		variant.flags += {.Sticky}
	case .PaddleTilt:
		variant.flags += {.Tilt_Enabled}
	case .Invalid:
		log.warn("Cannot apply", powerup)
	}
}

@(private = "file")
paddle_capsule :: proc(size: Paddle_Size) -> b2.Capsule {
	half_width := paddle_half_width(size)
	return b2.Capsule {
		center1 = {-half_width + PADDLE_HALF_HEIGHT, 0},
		center2 = {half_width - PADDLE_HALF_HEIGHT, 0},
		radius = PADDLE_HALF_HEIGHT,
	}
}

@(private = "file")
paddle_half_width :: #force_inline proc(size: Paddle_Size) -> f32 {
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

// keep paddle inside the side walls
@(private = "file")
paddle_x_max :: #force_inline proc(size: Paddle_Size) -> f32 {
	return ARENA_HALF_HEIGHT - paddle_half_width(size) - 0.5
}
