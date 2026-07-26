package breakout

import "core:math"
import "core:math/rand"
import b2 "vendor:box2d"
import rl "vendor:raylib"


BALL_RADIUS :: f32(1)
BALL_SPEED_INITIAL :: f32(25)

Entity_Extra_Ball :: struct {
	damage: u8,
}

Ball_Create :: proc(world_position: [2]f32) {
	ball_def := b2.DefaultBodyDef()
	ball_def.type = .dynamicBody
	ball_def.position = world_position
	ball_def.name = "ball"
	ball_def.linearVelocity = random_ball_velocity(BALL_SPEED_INITIAL)
	body_id := b2.CreateBody(g.world_id, ball_def)

	circle := b2.Circle {
		center = {0, 0},
		radius = BALL_RADIUS,
	}
	shape_def := b2.DefaultShapeDef()
	shape_def.density = 1.0
	shape_def.material.friction = 0.0 // a bouncing ball shouldn't "stick" on contact
	shape_def.material.restitution = 1.0 // perfectly elastic bounce
	shape_def.enableSensorEvents = true // required on both sides
	shape_def.enableHitEvents = true
	shape_id := b2.CreateCircleShape(body_id, shape_def, &circle)

	Game_AddEntity(
		{
			body_id = body_id,
			shape_id = shape_id,
			extra = Entity_Extra_Ball {
				damage = 1, // TODO feature: deal more damage to blocks
			},
			texture = .BallGrey,
			// v-table
			draw = Ball_Draw,
			update = Ball_Update,
			//hit       = Ball_Hit,
		},
	)
}

random_ball_velocity :: proc(speed: f32) -> [2]f32 {
	// Avoid near-horizontal (grazing) and near-vertical (boring) launches
	// by picking from two 60°-wide cones, one upward-diagonal, one downward-diagonal
	min_angle: f32 = math.PI * 0.15 // ~27°
	max_angle: f32 = math.PI * 0.35 // ~63°

	angle := rand.float32_range(min_angle, max_angle)
	if rand.float32() < 0.5 {
		angle = math.PI - angle // mirror into the upper-left cone
	}

	return {math.cos(angle) * speed, math.sin(angle) * speed}
}

Ball_Draw :: proc(entity: ^Entity) {
	if b2.IsValid(entity.body_id) {
		pos := b2.Body_GetPosition(entity.body_id)
		rot := b2.Body_GetRotation(entity.body_id)
		angle_deg := rl.RAD2DEG * b2.Rot_GetAngle(rot)
		screen_pos := world_to_screen(pos)

		diameter := BALL_RADIUS * 2 * PPM
		rl_texture := g.textures[entity.texture]

		source := rl.Rectangle{0, 0, f32(rl_texture.width), f32(rl_texture.height)}
		dest := rl.Rectangle{screen_pos.x, screen_pos.y, diameter, diameter}
		origin := rl.Vector2{diameter / 2, diameter / 2} // center pivot

		rl.DrawTexturePro(rl_texture, source, dest, origin, -angle_deg, rl.WHITE)
	}
}

Ball_Update :: proc(entity: ^Entity, dt: f32) {
	// normalize ball speed
	vel := b2.Body_GetLinearVelocity(entity.body_id)
	speed := b2.Length(vel)
	if speed > 0 {
		b2.Body_SetLinearVelocity(entity.body_id, vel * (g.ball_speed / speed))
	}
}

/*
Ball_Hit :: proc(entity: ^Entity, hit: b2.ContactHitEvent) {
	// TODO play sound if two balls hit 
}
*/
