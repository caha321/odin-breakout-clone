package game

import "core:log"
import "core:math"
import "core:math/rand"
import b2 "vendor:box2d"
import rl "vendor:raylib"

import "../engine"

BALL_RADIUS :: 1
BALL_SPEED_INITIAL :: 25
BALL_RELEASE_BUTTON :: rl.MouseButton.LEFT
REATTACH_COOLDOWN :: 0.3

Ball_Kind :: enum u8 {
	Blue,
	Grey,
}

Ball :: struct {
	kind:              Ball_Kind,
	damage:            u8,
	attached_to:       b2.BodyId, // invalid handle = not attached
	attach_offset_x:   f32,
	reattach_cooldown: f32, // seconds remaining before this ball can stick again
}

Ball_Create :: proc(world_position: [2]f32, kind: Ball_Kind = Ball_Kind.Grey) {
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
	_ = b2.CreateCircleShape(body_id, shape_def, &circle)

	Game_AddEntity(
		{
			body_id = body_id,
			variant = Ball {
				damage = 1, // TODO feature: deal more damage to blocks
				kind   = kind,
			},
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

@(private = "file")
ball_kind_to_texture := [Ball_Kind]Texture {
	.Blue = .BallBlue,
	.Grey = .BallGrey,
}

Ball_Draw :: proc(self: ^Entity) {
	if !b2.IsValid(self.body_id) {
		log.debug("Cannot draw ball without valid body!")
		return
	}

	rt := get_render_transform_blended(
		self.previous_transform,
		b2.Body_GetTransform(self.body_id),
		alpha = g.accumulated_time / DT,
	)

	diameter: f32 = BALL_RADIUS * 2 * PPM
	rl_texture := g.textures[ball_kind_to_texture[self.variant.(Ball).kind]]

	source := rl.Rectangle{0, 0, f32(rl_texture.width), f32(rl_texture.height)}
	dest := rl.Rectangle{rt.screen_position.x, rt.screen_position.y, diameter, diameter}
	origin := rl.Vector2{diameter / 2, diameter / 2} // center pivot

	rl.DrawTexturePro(rl_texture, source, dest, origin, -rt.angle_deg, rl.WHITE)
}

try_attach_ball :: proc(paddle_entity, ball_entity: ^Entity) -> bool {
	if rl.IsMouseButtonDown(BALL_RELEASE_BUTTON) do return false
	if paddle_entity == nil || ball_entity == nil do return false
	paddle_variant := paddle_entity.variant.(Paddle) or_return
	ball_variant := (&ball_entity.variant.(Ball)) or_return

	if ball_variant.reattach_cooldown > 0 do return false
	if .Sticky not_in paddle_variant.flags do return false

	ball_pos := b2.Body_GetPosition(ball_entity.body_id)
	paddle_pos := b2.Body_GetPosition(paddle_entity.body_id)

	ball_variant.attach_offset_x = ball_pos.x - paddle_pos.x
	ball_variant.attached_to = paddle_entity.body_id

	b2.Body_SetLinearVelocity(ball_entity.body_id, {0, 0})
	b2.Body_SetType(ball_entity.body_id, .kinematicBody) // no longer affected by physics forces
	log.debug("Attached ball", ball_entity.body_id)
	return true
}

try_release_ball :: proc(ball_entity: ^Entity, variant: ^Ball) -> bool {
	paddle_entity := engine.Pool_Get(g.entity_pool, variant.attached_to) or_return
	if b2.Body_GetType(ball_entity.body_id) != .kinematicBody do return false

	b2.Body_SetType(ball_entity.body_id, .dynamicBody)
	b2.Body_SetLinearVelocity(ball_entity.body_id, random_ball_velocity(g.ball_speed))

	variant.attached_to = {}
	variant.reattach_cooldown = REATTACH_COOLDOWN
	log.debug("Released ball", ball_entity.body_id)
	return true
}

Ball_Update :: proc(self: ^Entity, variant: ^Ball, dt: f32) {
	self.previous_transform = b2.Body_GetTransform(self.body_id)

	paddle, ok := engine.Pool_Get(g.entity_pool, variant.attached_to)
	if ok { 	// we are attached to a paddle
		if rl.IsMouseButtonPressed(BALL_RELEASE_BUTTON) {
			try_release_ball(self, variant)
		} else {
			paddle_transform := b2.Body_GetTransform(paddle.body_id)

			local_offset := [2]f32{variant.attach_offset_x, PADDLE_HALF_HEIGHT + BALL_RADIUS}
			world_pos := b2.TransformPoint(paddle_transform, local_offset)

			// Match the ball's rotation to the paddle's too, so it visually
			// "sits on" the tilted surface rather than staying upright
			b2.Body_SetTransform(self.body_id, world_pos, paddle_transform.q)
		}
	} else {
		if variant.reattach_cooldown > 0 {
			variant.reattach_cooldown -= dt
		}
		// normalize ball speed
		vel := b2.Body_GetLinearVelocity(self.body_id)
		speed := b2.Length(vel)
		if speed > 0 {
			b2.Body_SetLinearVelocity(self.body_id, vel * (g.ball_speed / speed))
		}
	}
}

/*
Ball_Hit :: proc(entity: ^Entity, hit: b2.ContactHitEvent) {
	// TODO play sound if two balls hit 
}
*/
