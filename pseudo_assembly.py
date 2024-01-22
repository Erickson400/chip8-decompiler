import struct as s
from pseudo import opcode_to_str


def decomp_to_pseudo_assembly(input_file_path):
	output_buffer = ""

	with open(input_file_path, "rb") as input_file:
		address = 0x200

		while True:
			bytes = input_file.read(2)
			if not bytes: break

			opcode = s.unpack(">H", bytes)[0]
			byte0 = opcode >> 8
			byte1 = opcode & 0xff

			output_buffer += f"0x{address:x}:  "
			output_buffer += f"{byte0:02x} {byte1:02x}    "
			output_buffer += f"{opcode_to_str(opcode, use_skips=True)} \n"

			address += 2

	with open("out/asm.txt", "w") as output_file:
	   output_file.write(output_buffer)

