package breakout

import "core:log"
import b2 "vendor:box2d"


// Extra data not shared by all entities. Size will be maximum size of each
Entity_Extra :: union {
	Entity_Extra_Ball,
	Entity_Extra_Paddle,
	Entity_Extra_Block,
}

Entity :: struct {
	body_id:  b2.BodyId,
	shape_id: b2.ShapeId,
	texture:  Texture,
	extra:    Entity_Extra, // by value
	// v-table
	update:   proc(e: ^Entity, dt: f32), // called before physics step
	draw:     proc(e: ^Entity),
	hit:      proc(e: ^Entity, hit: b2.ContactHitEvent),
	//destroy:   proc(e: ^Entity),
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

entity_index_to_userdata :: proc(index: uint) -> rawptr {
	return rawptr(uintptr(index + 1)) // +1 so index 0 doesn't collide with nil
}

userdata_to_entity_index :: proc(p: rawptr) -> uint {
	return uint(uintptr(p)) - 1
}

get_entity_uint :: proc(index: uint) -> ^Entity {
	if index >= len(g.entities) do return nil
	return &g.entities[index]
}

get_entity_userdata :: proc(user_data: rawptr) -> ^Entity {
	return get_entity_uint(userdata_to_entity_index(user_data))
}

get_entity :: proc {
	get_entity_uint,
	get_entity_userdata,
}
