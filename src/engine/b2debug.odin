package engine

import "base:runtime"
import b2 "vendor:box2d"
import rl "vendor:raylib"


init_debug_draw :: proc "contextless" () -> b2.DebugDraw {
	// ---- Assemble the DebugDraw struct ----
	debug_draw := b2.DefaultDebugDraw()
	debug_draw.DrawPolygonFcn = draw_polygon
	debug_draw.DrawSolidPolygonFcn = draw_solid_polygon
	debug_draw.DrawCircleFcn = draw_circle
	debug_draw.DrawSolidCircleFcn = draw_solid_circle
	debug_draw.DrawSolidCapsuleFcn = draw_solid_capsule
	debug_draw.DrawSegmentFcn = draw_segment
	debug_draw.DrawTransformFcn = draw_transform
	debug_draw.DrawPointFcn = draw_point
	debug_draw.DrawStringFcn = draw_string

	debug_draw.drawShapes = true
	debug_draw.drawJoints = true
	debug_draw.drawBounds = false // AABBs — noisy, enable if you need it
	debug_draw.drawMass = true

	return debug_draw
}

@(private = "file")
hex_to_rl_color :: proc "c" (c: b2.HexColor, alpha: u8 = 255) -> rl.Color {
	v := u32(c)
	return rl.Color{u8(v >> 16), u8(v >> 8), u8(v), alpha}
}

// ---- Debug draw callbacks ----

draw_polygon :: proc "c" (vertices: [^][2]f32, vertexCount: i32, color: b2.HexColor, ctx: rawptr) {
	col := hex_to_rl_color(color)
	for i in 0 ..< vertexCount {
		p1 := world_to_screen(vertices[i])
		p2 := world_to_screen(vertices[(i + 1) % vertexCount])
		rl.DrawLineV(p1, p2, col)
	}
}

draw_solid_polygon :: proc "c" (
	transform: b2.Transform,
	vertices: [^][2]f32,
	vertexCount: i32,
	radius: f32,
	color: b2.HexColor,
	ctx: rawptr,
) {
	context = runtime.default_context()

	col := hex_to_rl_color(color, 150)
	// Transform each local vertex into world space, then to screen space
	points := make([dynamic]rl.Vector2, vertexCount, context.temp_allocator)

	for i in 0 ..< vertexCount {
		world_pt := b2.TransformPoint(transform, vertices[i])
		points[i] = world_to_screen(world_pt)
	}
	// Fan-triangulate for a simple convex polygon fill
	for i in 1 ..< vertexCount - 1 {
		rl.DrawTriangle(points[0], points[i], points[i + 1], col)
	}
	// If radius > 0, draw rounded corners as small circles at each vertex —
	// a cheap approximation, not a true rounded-rect outline
	/*
	if radius > 0 {
		for i in 0 ..< vertexCount {
			rl.DrawCircleV(points[i], radius * PPM, col)
		}
	}
    */
	// Outline
	for i in 0 ..< vertexCount {
		rl.DrawLineV(points[i], points[(i + 1) % vertexCount], hex_to_rl_color(color))
	}
}

draw_circle :: proc "c" (center: [2]f32, radius: f32, color: b2.HexColor, ctx: rawptr) {
	p := world_to_screen(center)
	rl.DrawCircleLinesV(p, radius, hex_to_rl_color(color))
}

draw_solid_circle :: proc "c" (
	transform: b2.Transform,
	radius: f32,
	color: b2.HexColor,
	ctx: rawptr,
) {
	p := world_to_screen(transform.p)
	rl.DrawCircleV(p, radius, hex_to_rl_color(color, 150))
	// Draw a radius line so rotation is visible on circles too
	axis := b2.RotateVector(transform.q, {radius, 0})
	edge := world_to_screen(transform.p + axis)
	rl.DrawLineV(p, edge, rl.BLACK)
}

draw_solid_capsule :: proc "c" (p1, p2: [2]f32, radius: f32, color: b2.HexColor, ctx: rawptr) {
	a := world_to_screen(p1)
	b := world_to_screen(p2)
	rl.DrawCircleV(a, radius, hex_to_rl_color(color, 150))
	rl.DrawCircleV(b, radius, hex_to_rl_color(color, 150))
	rl.DrawLineEx(a, b, radius * 2, hex_to_rl_color(color, 150))
}

draw_segment :: proc "c" (p1, p2: [2]f32, color: b2.HexColor, ctx: rawptr) {
	rl.DrawLineV(world_to_screen(p1), world_to_screen(p2), hex_to_rl_color(color))
}

draw_transform :: proc "c" (transform: b2.Transform, ctx: rawptr) {
	origin := world_to_screen(transform.p)
	x_axis := world_to_screen(transform.p + b2.RotateVector(transform.q, {0.5, 0}))
	y_axis := world_to_screen(transform.p + b2.RotateVector(transform.q, {0, 0.5}))
	rl.DrawLineV(origin, x_axis, rl.RED)
	rl.DrawLineV(origin, y_axis, rl.GREEN)
}

draw_point :: proc "c" (p: [2]f32, size: f32, color: b2.HexColor, ctx: rawptr) {
	rl.DrawCircleV(world_to_screen(p), size / 2, hex_to_rl_color(color))
}

draw_string :: proc "c" (p: [2]f32, s: cstring, color: b2.HexColor, ctx: rawptr) {
	font := rl.GetFontDefault()
	font_size := 14 / camera.zoom
	font_spacing := 1 / camera.zoom
	rl.DrawTextEx(font, s, world_to_screen(p), font_size, font_spacing, hex_to_rl_color(color))
}
