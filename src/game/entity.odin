package game

import "core:log"
import b2 "vendor:box2d"


Entity_Variant :: union {
	Ball,
	Block,
	Paddle,
	Wall,
	Powerup,
}

Entity :: struct {
	body_id: b2.BodyId,
	variant: Entity_Variant,
}

Entity_Draw :: proc(entity: ^Entity) {
	switch v in entity.variant {
	case Ball:
		Ball_Draw(entity)
	case Block:
		Block_Draw(entity, v)
	case Paddle:
		Paddle_Draw(entity, v)
	case Wall:
		break
	case Powerup:
		Powerup_Draw(entity, v)
	}
}

Entity_Update :: proc(entity: ^Entity, dt: f32) {
	switch &v in entity.variant {
	case Ball:
		Ball_Update(entity, &v, dt)
	case Paddle:
		Paddle_Update(entity, v, dt)
	case Block:
		break
	case Wall:
		break
	case Powerup:
		break
	}
}

Entity_Hit :: proc(entity: ^Entity, hit: b2.ContactHitEvent) {
	switch &v in entity.variant {
	case Ball:
		break
	case Block:
		Block_Hit(entity, &v, hit)
	case Paddle:
		Paddle_Hit(entity, hit)
	case Wall:
		Wall_Hit(entity, hit)
	case Powerup:
		break
	}
}

Entity_Destroy :: proc(entity: ^Entity) {
	if b2.Body_IsValid(entity.body_id) {
		log.debug(
			"Destroying Box2D body... name:",
			b2.Body_GetName(entity.body_id),
			"; id:",
			entity.body_id,
		)
		b2.DestroyBody(entity.body_id)
	}
}
