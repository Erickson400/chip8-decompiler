package main

import "core:fmt"
import "core:os"
import "core:mem"
import "core:log"

HELP ::
    "Usage:\n\n" +
    "chip8-disasm [input file] [output file]\n" +
    "        Dissasembles the rom to assembly.\n\n" +
    "chip8-disasm create-settings\n" +
    "        Create a settings.json file next to the executable for advanced tweaks.\n\n" +
    "chip8-disasm help         \n" +
    "        Shows this message.\n"

main :: proc() {
    // Setup tracking allocator
    tracker: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracker, context.allocator)
    context.allocator = mem.tracking_allocator(&tracker)
    defer {
        if len(tracker.allocation_map) > 0 {
            total_size := 0
            for _, leak in tracker.allocation_map {
                fmt.printf("%v leaked %m\n", leak.location, leak.size)
                total_size += leak.size
            }
            fmt.printf("Total leaks: %v\nTotal leak Size: %m\n", len(tracker.allocation_map), total_size)
        }
        mem.tracking_allocator_destroy(&tracker)
    }

    // Setup logger
    file_logger, logger_err := os.create("./logs.txt")
    assert(logger_err == os.ERROR_NONE)
    defer os.close(file_logger)
    context.logger = log.create_file_logger(file_logger, opt = {.Level, .Time})
    defer log.destroy_file_logger(context.logger)

    if len(os.args) == 1 {
        fmt.println(HELP)
    } else if len(os.args) == 2{
        switch os.args[1] {
        case "help":
            fmt.println(HELP)
        case "create-settings":
            create_settings()
        case:
            fmt.println(HELP)
        }
    } else if len(os.args) == 3 {
        load_settings()
        disassemble(os.args[1], os.args[2])
        unload_settings()
    } else {
        fmt.println(HELP)
    }
}



