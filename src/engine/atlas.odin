package engine

import "core:fmt"
import "core:log"
import rl "vendor:raylib"

AtlasRegion :: distinct rl.Rectangle
AtlasUV :: distinct rl.Rectangle

atlas_region_to_uv :: proc "contextless" (region: AtlasRegion) -> AtlasUV {
	return AtlasUV {
		x = region.x / f32(g_atlas_texture.width),
		y = region.y / f32(g_atlas_texture.height),
		width = region.width / f32(g_atlas_texture.width),
		height = region.height / f32(g_atlas_texture.height),
	}
}

// simple shelf packed atlas
@(private = "file")
Atlas :: struct {
	// internal
	canvas:     rl.Image, // in RAM
	cursor_x:   i32,
	cursor_y:   i32,
	row_height: i32,
}

@(private = "file")
g_atlas := Atlas{}

g_atlas_texture: rl.Texture2D

init_atlas :: proc(size: i32 = 2048) {
	g_atlas.canvas = rl.GenImageColor(size, size, rl.BLANK)
}

destory_atlas :: proc() {
	if rl.IsImageValid(g_atlas.canvas) do rl.UnloadImage(g_atlas.canvas)
	g_atlas.canvas = {}
	if rl.IsTextureValid(g_atlas_texture) do rl.UnloadTexture(g_atlas_texture)
	g_atlas_texture = {}
}

load_texture_from_file :: proc(file_name: cstring) -> (region: AtlasRegion, ok: bool) {
	path := fmt.ctprintf("assets/textures/%s", file_name)
	img := rl.LoadImage(path)
	if img.width <= 0 {
		log.error("Could not load image", path)
		return {}, false
	}
	defer rl.UnloadImage(img)
	region, ok = load_texture_from_image(img)
	if ok do log.info("Successfully loaded texture", path, "into atlas!")
	return region, true
}

load_texture_from_image :: proc(img: rl.Image) -> (region: AtlasRegion, ok: bool) {
	if !rl.IsImageValid(g_atlas.canvas) {
		log.error("Loading textures only possible after init_atlas() but before build_atlas()!")
		return {}, false
	}

	// wrap to next row if this sprite doesn't fit
	if g_atlas.cursor_x + img.width > g_atlas.canvas.width {
		g_atlas.cursor_x = 0
		g_atlas.cursor_y += g_atlas.row_height
		g_atlas.row_height = 0
	}

	src := rl.Rectangle{0, 0, f32(img.width), f32(img.height)}
	dest := rl.Rectangle {
		f32(g_atlas.cursor_x),
		f32(g_atlas.cursor_y),
		f32(img.width),
		f32(img.height),
	}
	rl.ImageDraw(&g_atlas.canvas, img, src, dest, rl.WHITE)

	g_atlas.cursor_x += img.width
	g_atlas.row_height = max(g_atlas.row_height, img.height)

	return cast(AtlasRegion)dest, true
}

load_texture :: proc {
	load_texture_from_file,
	load_texture_from_image,
}

build_atlas :: proc() -> bool {
	g_atlas_texture = rl.LoadTextureFromImage(g_atlas.canvas)
	if !rl.IsTextureValid(g_atlas_texture) {
		log.error("Could not build atlas texture!")
		return false
	}
	log.info("Successfully build atlas texture.")

	if rl.IsImageValid(g_atlas.canvas) do rl.UnloadImage(g_atlas.canvas)
	g_atlas.canvas = {}

	return true
}

uv_from_atlas_source :: proc(
	source: rl.Rectangle,
	atlas: rl.Texture2D,
) -> (
	uv_min, uv_max: rl.Vector2,
) {
	uv_min = {source.x / f32(atlas.width), source.y / f32(atlas.height)}
	uv_max = {
		(source.x + source.width) / f32(atlas.width),
		(source.y + source.height) / f32(atlas.height),
	}
	return
}
