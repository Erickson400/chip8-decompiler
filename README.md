# Chip8 Decompiler

Turn Chip8 roms into a readable python-style pseudo code or pseudo-assembly.

*Pseudo Code:*

![Pseudo code](https://github.com/Erickson400/chip8-decompiler/blob/main/pseudo.png?raw=true)

*Data file generated alongside Pseudo code:*

![Data file generated along side Pseudo code](https://github.com/Erickson400/chip8-decompiler/blob/main/data.png?raw=true)

*Easy to read Assembly option:*

![enter image description here](https://github.com/Erickson400/chip8-decompiler/blob/main/assembly.png?raw=true)

The decompiler can detect what opcodes are instructions, and which are sprite or general data.
This concept is used in the pseudo decomp and will export the data info to a separate file.


# Usage
The script takes one argument, the path to the rom. It will then ask for the decomp mode you'll like to use, 
 Input the number corresponding to the mode.

    >>python3 run.py rom.ch8
    
    What decomp mode would you like to use?
        1 - pseudo assembly
        2 - pseudo python (full analyzis)
    :
