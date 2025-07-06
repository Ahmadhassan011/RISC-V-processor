`timescale 1ns / 1ps

module testbench();
    reg clk;
    reg rst;
    
    // Instantiate the processor
    RISCV_Processor uut (
        .clk(clk),
        .rst(rst)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period = 100MHz
    end
    
    // Test sequence
    initial begin
        // Initialize
        rst = 1;
        #20;
        rst = 0;
        
        // Run simulation for multiple cycles
        #500;
        
        $finish;
    end
    
    // Monitor and output processor state
    integer cycle_count;
    initial cycle_count = 0;
    
    always @(posedge clk) begin
        if (!rst) begin
            cycle_count = cycle_count + 1;
            
            // Output cycle information in structured format
            $display("CYCLE %0d: PC=0x%08h", cycle_count, uut.pc_current);
            
            // Output register file contents
            $display("REG[0]=0x%08h REG[1]=0x%08h REG[2]=0x%08h REG[3]=0x%08h", 
                     uut.reg_file.register_bank[0], uut.reg_file.register_bank[1], 
                     uut.reg_file.register_bank[2], uut.reg_file.register_bank[3]);
            $display("REG[4]=0x%08h REG[5]=0x%08h REG[6]=0x%08h REG[7]=0x%08h", 
                     uut.reg_file.register_bank[4], uut.reg_file.register_bank[5], 
                     uut.reg_file.register_bank[6], uut.reg_file.register_bank[7]);
            $display("REG[8]=0x%08h REG[9]=0x%08h REG[10]=0x%08h REG[11]=0x%08h", 
                     uut.reg_file.register_bank[8], uut.reg_file.register_bank[9], 
                     uut.reg_file.register_bank[10], uut.reg_file.register_bank[11]);
            $display("REG[12]=0x%08h REG[13]=0x%08h REG[14]=0x%08h REG[15]=0x%08h", 
                     uut.reg_file.register_bank[12], uut.reg_file.register_bank[13], 
                     uut.reg_file.register_bank[14], uut.reg_file.register_bank[15]);
            $display("REG[16]=0x%08h REG[17]=0x%08h REG[18]=0x%08h REG[19]=0x%08h", 
                     uut.reg_file.register_bank[16], uut.reg_file.register_bank[17], 
                     uut.reg_file.register_bank[18], uut.reg_file.register_bank[19]);
            $display("REG[20]=0x%08h REG[21]=0x%08h REG[22]=0x%08h REG[23]=0x%08h", 
                     uut.reg_file.register_bank[20], uut.reg_file.register_bank[21], 
                     uut.reg_file.register_bank[22], uut.reg_file.register_bank[23]);
            $display("REG[24]=0x%08h REG[25]=0x%08h REG[26]=0x%08h REG[27]=0x%08h", 
                     uut.reg_file.register_bank[24], uut.reg_file.register_bank[25], 
                     uut.reg_file.register_bank[26], uut.reg_file.register_bank[27]);
            $display("REG[28]=0x%08h REG[29]=0x%08h REG[30]=0x%08h REG[31]=0x%08h", 
                     uut.reg_file.register_bank[28], uut.reg_file.register_bank[29], 
                     uut.reg_file.register_bank[30], uut.reg_file.register_bank[31]);
            
            // Output pipeline stage information with more details
            // IF/ID Stage
            $display("IF_ID_INSTR=0x%08h IF_ID_PC=0x%08h", uut.if_id_instr, uut.if_id_pc);
            
            // ID/EX Stage with register values
            $display("ID_EX_INSTR=0x%08h ID_EX_PC=0x%08h", uut.if_id_instr, uut.id_ex_pc);
            $display("ID_EX_RS1=0x%02h ID_EX_RS1_VAL=0x%08h", uut.id_ex_rs1, uut.id_ex_read_data1);
            $display("ID_EX_RS2=0x%02h ID_EX_RS2_VAL=0x%08h", uut.id_ex_rs2, uut.id_ex_read_data2);
            $display("ID_EX_RD=0x%02h ID_EX_IMM=0x%08h", uut.id_ex_rd, uut.id_ex_imm);
            
            // EX/MEM Stage with ALU result and destination register
            $display("EX_MEM_ALU=0x%08h EX_MEM_PC=0x%08h", uut.ex_mem_alu_result, uut.ex_mem_pc);
            $display("EX_MEM_RD=0x%02h EX_MEM_ZERO=%0d", uut.ex_mem_rd, uut.ex_mem_zero_flag);
            
            // MEM/WB Stage with result and destination register
            $display("MEM_WB_DATA=0x%08h MEM_WB_PC=0x%08h", uut.mem_wb_alu_result, uut.mem_wb_pc);
            $display("MEM_WB_RD=0x%02h", uut.mem_wb_rd);
            
            // Output control signals
            $display("CTRL_REGWRITE=%0d CTRL_MEMREAD=%0d CTRL_MEMWRITE=%0d", 
                     uut.reg_write, uut.mem_read, uut.mem_write);
            $display("CTRL_BRANCH=%0d CTRL_ALUSRC=%0d CTRL_MEMTOREG=%0d", 
                     uut.branch, uut.alu_src, uut.mem_to_reg);
            
            // Output memory contents (first 16 words)
            $display("MEM[0]=0x%08h MEM[4]=0x%08h MEM[8]=0x%08h MEM[12]=0x%08h", 
                     uut.dmem.data_memory_array[0], uut.dmem.data_memory_array[1], 
                     uut.dmem.data_memory_array[2], uut.dmem.data_memory_array[3]);
            $display("MEM[16]=0x%08h MEM[20]=0x%08h MEM[24]=0x%08h MEM[28]=0x%08h", 
                     uut.dmem.data_memory_array[4], uut.dmem.data_memory_array[5], 
                     uut.dmem.data_memory_array[6], uut.dmem.data_memory_array[7]);
            
            $display("----");
            
            // Stop after reasonable number of cycles
            if (cycle_count >= 20) begin
                $finish;
            end
        end
    end
    
endmodule
