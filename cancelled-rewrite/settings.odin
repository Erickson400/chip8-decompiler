package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:mem"

/*
    Credits:
    https://github.com/chip-8/chip-8-database/blob/master/database/quirks.json
*/

Settings :: struct {
	max_label_jumps: int,
	quirks:          Quirks,
}

Quirks :: struct {
	shift:                    Quirk,
	memory_increment_by_x:    Quirk,
	memory_leave_i_unchanged: Quirk,
	jump:                     Quirk,
	logic:                    Quirk,
}

Quirk :: struct {
	name:        string,
	description: string,
	enabled:     bool,
	if_true:     string,
	if_false:    string,
}

@(private = "file", rodata)
DEFAULT_SETTINGS := Settings {
	max_label_jumps = 1000,
	quirks = {
        shift = {
            name = "Shift quirk",
            description = "On most systems the shift opcodes take `vY` as input and stores the shifted version of `vY` into `vX`. The interpreters for the HP48 took `vX` as both the input and the output, introducing the shift quirk.",
            enabled = false,
            if_true = "Opcodes `8XY6` and `8XYE` take `vX` as both input and output",
            if_false = "Opcodes `8XY6` and `8XYE` take `vY` as input and `vX` as output",
        },
        memory_increment_by_x = {
            name = "Load/Store quirk: increment index register by X",
            description = "On most systems storing and retrieving data between registers and memory increments the `i` register with `X + 1` (the number of registers read or written). So for each register read or writen, the index register would be incremented. The CHIP-48 interpreter for the HP48 would only increment the `i` register by `X`, introducing the first load/store quirk.",
            enabled = false,
            if_true = "`FX55` and `FX65` increment the `i` register with `X`",
            if_false = "`FX55` and `FX65` increment the `i` register with `X + 1`",
        },
        memory_leave_i_unchanged = {
            name = "Load/Store quirk: leave index register unchanged",
            description = "On most systems storing and retrieving data between registers and memory increments the `i` register relative to the number of registers read or written. The Superchip 1.1 interpreter for the HP48 however did not increment the `i` register at all, introducing the second load/store quirk.",
            enabled = false,
            if_true = "`FX55` and `FX65` leave the `i` register unchanged",
            if_false = "`FX55` and `FX65` increment the `i` register",
        },
        jump = {
            name = "Jump quirk",
            description = "The jump to `<address> + v0` opcode was wronly implemented on all the HP48 interpreters as jump to `<address> + vX`, introducing the jump quirk.",
            enabled = false,
            if_true = "Opcode `BXNN` jumps to address `XNN + vX`",
            if_false = "Opcode `BNNN` jumps to address `NNN + v0`",
        },
        logic = {
            name = "vF reset quirk",
            description = "On the original Cosmac VIP interpreter, `vF` would be reset after each opcode that would invoke the maths coprocessor. Later interpreters have not copied this behaviour.",
            enabled = true,
            if_true = "Opcodes `8XY1`, `8XY2` and `8XY3` (OR, AND and XOR) will set `vF` to zero after execution (even if `vF` is the parameter `X`)",
            if_false = "Opcodes `8XY1`, `8XY2` and `8XY3` (OR, AND and XOR) will leave `vF` unchanged (unless `vF` is the parameter `X`)",
        },
    },
}

@(private = "file", rodata)
MARSHAL_OPTIONS := json.Marshal_Options {
    pretty = true,
    mjson_keys_use_quotes = true,
}

@(private = "file")
MARSHAL_ERROR_NONE :: json.Marshal_Error{}
@(private = "file")
UNMARSHAL_ERROR_NONE :: json.Unmarshal_Error{}

@(private = "file")
settings_arena: mem.Arena
@(private = "file")
settings_arena_backing: []byte

settings: Settings

create_settings :: proc() {
	file, err := os.create("./settings.json")
	if err != os.ERROR_NONE {
		fmt.eprintfln("Could not create settings.json: %s", err)
		return
	}
	defer os.close(file)
    json_data, marsh_err := json.marshal(DEFAULT_SETTINGS, MARSHAL_OPTIONS)
    assert(marsh_err == MARSHAL_ERROR_NONE, "Can't marshal default settings struct")
    defer delete(json_data)
	_, err = os.write(file, json_data)
	if err != os.ERROR_NONE {
		fmt.eprintfln("Could not write to settings.json: %s", err)
		return
	}
	fmt.println("Created settings.json")
}

load_settings :: proc() {
    initialize_arena()
    if !os.exists("./settings.json") {
        settings = DEFAULT_SETTINGS
        return
    }
	file, file_err := os.open("./settings.json")
	if file_err != os.ERROR_NONE {
		fmt.eprintfln("Could not open settings.json: %s", file_err)
		fmt.eprintfln("Using default settings instead.")
        settings = DEFAULT_SETTINGS
		return
	}
	defer os.close(file)
    file_size, size_err := os.file_size(file)
    json_data := make([]u8, file_size)
    defer delete(json_data)
    _, read_err := os.read(file, json_data)
    if read_err != os.ERROR_NONE || size_err != os.ERROR_NONE {
		fmt.eprintfln("Could not read settings.json: %s, %s", read_err, size_err)
		fmt.eprintfln("Using default settings instead.")
        settings = DEFAULT_SETTINGS
		return
	}
    unmarsh_err := json.unmarshal(json_data, &settings, .JSON, allocator = mem.arena_allocator(&settings_arena))
    if unmarsh_err != UNMARSHAL_ERROR_NONE {
		fmt.eprintfln("Could not unmarshal settings.json: %s", unmarsh_err)
		fmt.eprintfln("Using default settings instead.")
        settings = DEFAULT_SETTINGS
		return
	}
}

@(private="file")
initialize_arena :: proc() {
    settings_arena_backing = make([]byte, mem.Kilobyte * 4)
    mem.arena_init(&settings_arena, settings_arena_backing)
}

unload_settings :: proc() {
    delete(settings_arena_backing)
}

