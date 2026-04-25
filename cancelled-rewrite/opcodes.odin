package main

import "core:fmt"
import "core:mem"

/*
    Credits:
    https://github.com/mattmikolay/chip-8/wiki/CHIP%E2%80%908-Instruction-Set
    https://github.com/j-schwar/chip8/blob/main/src%2Fopcode.rs
    http://devernay.free.fr/hacks/chip8/C8TECH10.HTM#3.1
*/

ChipAddress  :: u16
ChipRegister :: u8
ChipByte     :: u8
ChipNibble   :: u8

/*
    nnn or addr - A 12-bit value, the lowest 12 bits of the instruction
    n or nibble - A 4-bit value, the lowest 4 bits of the instruction
    x - A 4-bit value, the lower 4 bits of the high byte of the instruction
    y - A 4-bit value, the upper 4 bits of the low byte of the instruction
    kk or byte - An 8-bit value, the lowest 8 bits of the instruction
*/
Opcode :: union #no_nil {
    Unknown, Sys, Cls, Ret, Jump, Call, SeRB, SneRB, SeRR,
    LdRB, AddRB, LdRR, Or, And, Xor, AddRR, SubRR,
    Shr, SubnRR, Shl, SneRR, LdI, JumpV0, JumpVX, Rnd, Draw,
    SkKey, SknKey, LdVDt, KeyHalt, LdDtV, LdStV, AddI,
    LdHex, LdBCD, Dump, Restore
}

Unknown :: struct {}
Sys :: struct { address: ChipAddress }                                      // 0nnn - Jump to machine code routine at nnn (unused)
Cls :: struct {}                                                            // 00E0 - Clear the display
Ret :: struct {}                                                            // 00EE - Return from subroutine
Jump :: struct { address: ChipAddress }                                     // 1nnn - Jump to address
Call :: struct { address: ChipAddress }                                     // 2nnn - Call subroutine
SeRB :: struct { register: ChipRegister, b: ChipByte }                      // 3xkk - Skip next instruction if Vx == kk
SneRB :: struct { register: ChipRegister, b: ChipByte }                     // 4xkk - Skip next instruction if Vx != kk
SeRR :: struct { register_x, register_y: ChipRegister }                     // 5xy0 - Skip next instruction if Vx == Vy
LdRB :: struct { register: ChipRegister, b: ChipByte }                      // 6xkk - Set Vx to kk
AddRB :: struct { register: ChipRegister, b: ChipByte }                     // 7xkk - Set Vx to Vx + kk
LdRR :: struct { register_x, register_y: ChipRegister }                     // 8xy0 - Set Vx to Vy
Or :: struct { register_x, register_y: ChipRegister }                       // 8xy1 - Set Vx to Vx | Vy
And :: struct { register_x, register_y: ChipRegister }                      // 8xy2 - Set Vx to Vx & Vy
Xor :: struct { register_x, register_y: ChipRegister }                      // 8xy3 - Set Vx to Vx ^ Vy
AddRR :: struct { register_x, register_y: ChipRegister }                    // 8xy4 - Set Vx to Vx + Vy and set VF = carry
SubRR :: struct { register_x, register_y: ChipRegister }                    // 8xy5 - Set Vx to Vx - Vy and set VF = NOT borrow
Shr :: struct { register_x, register_y: ChipRegister }                      // 8xy6 - Set Vy to Vx >> 1 and set VF = Vx & 0x01
SubnRR :: struct { register_x, register_y: ChipRegister }                   // 8xy7 - Set Vx to Vy - Vx and set VF = NOT borrow
Shl :: struct { register_x, register_y: ChipRegister }                      // 8xyE - Set Vy to Vx << 1 and set VF = Vx & 0x80
SneRR :: struct { register_x, register_y: ChipRegister }                    // 9xy0 - Skip next instruction if Vx != Vy
LdI :: struct { address: ChipAddress }                                      // Annn - Set I to nnn
JumpV0 :: struct { address: ChipAddress }                                   // Bnnn - Jump to address + V0
JumpVX :: struct { register: ChipRegister, address: ChipByte }              // Bxkk - Quirk from Bnnn, Jump to kk + Vx
Rnd :: struct { register: ChipRegister, b: ChipByte }                       // Cxkk - Set Vx to random number AND kk
Draw :: struct { register_x, register_y: ChipRegister, nibble: ChipNibble } // DxyN - Draw sprite at position (Vx, Vy) with width 8 pixels and height N pixels
SkKey :: struct { register: ChipRegister }                                  // Ex9E - Skip next instruction if key corresponding to Vx is pressed
SknKey :: struct { register: ChipRegister }                                 // ExA1 - Skip next instruction if key corresponding to Vx is not pressed
LdVDt :: struct { register: ChipRegister }                                  // Fx07 - Set Vx to delay timer value
KeyHalt :: struct { register: ChipRegister }                                // Fx0A - Wait for key press and store in Vx
LdDtV :: struct { register: ChipRegister }                                  // Fx15 - Set delay timer to Vx
LdStV :: struct { register: ChipRegister }                                  // Fx18 - Set sound timer to Vx
AddI :: struct { register: ChipRegister }                                   // Fx1E - Add Vx to I
LdHex :: struct { register: ChipRegister }                                  // Fx29 - Load font character at address I
LdBCD :: struct { register: ChipRegister }                                  // Fx33 - Store BCD representation of Vx at address I
Dump :: struct { register: ChipRegister }                                   // Fx55 - Dump registers V0 to Vx to memory starting at address I
Restore :: struct { register: ChipRegister }                                // Fx65 - Load registers V0 to Vx from memory starting at address I

bytes_to_opcode :: proc(high_byte, low_byte: u8) -> Opcode {
    group := (high_byte & 0xF0) >> 4
    kk := low_byte
    x := high_byte & 0xF
    y := (low_byte & 0xF0) >> 4
    n := low_byte & 0xF
    nnn := ((u16(high_byte) & 0xF) << 8) | u16(low_byte)

    switch group {
        case 0x0:
            switch nnn {
                case 0x0E0: return Cls{}
                case 0x0EE: return Ret{}
                case: return Sys{nnn}
            }
        case 0x1: return Jump{nnn}
        case 0x2: return Call{nnn}
        case 0x3: return SeRB{x, kk}
        case 0x4: return SneRB{x, kk}
        case 0x5: return SeRR{x, y}
        case 0x6: return LdRB{x, kk}
        case 0x7: return AddRB{x, kk}
        case 0x8:
            switch n {
                case 0x0: return LdRR{x, y}
                case 0x1: return Or{x, y}
                case 0x2: return And{x, y}
                case 0x3: return Xor{x, y}
                case 0x4: return AddRR{x, y}
                case 0x5: return SubRR{x, y}
                case 0x6: return Shr{x, y}
                case 0x7: return SubnRR{x, y}
                case 0xE: return Shl{x, y}
                case: return Unknown{}
            }
        case 0x9: return SneRR{x, y} if n == 0 else Unknown{}
        case 0xA: return LdI{nnn}
        case 0xB: return JumpVX{x, kk} if settings.quirks.jump.enabled else JumpV0{nnn}
        case 0xC: return Rnd{x, kk}
        case 0xD: return Draw{x, y, n}
        case 0xE:
            switch kk {
                case 0x9E: return SkKey{x}
                case 0xA1: return SknKey{x}
                case: return Unknown{}
            }
        case 0xF:
            switch kk {
                case 0x07: return LdVDt{x}
                case 0x0A: return KeyHalt{x}
                case 0x15: return LdDtV{x}
                case 0x18: return LdStV{x}
                case 0x1E: return AddI{x}
                case 0x29: return LdHex{x}
                case 0x33: return LdBCD{x}
                case 0x55: return Dump{x}
                case 0x65: return Restore{x}
                case: return Unknown{}
            }
        case: return Unknown{}
    }
}

opcode_to_string :: proc(opcode: Opcode, allocator := context.allocator) -> string {
    checkpoint := mem.begin_arena_temp_memory(cast(^mem.Arena)context.temp_allocator.data)
    defer mem.end_arena_temp_memory(checkpoint)
    address :: proc(addr: ChipAddress) -> string {
        return fmt.tprintf("0x{:3X}", addr)
    }
    register :: proc(reg: ChipRegister) -> string {
        return fmt.tprintf("v{:X}", reg)
    }
    byte_imm :: proc(b: ChipByte) -> string {
        return fmt.tprintf("0x{:2X}", b)
    }
    nibble_imm :: byte_imm

    stringed: string
    switch op in opcode {
        case Unknown: stringed =             "Unknown"
        case Sys: stringed =     fmt.aprintf("Sys     {:v}", address(op.address), allocator = allocator)
        case Cls: stringed =                 "Cls"
        case Ret: stringed =                 "Ret"
        case Jump: stringed =    fmt.aprintf("Jump    {:v}", address(op.address), allocator = allocator)
        case Call: stringed =    fmt.aprintf("Call    {:v}", address(op.address), allocator = allocator)
        case SeRB: stringed =    fmt.aprintf("Se      {:v}, {:v}", register(op.register), byte_imm(op.b), allocator = allocator)
        case SneRB: stringed =   fmt.aprintf("Sne     {:v}, {:v}", register(op.register), byte_imm(op.b), allocator = allocator)
        case SeRR: stringed =    fmt.aprintf("Se      {:v}, {:v}", register(op.register_x), register(op.register_y), allocator = allocator)
        case LdRB: stringed =    fmt.aprintf("Ld      {:v}, {:v}", register(op.register), byte_imm(op.b), allocator = allocator)
        case AddRB: stringed =   fmt.aprintf("Add     {:v}, {:v}", register(op.register), byte_imm(op.b), allocator = allocator)
        case LdRR: stringed =    fmt.aprintf("Ld      {:v}, {:v}", register(op.register_x), register(op.register_y), allocator = allocator)
        case Or: stringed =      fmt.aprintf("Or      {:v}, {:v}", register(op.register_x), register(op.register_y), allocator = allocator)
        case And: stringed =     fmt.aprintf("And     {:v}, {:v}", register(op.register_x), register(op.register_y), allocator = allocator)
        case Xor: stringed =     fmt.aprintf("Xor     {:v}, {:v}", register(op.register_x), register(op.register_y), allocator = allocator)
        case AddRR: stringed =   fmt.aprintf("Add     {:v}, {:v}", register(op.register_x), register(op.register_y), allocator = allocator)
        case SubRR: stringed =   fmt.aprintf("Sub     {:v}, {:v}", register(op.register_x), register(op.register_y), allocator = allocator)
        case Shr: stringed =     fmt.aprintf("Shr     {:v}, {:v}", register(op.register_x), register(op.register_y), allocator = allocator)
        case SubnRR: stringed =  fmt.aprintf("Subn    {:v}, {:v}", register(op.register_x), register(op.register_y), allocator = allocator)
        case Shl: stringed =     fmt.aprintf("Shl     {:v}, {:v}", register(op.register_x), register(op.register_y), allocator = allocator)
        case SneRR: stringed =   fmt.aprintf("Sne     {:v}, {:v}", register(op.register_x), register(op.register_y), allocator = allocator)
        case LdI: stringed =     fmt.aprintf("Ld      I, {:v}", address(op.address), allocator = allocator)
        case JumpV0: stringed =  fmt.aprintf("Jump    V0, {:v}", address(op.address), allocator = allocator)
        case JumpVX: stringed =  fmt.aprintf("Jump    V{:v}, {:v}", register(op.register), byte_imm(op.address), allocator = allocator)
        case Rnd: stringed =     fmt.aprintf("Rnd     {:v}, {:v}", register(op.register), byte_imm(op.b), allocator = allocator)
        case Draw: stringed =    fmt.aprintf("Draw    {:v}, {:v}, {:v}", register(op.register_x), register(op.register_y), nibble_imm(op.nibble), allocator = allocator)
        case SkKey: stringed =   fmt.aprintf("SkKey   {:v}", register(op.register), allocator = allocator)
        case SknKey: stringed =  fmt.aprintf("SknKey  {:v}", register(op.register), allocator = allocator)
        case LdVDt: stringed =   fmt.aprintf("Ld      {:v}, DT", register(op.register), allocator = allocator)
        case KeyHalt: stringed = fmt.aprintf("KeyHalt {:v}", register(op.register), allocator = allocator)
        case LdDtV: stringed =   fmt.aprintf("Ld DT,  {:v}", register(op.register), allocator = allocator)
        case LdStV: stringed =   fmt.aprintf("Ld ST,  {:v}", register(op.register), allocator = allocator)
        case AddI: stringed =    fmt.aprintf("Add I,  {:v}", register(op.register), allocator = allocator)
        case LdHex: stringed =   fmt.aprintf("LdHex   {:v}", register(op.register), allocator = allocator)
        case LdBCD: stringed =   fmt.aprintf("LdBCD   {:v}", register(op.register), allocator = allocator)
        case Dump: stringed =    fmt.aprintf("Dump    {:v}", register(op.register), allocator = allocator)
        case Restore: stringed = fmt.aprintf("Restore {:v}", register(op.register), allocator = allocator)
    }
    return stringed
}
