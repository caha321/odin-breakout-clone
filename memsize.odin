package breakout

import "base:runtime"
import "core:fmt"

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
