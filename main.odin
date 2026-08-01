package breakout

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import b2 "vendor:box2d"
import rl "vendor:raylib"

DT :: 1.0 / 60.0
SUB_STEP_COUNT :: 4 // Box2D

run :: proc() -> bool {
	rl.SetTraceLogLevel(.WARNING)
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Breakout!")
	defer rl.CloseWindow()

	rl.SetTargetFPS(75)

	return Game_Run()
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

		print_struct_field_sizes(Entity)
		print_union_variant_sizes(Entity_Variant)
		print_struct_field_sizes(Entity_Slot)
		print_struct_field_sizes(Entity_Handle)
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
