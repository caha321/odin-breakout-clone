package game

import "core:log"
import b2 "vendor:box2d"


Entity_Variant :: union {
	Ball,
	Block,
	Paddle,
	Wall,
	Powerup,
	Fragment,
}

Entity :: struct {
	body_id:            b2.BodyId,
	previous_transform: b2.Transform, // used for blending, set by entities themselves
	variant:            Entity_Variant,
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
	case Fragment:
		Fragment_Draw(entity, v)
	}
}

Entity_Update :: proc(entity: ^Entity, dt: f32) {
	#partial switch &v in entity.variant {
	case Ball:
		Ball_Update(entity, &v, dt)
	case Paddle:
		Paddle_Update(entity, v, dt)
	}
}

Entity_Hit :: proc(entity: ^Entity, hit: b2.ContactHitEvent) {
	#partial switch &v in entity.variant {
	case Block:
		Block_Hit(entity, &v, hit)
	case Paddle:
		Paddle_Hit(entity, hit)
	case Wall:
		Wall_Hit(entity, hit)
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
	#partial switch &v in entity.variant {
	case Fragment:
		delete(v.uvs)
		delete(v.vertices)
		log.debug("Fragment variant destroyed")
	}
}
