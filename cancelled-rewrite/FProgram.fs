
let printHelp () =
    printfn "%s" """Usage:
    chip8-decompiler asm [input file] [output file]
            Dissasembles the rom to assembly and pseudo assembly.

    chip8-decompiler py [input file] [output file]
            Decompiles the rom to a pythonic script.

    chip8-decompiler help         
            Shows this message.
"""

[<EntryPoint>]
let main args = 
    match Array.toList args with
    | [] -> printHelp (); 0
    | cmd :: _ when cmd = "help" -> printHelp (); 0
    | [cmd; input; output] when cmd = "asm" -> Disassembly.disassemble input output
    // | [cmd; input; output] when cmd = "py" -> 0
    | _ ->printfn "Invalid arguments"; 1
    


