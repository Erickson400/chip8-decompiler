module Opcodes
(*
    Credits:
    https://github.com/mattmikolay/chip-8/wiki/CHIP%E2%80%908-Instruction-Set
    https://github.com/j-schwar/chip8/blob/main/src%2Fopcode.rs
    http://devernay.free.fr/hacks/chip8/C8TECH10.HTM#3.1
*)

type ChipAddress  = uint16
type ChipRegister = byte
type ChipByte     = byte
type ChipNibble   = byte

(*
    nnn or addr - A 12-bit value, the lowest 12 bits of the instruction
    n or nibble - A 4-bit value, the lowest 4 bits of the instruction
    x - A 4-bit value, the lower 4 bits of the high byte of the instruction
    y - A 4-bit value, the upper 4 bits of the low byte of the instruction
    kk or byte - An 8-bit value, the lowest 8 bits of the instruction
*)
type Opcode =
    | Sys of ChipAddress                                  // 0nnn - Jump to machine code routine at nnn (unused)
    | Cls                                                 // 00E0 - Clear the display
    | Ret                                                 // 00EE - Return from subroutine
    | Jump of ChipAddress                                 // 1nnn - Jump to address
    | Call of ChipAddress                                 // 2nnn - Call subroutine
    | SeRB of ChipRegister * ChipByte                     // 3xkk - Skip next instr. if Vx == kk
    | SneRB of ChipRegister * ChipByte                    // 4xkk - Skip next instr. if Vx != kk
    | SeRR of ChipRegister * ChipRegister                 // 5xy0 - Skip next instr. if Vx == Vy
    | LdRB of ChipRegister * ChipByte                     // 6xkk - Set Vx to kk
    | AddRB of ChipRegister * ChipByte                    // 7xkk - Set Vx to Vx + kk
    | LdRR of ChipRegister * ChipRegister                 // 8xy0 - Set Vx to Vy
    | Or of ChipRegister * ChipRegister                   // 8xy1 - Set Vx to Vx | Vy
    | And of ChipRegister * ChipRegister                  // 8xy2 - Set Vx to Vx & Vy
    | Xor of ChipRegister * ChipRegister                  // 8xy3 - Set Vx to Vx ^ Vy
    | AddRR of ChipRegister * ChipRegister                // 8xy4 - Set Vx to Vx + Vy and set VF = carry
    | SubRR of ChipRegister * ChipRegister                // 8xy5 - Set Vx to Vx - Vy and set VF = NOT borrow
    | Shr of ChipRegister * ChipRegister                  // 8xy6 - Set Vx to Vx >> 1 and set VF = Vx & 0x01
    | SubnRR of ChipRegister * ChipRegister               // 8xy7 - Set Vx to Vy - Vx and set FV = NOT borrow
    | Shl of ChipRegister * ChipRegister                  // 8xyE - Set Vx to Vx << 1 and set VF = (Vx & 0x80) >> 8
    | SneRR of ChipRegister * ChipRegister                // 9xy0 - Skip next instr. if Vx !=Vy                
    | LdI of ChipAddress                                  // Annn - Set I to nnn
    | JumpV0 of ChipAddress                               // Bnnn - The program counter is set to nnn plus the value of V0.
    | Rnd of ChipRegister * ChipByte                      // Cxkk - Set Vx to RANDOM BYTE & kk               
    | Draw of ChipRegister * ChipRegister * ChipNibble    // Dxyn - Display n-byte sprite at address I at position (Vx, Vy) set VF = collision                                 
    | SkKey of ChipRegister                               // Ex9E - Skip next instr. if key with value Vx is pressed      
    | SknKey of ChipRegister                              // ExA1 - Skip next instr. if key with value Vx is not pressed           
    | LdVDt of ChipRegister                               // Fx07 - Load the delay timer value into Vx      
    | KeyHalt of ChipRegister                             // Fx0A - Halt and wait for a key press, store the value in Vx       
    | LdDtV of ChipRegister                               // Fx15 - Set the delay timer to Vx           
    | LdStV of ChipRegister                               // Fx18 - Set the sound timer to Vx
    | AddI of ChipRegister                                // Fx1E - Set I to I + Vx  
    | LdHex of ChipRegister                               // Fx29 - Set I to the location of the sprite for digit Vx        
    | LdBCD of ChipRegister                               // Fx33 - Store the BCD rep. of Vx in locations I, I+1, and I+2        
    | Dump of ChipRegister                                // Fx55 - Store V0 to Vx in memory starting at loc. I          
    | Restore of ChipRegister                             // Fx65 - Read V0 to Vx from memory starting at loc. I             
    | Unknown                                             // Unknown opcode or just data

let bytesToOpcode (highByte, lowByte) =
    let group = highByte &&& 0xF0uy >>> 4
    let kk = lowByte
    let x = highByte &&& 0xFuy
    let y = lowByte &&& 0xF0uy >>> 4
    let n = lowByte &&& 0xFuy
    let nnn = uint16 highByte &&& 0xFus <<< 8 ||| uint16 lowByte

    match int group with
    | 0x0 ->
        match int nnn with
        | 0x0E0 ->  Cls
        | 0x0EE ->  Ret
        | _     -> Sys nnn
    | 0x1 -> Jump nnn
    | 0x2 -> Call nnn
    | 0x3 -> SeRB(x, kk)
    | 0x4 -> SneRB(x, kk)
    | 0x5 -> SeRR(x, y)
    | 0x6 -> LdRB(x, kk)
    | 0x7 -> AddRB(x, kk)
    | 0x8 ->
        match int n with
        | 0x0 -> LdRR(x, y)
        | 0x1 -> Or(x, y)
        | 0x2 -> And(x, y)
        | 0x3 -> Xor(x, y)
        | 0x4 -> AddRR(x, y)
        | 0x5 -> SubRR(x, y)
        | 0x6 -> Shr(x, y)
        | 0x7 -> SubnRR(x, y)
        | 0xE -> Shl(x, y)
        | _   -> Unknown
    | 0x9 -> if n = 0uy then SneRR(x, y) else Unknown
    | 0xA -> LdI nnn
    | 0xB -> JumpV0 nnn
    | 0xC -> Rnd(x, kk)
    | 0xD -> Draw(x, y, n)
    | 0xE ->
        match int kk with
        | 0x9E -> SkKey x
        | 0xA1 -> SknKey x
        | _ -> Unknown
    |0xF ->
        match int kk with
        | 0x07 -> LdVDt x
        | 0x0A -> KeyHalt x
        | 0x15 -> LdDtV x
        | 0x18 -> LdStV x
        | 0x1E -> AddI x
        | 0x29 -> LdHex x
        | 0x33 -> LdBCD x
        | 0x55 -> Dump x
        | 0x65 -> Restore x
        | _ -> Unknown
    | _ -> Unknown

let opcodeToString opcode =
    let address addr = $"0x{addr:X3}"
    let register reg = $"v{reg:X}"
    let byteImm b = $"0x{b:X2}"
    let nibble = byteImm

    match opcode with
    | Sys a ->          $"Sys     {address a}"
    | Cls ->             "Cls"
    | Ret ->             "Ret"
    | Jump a ->         $"Jump    {address a}"
    | Call a ->         $"Call    {address a}"
    | SeRB(r, b) ->     $"Se      {register r}, {byteImm b}"
    | SneRB(r, b) ->    $"Sne     {register r}, {byteImm b}"
    | SeRR(r,r2) ->     $"Se      {register r}, {register r2}"
    | LdRB(r,b) ->      $"Ld      {register r}, {byteImm b}"
    | AddRB(r, b) ->    $"Add     {register r}, {byteImm b}"
    | LdRR(r, r2) ->    $"Ld      {register r}, {register r2}"
    | Or(r, r2) ->      $"Or      {register r}, {register r2}"
    | And(r, r2) ->     $"And     {register r}, {register r2}"
    | Xor(r, r2) ->     $"Xor     {register r}, {register r2}"
    | AddRR(r, r2) ->   $"Add     {register r}, {register r2}"
    | SubRR(r, r2) ->   $"Sub     {register r}, {register r2}"
    | Shr(r, r2) ->     $"Shr     {register r}, {register r2}"
    | SubnRR(r, r2) ->  $"Subn    {register r}, {register r2}"
    | Shl(r, r2) ->     $"Shl     {register r}, {register r2}"
    | SneRR(r, r2) ->   $"Sne     {register r}, {register r2}"
    | LdI a ->          $"Ld      I, {address a}"
    | JumpV0 a ->       $"Jump    V0, {address a}"
    | Rnd(r, b) ->      $"Rnd     {register r}, {byteImm b}"
    | Draw(r, r2, n) -> $"Draw    {register r}, {register r2}, {nibble n}"
    | SkKey r ->        $"SkKey   {register r}"
    | SknKey r ->       $"SknKey  {register r}"
    | LdVDt r ->        $"Ld      {register r}, DT"
    | KeyHalt r ->      $"KeyHalt {register r}"
    | LdDtV r ->        $"Ld DT,  {register r}"
    | LdStV r ->        $"Ld ST,  {register r}"
    | AddI r ->         $"Add I,  {register r}"
    | LdHex r ->        $"LdHex   {register r}"
    | LdBCD r ->        $"LdBCD   {register r}"
    | Dump r ->         $"Dump    {register r}"
    | Restore r ->      $"Restore {register r}"
    | Unknown ->        $"Unknown"


