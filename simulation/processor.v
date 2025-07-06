//
//-------------------------------------------------
//-- Basic Components
//-------------------------------------------------
//

//.........Program Counter...................................//
module program_counter(
    input wire clk,
    input wire rst,
    input wire [31:0] pc_in,
    output reg [31:0] pc_out
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            pc_out <= 32'b0;
        else
            pc_out <= pc_in;
    end
endmodule

//.................PC Adder .......................................//
module pc_adder(
    input wire [31:0] current_pc,
    output wire [31:0] next_pc_value
);
    assign next_pc_value = current_pc + 4;
endmodule

//--------------PC Mux -------
module pc_mux(
    input wire [31:0] sequential_pc,
    input wire [31:0] branch_pc,
    input wire pc_selection_signal,
    output reg [31:0] selected_pc
);
    always @(*) begin
        if (pc_selection_signal)
            selected_pc = branch_pc;
        else
            selected_pc = sequential_pc;
    end
endmodule

//..........Data Memory / ALU Mux (2x1)....................................//
module MUX2to1 (
    input wire [31:0] input_zero,
    input wire [31:0] input_one,
    input wire select_signal,
    output wire [31:0] mux_output
);
    assign mux_output = (select_signal) ? input_one : input_zero;
endmodule

//............Branch Adder......................................//
module Branch_Adder(
    input wire [31:0] current_program_counter,
    input wire [31:0] branch_offset,
    output wire [31:0] calculated_branch_target
);
    assign calculated_branch_target = current_program_counter + branch_offset;
endmodule

//
//-------------------------------------------------
//-- ALU and Control
//-------------------------------------------------
//

//......................................................................ALU .........................................//
module ALU(
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,
    input wire [3:0] alu_control_signal,
    output reg [31:0] alu_result,
    output reg zero_flag
);
    always @(*) begin
        case (alu_control_signal)
            4'b0000: alu_result = operand_a + operand_b; // ADD
            4'b0001: alu_result = operand_a - operand_b; // SUB
            4'b0010: alu_result = operand_a & operand_b; // AND
            4'b0011: alu_result = operand_a | operand_b; // OR
            4'b0100: alu_result = operand_a ^ operand_b; // XOR
            4'b0101: alu_result = operand_a << operand_b[4:0]; // SLL
            default: alu_result = 32'b0;
        endcase
    end

    always @(*) begin
        if (alu_result == 32'b0)
            zero_flag = 1'b1;
        else
            zero_flag = 1'b0;
    end
endmodule

//..............................................ALU Control...................................................//
module ALU_Control(
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input wire [1:0] alu_op,
    output reg [3:0] alu_control_output
);
    always @(*) begin
        case (alu_op)
            2'b00: alu_control_output = 4'b0000; // LW/SW -> ADD
            2'b01: alu_control_output = 4'b0001; // Branch -> SUB
            2'b10: begin // R-Type
                case ({funct7, funct3})
                    10'b0000000_000: alu_control_output = 4'b0000; // ADD
                    10'b0100000_000: alu_control_output = 4'b0001; // SUB
                    10'b0000000_111: alu_control_output = 4'b0010; // AND
                    10'b0000000_110: alu_control_output = 4'b0011; // OR
                    10'b0000000_100: alu_control_output = 4'b0100; // XOR
                    10'b0000000_001: alu_control_output = 4'b0101; // SLL
                    default:         alu_control_output = 4'bxxxx; // Should not occur
                endcase
            end
            default: alu_control_output = 4'bxxxx; // Should not occur
        endcase
    end
endmodule

//
//-------------------------------------------------
//-- Memory and Register File
//-------------------------------------------------
//

//.............register file .....................................//
module Register_File(
    input wire system_clock,
    input wire system_reset,
    input wire register_write_enable,
    input wire [4:0] source_register_1,
    input wire [4:0] source_register_2,
    input wire [4:0] destination_register,
    input wire [31:0] register_write_data,
    output wire [31:0] register_read_data_1,
    output wire [31:0] register_read_data_2
);
    reg [31:0] register_bank [0:31];
    integer i;

    // Initialize registers for testing purposes
    initial begin
        for (i = 0; i < 32; i = i + 1)
            register_bank[i] = i + 10; // Simple initialization
        register_bank[0] = 0;
    end

    always @(posedge system_clock) begin
        if (system_reset) begin
            for (i = 0; i < 32; i = i + 1)
                register_bank[i] <= 32'b0;
        end else if (register_write_enable && (destination_register != 5'b0)) begin
            register_bank[destination_register] <= register_write_data;
        end
    end

    assign register_read_data_1 = (source_register_1 == 5'b0) ? 32'b0 : register_bank[source_register_1];
    assign register_read_data_2 = (source_register_2 == 5'b0) ? 32'b0 : register_bank[source_register_2];
endmodule

//................instructionmemory .................................................//
module Instruction_Memory(
    input wire reset_input,
    input wire clock_input,
    input wire [31:0] instruction_address,
    output wire [31:0] fetched_instruction
);
    reg [31:0] instruction_memory_array [0:63];
    integer i;

    // Initialize instruction memory from file
    initial begin
        // Initialize with NOPs first
        for (i = 0; i < 64; i = i + 1)
            instruction_memory_array[i] = 32'h00000013; // NOP
        
        // Load instructions from file if it exists
        if ($test$plusargs("INSTRUCTION_FILE")) begin
            $readmemh("simulation/instructions.hex", instruction_memory_array);
        end else begin
            // Default test instructions
            instruction_memory_array[0] = 32'h00C88693; // addi x13, x17, 12
            instruction_memory_array[1] = 32'h003102B3; // add x5, x2, x3
            instruction_memory_array[2] = 32'h0042A213; // slti x4, x5, 4
            instruction_memory_array[3] = 32'h0064C383; // lw x7, 6(x9)
            instruction_memory_array[4] = 32'h00B52C23; // sw x11, 8(x10)
            instruction_memory_array[5] = 32'hFE842AE3; // beq x8, x8, -32 (using x8 for demo)
        end
    end

    assign fetched_instruction = instruction_memory_array[instruction_address[7:2]];
endmodule

//...............................datamemory..................................................//
module Data_Memory(
    input wire memory_clock,
    input wire memory_reset,
    input wire memory_read_enable,
    input wire memory_write_enable,
    input wire [31:0] memory_address,
    input wire [31:0] data_to_write,
    output wire [31:0] data_read_from_memory
);
    reg [31:0] data_memory_array [0:63];
    integer i;

    initial begin
        for (i = 0; i < 64; i = i + 1) begin
            data_memory_array[i] = 0;
        end
        // Pre-load some memory for testing lw
        data_memory_array[10] = 32'd123;
    end

    always @(posedge memory_clock) begin
        if (memory_write_enable) begin
            data_memory_array[memory_address[7:2]] <= data_to_write;
        end
    end

    assign data_read_from_memory = (memory_read_enable) ? data_memory_array[memory_address[7:2]] : 32'b0;
endmodule

//
//-------------------------------------------------
//-- Control and Immediate Generator
//-------------------------------------------------
//

//......................controlunit..................................................//
module main_control_unit(
    input wire [6:0] instruction_opcode,
    output reg register_write_signal,
    output reg memory_read_signal,
    output reg memory_write_signal,
    output reg memory_to_register_signal,
    output reg alu_source_signal,
    output reg branch_signal,
    output reg [1:0] alu_operation_signal
);
    always @(*) begin
        // Set default values to avoid latches
        {register_write_signal, memory_read_signal, memory_write_signal, memory_to_register_signal, alu_source_signal, branch_signal, alu_operation_signal} = 9'b0;

        case (instruction_opcode)
            7'b0110011:  // R-type
                {register_write_signal, memory_read_signal, memory_write_signal, memory_to_register_signal, alu_source_signal, branch_signal, alu_operation_signal} = {1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b10};
            7'b0010011:  // I-type (ALU immediate)
                {register_write_signal, memory_read_signal, memory_write_signal, memory_to_register_signal, alu_source_signal, branch_signal, alu_operation_signal} = {1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 2'b10}; // Note: Corrected ALUOp for I-type
            7'b0000011:  // Load
                {register_write_signal, memory_read_signal, memory_write_signal, memory_to_register_signal, alu_source_signal, branch_signal, alu_operation_signal} = {1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 2'b00};
            7'b0100011:  // Store
                {register_write_signal, memory_read_signal, memory_write_signal, memory_to_register_signal, alu_source_signal, branch_signal, alu_operation_signal} = {1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 2'b00};
            7'b1100011:  // Branch
                {register_write_signal, memory_read_signal, memory_write_signal, memory_to_register_signal, alu_source_signal, branch_signal, alu_operation_signal} = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b01};
            default:
                {register_write_signal, memory_read_signal, memory_write_signal, memory_to_register_signal, alu_source_signal, branch_signal, alu_operation_signal} = 9'b0;
        endcase
    end
endmodule

// ......................................immediate generator ..................................... //
module immediate_generator(
    input wire [31:0] current_instruction,
    output reg [31:0] immediate_value_output
);
    always @(*) begin
        case (current_instruction[6:0])
            7'b0010011, // I-type
            7'b0000011:  // Load-type
                immediate_value_output = {{20{current_instruction[31]}}, current_instruction[31:20]};
            7'b0100011:  // Store-type
                immediate_value_output = {{20{current_instruction[31]}}, current_instruction[31:25], current_instruction[11:7]};
            7'b1100011:  // B-type
                immediate_value_output = {{19{current_instruction[31]}}, current_instruction[7], current_instruction[30:25], current_instruction[11:8], 1'b0};
            default:
                immediate_value_output = 32'b0;
        endcase
    end
endmodule

//
//-------------------------------------------------
//-- Pipeline Registers
//-------------------------------------------------
//

//.............................................IF/ID Register......................................//
module IF_ID_Reg(
    input wire clk,
    input wire rst,
    input wire stall, // Stall signal from Hazard Unit
    input wire [31:0] pc_in,
    input wire [31:0] instr_in,
    output reg [31:0] pc_out,
    output reg [31:0] instr_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out <= 32'b0;
            instr_out <= 32'h00000013; // NOP
        end else if (!stall) begin // Only write if not stalled
            pc_out <= pc_in;
            instr_out <= instr_in;
        end
    end
endmodule

//.........................................ID/EX Register....................................//
module ID_EX_Reg(
    input wire clk,
    input wire rst,
    input wire flush, // Flush signal from Hazard Unit

    // Control Signals
    input wire RegWrite_in, MemRead_in, MemWrite_in, MemtoReg_in, ALUSrc_in, Branch_in,
    input wire [1:0] ALUOp_in,

    // Data Signals
    input wire [31:0] pc_in, read_data1_in, read_data2_in, imm_in,
    input wire [4:0] rs1_in, rs2_in, rd_in,
    input wire [2:0] funct3_in,
    input wire [6:0] funct7_in,

    // Outputs
    output reg RegWrite_out, MemRead_out, MemWrite_out, MemtoReg_out, ALUSrc_out, Branch_out,
    output reg [1:0] ALUOp_out,
    output reg [31:0] pc_out, read_data1_out, read_data2_out, imm_out,
    output reg [4:0] rs1_out, rs2_out, rd_out,
    output reg [2:0] funct3_out,
    output reg [6:0] funct7_out
);
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            // Clear all control signals
            {RegWrite_out, MemRead_out, MemWrite_out, MemtoReg_out, ALUSrc_out, Branch_out, ALUOp_out} <= 9'b0;
            {pc_out, read_data1_out, read_data2_out, imm_out} <= 128'b0;
            {rs1_out, rs2_out, rd_out} <= 15'b0;
            {funct3_out, funct7_out} <= 10'b0;
        end else begin
            // Transfer all signals
            {RegWrite_out, MemRead_out, MemWrite_out, MemtoReg_out, ALUSrc_out, Branch_out, ALUOp_out} 
                <= {RegWrite_in, MemRead_in, MemWrite_in, MemtoReg_in, ALUSrc_in, Branch_in, ALUOp_in};
            {pc_out, read_data1_out, read_data2_out, imm_out} 
                <= {pc_in, read_data1_in, read_data2_in, imm_in};
            {rs1_out, rs2_out, rd_out} <= {rs1_in, rs2_in, rd_in};
            {funct3_out, funct7_out} <= {funct3_in, funct7_in};
        end
    end
endmodule

//........................................EX/MEM Register....................................//
module EX_MEM_Reg(
    input wire clk,
    input wire rst,

    // Control Signals
    input wire RegWrite_in, MemRead_in, MemWrite_in, MemtoReg_in, Branch_in,

    // Data Signals
    input wire [31:0] pc_in, alu_result_in, read_data2_in, branch_target_in,
    input wire [4:0] rd_in,
    input wire zero_flag_in,

    // Outputs
    output reg RegWrite_out, MemRead_out, MemWrite_out, MemtoReg_out, Branch_out,
    output reg [31:0] pc_out, alu_result_out, read_data2_out, branch_target_out,
    output reg [4:0] rd_out,
    output reg zero_flag_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            {RegWrite_out, MemRead_out, MemWrite_out, MemtoReg_out, Branch_out} <= 5'b0;
            {pc_out, alu_result_out, read_data2_out, branch_target_out} <= 128'b0;
            rd_out <= 5'b0;
            zero_flag_out <= 1'b0;
        end else begin
            {RegWrite_out, MemRead_out, MemWrite_out, MemtoReg_out, Branch_out} 
                <= {RegWrite_in, MemRead_in, MemWrite_in, MemtoReg_in, Branch_in};
            {pc_out, alu_result_out, read_data2_out, branch_target_out} 
                <= {pc_in, alu_result_in, read_data2_in, branch_target_in};
            rd_out <= rd_in;
            zero_flag_out <= zero_flag_in;
        end
    end
endmodule

//........................................MEM/WB Register....................................//
module MEM_WB_Reg(
    input wire clk,
    input wire rst,

    // Control Signals
    input wire RegWrite_in, MemtoReg_in,

    // Data Signals
    input wire [31:0] pc_in, alu_result_in, mem_data_in,
    input wire [4:0] rd_in,

    // Outputs
    output reg RegWrite_out, MemtoReg_out,
    output reg [31:0] pc_out, alu_result_out, mem_data_out,
    output reg [4:0] rd_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            {RegWrite_out, MemtoReg_out} <= 2'b0;
            {pc_out, alu_result_out, mem_data_out} <= 96'b0;
            rd_out <= 5'b0;
        end else begin
            {RegWrite_out, MemtoReg_out} <= {RegWrite_in, MemtoReg_in};
            {pc_out, alu_result_out, mem_data_out} <= {pc_in, alu_result_in, mem_data_in};
            rd_out <= rd_in;
        end
    end
endmodule

//
//-------------------------------------------------
//-- Top Level RISC-V Processor
//-------------------------------------------------
//

module RISCV_Processor(
    input wire clk,
    input wire rst
);
    // Pipeline stage connections
    wire [31:0] pc_current, pc_next, pc_plus4, branch_target;
    wire [31:0] instruction;
    wire pc_src;

    // IF/ID signals
    wire [31:0] if_id_pc, if_id_instr;

    // Control signals
    wire reg_write, mem_read, mem_write, mem_to_reg, alu_src, branch;
    wire [1:0] alu_op;

    // Register file signals
    wire [31:0] read_data1, read_data2, write_data;
    wire [4:0] rs1, rs2, rd;

    // Immediate and ALU signals
    wire [31:0] immediate;
    wire [31:0] alu_input_b, alu_result;
    wire [3:0] alu_control;
    wire zero_flag;

    // ID/EX signals
    wire id_ex_reg_write, id_ex_mem_read, id_ex_mem_write, id_ex_mem_to_reg, id_ex_alu_src, id_ex_branch;
    wire [1:0] id_ex_alu_op;
    wire [31:0] id_ex_pc, id_ex_read_data1, id_ex_read_data2, id_ex_imm;
    wire [4:0] id_ex_rs1, id_ex_rs2, id_ex_rd;
    wire [2:0] id_ex_funct3;
    wire [6:0] id_ex_funct7;

    // EX/MEM signals
    wire ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write, ex_mem_mem_to_reg, ex_mem_branch;
    wire [31:0] ex_mem_pc, ex_mem_alu_result, ex_mem_read_data2, ex_mem_branch_target;
    wire [4:0] ex_mem_rd;
    wire ex_mem_zero_flag;

    // MEM/WB signals
    wire mem_wb_reg_write, mem_wb_mem_to_reg;
    wire [31:0] mem_wb_pc, mem_wb_alu_result, mem_wb_mem_data;
    wire [4:0] mem_wb_rd;

    // Memory data
    wire [31:0] mem_data;

    // Instruction fetch stage
    program_counter pc_reg(.clk(clk), .rst(rst), .pc_in(pc_next), .pc_out(pc_current));
    pc_adder pc_add(.current_pc(pc_current), .next_pc_value(pc_plus4));
    Instruction_Memory imem(.reset_input(rst), .clock_input(clk), .instruction_address(pc_current), .fetched_instruction(instruction));
    pc_mux pc_mux_inst(.sequential_pc(pc_plus4), .branch_pc(ex_mem_branch_target), .pc_selection_signal(pc_src), .selected_pc(pc_next));

    // IF/ID pipeline register
    IF_ID_Reg if_id_reg(.clk(clk), .rst(rst), .stall(1'b0), .pc_in(pc_current), .instr_in(instruction), .pc_out(if_id_pc), .instr_out(if_id_instr));

    // Instruction decode
    assign rs1 = if_id_instr[19:15];
    assign rs2 = if_id_instr[24:20];
    assign rd = if_id_instr[11:7];

    main_control_unit control(.instruction_opcode(if_id_instr[6:0]), .register_write_signal(reg_write), .memory_read_signal(mem_read), .memory_write_signal(mem_write), .memory_to_register_signal(mem_to_reg), .alu_source_signal(alu_src), .branch_signal(branch), .alu_operation_signal(alu_op));
    Register_File reg_file(.system_clock(clk), .system_reset(rst), .register_write_enable(mem_wb_reg_write), .source_register_1(rs1), .source_register_2(rs2), .destination_register(mem_wb_rd), .register_write_data(write_data), .register_read_data_1(read_data1), .register_read_data_2(read_data2));
    immediate_generator imm_gen(.current_instruction(if_id_instr), .immediate_value_output(immediate));

    // ID/EX pipeline register
    ID_EX_Reg id_ex_reg(.clk(clk), .rst(rst), .flush(1'b0), .RegWrite_in(reg_write), .MemRead_in(mem_read), .MemWrite_in(mem_write), .MemtoReg_in(mem_to_reg), .ALUSrc_in(alu_src), .Branch_in(branch), .ALUOp_in(alu_op), .pc_in(if_id_pc), .read_data1_in(read_data1), .read_data2_in(read_data2), .imm_in(immediate), .rs1_in(rs1), .rs2_in(rs2), .rd_in(rd), .funct3_in(if_id_instr[14:12]), .funct7_in(if_id_instr[31:25]), .RegWrite_out(id_ex_reg_write), .MemRead_out(id_ex_mem_read), .MemWrite_out(id_ex_mem_write), .MemtoReg_out(id_ex_mem_to_reg), .ALUSrc_out(id_ex_alu_src), .Branch_out(id_ex_branch), .ALUOp_out(id_ex_alu_op), .pc_out(id_ex_pc), .read_data1_out(id_ex_read_data1), .read_data2_out(id_ex_read_data2), .imm_out(id_ex_imm), .rs1_out(id_ex_rs1), .rs2_out(id_ex_rs2), .rd_out(id_ex_rd), .funct3_out(id_ex_funct3), .funct7_out(id_ex_funct7));

    // Execute stage
    MUX2to1 alu_src_mux(.input_zero(id_ex_read_data2), .input_one(id_ex_imm), .select_signal(id_ex_alu_src), .mux_output(alu_input_b));
    ALU_Control alu_ctrl(.funct3(id_ex_funct3), .funct7(id_ex_funct7), .alu_op(id_ex_alu_op), .alu_control_output(alu_control));
    ALU alu_inst(.operand_a(id_ex_read_data1), .operand_b(alu_input_b), .alu_control_signal(alu_control), .alu_result(alu_result), .zero_flag(zero_flag));
    Branch_Adder branch_adder(.current_program_counter(id_ex_pc), .branch_offset(id_ex_imm), .calculated_branch_target(branch_target));

    // EX/MEM pipeline register
    EX_MEM_Reg ex_mem_reg(.clk(clk), .rst(rst), .RegWrite_in(id_ex_reg_write), .MemRead_in(id_ex_mem_read), .MemWrite_in(id_ex_mem_write), .MemtoReg_in(id_ex_mem_to_reg), .Branch_in(id_ex_branch), .pc_in(id_ex_pc), .alu_result_in(alu_result), .read_data2_in(id_ex_read_data2), .branch_target_in(branch_target), .rd_in(id_ex_rd), .zero_flag_in(zero_flag), .RegWrite_out(ex_mem_reg_write), .MemRead_out(ex_mem_mem_read), .MemWrite_out(ex_mem_mem_write), .MemtoReg_out(ex_mem_mem_to_reg), .Branch_out(ex_mem_branch), .pc_out(ex_mem_pc), .alu_result_out(ex_mem_alu_result), .read_data2_out(ex_mem_read_data2), .branch_target_out(ex_mem_branch_target), .rd_out(ex_mem_rd), .zero_flag_out(ex_mem_zero_flag));

    // Memory stage
    Data_Memory dmem(.memory_clock(clk), .memory_reset(rst), .memory_read_enable(ex_mem_mem_read), .memory_write_enable(ex_mem_mem_write), .memory_address(ex_mem_alu_result), .data_to_write(ex_mem_read_data2), .data_read_from_memory(mem_data));
    assign pc_src = ex_mem_branch & ex_mem_zero_flag;

    // MEM/WB pipeline register
    MEM_WB_Reg mem_wb_reg(.clk(clk), .rst(rst), .RegWrite_in(ex_mem_reg_write), .MemtoReg_in(ex_mem_mem_to_reg), .pc_in(ex_mem_pc), .alu_result_in(ex_mem_alu_result), .mem_data_in(mem_data), .rd_in(ex_mem_rd), .RegWrite_out(mem_wb_reg_write), .MemtoReg_out(mem_wb_mem_to_reg), .pc_out(mem_wb_pc), .alu_result_out(mem_wb_alu_result), .mem_data_out(mem_wb_mem_data), .rd_out(mem_wb_rd));

    // Write back stage
    MUX2to1 wb_mux(.input_zero(mem_wb_alu_result), .input_one(mem_wb_mem_data), .select_signal(mem_wb_mem_to_reg), .mux_output(write_data));

endmodule
