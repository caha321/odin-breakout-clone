package breakout

import b2 "vendor:box2d"
import rl "vendor:raylib"

BALL_RADIUS :: f32(1)
BALL_SPEED_INITIAL :: f32(25)

Ball_Create :: proc() {
	ball_def := b2.DefaultBodyDef()
	ball_def.type = .dynamicBody
	ball_def.position = {0, 0}
	ball_def.name = "ball"
	ball_def.linearVelocity = {BALL_SPEED_INITIAL * 0.7, BALL_SPEED_INITIAL * 0.7}
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
			body_id  = body_id,
			shape_id = shape_id,
			extra    = nil,
			texture  = .BallGrey,
			// v-table
			draw     = Ball_Draw,
			update   = Ball_Update,
			//hit       = Ball_Hit,
		},
	)
}

Ball_Draw :: proc(entity: ^Entity) {
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

}
*/
