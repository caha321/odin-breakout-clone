package game

import "core:log"
import b2 "vendor:box2d"

import "../engine"

Fragment :: struct {} // TODO remove

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
	render_data:        engine.RenderData,
	variant:            Entity_Variant,
}

// box2d filter category
Category_Flag :: enum u64 {
	Ball,
	Foreground,
	Background,
}
Category_Flags :: bit_set[Category_Flag]

Entity_Draw :: proc(entity: ^Entity) {
	if !b2.IsValid(entity.body_id) {
		log.debug("Cannot draw entity without valid body!")
		return
	}

	switch v in entity.variant {
	case Ball:
		Ball_Draw(entity)
	case Block:
		Block_Draw(entity, v)
	case Paddle:
		Paddle_Draw(entity)
	case Wall:
		rt := engine.get_render_transform(b2.Body_GetTransform(entity.body_id))
		engine.render(entity.render_data, rt)
		break
	case Powerup:
		Powerup_Draw(entity, v)
	case Fragment:
		rt := engine.get_render_transform(b2.Body_GetTransform(entity.body_id))
		engine.render(entity.render_data, rt)
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

Entity_Hit :: proc(entity, other: ^Entity, hit: b2.ContactHitEvent) {
	if !b2.Body_IsValid(entity.body_id) do return
	if !b2.Body_IsValid(other.body_id) do return

	#partial switch &v in entity.variant {
	case Block:
		ball, ok := other.variant.(Ball)
		if ok {
			Block_Hit(entity, &v, hit)
		} else {
			log.warn("Block hit by something else:", typeid_of(type_of(other.variant)))
		}
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
	engine.RenderData_Destroy(entity.render_data)
}
