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
	generation: u32, // even = invalid (because of 0), odd = valid
}

Entity_Pool :: struct {
	slots:     [dynamic]Entity_Slot,
	free_list: [dynamic]u32, // indices of dead slots ready to use
}

slot_valid :: #force_inline proc(generation: u32) -> bool {
	return generation % 2 == 1
}

Pool_Add :: proc(pool: ^Entity_Pool, entity: Entity) -> Entity_Handle {
	handle: Entity_Handle

	if len(pool.free_list) > 0 {
		index := pop(&pool.free_list)
		pool.slots[index].entity = entity
		pool.slots[index].generation += 1 // odd = dead, now even = alive
		log.debug("Reused dead slot", index, "for", entity)
		handle = {
			index      = index + 1,
			generation = pool.slots[index].generation,
		}
	} else {
		append(&pool.slots, Entity_Slot{entity = entity, generation = 1})
		log.debug("Appended slot", len(pool.slots), "for", entity)
		handle = Entity_Handle {
			index      = u32(len(pool.slots)),
			generation = 1,
		}
	}

	set_user_data(entity.body_id, handle)
	return handle
}

@(private = "file")
entity_handle_to_index :: #force_inline proc(handle: Entity_Handle) -> (index: int, ok: bool) {
	index = int(handle.index) - 1 // indices stored as +1, since 0 is always invalid
	ok = index >= 0
	return
}

Pool_Remove_Handle :: proc(pool: ^Entity_Pool, handle: Entity_Handle) -> bool {
	index, ok := Pool_GetValidIndex(pool^, handle)
	if !ok {
		log.warn("Tried to remove with invalid handle", handle)
		return false
	}
	log.debug("Removing", handle, "from pool")

	Entity_Destroy(pool.slots[index].entity)

	pool.slots[index].generation += 1 // invalidate old handles and marks it as invalid
	append(&pool.free_list, u32(index))
	return true
}

Pool_Remove_BodyId :: proc(pool: ^Entity_Pool, id: b2.BodyId) -> bool {
	if !b2.Body_IsValid(id) {
		log.warn("Tried to remove with invalid body id", id)
		return false
	}
	handle := userdata_to_entity_handle(b2.Body_GetUserData(id))
	return Pool_Remove_Handle(pool, handle)
}

Pool_Remove_ShapeId :: proc(pool: ^Entity_Pool, id: b2.ShapeId) -> bool {
	if !b2.Shape_IsValid(id) {
		log.warn("Tried to remove with invalid shape id", id)
		return false
	}
	handle := userdata_to_entity_handle(b2.Shape_GetUserData(id))
	return Pool_Remove_Handle(pool, handle)
}

Pool_Remove :: proc {
	Pool_Remove_Handle,
	Pool_Remove_BodyId,
	Pool_Remove_ShapeId,
}

@(private = "file")
Pool_GetValidIndex :: proc(pool: Entity_Pool, handle: Entity_Handle) -> (index: int, ok: bool) {
	index, ok = entity_handle_to_index(handle)
	if !ok do return
	ok =
		(index < len(pool.slots) &&
			slot_valid(handle.generation) &&
			pool.slots[index].generation == handle.generation)
	return
}

Pool_Get_Handle :: proc(pool: Entity_Pool, handle: Entity_Handle) -> (entity: ^Entity, ok: bool) {
	index: int
	index, ok = Pool_GetValidIndex(pool, handle)
	if !ok {
		log.warn("Tried to get with invalid handle", handle)
		return nil, false
	}
	return &pool.slots[index].entity, true
}

Pool_Get_BodyId :: proc(pool: Entity_Pool, id: b2.BodyId) -> (entity: ^Entity, ok: bool) {
	if !b2.Body_IsValid(id) {
		log.warn("Tried to get with invalid body id", id)
		return nil, false
	}
	handle := userdata_to_entity_handle(b2.Body_GetUserData(id))
	return Pool_Get_Handle(pool, handle)
}

Pool_Get_ShapeId :: proc(pool: Entity_Pool, id: b2.ShapeId) -> (entity: ^Entity, ok: bool) {
	if !b2.Shape_IsValid(id) {
		log.warn("Tried to get with invalid shape id", id)
		return nil, false
	}
	handle := userdata_to_entity_handle(b2.Shape_GetUserData(id))
	return Pool_Get_Handle(pool, handle)
}

Pool_Get :: proc {
	Pool_Get_Handle,
	Pool_Get_BodyId,
	Pool_Get_ShapeId,
}

Pool_Clear :: proc(pool: ^Entity_Pool) {
	log.debug("Clearing Pool...")
	for slot, index in pool.slots {
		if !slot_valid(slot.generation) do continue
		Entity_Destroy(slot.entity)
	}
	clear(&pool.free_list)
	clear(&pool.slots)
}

Pool_Delete :: proc(pool: Entity_Pool) {
	delete(pool.free_list)
	delete(pool.slots)
}

// make sure our handle fits into user data "pointer"
// we transmute, so they must be exactly the same size
#assert(size_of(Entity_Handle) == size_of(rawptr))

@(private = "file")
entity_handle_to_userdata :: #force_inline proc(handle: Entity_Handle) -> rawptr {
	return transmute(rawptr)handle
}

@(private = "file")
userdata_to_entity_handle :: #force_inline proc(p: rawptr) -> Entity_Handle {
	return transmute(Entity_Handle)p
}

// set userdata of entities body and shapes to entity ID
@(private = "file")
set_user_data :: proc(body_id: b2.BodyId, handle: Entity_Handle) {
	user_data := entity_handle_to_userdata(handle)

	b2.Body_SetUserData(body_id, user_data)

	buffer: [8]b2.ShapeId // is currently more than enough
	assert(b2.Body_GetShapeCount(body_id) <= 8)

	shapes := b2.Body_GetShapes(body_id, buffer[:])
	for shape_id in shapes {
		b2.Shape_SetUserData(shape_id, user_data)
	}
}


// ---- test helpers ----

import "core:sync"
import "core:testing"

@(private = "file")
g_world_mutex: sync.Mutex // Creating/destroying worlds is NOT thread safe :)

@(private = "file")
make_test_world :: proc() -> b2.WorldId {
	sync.mutex_lock(&g_world_mutex)
	defer sync.mutex_unlock(&g_world_mutex)

	def := b2.DefaultWorldDef()
	return b2.CreateWorld(def)
}

@(private = "file")
destroy_test_world :: proc(world: b2.WorldId) {
	sync.mutex_lock(&g_world_mutex)
	defer sync.mutex_unlock(&g_world_mutex)
	b2.DestroyWorld(world)
}

@(private = "file")
make_test_entity :: proc(world: b2.WorldId) -> Entity {
	def := b2.DefaultBodyDef()
	body_id := b2.CreateBody(world, def)
	return Entity{body_id = body_id, variant = Wall{}} // pick whatever cheap variant
}

// ---- tests ----

@(test)
test_pool_add_returns_valid_handle :: proc(t: ^testing.T) {
	world := make_test_world()
	defer destroy_test_world(world)

	pool: Entity_Pool
	defer Pool_Delete(pool)

	e := make_test_entity(world)
	h := Pool_Add(&pool, e)

	testing.expect(t, h.index != 0, "handle index should never be 0 for a valid add")
	testing.expect(t, h.generation != 0, "handle generation should never be 0 for a valid add")
	index, ok := Pool_GetValidIndex(pool, h)
	testing.expect(t, ok, "freshly added handle should be valid")
	testing.expect(
		t,
		u32(index + 1) == h.index,
		"handle index should be +1 to account for 0=invalid",
	)
	testing.expect(t, pool.slots[index].generation == h.generation)

	entity: ^Entity
	entity, ok = Pool_Get(pool, h)
	testing.expect(t, ok, "Pool_Get should succeed for a valid handle")
	testing.expect(t, entity.body_id == e.body_id, "returned entity should match what was added")
}

@(test)
test_pool_add_twice_gives_distinct_handles :: proc(t: ^testing.T) {
	world := make_test_world()
	defer destroy_test_world(world)

	pool: Entity_Pool
	defer Pool_Delete(pool)

	e1 := make_test_entity(world)
	e2 := make_test_entity(world)

	h1 := Pool_Add(&pool, e1)
	h2 := Pool_Add(&pool, e2)

	testing.expect(t, h1.index != h2.index, "two distinct adds must get distinct slots")
	testing.expect(t, len(pool.slots) == 2, "exactly 2 slots should exist after 2 adds")

	ent1, ok1 := Pool_Get(pool, h1)
	ent2, ok2 := Pool_Get(pool, h2)
	testing.expect(t, ok1 && ok2, "both handles should resolve")
	testing.expect(t, ent1.body_id != ent2.body_id, "the two entities must not share a body_id")
}

@(test)
test_pool_remove_invalidates_handle :: proc(t: ^testing.T) {
	world := make_test_world()
	defer destroy_test_world(world)

	pool: Entity_Pool
	defer Pool_Delete(pool)

	e := make_test_entity(world)
	h := Pool_Add(&pool, e)

	ok := Pool_Remove(&pool, h)
	testing.expect(t, ok, "removing a valid handle should succeed")
	_, ok = Pool_GetValidIndex(pool, h)
	testing.expect(t, !ok, "handle should be invalid after removal")

	_, ok = Pool_Get(pool, h)
	testing.expect(t, !ok, "Pool_Get should fail on a removed handle")
}

@(test)
test_pool_reuses_freed_slot_with_bumped_generation :: proc(t: ^testing.T) {
	world := make_test_world()
	defer destroy_test_world(world)

	pool: Entity_Pool
	defer Pool_Delete(pool)

	e1 := make_test_entity(world)
	h1 := Pool_Add(&pool, e1)
	Pool_Remove(&pool, h1)

	e2 := make_test_entity(world)
	h2 := Pool_Add(&pool, e2)

	testing.expect(t, len(pool.slots) == 1, "freed slot should be reused, not grow the array")
	testing.expect(t, h2.index == h1.index, "reused slot should have the same index")
	testing.expect(t, h2.generation != h1.generation, "reused slot must get a new generation")
	_, ok := Pool_GetValidIndex(pool, h1)
	testing.expect(t, !ok, "old handle must stay invalid after slot reuse")
	_, ok = Pool_GetValidIndex(pool, h2)
	testing.expect(t, ok, "new handle for the reused slot must be valid")
}

@(test)
test_stale_handle_never_aliases_new_entity :: proc(t: ^testing.T) {
	world := make_test_world()
	defer destroy_test_world(world)

	pool: Entity_Pool
	defer Pool_Delete(pool)

	e1 := make_test_entity(world)
	h1 := Pool_Add(&pool, e1)
	Pool_Remove(&pool, h1)

	e2 := make_test_entity(world)
	h2 := Pool_Add(&pool, e2)

	// old handle must NOT resolve to the new entity, even though it may
	// reuse the same slot index
	entity_via_stale, ok := Pool_Get(pool, h1)
	testing.expect(t, !ok, "stale handle must not resolve at all")
}

@(test)
test_pool_get_by_body_id_matches_handle :: proc(t: ^testing.T) {
	world := make_test_world()
	defer destroy_test_world(world)

	pool: Entity_Pool
	defer Pool_Delete(pool)

	e := make_test_entity(world)
	h := Pool_Add(&pool, e)

	entity, ok := Pool_Get(pool, e.body_id)
	testing.expect(t, ok, "Pool_Get by body_id should succeed")
	testing.expect(t, entity.body_id == e.body_id)

	got_handle_entity, _ := Pool_Get(pool, h)
	testing.expect(t, entity == got_handle_entity, "both lookup paths must return the same slot")
}

@(test)
test_pool_clear_invalidates_everything :: proc(t: ^testing.T) {
	world := make_test_world()
	defer destroy_test_world(world)

	pool: Entity_Pool
	defer Pool_Delete(pool)

	e1 := make_test_entity(world)
	e2 := make_test_entity(world)
	h1 := Pool_Add(&pool, e1)
	h2 := Pool_Add(&pool, e2)

	Pool_Clear(&pool)

	_, ok := Pool_GetValidIndex(pool, h1)
	testing.expect(t, !ok)
	_, ok = Pool_GetValidIndex(pool, h2)
	testing.expect(t, !ok)
	testing.expect(t, len(pool.slots) == 0)
	testing.expect(t, len(pool.free_list) == 0)
}

@(test)
test_handle_zero_index_always_invalid :: proc(t: ^testing.T) {
	pool: Entity_Pool
	defer Pool_Delete(pool)

	zero_handle := Entity_Handle {
		index      = 0,
		generation = 1,
	}
	_, ok := Pool_GetValidIndex(pool, zero_handle)
	testing.expect(t, !ok, "index 0 must always be invalid")
}
