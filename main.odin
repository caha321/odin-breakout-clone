package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import b2 "vendor:box2d"
import rl "vendor:raylib"

import "src/engine"
import "src/game"

run :: proc() -> bool {
	rl.SetTraceLogLevel(.WARNING)
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(engine.screen.width, engine.screen.height, "Breakout!")
	defer rl.CloseWindow()

	rl.SetTargetFPS(75)

	return game.Game_Run()
}


main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			} else {
				fmt.eprintln("No memory leaks detected.")
			}
			mem.tracking_allocator_destroy(&track)
		}
		log_level :: log.Level.Debug

		print_struct_field_sizes(game.Entity)
		print_union_variant_sizes(game.Entity_Variant)
		print_struct_field_sizes(engine.Slot(game.Entity))
		print_struct_field_sizes(engine.Handle)
	} else {
		log_level :: log.Level.Info
	}

	context.logger = log.create_console_logger(lowest = log_level)
	defer log.destroy_console_logger(context.logger)

	if !run() {
		os.exit(1)
	}

	log.debug("Box2D ByteCount:", b2.GetByteCount())
}


//////////////////////////

import "base:runtime"

print_union_variant_sizes :: proc($T: typeid) {
	info := type_info_of(T)
	// strip named wrapper if present, to get to the actual union info
	ti := runtime.type_info_base(info)

	u, ok := ti.variant.(runtime.Type_Info_Union)
	if !ok {
		fmt.println(type_info_of(T), "is not a union")
		return
	}

	fmt.printfln("%v total size: %d, align: %d", type_info_of(T), info.size, info.align)
	for variant in u.variants {
		fmt.printfln("  %v: size = %d, align = %d", variant, variant.size, variant.align)
	}
}

print_struct_field_sizes :: proc($T: typeid) {
	info := runtime.type_info_base(type_info_of(T))
	s, ok := info.variant.(runtime.Type_Info_Struct)
	if !ok do return

	fmt.printfln("%v total size: %d, align: %d", type_info_of(T), info.size, info.align)
	for i in 0 ..< int(s.field_count) {
		fmt.printfln("  %v: offset = %d, size = %d", s.names[i], s.offsets[i], s.types[i].size)
	}
}
