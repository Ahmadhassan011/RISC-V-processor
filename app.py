import os
import json
import subprocess
import tempfile
import re
from flask import Flask, render_template, request, jsonify

app = Flask(__name__)
app.secret_key = os.environ.get("SESSION_SECRET", "dev-secret-key")

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/guide')
def guide():
    return render_template('guide.html')

@app.route('/simulate', methods=['POST'])
def simulate():
    try:
        data = request.get_json() or {}
        instructions = data.get('instructions', '')
        
        # Create instructions file
        instructions_path = os.path.join('simulation', 'instructions.hex')
        os.makedirs('simulation', exist_ok=True)
        
        # Process instructions - convert assembly to hex if needed
        hex_instructions = process_instructions(instructions)
        
        with open(instructions_path, 'w') as f:
            f.write(hex_instructions)
        
        # Run Python-based RISC-V simulation
        simulation_data = run_riscv_simulation(hex_instructions)
        
        return jsonify({
            'success': True,
            'data': simulation_data
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })

def process_instructions(instructions):
    """Process assembly instructions or hex values"""
    lines = instructions.strip().split('\n')
    hex_lines = []
    
    for line in lines:
        line = line.strip()
        if not line or line.startswith('//') or line.startswith('#'):
            continue
            
        # If it's already hex (starts with 0x or is 8 hex digits)
        if line.startswith('0x') or (len(line) == 8 and all(c in '0123456789abcdefABCDEF' for c in line)):
            hex_lines.append(line.replace('0x', ''))
        else:
            # For now, add default NOP instruction for assembly
            hex_lines.append('00000013')  # NOP instruction
    
    return '\n'.join(hex_lines)

def run_riscv_simulation(hex_instructions):
    """Run a Verilog-based RISC-V pipeline simulation using iverilog and vvp"""
    try:
        # Check if iverilog and vvp are installed
        try:
            # Test if iverilog is available
            subprocess.run(['iverilog', '-v'], capture_output=True, check=True)
            # Test if vvp is available
            subprocess.run(['vvp', '-v'], capture_output=True, check=True)
        except (subprocess.SubprocessError, FileNotFoundError):
            print("Icarus Verilog (iverilog/vvp) not found. Please install it to use Verilog simulation.")
            print("Falling back to Python simulation.")
            return fallback_python_simulation(hex_instructions)
        
        # Ensure simulation directory exists
        os.makedirs('simulation', exist_ok=True)
        
        # Create a file to capture simulation output
        output_file_path = os.path.join('simulation', 'simulation_output.txt')
        
        # Compile the Verilog code using iverilog
        compile_cmd = ['iverilog', '-o', 'simulation/processor_sim', 'simulation/processor.v', 'simulation/testbench.v']
        compile_process = subprocess.run(compile_cmd, capture_output=True, text=True, check=False)
        
        if compile_process.returncode != 0:
            print(f"Verilog compilation failed: {compile_process.stderr}")
            print("Falling back to Python simulation.")
            return fallback_python_simulation(hex_instructions)
        
        # Run the simulation using vvp and capture the output
        run_cmd = ['vvp', 'simulation/processor_sim', '+INSTRUCTION_FILE']
        with open(output_file_path, 'w') as output_file:
            run_process = subprocess.run(run_cmd, stdout=output_file, stderr=subprocess.PIPE, text=True, check=False)
        
        if run_process.returncode != 0:
            print(f"Verilog simulation failed: {run_process.stderr}")
            print("Falling back to Python simulation.")
            return fallback_python_simulation(hex_instructions)
        
        # Parse the simulation output file to extract cycle data
        simulation_data = parse_simulation_output(output_file_path)
        
        # If parsing failed or returned empty data, fall back to Python simulation
        if not simulation_data:
            print("Failed to parse Verilog simulation output.")
            print("Falling back to Python simulation.")
            return fallback_python_simulation(hex_instructions)
            
        return simulation_data
        
    except Exception as e:
        # If there's an error with the Verilog simulation, fall back to Python simulation
        print(f"Error in Verilog simulation: {str(e)}")
        print("Falling back to Python simulation.")
        return fallback_python_simulation(hex_instructions)

def parse_simulation_output(output_file_path):
    """Parse the Verilog simulation output file and convert to the expected format"""
    cycles = []
    current_cycle = None
    registers = [0] * 32
    memory = {}
    pipeline = {}
    control_signals = {
        'regwrite': False,
        'memread': False,
        'memwrite': False,
        'branch': False,
        'alusrc': False,
        'memtoreg': False
    }
    
    try:
        with open(output_file_path, 'r') as f:
            lines = f.readlines()
        
        cycle_num = 0
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            
            # Start of a new cycle
            if line.startswith("CYCLE"):
                # Save previous cycle data if it exists
                if current_cycle is not None:
                    cycles.append(current_cycle)
                
                # Extract cycle number and PC
                match = re.match(r"CYCLE (\d+): PC=0x([0-9a-fA-F]+)", line)
                if match:
                    cycle_num = int(match.group(1))
                    pc = int(match.group(2), 16)
                    
                    # Initialize new cycle data
                    current_cycle = {
                        'cycle': cycle_num,
                        'pc': pc,
                        'registers': registers.copy(),
                        'pipeline': {
                            'if_id': {'pc': 0, 'instruction': '00000013'},
                            'id_ex': {
                                'pc': 0, 
                                'instruction': '00000013', 
                                'rs1': 0,
                                'rs2': 0,
                                'rd': 0,
                                'rs1_val': 0, 
                                'rs2_val': 0,
                                'imm': 0
                            },
                            'ex_mem': {
                                'pc': 0, 
                                'alu_result': 0, 
                                'rd': 0,
                                'zero_flag': 0
                            },
                            'mem_wb': {
                                'pc': 0, 
                                'result': 0, 
                                'rd': 0
                            }
                        },
                        'memory': {},
                        'control_signals': control_signals.copy()
                    }
            
            # Parse register values
            elif line.startswith("REG["):
                # Extract register values
                matches = re.findall(r"REG\[(\d+)\]=0x([0-9a-fA-F]+)", line)
                for match in matches:
                    reg_num = int(match[0])
                    reg_val = int(match[1], 16)
                    if reg_num < 32:
                        registers[reg_num] = reg_val
            
            # Parse pipeline stage information
            elif line.startswith("IF_ID_INSTR"):
                match = re.match(r"IF_ID_INSTR=0x([0-9a-fA-F]+) IF_ID_PC=0x([0-9a-fA-F]+)", line)
                if match and current_cycle is not None:
                    current_cycle['pipeline']['if_id']['instruction'] = match.group(1)
                    current_cycle['pipeline']['if_id']['pc'] = int(match.group(2), 16)
            
            elif line.startswith("ID_EX_INSTR"):
                match = re.match(r"ID_EX_INSTR=0x([0-9a-fA-F]+) ID_EX_PC=0x([0-9a-fA-F]+)", line)
                if match and current_cycle is not None:
                    current_cycle['pipeline']['id_ex']['instruction'] = match.group(1)
                    current_cycle['pipeline']['id_ex']['pc'] = int(match.group(2), 16)
            
            elif line.startswith("ID_EX_RS1="):
                match = re.match(r"ID_EX_RS1=0x([0-9a-fA-F]+) ID_EX_RS1_VAL=0x([0-9a-fA-F]+)", line)
                if match and current_cycle is not None:
                    current_cycle['pipeline']['id_ex']['rs1'] = int(match.group(1), 16)
                    current_cycle['pipeline']['id_ex']['rs1_val'] = int(match.group(2), 16)
            
            elif line.startswith("ID_EX_RS2="):
                match = re.match(r"ID_EX_RS2=0x([0-9a-fA-F]+) ID_EX_RS2_VAL=0x([0-9a-fA-F]+)", line)
                if match and current_cycle is not None:
                    current_cycle['pipeline']['id_ex']['rs2'] = int(match.group(1), 16)
                    current_cycle['pipeline']['id_ex']['rs2_val'] = int(match.group(2), 16)
            
            elif line.startswith("ID_EX_RD="):
                match = re.match(r"ID_EX_RD=0x([0-9a-fA-F]+) ID_EX_IMM=0x([0-9a-fA-F]+)", line)
                if match and current_cycle is not None:
                    current_cycle['pipeline']['id_ex']['rd'] = int(match.group(1), 16)
                    current_cycle['pipeline']['id_ex']['imm'] = int(match.group(2), 16)
            
            elif line.startswith("EX_MEM_ALU"):
                match = re.match(r"EX_MEM_ALU=0x([0-9a-fA-F]+) EX_MEM_PC=0x([0-9a-fA-F]+)", line)
                if match and current_cycle is not None:
                    current_cycle['pipeline']['ex_mem']['alu_result'] = int(match.group(1), 16)
                    current_cycle['pipeline']['ex_mem']['pc'] = int(match.group(2), 16)
            
            elif line.startswith("EX_MEM_RD="):
                match = re.match(r"EX_MEM_RD=0x([0-9a-fA-F]+) EX_MEM_ZERO=(\d+)", line)
                if match and current_cycle is not None:
                    current_cycle['pipeline']['ex_mem']['rd'] = int(match.group(1), 16)
                    current_cycle['pipeline']['ex_mem']['zero_flag'] = int(match.group(2))
            
            elif line.startswith("MEM_WB_DATA"):
                match = re.match(r"MEM_WB_DATA=0x([0-9a-fA-F]+) MEM_WB_PC=0x([0-9a-fA-F]+)", line)
                if match and current_cycle is not None:
                    current_cycle['pipeline']['mem_wb']['result'] = int(match.group(1), 16)
                    current_cycle['pipeline']['mem_wb']['pc'] = int(match.group(2), 16)
            
            elif line.startswith("MEM_WB_RD="):
                match = re.match(r"MEM_WB_RD=0x([0-9a-fA-F]+)", line)
                if match and current_cycle is not None:
                    current_cycle['pipeline']['mem_wb']['rd'] = int(match.group(1), 16)
            
            # Parse control signals
            elif line.startswith("CTRL_REGWRITE="):
                match = re.match(r"CTRL_REGWRITE=(\d+) CTRL_MEMREAD=(\d+) CTRL_MEMWRITE=(\d+)", line)
                if match and current_cycle is not None:
                    current_cycle['control_signals']['regwrite'] = bool(int(match.group(1)))
                    current_cycle['control_signals']['memread'] = bool(int(match.group(2)))
                    current_cycle['control_signals']['memwrite'] = bool(int(match.group(3)))
            
            elif line.startswith("CTRL_BRANCH="):
                match = re.match(r"CTRL_BRANCH=(\d+) CTRL_ALUSRC=(\d+) CTRL_MEMTOREG=(\d+)", line)
                if match and current_cycle is not None:
                    current_cycle['control_signals']['branch'] = bool(int(match.group(1)))
                    current_cycle['control_signals']['alusrc'] = bool(int(match.group(2)))
                    current_cycle['control_signals']['memtoreg'] = bool(int(match.group(3)))
            
            # Parse memory contents
            elif line.startswith("MEM["):
                matches = re.findall(r"MEM\[(\d+)\]=0x([0-9a-fA-F]+)", line)
                for match in matches:
                    mem_addr = int(match[0]) // 4  # Convert byte address to word address
                    mem_val = int(match[1], 16)
                    if mem_val != 0:  # Only store non-zero values
                        current_cycle['memory'][mem_addr] = mem_val
            
            i += 1
        
        # Add the last cycle
        if current_cycle is not None:
            cycles.append(current_cycle)
        
        return cycles
    
    except Exception as e:
        print(f"Error parsing simulation output: {str(e)}")
        return []

def fallback_python_simulation(hex_instructions):
    """Fallback to Python-based simulation if Verilog simulation fails"""
    class RISCVSimulator:
        def __init__(self):
            self.registers = [0] * 32  # 32 general purpose registers
            self.memory = [0] * 256    # Data memory
            self.pc = 0
            self.instruction_memory = []
            self.cycles = []
            
            # Pipeline registers
            self.if_id = {'pc': 0, 'instruction': 0x00000013}
            self.id_ex = {'pc': 0, 'instruction': 0x00000013, 'rs1_val': 0, 'rs2_val': 0, 'imm': 0, 'rd': 0}
            self.ex_mem = {'pc': 0, 'alu_result': 0, 'rd': 0, 'mem_write_data': 0}
            self.mem_wb = {'pc': 0, 'result': 0, 'rd': 0}
            
            # Control signals
            self.control = {
                'reg_write': False,
                'mem_read': False,
                'mem_write': False,
                'mem_to_reg': False,
                'alu_src': False,
                'branch': False
            }
        
        def load_instructions(self, hex_str):
            """Load hex instructions into instruction memory"""
            lines = hex_str.strip().split('\n')
            for line in lines:
                line = line.strip()
                if line and not line.startswith('#'):
                    try:
                        instr = int(line, 16)
                        self.instruction_memory.append(instr)
                    except ValueError:
                        self.instruction_memory.append(0x00000013)  # NOP
            
            # Pad with NOPs
            while len(self.instruction_memory) < 64:
                self.instruction_memory.append(0x00000013)
        
        def decode_instruction(self, instr):
            """Decode RISC-V instruction"""
            opcode = instr & 0x7F
            rd = (instr >> 7) & 0x1F
            funct3 = (instr >> 12) & 0x7
            rs1 = (instr >> 15) & 0x1F
            rs2 = (instr >> 20) & 0x1F
            funct7 = (instr >> 25) & 0x7F
            
            # Immediate generation
            if opcode == 0x13 or opcode == 0x03:  # I-type
                imm = (instr >> 20) & 0xFFF
                if imm & 0x800:  # Sign extend
                    imm |= 0xFFFFF000
            elif opcode == 0x23:  # S-type
                imm = ((instr >> 25) << 5) | ((instr >> 7) & 0x1F)
                if imm & 0x800:  # Sign extend
                    imm |= 0xFFFFF000
            elif opcode == 0x63:  # B-type
                imm = ((instr >> 31) << 12) | (((instr >> 7) & 0x1) << 11) | (((instr >> 25) & 0x3F) << 5) | (((instr >> 8) & 0xF) << 1)
                if imm & 0x1000:  # Sign extend
                    imm |= 0xFFFFE000
            else:
                imm = 0
            
            return {
                'opcode': opcode,
                'rd': rd,
                'funct3': funct3,
                'rs1': rs1,
                'rs2': rs2,
                'funct7': funct7,
                'imm': imm & 0xFFFFFFFF
            }
        
        def execute_alu(self, op1, op2, funct3, funct7, opcode):
            """Execute ALU operation"""
            if opcode == 0x33:  # R-type
                if funct3 == 0:  # ADD/SUB
                    if funct7 == 0x20:  # SUB
                        return (op1 - op2) & 0xFFFFFFFF
                    else:  # ADD
                        return (op1 + op2) & 0xFFFFFFFF
                elif funct3 == 7:  # AND
                    return op1 & op2
                elif funct3 == 6:  # OR
                    return op1 | op2
                elif funct3 == 4:  # XOR
                    return op1 ^ op2
                elif funct3 == 1:  # SLL
                    return (op1 << (op2 & 0x1F)) & 0xFFFFFFFF
            elif opcode == 0x13:  # I-type
                if funct3 == 0:  # ADDI
                    return (op1 + op2) & 0xFFFFFFFF
                elif funct3 == 2:  # SLTI
                    return 1 if (op1 < op2) else 0
            elif opcode == 0x03 or opcode == 0x23:  # Load/Store
                return (op1 + op2) & 0xFFFFFFFF
            
            return 0
        
        def simulate_cycle(self, cycle_num):
            """Simulate one clock cycle"""
            cycle_data = {
                'cycle': cycle_num,
                'pc': self.pc,
                'registers': self.registers.copy(),
                'pipeline': {
                    'if_id': {
                        'pc': self.if_id.get('pc', 0),
                        'instruction': format(self.if_id.get('instruction', 0x00000013), '08X')
                    },
                    'id_ex': {
                        'pc': self.id_ex.get('pc', 0),
                        'instruction': format(self.id_ex.get('instruction', 0x00000013), '08X'),
                        'rs1_val': self.id_ex.get('rs1_val', 0),
                        'rs2_val': self.id_ex.get('rs2_val', 0)
                    },
                    'ex_mem': {
                        'pc': self.ex_mem.get('pc', 0),
                        'alu_result': self.ex_mem.get('alu_result', 0),
                        'rd': self.ex_mem.get('rd', 0)
                    },
                    'mem_wb': {
                        'pc': self.mem_wb.get('pc', 0),
                        'result': self.mem_wb.get('result', 0),
                        'rd': self.mem_wb.get('rd', 0)
                    }
                },
                'memory': {i: self.memory[i] for i in range(16) if self.memory[i] != 0}
            }
            
            # Write Back stage
            if self.mem_wb['rd'] != 0 and cycle_num > 4:  # WB happens after 5 cycles
                self.registers[self.mem_wb['rd']] = self.mem_wb['result']
            
            # Memory stage
            if cycle_num > 3:  # MEM happens after 4 cycles
                decoded = self.decode_instruction(self.ex_mem.get('instruction', 0x00000013))
                if decoded['opcode'] == 0x03:  # Load
                    addr = (self.ex_mem['alu_result'] // 4) % len(self.memory)
                    self.mem_wb['result'] = self.memory[addr]
                elif decoded['opcode'] == 0x23:  # Store
                    addr = (self.ex_mem['alu_result'] // 4) % len(self.memory)
                    self.memory[addr] = self.ex_mem['mem_write_data']
                    self.mem_wb['result'] = self.ex_mem['alu_result']
                else:
                    self.mem_wb['result'] = self.ex_mem['alu_result']
                
                self.mem_wb['rd'] = self.ex_mem['rd']
                self.mem_wb['pc'] = self.ex_mem['pc']
            
            # Execute stage
            if cycle_num > 2:  # EX happens after 3 cycles
                decoded = self.decode_instruction(self.id_ex.get('instruction', 0x00000013))
                op2 = self.id_ex['imm'] if decoded['opcode'] in [0x13, 0x03, 0x23] else self.id_ex['rs2_val']
                alu_result = self.execute_alu(self.id_ex['rs1_val'], op2, decoded['funct3'], decoded['funct7'], decoded['opcode'])
                
                self.ex_mem['alu_result'] = alu_result
                self.ex_mem['rd'] = self.id_ex['rd']
                self.ex_mem['pc'] = self.id_ex['pc']
                self.ex_mem['mem_write_data'] = self.id_ex['rs2_val']
                self.ex_mem['instruction'] = self.id_ex['instruction']
            
            # Decode stage
            if cycle_num > 1:  # ID happens after 2 cycles
                decoded = self.decode_instruction(self.if_id['instruction'])
                self.id_ex['rs1_val'] = self.registers[decoded['rs1']] if decoded['rs1'] != 0 else 0
                self.id_ex['rs2_val'] = self.registers[decoded['rs2']] if decoded['rs2'] != 0 else 0
                self.id_ex['imm'] = decoded['imm']
                self.id_ex['rd'] = decoded['rd']
                self.id_ex['pc'] = self.if_id['pc']
                self.id_ex['instruction'] = self.if_id['instruction']
            
            # Fetch stage
            if self.pc // 4 < len(self.instruction_memory):
                instruction = self.instruction_memory[self.pc // 4]
                self.if_id['instruction'] = instruction
                self.if_id['pc'] = self.pc
                self.pc += 4
            
            return cycle_data
        
        def run(self, num_cycles=20):
            """Run simulation for specified number of cycles"""
            self.registers[2] = 100   # x2 = sp
            self.registers[3] = 200   # x3 = some value
            self.registers[17] = 50   # x17 = some value
            self.memory[10] = 123     # Pre-load some test data
            
            for cycle in range(num_cycles):
                cycle_data = self.simulate_cycle(cycle + 1)
                self.cycles.append(cycle_data)
            
            return self.cycles
    
    # Create and run simulation
    sim = RISCVSimulator()
    sim.load_instructions(hex_instructions)
    return sim.run()

@app.route('/about')
def about():
    return render_template('about.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)