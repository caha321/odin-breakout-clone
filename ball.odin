package breakout

import b2 "vendor:box2d"
import rl "vendor:raylib"

BALL_RADIUS :: f32(1)
BALL_SPEED_INITIAL :: f32(25)

ball_id: b2.BodyId

ball_create :: proc(world_id: b2.WorldId) {
	ball_def := b2.DefaultBodyDef()
	ball_def.type = .dynamicBody
	ball_def.position = {0, 0}
	ball_def.name = "ball"
	ball_def.linearVelocity = {BALL_SPEED_INITIAL * 0.7, BALL_SPEED_INITIAL * 0.7}
	//ball_def.angularVelocity = 1
	//ball_def.fixedRotation = true // spin doesn't matter for a round ball's motion
	ball_id = b2.CreateBody(world_id, ball_def)

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

	data := new(User_Data)
	data.sound_hit = .NoSound
	shape_def.userData = data

	_ = b2.CreateCircleShape(ball_id, shape_def, &circle)
}

ball_draw :: proc() {
	pos := b2.Body_GetPosition(ball_id)
	rot := b2.Body_GetRotation(ball_id)
	angle_deg := rl.RAD2DEG * b2.Rot_GetAngle(rot)
	screen_pos := world_to_screen(pos)

	diameter := BALL_RADIUS * 2 * PPM
	ball_texture := g.textures[.BallGrey]

	source := rl.Rectangle{0, 0, f32(ball_texture.width), f32(ball_texture.height)}
	dest := rl.Rectangle{screen_pos.x, screen_pos.y, diameter, diameter}
	origin := rl.Vector2{diameter / 2, diameter / 2} // center pivot

	rl.DrawTexturePro(ball_texture, source, dest, origin, -angle_deg, rl.WHITE)
}
