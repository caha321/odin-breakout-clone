package breakout

import "core:log"
import b2 "vendor:box2d"

EntityKind :: enum {
	Unknown,
	Ball,
	Paddle,
	Block,
	Wall,
}

// used as user data in b2 shapes
User_Data :: struct {
	sound_hit:   Sound,
	entity_kind: EntityKind,
	entity_id:   uint, // must be > 0 to be valid
}

// Extra data not shared by all entities. Size will be maximum size of each
Entity_Extra :: union {
	Entity_Extra_Paddle,
	Entity_Extra_Block,
}


Entity :: struct {
	kind:      EntityKind,
	body_id:   b2.BodyId,
	shape_id:  b2.ShapeId,
	user_data: ^User_Data, // b2 userdata, owned by the entity
	texture:   Texture,
	extra:     Entity_Extra, // by value
	// v-table
	update:    proc(e: ^Entity, dt: f32), // called before physics step
	draw:      proc(e: ^Entity),
	//destroy:   proc(e: ^Entity),
}

Entity_Destroy :: proc(entity: ^Entity) {
	if b2.Body_IsValid(entity.body_id) {
		log.debug("Destroying Box2D body", entity.body_id)
		b2.DestroyBody(entity.body_id)
	}
	if entity.user_data != nil {
		log.debug("Freeing user data", entity.user_data)
		free(entity.user_data)
		entity.user_data = nil
	}
}
