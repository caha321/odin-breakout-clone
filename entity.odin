package breakout

import "core:log"
import b2 "vendor:box2d"


Entity_Variant :: union {
	Ball,
	Block,
	Paddle,
	Wall,
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
	}
}

Entity_Update :: proc(entity: ^Entity, dt: f32) {
	switch v in entity.variant {
	case Ball:
		Ball_Update(entity, dt)
	case Paddle:
		Paddle_Update(entity, v, dt)
	case Block:
		break
	case Wall:
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
	}
}

Entity_Destroy :: proc(entity: Entity) {
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


Entity_Handle :: struct {
	index:      u32, // 0 is always invalid
	generation: u32,
}

Entity_Slot :: struct {
	entity:     Entity,
	generation: u32,
	alive:      bool,
}

Entity_Pool :: struct {
	slots:     [dynamic]Entity_Slot,
	free_list: [dynamic]u32, // indices of dead slots ready to use
}

// set userdata of entities body and shapes to entity ID
@(private = "file")
set_user_data :: proc(body_id: b2.BodyId, handle: Entity_Handle) {
	user_data := entity_handle_to_userdata(handle)

	b2.Body_SetUserData(body_id, user_data)

	@(static) buffer: [8]b2.ShapeId // is currently more than enough
	assert(b2.Body_GetShapeCount(body_id) <= 8)

	shapes := b2.Body_GetShapes(body_id, buffer[:])
	for shape_id in shapes {
		b2.Shape_SetUserData(shape_id, user_data)
	}
}

Pool_Add :: proc(pool: ^Entity_Pool, entity: Entity) -> Entity_Handle {
	handle: Entity_Handle

	if len(pool.free_list) > 0 {
		index := pop(&pool.free_list)
		pool.slots[index].entity = entity
		pool.slots[index].alive = true
		log.debug("Reused dead slot", index, "for", entity)
		handle = {
			index      = index,
			generation = pool.slots[index].generation,
		}
	}
	append(&pool.slots, Entity_Slot{entity = entity, generation = 0, alive = true})
	handle = Entity_Handle {
		index      = u32(len(pool.slots)),
		generation = 0,
	}

	set_user_data(entity.body_id, handle)
	return handle
}

@(private = "file")
entity_handle_to_index :: #force_inline proc(handle: Entity_Handle) -> int {
	index := int(handle.index) - 1 // indices stored as +1, since 0 is always invalid
	assert(index >= 0)
	return index
}

Pool_Remove_Handle :: proc(pool: ^Entity_Pool, handle: Entity_Handle) -> bool {
	if !Pool_IsValid(pool^, handle) do return false
	index := entity_handle_to_index(handle)

	Entity_Destroy(pool.slots[index].entity)

	pool.slots[index].alive = false
	pool.slots[index].generation += 1 // invalidate old handles
	append(&pool.free_list, u32(index))
	return true
}

Pool_Remove_BodyId :: proc(pool: ^Entity_Pool, id: b2.BodyId) -> bool {
	if !b2.Body_IsValid(id) do return false
	handle := userdata_to_entity_handle(b2.Body_GetUserData(id))
	return Pool_Remove_Handle(pool, handle)
}

Pool_Remove_ShapeId :: proc(pool: ^Entity_Pool, id: b2.ShapeId) -> bool {
	if !b2.Shape_IsValid(id) do return false
	handle := userdata_to_entity_handle(b2.Shape_GetUserData(id))
	return Pool_Remove_Handle(pool, handle)
}

Pool_Remove :: proc {
	Pool_Remove_Handle,
	Pool_Remove_BodyId,
	Pool_Remove_ShapeId,
}

Pool_IsValid :: proc(pool: Entity_Pool, handle: Entity_Handle) -> bool {
	index := entity_handle_to_index(handle)
	return(
		index < len(pool.slots) &&
		pool.slots[index].alive &&
		pool.slots[index].generation == handle.generation \
	)
}

Pool_Get_Handle :: proc(pool: Entity_Pool, handle: Entity_Handle) -> (entity: ^Entity, ok: bool) {
	if !Pool_IsValid(pool, handle) do return nil, false
	return &pool.slots[entity_handle_to_index(handle)].entity, true
}

Pool_Get_BodyId :: proc(pool: Entity_Pool, id: b2.BodyId) -> (entity: ^Entity, ok: bool) {
	if !b2.Body_IsValid(id) do return nil, false
	handle := userdata_to_entity_handle(b2.Body_GetUserData(id))
	return Pool_Get_Handle(pool, handle)
}

Pool_Get_ShapeId :: proc(pool: Entity_Pool, id: b2.ShapeId) -> (entity: ^Entity, ok: bool) {
	if !b2.Shape_IsValid(id) do return nil, false
	handle := userdata_to_entity_handle(b2.Shape_GetUserData(id))
	return Pool_Get_Handle(pool, handle)
}

Pool_Get :: proc {
	Pool_Get_Handle,
	Pool_Get_BodyId,
	Pool_Get_ShapeId,
}

Pool_Clear :: proc(pool: ^Entity_Pool) {
	for slot in g.entity_pool.slots {
		if !slot.alive do continue
		Entity_Destroy(slot.entity)
	}
	clear(&pool.free_list)
	clear(&pool.slots)
}

Pool_Delete :: proc(pool: Entity_Pool) {
	delete(pool.free_list)
	delete(pool.slots)
}

@(private = "file")
entity_handle_to_userdata :: #force_inline proc(handle: Entity_Handle) -> rawptr {
	return transmute(rawptr)handle
}

@(private = "file")
userdata_to_entity_handle :: #force_inline proc(p: rawptr) -> Entity_Handle {
	return transmute(Entity_Handle)p
}
