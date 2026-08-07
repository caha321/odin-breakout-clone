package engine

import "core:math/linalg"
import rl "vendor:raylib"


ParticleDefinition :: struct {
	render_data: RenderData,
	position:    [2]f32, // center pos if circle
	velocity:    [2]f32,
	color_begin: rl.Color,
	color_end:   rl.Color,
	size_begin:  f32, // rectangle: width & height, circle: diameter (see RenderData shape)
	size_end:    f32,
	life_total:  f32, // in seconds
}

@(private = "file")
Particle :: struct {
	using defintion: ParticleDefinition,
	life_remaining:  f32, // in seconds
	active:          bool,
}

ParticleSystem :: struct {
	particles: #soa[dynamic]Particle,
}

ParticleSystem_Init :: proc(capacity: int) -> ParticleSystem {
	return ParticleSystem{particles = make(#soa[dynamic]Particle, capacity)}
}

ParticleSystem_Clear :: proc "contextless" (self: ^ParticleSystem) {
	for &p in self.particles do p.active = false
}

ParticleSystem_Update :: proc "contextless" (self: ^ParticleSystem, dt: f32) {
	for &p in self.particles {
		if !p.active do continue
		p.life_remaining -= dt
		if p.life_remaining <= 0 {
			p.active = false
			continue
		}

		p.position += p.velocity * dt
		p.velocity *= 0.98 // hard-coded drag
	}
}

ParticleSystem_Draw :: proc "contextless" (self: ^ParticleSystem) {
	for &p in self.particles {
		if !p.active do continue

		t := 1 - (p.life_remaining / p.life_total)
		size := linalg.lerp(p.size_begin, p.size_end, t)
		color := rl.ColorLerp(p.color_begin, p.color_end, t)
		color = rl.ColorAlpha(color, p.life_remaining / p.life_total)

		// update render data
		switch &v in p.render_data.shape {
		case RenderShape_Circle:
			v.diameter = size
		case RenderShape_Rectangle:
			v.height = size
			v.width = size
		}
		p.render_data.tint = color

		rt := get_render_transform(p.position, angle_deg = 0)
		render(p.render_data, rt)
	}
}

ParticleSystem_Emit :: proc "contextless" (
	self: ^ParticleSystem,
	defintion: ParticleDefinition,
) -> bool {
	for &p in self.particles {
		if !p.active {
			p.defintion = defintion
			// apply some defaults to at least show something
			if p.color_begin == rl.BLANK do p.color_begin = rl.WHITE
			if p.life_total == 0 do p.life_total = 1.0
			if p.size_begin == 0 do p.size_begin = 1.0

			p.life_remaining = defintion.life_total
			p.active = true
			return true
		}
	}
	return false
}

ParticleSystem_Destroy :: proc(self: ParticleSystem) {
	delete(self.particles)
}
