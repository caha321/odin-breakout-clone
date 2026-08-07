package engine

import "core:encoding/json"
import "core:log"
import "core:os"


// Load config from given `file_name`. On error fall back to given `default`.
Config_Init :: proc(file_name: string, default: $T) -> T {
	data, read_err := os.read_entire_file(file_name, context.allocator)
	if read_err != nil {
		log.warnf(
			"Could not load config file '%s', using defaults. Error = %v",
			file_name,
			read_err,
		)
		return default
	}
	defer delete(data)

	config: T
	unmarshal_err := json.unmarshal(data, &config)
	if unmarshal_err != nil {
		log.warnf(
			"Could not unmarshal config file '%s', using defaults. Error = %v",
			file_name,
			unmarshal_err,
		)
		return default
	}

	log.infof("Loaded game config file '%s' successfully.", file_name)
	return config
}

// Write given `config` to given `file_name`.
Config_Write :: proc(config: $T, file_name: string) -> bool {
	json_data, err := json.marshal(config, {pretty = true})
	if err != nil {
		log.errorf("Unable to marshal config! Error = %v", err)
		return false
	}
	defer delete(json_data)

	write_err := os.write_entire_file(file_name, json_data)
	if write_err != nil {
		log.errorf("Unable to write config file '%s'! Error = %v", file_name, write_err)
		return false
	}

	log.infof("Saved game config file '%s' successfully.", file_name)
	return true
}
