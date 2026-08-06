package engine

import "core:math/rand"

Camera_Shake :: struct {
	trauma: f32, // 0..1
}

camera_shake: Camera_Shake

SHAKE_DECAY :: 1.5 // trauma units per second
SHAKE_MAX_OFFSET :: 20 // max pixel offset at full trauma
SHAKE_MAX_ROT :: 5 // max rotation in degrees at full trauma

shake_add_trauma :: proc(amount: f32) {
	camera_shake.trauma = min(camera_shake.trauma + amount, 1)
}

shake_update :: proc(dt: f32) {
	if camera_shake.trauma <= 0 {
		camera.offset = {f32(screen.width) / 2, f32(screen.height) / 2}
		camera.rotation = 0
		return
	}

	camera_shake.trauma = max(camera_shake.trauma - SHAKE_DECAY * dt, 0)
	shake_amount := camera_shake.trauma * camera_shake.trauma // squared falloff

	offset_x := (rand.float32() * 2 - 1) * SHAKE_MAX_OFFSET * shake_amount
	offset_y := (rand.float32() * 2 - 1) * SHAKE_MAX_OFFSET * shake_amount
	rot := (rand.float32() * 2 - 1) * SHAKE_MAX_ROT * shake_amount

	camera.offset = {f32(screen.width) / 2 + offset_x, f32(screen.height) / 2 + offset_y}
	camera.rotation = rot
}
