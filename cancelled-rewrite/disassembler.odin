package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:log"

Instruction :: struct {
    address: ChipAddress,
    opcode_bytes: [2]ChipByte,
    opcode: Opcode,
}

disassemble :: proc(input_path, output_path: string) {
    // Pass #1. Looks for reachable Labels and Functions.
    log.info("Starting Pass #1")
    rom_file, rom_err := os.open(input_path)
    if rom_err != os.ERROR_NONE {
        fmt.eprintfln("Failed to read Rom. {:v}", rom_err)
        return
    }
    defer os.close(rom_file)
    file_size, _:= os.file_size(rom_file)
    rom := make([]byte, file_size)
    os.read(rom_file, rom)
    defer delete(rom)
    instructions := create_instructions(rom)
    defer delete(instructions)
    // for i in instructions {
    //     stringed := opcode_to_string(i.opcode)
    //     fmt.println(stringed)
    //     delete(stringed)
    // }
    reachable, ok := get_reachable_addresses(instructions[:])
    if ok {
        fmt.println(len(reachable))

        // for i in reachable {
        //     fmt.printfln("Reachable Addresses: {:X}", i)
        // }
        delete(reachable)
    }
    log.info("Finished Pass #1")

    
}

create_instructions :: proc(rom: []byte) -> [dynamic]Instruction {
    instructions := make([dynamic]Instruction, 0, len(rom) / 2)
    for i := 0; i + 1 < len(rom); {
        instruction := Instruction{
            address = ChipAddress(0x200 + i),
            opcode_bytes = {rom[i], rom[i + 1]},
            opcode = bytes_to_opcode(rom[i], rom[i + 1]),
        }
        append(&instructions, instruction)
        i += 2
    }
    return instructions
}

get_reachable_addresses :: proc(instructions: []Instruction) -> (reached_addresses: [dynamic]ChipAddress, ok: bool){
    // context.logger.lowest_level = .Info
    branches: [dynamic]int
    defer delete(branches)
    append(&branches, 0)

    for len(branches) > 0 {
        log.debugf("Branch stack: {:v}", branches)
        branch_index := pop(&branches)
        log.debugf("Processing branch {:v}", branch_index)
        branch_loop: for i in branch_index..<len(instructions) {
            instruction := instructions[i]
            // Terminate branch if the isntruction address is already reached
            if slice.contains(reached_addresses[:], instruction.address) {
                log.debugf("Terminated branch {:v} because it's instruction is already marked as reachable", branch_index)
                break
            }
            append(&reached_addresses, instruction.address)
            #partial switch op in instruction.opcode {
            case Unknown:
                // A reachable Unknown opcode means the rom is invalid.
                delete(reached_addresses)
                log.errorf("{:v}", instructions[i - 1])
                log.errorf("A reachable Unknown opcode has been hit.")
                return nil, false
            case Ret:
                // Terminate branch if there is a Ret opcode
                log.debugf("Terminated branch {:v} with Ret opcode", branch_index)
                break branch_loop
            case Call:
                // Create branchs on the target address and on the instruction after the call.
                // Then terminate this branch.
                instruction_index_at_call, found := get_instruction_index_by_address(instructions, op.address)
                // fmt.println(op.address)
                if !found {
                    log.errorf("Call target {:v} is invalid", instructions[instruction_index_at_call])
                }
                assert(found, "Marked an unreachable call as reachable.")
                append(&branches, instruction_index_at_call, branch_index + i + 1)
                log.debugf("Found branch at index {:v}", instruction_index_at_call)
                log.debugf("Found branch at index {:v}", branch_index + i + 1)
                log.debugf("Terminated branch {:v} with Call opcode", branch_index)
                break branch_loop
            case Jump:
                // Create branch on the target address then terminate this branch.
                instruction_index_at_jump, found := get_instruction_index_by_address(instructions, op.address)
                if !found {
                    log.errorf("Jump target {:v} is invalid", instructions[instruction_index_at_jump])
                }
                assert(found, "Marked an unreachable jump as reachable.")
                append(&branches, instruction_index_at_jump)
                log.debugf("Found branch at index {:v}", instruction_index_at_jump)
                log.debugf("Terminated branch {:v} with Jump opcode", branch_index)
                break branch_loop
            case SeRB, SneRB, SeRR, SneRR, SkKey, SknKey:
                // Create branchs on the next instruction, and on the instruction after that one.
                // Then terminate this branch.
                append(&branches, i + 1, i + 2)
                log.debugf("Found branch at index {:v}", i + 1)
                log.debugf("Found branch at index {:v}", i + 2)
                log.debugf("Terminated branch {:v} with a Skip opcode", branch_index)
                break branch_loop
            case:
                // All other instructions can keep being ignored till a termination case appears.
                log.debugf("Branch {:v} read opcode {:v} at 0x{:3X}", branch_index, instruction.opcode, instruction.address)
            }
        }
    }
    slice.sort(reached_addresses[:])
    return reached_addresses, true
}

get_instruction_index_by_address :: proc(instructions: []Instruction, address: ChipAddress) -> (instruction_index: int, found: bool) {
    for inst, index in instructions {
        if inst.address == address {
            return index, true
        }
    }
    return 0, false
} 