import sys
import os
import time
from pseudo_assembly import decomp_to_pseudo_assembly
from pseudo import decomp_to_pseudo

def main():
    if len(sys.argv) < 2 :
        print("Error: Invalid ROM path: '' ")
        sys.exit()
    
    if not os.path.exists(sys.argv[1]):
        print(f"Error: Invalid ROM path: '{sys.argv[1]}'")
        sys.exit()

    mode = input("""What decomp mode would you like to use?
1 - pseudo assembly
2 - pseudo python (full analyzis)
:""")
    input_file_path = sys.argv[1]
    previous_time = time.time_ns() / 1_000_000

    if mode == "1":
        print(f"Decompiling ROM '{input_file_path}' into Pseudo Assembly")
        decomp_to_pseudo_assembly(input_file_path)  
    elif mode == "2":
        print(f"Decompiling ROM '{input_file_path}' into Pseudo Python")
        decomp_to_pseudo(input_file_path)
    else:
        print("Error: Invalid decomp mode " + mode)
        sys.exit()

    decomp_time = (time.time_ns()/1_000_000) - previous_time
    print(f"Fnished Decompiling, {round(decomp_time)}ms")

if __name__ == "__main__":
    main()









