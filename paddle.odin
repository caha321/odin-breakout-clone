package breakout

import "core:log"
import b2 "vendor:box2d"
import rl "vendor:raylib"

PADDLE_HALF_WIDTH :: f32(4)
PADDLE_HALF_HEIGHT :: f32(0.8)
PADDLE_CORNER_RADIUS :: f32(0.15)
PADDLE_Y :: f32(-20) // fixed height in world space

Entity_Extra_Paddle :: struct {
	// tilt-mechanic
	stop_timer: f32,
	held_tilt:  f32,
}

Paddle_Create :: proc(world_id: b2.WorldId) -> uint {
	body_def := b2.DefaultBodyDef()
	body_def.type = .kinematicBody // moved by player, not by physics forces
	body_def.name = "paddle"
	body_def.position = {0, PADDLE_Y}
	body_id := b2.CreateBody(world_id, body_def)

	// A "rounded box" is just a polygon with a corner radius
	box := b2.MakeRoundedBox(PADDLE_HALF_WIDTH, PADDLE_HALF_HEIGHT, PADDLE_CORNER_RADIUS)
	shape_def := b2.DefaultShapeDef()
	shape_def.material.friction = 0.3
	shape_def.enableHitEvents = true

	data := new(User_Data)
	data.sound_hit = .HitPaddle
	data.entity_kind = .Paddle
	data.entity_id = len(g.entities) + 1 // 0 means invalid
	shape_def.userData = data

	shape_id := b2.CreatePolygonShape(body_id, shape_def, &box)

	append(
		&g.entities,
		Entity {
			kind      = .Paddle,
			body_id   = body_id,
			shape_id  = shape_id,
			user_data = data,
			texture   = .PaddleBlue,
			extra     = Entity_Extra_Paddle{},
			//v-table
			draw      = Paddle_Draw,
			update    = Paddle_Update,
		},
	)

	return data.entity_id
}


PADDLE_MAX_TILT :: rl.DEG2RAD * 22 // max lean angle
PADDLE_TILT_SENSITIVITY :: f32(0.02) // radians of tilt per unit of vx
PADDLE_VX_STOP_THRESHOLD :: f32(0.05) // below this speed, considered "stopped"
PADDLE_SETTLE_DELAY :: f32(0) // seconds of stillness before flattening
PADDLE_ANGULAR_GAIN :: f32(12) // how snappily rotation chases its target


// Call once per fixed physics step, BEFORE b2.World_Step
Paddle_Update :: proc(entity: ^Entity, dt: f32) {
	extra := entity.extra.(Entity_Extra_Paddle)
	target_world := screen_to_world(rl.GetMousePosition())
	target_world.y = PADDLE_Y

	max_x := WORLD_SCREEN_HALF_WIDTH - PADDLE_HALF_WIDTH - 0.5 // keep paddle inside the side walls
	target_world.x = clamp(target_world.x, -max_x, max_x)

	current_pos := b2.Body_GetPosition(entity.body_id)

	// Drive it via velocity, not by teleporting position directly —
	// this way Box2D's solver sees a real velocity and resolves
	// collisions/pushes against the ball correctly.
	velo := (target_world - current_pos) / dt
	b2.Body_SetLinearVelocity(entity.body_id, velo)

	// ---- Tilt logic ----
	target_angle: f32
	if abs(velo.x) > PADDLE_VX_STOP_THRESHOLD {
		extra.stop_timer = 0
		target_angle = clamp(-velo.x * PADDLE_TILT_SENSITIVITY, -PADDLE_MAX_TILT, PADDLE_MAX_TILT)
		extra.held_tilt = target_angle
	} else {
		extra.stop_timer += dt
		if extra.stop_timer >= PADDLE_SETTLE_DELAY {
			target_angle = 0 // settle delay elapsed — ease back to flat
		} else {
			target_angle = extra.held_tilt // still within grace period — hold the tilt
		}
	}

	current_rot := b2.Body_GetRotation(entity.body_id)
	current_angle := b2.Rot_GetAngle(current_rot)
	angle_diff := target_angle - current_angle
	b2.Body_SetAngularVelocity(entity.body_id, angle_diff * PADDLE_ANGULAR_GAIN)
}

Paddle_Draw :: proc(entity: ^Entity) {
	pos := b2.Body_GetPosition(entity.body_id)
	rot := b2.Body_GetRotation(entity.body_id)
	angle_deg := rl.RAD2DEG * b2.Rot_GetAngle(rot)
	screen_pos := world_to_screen(pos)

	width := PADDLE_HALF_WIDTH * 2 * PPM
	height := PADDLE_HALF_HEIGHT * 2 * PPM
	paddle_texture := g.textures[.PaddleBlue]

	source := rl.Rectangle{0, 0, f32(paddle_texture.width), f32(paddle_texture.height)}
	dest := rl.Rectangle{screen_pos.x, screen_pos.y, width, height}
	origin := rl.Vector2{width / 2, height / 2}

	rl.DrawTexturePro(paddle_texture, source, dest, origin, -angle_deg, rl.WHITE)
}
