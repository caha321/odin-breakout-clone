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

POWERUP_RADIUS :: 1
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
		radius = POWERUP_RADIUS,
	}
	shape_def := b2.DefaultShapeDef()
	shape_def.enableSensorEvents = true
	shape_def.isSensor = true
	_ = b2.CreateCircleShape(body_id, shape_def, &circle)

	kind := kind
	if kind == .Invalid do kind = rand.choice(POWERUP_KINDS)
	Game_AddEntity(
		{
			body_id = body_id,
			render_data = {
				texture = g.textures[kind_to_texture[kind]],
				shape = engine.RenderShape_Circle{diameter = POWERUP_RADIUS * 2},
				tint = rl.WHITE,
			},
			variant = Powerup{kind = kind},
		},
	)
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

@(private = "file")
kind_to_texture := [Powerup_Kind]Texture {
	.Invalid      = .NoTexture,
	.ExtraBall    = .PowerupExtraBall,
	.PaddleSmall  = .PowerupPaddleSmall,
	.PaddleWide   = .PowerupPaddleWide,
	.PaddleSticky = .PowerupPaddleSticky,
	.PaddleTilt   = .PowerupPaddleTilt,
}

create_powerup_textures :: proc() {
	font_spacing :: 1
	font_size :: 100
	img_size :: 128
	circle_radius :: 64

	for kind in Powerup_Kind {
		text := kind_to_text[kind]
		text_measure := rl.MeasureTextEx(g.font, text, font_size, font_spacing)

		img := rl.GenImageColor(img_size, img_size, rl.BLANK)

		center := [2]f32{img_size / 2, img_size / 2}
		rl.ImageDrawCircleV(&img, center, circle_radius, kind_to_color[kind])

		text_position := center - (text_measure / 2)
		rl.ImageDrawTextEx(&img, g.font, text, text_position, font_size, font_spacing, rl.WHITE)

		g.textures[kind_to_texture[kind]] = rl.LoadTextureFromImage(img)
		rl.UnloadImage(img)
	}
}
