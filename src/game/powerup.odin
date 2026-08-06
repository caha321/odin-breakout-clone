package game

import "core:math/rand"
import b2 "vendor:box2d"
import rl "vendor:raylib"

import "../engine"

Powerup_Kind :: enum u8 {
	Invalid,
	ExtraBall,
	PaddleSmall,
	PaddleWide,
	PaddleSticky,
	PaddleTilt,
}

// weighted table, paddle small & wide kinds are twice as likely
POWERUP_KINDS := []Powerup_Kind {
	.ExtraBall,
	.PaddleSmall,
	.PaddleSmall,
	.PaddleWide,
	.PaddleWide,
	.PaddleSticky,
	.PaddleTilt,
}

Powerup :: struct {
	kind: Powerup_Kind,
}

POWER_UP_RADIUS :: 1
POWERUP_FALL_SPEED_MIN :: 5
POWERUP_FALL_SPEED_MAX :: 20
POWERUP_DROP_CHANCE :: .5 // TODO too high, just for testing

// Spawn a new powerup at given position. Kind is random by default.
Powerup_Create :: proc(position: [2]f32, kind: Powerup_Kind = .Invalid) {
	body_def := b2.DefaultBodyDef()
	body_def.name = "powerup"
	body_def.type = .kinematicBody
	body_def.position = position
	body_def.linearVelocity = {
		0,
		-rand.float32_range(POWERUP_FALL_SPEED_MIN, POWERUP_FALL_SPEED_MAX),
	}
	body_id := b2.CreateBody(g.world_id, body_def)

	circle := b2.Circle {
		radius = POWER_UP_RADIUS,
	}
	shape_def := b2.DefaultShapeDef()
	shape_def.enableSensorEvents = true
	shape_def.isSensor = true
	_ = b2.CreateCircleShape(body_id, shape_def, &circle)

	kind := kind
	if kind == .Invalid do kind = rand.choice(POWERUP_KINDS)
	Game_AddEntity({body_id = body_id, variant = Powerup{kind = kind}})
}


// TODO proper textures
@(private = "file")
kind_to_color := [Powerup_Kind]rl.Color {
	.Invalid      = rl.PINK,
	.ExtraBall    = rl.BLUE,
	.PaddleSmall  = rl.RED,
	.PaddleWide   = rl.GREEN,
	.PaddleSticky = rl.LIME,
	.PaddleTilt   = rl.PINK,
}

@(private = "file")
kind_to_text := [Powerup_Kind]cstring {
	.Invalid      = "X",
	.PaddleSmall  = "-",
	.PaddleWide   = "+",
	.ExtraBall    = "B",
	.PaddleSticky = "S",
	.PaddleTilt   = "T",
}

Powerup_Draw :: proc(entity: ^Entity, variant: Powerup) {
	pos := b2.Body_GetPosition(entity.body_id)
	screen_pos := engine.world_to_screen(pos)

	rl.DrawCircleV(screen_pos, POWER_UP_RADIUS, kind_to_color[variant.kind])

	font := rl.GetFontDefault()
	font_size := 30 / engine.camera.zoom
	font_spacing := 1 / engine.camera.zoom
	text := kind_to_text[variant.kind]

	text_measure := rl.MeasureTextEx(font, text, font_size, font_spacing)

	text_position := [2]f32{screen_pos.x - text_measure.x / 2, screen_pos.y - text_measure.y / 2}
	rl.DrawTextEx(font, text, text_position, font_size, font_spacing, rl.WHITE)
}
