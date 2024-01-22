import struct as s
import sys
from copy import deepcopy, copy
from collections import deque

def decomp_to_pseudo(input_file_path: str):
	ram = create_ram(input_file_path)
	symbols = create_symbols(ram)

	subroutine_entry_points = find_subroutine_entry_points(ram, symbols)

	main = stringify_subroutine(ram, symbols)
	subroutines = [] 
	for i in range(len(subroutine_entry_points)):
		subroutines.append(stringify_subroutine(ram, symbols, subroutine_entry_points[i]))

	with open("out/code.txt", "w") as output_file:
		output_file.write(main)
		for sub in subroutines:
			output_file.write('\n\n')
			output_file.write(sub)

	with open("out/data.txt", "w") as output_file:
		out = ""
		highest_opcode_address = max(symbols["opcodes_at"]) + 2
		for d in range(highest_opcode_address, len(ram)):
			if ram[d] not in symbols["opcodes_at"]:
				block_char = "\u2588"
				binary_block = ""
				binary = f"{ram[d]:08b}"
				for letter in binary:
					if letter == "1":
						binary_block += block_char
					else:
						binary_block += "-"

				out += f"0x{d:x}:  {ram[d]:08b} {binary_block} 0x{ram[d]:02x}\n"
		output_file.write(out)


def stringify_subroutine(ram: list, symbols: list, entry_point: int=None) -> str:
	"""
	Handle the string position of the else, labels, nested if statements
	and indentations. It handles this by making a tree of control flow.

	Append each line to result variable and then indent all of it at the end,
	then add the function name at the beginning.
	"""

	result = []
	pc = entry_point if entry_point else 0x200
	nodes = []

	safety_threshold = 10000
	for _ in range(safety_threshold):
		# Add a label if it has one
		if pc in symbols["labels_at"]:
			result.append(f"{'    '*len(nodes)}::label_{pc:x}::\n")
		
		opcode = (ram[pc] << 8) | ram[pc + 1]
		next_opcode = (ram[pc+2] << 8) | ram[pc + 3]
		instruction = instruction_type(opcode, ram, pc)
		if instruction[0] == "SkipJumpBack":
			result.append(f"{'    '*len(nodes)}{opcode_to_str(opcode)}\n")
			result.append(f"{'    '*(len(nodes)+1)}{opcode_to_str(next_opcode)}\n")
			pc += 4

		elif instruction[0] == "SkipJumpFront":
			result.append(f"{'    '*len(nodes)}{opcode_to_str(opcode)}\n")
			parent = None if len(nodes) == 0 else nodes[-1]
			node = {
				"parent": parent,
				"status": "body", # or "else"
				"body_address": instruction[1],
				"else_address":instruction[2],
			}
			nodes.append(node)
			pc = nodes[-1]["body_address"]
		
		elif instruction[0] == "SkipOpcode":
			result.append(f"{'    '*len(nodes)}{opcode_to_str(opcode)}\n")
			result.append(f"{'    '*(len(nodes)+1)}{opcode_to_str(next_opcode)}\n")
			pc += 4
				
		elif instruction[0] == "Return" or instruction[0] == "JumpBack":
			result.append(f"{'    '*(len(nodes))}{opcode_to_str(opcode)}\n")
			if len(nodes) == 0:
				break
			if nodes[-1]["status"] == "body":
				result.append(f"{'    '*(len(nodes)-1)}else:\n")
				nodes[-1]["status"] = "else"
				pc = nodes[-1]["else_address"]
			elif nodes[-1]["status"] == "else":
				if nodes[-1]["parent"]:
					while True:
						nodes.pop()
						if nodes[-1]["status"] == "body":
							nodes[-1]["status"] = "else"
							result.append(f"{'    '*(len(nodes)-1)}else:\n")
							pc = nodes[-1]["else_address"]
							break
				else:
					break

		elif instruction[0] == "JumpFront":
			pc = instruction[1]
		elif instruction[0] == "Opcode":
			result.append(f"{'    '*len(nodes)}{opcode_to_str(opcode)}\n")
			pc += 2

	if entry_point is None:
		indented_result = "def main():\n"
	else:
		indented_result = f"def fun_{entry_point:x}():\n"

	for line in range(len(result)):
		indented_result += f"    {result[line]}"

	return indented_result


def opcode_to_str(opcode, use_skips=False) -> str:
	"""
	This function will also exit the program if the game has a
	"jump with offset V0" opcode, This instruction makes it impossible
	to create symbols without interpreting the whole
	game & it's registers in realtime.
	"""

	x = (opcode & 0x0f00) >> 8
	y = (opcode & 0x00f0) >> 4
	z = opcode & 0x000f
	nn = opcode & 0x00ff
	nnn = opcode & 0x0fff

	if opcode == 0x00e0:
		return "clear()"
	elif opcode == 0x00ee:
		return "return"
	elif opcode & 0xf000 == 0x1000:
		return f"goto label_{nnn:x}"
	elif opcode & 0xf000 == 0x2000:
		return f"fun_{nnn:x}()"
	elif opcode & 0xf000 == 0x3000:
		if use_skips:
			return f"skip if V{x:x} == 0x{nn:x}:"
		return f"if V{x:x} != 0x{nn:x}:"
	elif opcode & 0xf000 == 0x4000:
		if use_skips:
			return f"skip if V{x:x} != 0x{nn:x}:"
		return f"if V{x:x} == 0x{nn:x}:"
	elif opcode & 0xf000 == 0x5000:
		if use_skips:
			return f"skip if V{x:x} == V{y:x}:"
		return f"if V{x:x} != V{y:x}:"
	elif opcode & 0xf000 == 0x6000:
		return f"V{x:x} = 0x{nn:x}"
	elif opcode & 0xf000 == 0x7000:
		return f"V{x:x} += 0x{nn:x}"
	elif opcode & 0xf00f == 0x8000:
		return f"V{x:x} = V{y:x}"
	elif opcode & 0xf00f == 0x8001:
		return f"V{x:x} |= V{y:x}"
	elif opcode & 0xf00f == 0x8002:
		return f"V{x:x} &= V{y:x}"
	elif opcode & 0xf00f == 0x8003:
		return f"V{x:x} ^= V{y:x}"
	elif opcode & 0xf00f == 0x8004:
		return f"V{x:x} += V{y:x}"
	elif opcode & 0xf00f == 0x8005:
		return f"V{x:x} -= V{y:x}"
	elif opcode & 0xf00f == 0x8006:
		return f"V{x:x} >>= V{y:x}"
	elif opcode & 0xf00f == 0x8007:
		return f"V{x:x} = V{x:x} - V{y:x}"
	elif opcode & 0xf00f == 0x800e:
		return f"V{x:x} <<= V{y:x}"
	elif opcode & 0xf00f == 0x9000:
		if use_skips:
			return f"skip if V{x:x} != V{y:x}:"
		return f"if V{x:x} == V{y:x}:"
	elif opcode & 0xf000 == 0xa000:
		return f"i = 0x{nnn:x}"
	elif opcode & 0xf000 == 0xb000:
		print("Found Jump with offset, Cant decomp")
		sys.exit()
	elif opcode & 0xf000 == 0xc000:
		return f"V{x:x} = random(0x{nn:x})"
	elif opcode & 0xf000 == 0xd000:
		return f"draw(V{x:x}, V{y:x}, 0x{z:x})"
	elif opcode & 0xf0ff == 0xe09e:
		if use_skips:
			return f"skip if key(V{x:x}).isDown:"
		return f"if key(V{x:x}).isUp:"
	elif opcode & 0xf0ff == 0xe0a1:
		if use_skips:
			return f"skip if key(V{x:x}).isUp:"
		return f"if key(V{x:x}).isDown:"
	elif opcode & 0xf0ff == 0xf007:
		return f"V{x:x} = delay"
	elif opcode & 0xf0ff == 0xf00a:
		return f"V{x:x} = key_halt()"
	elif opcode & 0xf0ff == 0xf015:
		return f"delay = V{x:x}"
	elif opcode & 0xf0ff == 0xf018:
		return f"sound_timer = V{x:x}"
	elif opcode & 0xf0ff == 0xf01e:
		return f"i += V{x:x}"
	elif opcode & 0xf0ff == 0xf029:
		return f"i = hex_digit(V{x:x})"
	elif opcode & 0xf0ff == 0xf033:
		return f"bcd(V{x:x})"
	elif opcode & 0xf0ff == 0xf055:
		return f"save(V{x:x})"
	elif opcode & 0xf0ff == 0xf065:
		return f"load(V{x:x})"
	else:
		return "nan"


def instruction_type(opcode, ram, pc) -> (str, int, int):
	"""
	Condences a pattern of instructions into a type.

	Returns (string type, body jump address, else jump address).
	The jump addresses are 0 if not needed.
	"""	
	
	if opcode == 0x00ee:
		return ("Return", 0, 0)
	elif opcode & 0xf000 == 0x3000 or \
	   opcode & 0xf000 == 0x4000 or \
	   opcode & 0xf000 == 0x5000 or \
	   opcode & 0xf00f == 0x9000 or \
	   opcode & 0xf0ff == 0xe09e or \
	   opcode & 0xf0ff == 0xe0a1:
		# Is a skip
		next_opcode = (ram[pc+2] << 8) | ram[pc + 3]
		if next_opcode & 0xf000 == 0x1000:
			# Next opcode is a jump
			jump_address = next_opcode & 0x0fff
			if jump_address <= pc:
				return ("SkipJumpBack", jump_address, 0)
			else:
				return ("SkipJumpFront", jump_address, pc+4)
		else:
			# Next opcode is NOT a jump
			return ("SkipOpcode", 0, 0)
	elif opcode & 0xf000 == 0x1000:
		# Is a jump
		jump_address = opcode & 0x0fff
		if jump_address <= pc:
			return ("JumpBack", jump_address, 0)
		else:
			return ("JumpFront", jump_address, 0)
	else:
		return ("Opcode", 0, 0)


def find_subroutine_entry_points(ram: list, \
symbols: list) -> list:
	"""
	Iterate through opcodes and check if its 
	a call to a unique address, Only checks opcodes
	that are on the opcodes_at list on the symbols.
	"""

	last_opcode_address = max(symbols["opcodes_at"])
	entry_points = []

	for i in range(0x200, last_opcode_address+2, 2):
		opcode = (ram[i] << 8) | ram[i + 1]
		if opcode & 0xf000 == 0x2000:
			# Is a call
			call_address = opcode & 0x0fff
			if call_address not in entry_points:
				entry_points.append(call_address)
	return entry_points


def run_branch(branch: dict, symbols: dict, ram: list) \
-> (list, dict, (str, int, int)):
	"""
	Runs a branch until it finds a skip opcode, a backwards jump
	or a return opcode. If a skip opcode is found then it'll return the
	call stack, the modified symbols dict, and a tuple holding a string
	saying if a branch was found, with the two addreses
	of the possible game flows if it did find one.

	The symbols parameter is updated and returned.

	This function will also exit the program if the game has a
	"jump with offset V0" opcode, This instruction makes it impossible
	to create symbols without interpreting the whole
	game & it's registers in realtime.
	"""

	pc = branch["pc"]
	stack = deepcopy(branch["stack"])
	new_symbols = deepcopy(symbols)

	# Run opcodes
	while True:
		opcode = (ram[pc] << 8) | ram[pc + 1]

		if pc not in new_symbols["opcodes_at"]:
			new_symbols["opcodes_at"].append(pc)
		
		if opcode & 0xf000 == 0x3000 or \
		   opcode & 0xf000 == 0x4000 or \
		   opcode & 0xf000 == 0x5000 or \
		   opcode & 0xf00f == 0x9000 or \
		   opcode & 0xf0ff == 0xe09e or \
		   opcode & 0xf0ff == 0xe0a1:
			# Is a skip
			return (stack, new_symbols, ("FoundBranch", pc+2, pc+4))
		elif opcode & 0xf000 == 0x1000:
			# Is a jump
			jump_address = opcode & 0x0fff
			if jump_address <= pc:
				if jump_address not in new_symbols["labels_at"]:
					new_symbols["labels_at"].append(jump_address)
				return (stack, new_symbols, ("NotFoundBranch", 0, 0))
			else:
				pc = jump_address
		elif  opcode & 0xf000 == 0xb000:
			# Is a jump with offset
			print("Found Jump with offset, Cant decomp")
			sys.exit()
		elif opcode & 0xf000 == 0x2000:
			# Is a call
			call_address = opcode & 0x0fff
			stack.append(pc+2)
			pc = call_address
		elif opcode == 0x00ee:
			# Is return
			pc = stack.pop()
		else:
			pc += 2


def create_symbols(ram: list) -> dict:
	"""
	Finds opcode and label addresses.

	A branch is a section of code that changes control flow,
	i.e an if/else statement. When a branch is found it will create two
	seperate branches for if the condition is true or false. That way this
	function can see all the possible states of the game, finding what
	code is ran, or referenced. It does this by having a queue where
	every cycle a branch is popped and ran. If it found another branch
	then append two branches, if it didn't then do nothing. This funciton
	returns the symbols when the queue is empty.
	
	Any address that might be ran will be added to opcodes_at in the symbols
	dictionary. This also means that any opcodes that are not in opcodes_at
	can be considered game data/sprites.

	labels_at in the symbols dictionary will hold any addresses that a jump opcode
	points to.
	"""

	symbols = {
		"opcodes_at": [],
		"labels_at": [],
	}

	branch_queue = deque()
	branch_queue.append({"pc":0x200, "stack":[]})

	while True:
		if len(branch_queue) == 0: break

		branch = branch_queue.popleft()
		new_stack, symbols, status = run_branch(branch, symbols, ram)

		if status[0] == "NotFoundBranch": continue
		elif status[0] == "FoundBranch":
			branch_queue.append({"pc":status[1], "stack":copy(new_stack)})
			branch_queue.append({"pc":status[2], "stack":copy(new_stack)})

	return symbols


def create_ram(input_file_path: str) -> list:
	ram = [0]*0x200
	with open(input_file_path, "rb") as input_file:
		while True:
			byte = input_file.read(1)
			if not byte: break

			ram.append(s.unpack("B", byte)[0])

	return ram





