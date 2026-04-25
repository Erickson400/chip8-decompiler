module Disassembly
open System.IO

type Instruction =
    {
        Address: Opcodes.ChipAddress
        OpcodeBytes: Opcodes.ChipByte * Opcodes.ChipByte
        Opcode: Opcodes.Opcode
    }

(*
    Info:
    Has self modyfying code: No
    Has indirect jumps: Yes
    Number of subroutines: 3


*)


let rec printInstructions instructions =
    let bytesToString (high, low) = $"{high:X2} {low:X2}"
    match instructions with
    | head :: tail -> printfn $"0x{head.Address:X3}: {bytesToString head.OpcodeBytes}    {Opcodes.opcodeToString head.Opcode}"; printInstructions tail
    | [] -> ()

let rec printAddressList addresses =
    match addresses with
    | addr :: tail -> printfn $"0x{addr:X3}"; printAddressList tail
    | [] -> ()

// Returns a tuple of jump addresses and subroutine addresses
let rec getLabelAddresses instructions reachableList jumpList callList =
    match instructions with
    | {Address = opAddress; Opcode = Opcodes.Jump jmpAddr} :: tail ->
        match () with
        | _ when List.contains opAddress reachableList && not (List.contains jmpAddr jumpList) ->
            getLabelAddresses tail reachableList (jmpAddr :: jumpList) callList
        | _ -> getLabelAddresses tail reachableList jumpList callList
    | {Address = opAddress; Opcode = Opcodes.Call callAddr} :: tail ->
        match () with
        | _ when List.contains opAddress reachableList && not (List.contains callAddr callList) ->
            getLabelAddresses tail reachableList jumpList (callAddr :: callList)
        | _ -> getLabelAddresses tail reachableList jumpList callList
    | _ :: tail -> getLabelAddresses tail reachableList jumpList callList
    | [] -> jumpList, callList

(*
    Edge cases:
    If instructions after a subroutine call are not meant to be ran (e.g if the subroutine is infinite)
    then the this function will fail, also a sign of a poorly programmed rom. 
*)
let getReachableAddresses instructions =
    let rec parseInstruction instList reachedList =
        match instList with
        | {Address = opAddress; Opcode = Opcodes.Ret} :: _ ->
            match () with
            | _ when List.contains opAddress reachedList -> Ok reachedList
            | _ -> opAddress :: reachedList |> Ok
        | {Address = opAddress; Opcode = Opcodes.Call callAddr} :: nextInsts ->
            match () with
            | _ when List.contains opAddress reachedList -> Ok reachedList
            | _ when List.contains callAddr reachedList -> opAddress :: reachedList |> Ok
            | _ ->
                let instsAtCall = List.skipWhile (fun x -> x.Address < callAddr) instructions
                let sideBranch = parseInstruction instsAtCall (opAddress :: reachedList)
                match sideBranch with
                | Ok v ->
                    parseInstruction nextInsts v // mainBranch
                | Error _ -> sideBranch
        | {Address = opAddress; Opcode = Opcodes.Jump jmpAddr} :: _ ->
            match () with
            | _ when List.contains opAddress reachedList -> Ok reachedList
            | _ when List.contains jmpAddr reachedList -> opAddress :: reachedList |> Ok
            | _ ->
                let instsAtCall = List.skipWhile (fun x -> x.Address < jmpAddr) instructions
                parseInstruction instsAtCall (opAddress :: reachedList)
        | {Address = opAddress; Opcode = Opcodes.SeRB _} :: nextInst :: tail
        | {Address = opAddress; Opcode = Opcodes.SneRB _} :: nextInst :: tail
        | {Address = opAddress; Opcode = Opcodes.SeRR _} :: nextInst :: tail
        | {Address = opAddress; Opcode = Opcodes.SneRR _} :: nextInst :: tail
        | {Address = opAddress; Opcode = Opcodes.SkKey _} :: nextInst :: tail
        | {Address = opAddress; Opcode = Opcodes.SknKey _} :: nextInst :: tail ->
            match () with
            | _ when List.contains opAddress reachedList -> Ok reachedList
            | _ ->
                let newReachedList = opAddress :: reachedList
                let skippedBranch = parseInstruction (nextInst :: tail) newReachedList
                match skippedBranch with
                | Ok v ->
                    parseInstruction tail v // mainBranch
                | Error _ -> skippedBranch
        | {Address = address; Opcode = Opcodes.Unknown} :: _ -> Error $"Unknown opcode reached at 0x{address:X3}"
        | {Address = opAddress} :: tail ->
            match () with
            | _ when List.contains opAddress reachedList -> Ok reachedList
            | _ -> parseInstruction tail (opAddress :: reachedList)
        | [] -> Ok reachedList
    parseInstruction instructions [] |> Result.map List.rev
    
let createInstructions rom =
    let rec createInstructionsRec rom address instsList =
        match rom with
        | high :: low :: tail ->
            let opcodeBytes = high, low
            let opcode = Opcodes.bytesToOpcode opcodeBytes
            let instruction = { Address = address; OpcodeBytes = opcodeBytes; Opcode = opcode }
            let newInsts = instruction :: instsList
            createInstructionsRec tail (address + 2us)  newInsts
        | [_] | [] -> instsList
    createInstructionsRec rom 0x200us [] |> List.rev

let readRom path =
    try
        File.ReadAllBytes path |> Array.toList |> Ok
    with
        | ex -> $"Failed to read Rom file: {path}.\n{ex.Message}" |> Error

let disassemble inputPath outputPath=
    let instructions = readRom inputPath |> Result.map createInstructions
    let reachablAddresses = instructions |> Result.bind getReachableAddresses

    let labelAddresses  =
        match instructions with
        | Ok instsList ->
            match reachablAddresses with
            | Ok addrs -> getLabelAddresses instsList addrs [] [] |> Ok
            | Error e -> Error e
        | Error e -> Error e

    match instructions with
    | Ok instsList -> printInstructions instsList
    | Error e -> printfn $"{e}"

    match labelAddresses with
    | Ok (label, call) -> printAddressList call
    | Error e -> printfn $"{e}"

    0





