`timescale 1ns / 1ps

module top_riscv(
    input clk,
    input reset,

    // ================= MEMORY INTERFACE =================
    output [31:0] mem_address,
    output [31:0] mem_write_data,
    output        mem_write_enable,
    output        mem_read_enable,
    input  [31:0] mem_read_data_in,

    // ================= DEBUG / OBSERVABILITY =================
    output [31:0] current_pc,
    output [31:0] instruction,
    output [4:0]  rs1, rs2, rd,
    output [6:0]  funct7, opcode,
    output [2:0]  funct3,
    output [31:0] imm_i, imm_s, imm_b, imm_u, imm_j,
    output [31:0] alu_result,
    output [31:0] write_back_data,
    output [31:0] store_data,
    output [31:0] next_pc,
    output        beq, bneq, bge, blt,
	 output [1:0] forwardA_debug, forwardB_debug,
	 output 		  load_use_hazard_debug
);

// =====================================================
    // ID / EX PIPELINE REGISTER
    // =====================================================
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_rs1_val;
    reg [31:0] id_ex_rs2_val;
    reg [31:0] id_ex_imm_i;
    reg [31:0] id_ex_imm_u;
    reg [31:0] id_ex_imm_b;
    reg [31:0] id_ex_imm_j;
    reg [31:0] id_ex_imm_s;


    reg [5:0]  id_ex_alu_control;
    reg        id_ex_reg_write;
    reg [4:0]  id_ex_rd;
    reg        id_ex_mem_read;
    reg        id_ex_mem_write;
    reg        id_ex_mem_to_reg;
    reg        id_ex_auipc;
    reg        id_ex_jalr;

    

    reg id_ex_jal;
    
    reg id_ex_lui;




    reg [4:0] id_ex_rs1;
    reg [4:0] id_ex_rs2;


    // =====================================================
    // EX / MEM PIPELINE REGISTER
    // =====================================================
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_store_data;
    reg [4:0]  ex_mem_rd;
    reg [31:0] ex_mem_imm_u;
    reg        ex_mem_mem_to_reg;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;
    reg        ex_mem_reg_write;

    reg [31:0] ex_mem_pc_plus4;

    reg ex_mem_jal;
    reg ex_mem_jalr;
    reg ex_mem_lui;





    // =====================================================
    // MEM / WB PIPELINE REGISTER
    // =====================================================
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [4:0]  mem_wb_rd;
    reg [31:0] mem_wb_imm_u;
    reg        mem_wb_mem_to_reg;
    reg        mem_wb_reg_write;

    reg [31:0] mem_wb_pc_plus4;

    reg mem_wb_jal;
    reg mem_wb_jalr;
    reg mem_wb_lui;


    assign mem_address      = ex_mem_alu_result;
    assign mem_write_data   = ex_mem_store_data;
    assign mem_write_enable = ex_mem_mem_write;
    assign mem_read_enable  = ex_mem_mem_read;

    


    // Write-back data bus (MEM/WB → Register File)
    wire [31:0] wb_write_data;

    // =======================
    // Control unit wires
    // =======================
    wire [5:0] alu_control;
    wire lb, mem_to_reg, bneq_control, beq_control, bgeq_control, blt_control;
    wire sw, lui_control, reg_write;
    wire auipc_control;
    wire jalr_control;
    wire jal_control;

    wire [31:0] pc_plus4; 
	 
	 wire load_use_hazard;
	 
	 wire branch_taken;


    

    // =====================================================
    // IF STAGE : PROGRAM COUNTER
    // =====================================================
    reg [31:0] pc;
    assign current_pc = pc;

    // PC update with stall support
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc <= 32'd0;
        else if (load_use_hazard)
            pc <= pc;          // stall
        else
            pc <= next_pc;     // normal
    end

    // =====================================================
    // INSTRUCTION FETCH
    // =====================================================
    instruction_memory imem (
        .clk(clk),
        .pc(pc),
        .reset(reset),
        .instruction_code(instruction)
    );

    // =====================================================
    // IF / ID PIPELINE REGISTER
    // Holds fetched instruction and PC for decode stage
    // =====================================================
    reg [31:0] instruction_code;
    reg [31:0] pc_decode;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            instruction_code <= 32'd0;
            pc_decode        <= 32'd0;
        end
        else if (branch_taken) begin
            // flush wrong-path instruction
            instruction_code <= 32'd0;
            pc_decode        <= 32'd0;
        end
        else if (load_use_hazard) begin
            // stall IF/ID
            instruction_code <= instruction_code;
            pc_decode        <= pc_decode;
        end
        else begin
            instruction_code <= instruction;
            pc_decode        <= pc;
        end
    end

    // =====================================================
    // ID STAGE : DECODE
    // =====================================================
    assign opcode = instruction_code[6:0];
    assign rd     = instruction_code[11:7];
    assign funct3 = instruction_code[14:12];
    assign rs1    = instruction_code[19:15];
    assign rs2    = instruction_code[24:20];
    assign funct7 = instruction_code[31:25];

    // =====================================================
    // IMMEDIATE GENERATION
    // =====================================================
    assign imm_i = {{20{instruction_code[31]}}, instruction_code[31:20]};
    assign imm_s = {{20{instruction_code[31]}}, instruction_code[31:25], instruction_code[11:7]};
    assign imm_b = {{19{instruction_code[31]}}, instruction_code[31], instruction_code[7],
                    instruction_code[30:25], instruction_code[11:8], 1'b0};
    assign imm_u = {instruction_code[31:12], 12'b0};
    assign imm_j = {{11{instruction_code[31]}}, instruction_code[31],
                    instruction_code[19:12], instruction_code[20],
                    instruction_code[30:21], 1'b0};

    // =====================================================
    // REGISTER FILE
    // =====================================================
    wire [31:0] reg_data1, reg_data2;

    register_file rf(
    .clk(clk),
    .rst(reset),

    .read_reg_num1(rs1),
    .read_reg_num2(rs2),

    .write_reg_num(mem_wb_rd),
    .write_data(wb_write_data),
    .reg_write(mem_wb_reg_write),

    .read_data1(reg_data1),
    .read_data2(reg_data2)

);



    control_unit cu (
        .reset(reset),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .alu_control(alu_control),
        .lb(lb),
        .mem_to_reg(mem_to_reg),
        .sw(sw),
        .lui_control(lui_control),
        .reg_write(reg_write),
        .beq_control(beq_control),
        .bneq_control(bneq_control),
        .bgeq_control(bgeq_control),
        .blt_control(blt_control),
        .auipc_control(auipc_control),
        .jalr_control(jalr_control),
        .jal_control(jal_control)
    );

  // =====================================================
    // ID / EX PIPELINE
    // =====================================================

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // bubble
            id_ex_pc          <= 0;
            id_ex_rs1_val     <= 0;
            id_ex_rs2_val     <= 0;
            id_ex_imm_i       <= 0;
            id_ex_imm_u       <= 0;
            id_ex_imm_b       <= 0;
            id_ex_imm_j       <= 0;

            id_ex_alu_control <= 0;
            id_ex_reg_write   <= 0;
            id_ex_rd          <= 0;
            id_ex_mem_read    <= 0;
            id_ex_mem_write   <= 0;
            id_ex_mem_to_reg  <= 0;
            id_ex_rs1 <= 0;
            id_ex_rs2 <= 0;
            id_ex_auipc <= 1'b0;
            id_ex_jalr <= 1'b0;
            id_ex_jal  <= 0;

            id_ex_lui  <= 0;
        end 
		  else if (branch_taken || load_use_hazard) begin
            // bubble
            id_ex_pc          <= 0;
            id_ex_rs1_val     <= 0;
            id_ex_rs2_val     <= 0;
            id_ex_imm_i       <= 0;
            id_ex_imm_u       <= 0;
            id_ex_imm_b       <= 0;
            id_ex_imm_j       <= 0;

            id_ex_alu_control <= 0;
            id_ex_reg_write   <= 0;
            id_ex_rd          <= 0;
            id_ex_mem_read    <= 0;
            id_ex_mem_write   <= 0;
            id_ex_mem_to_reg  <= 0;
            id_ex_rs1 <= 0;
            id_ex_rs2 <= 0;
            id_ex_auipc <= 1'b0;
            id_ex_jalr <= 1'b0;
            id_ex_jal  <= 0;

            id_ex_lui  <= 0;
        end else begin
            id_ex_pc          <= pc_decode;
            id_ex_rs1_val     <= reg_data1;
            id_ex_rs2_val     <= reg_data2;
            id_ex_imm_i       <= imm_i;
            id_ex_imm_u       <= imm_u;
            id_ex_imm_s       <= imm_s;

            id_ex_imm_b <= imm_b;
            id_ex_imm_j <= imm_j;

            id_ex_alu_control <= alu_control;
            id_ex_reg_write   <= reg_write;
            id_ex_rd          <= rd;
            id_ex_mem_read    <= lb;
            id_ex_mem_write   <= sw;
            id_ex_mem_to_reg  <= mem_to_reg;
            id_ex_rs1 <= rs1;
            id_ex_rs2 <= rs2;
            id_ex_auipc <= auipc_control;
            id_ex_jalr <= jalr_control;

            id_ex_jal  <= jal_control;

            id_ex_lui  <= lui_control;

        end
    end

    // =====================================================
    // FORWARDING UNIT
    // =====================================================
    reg [1:0] forwardA, forwardB;

    always @(*) begin
        forwardA = 2'b00;
        if (ex_mem_reg_write && ex_mem_rd != 0 && ex_mem_rd == id_ex_rs1)
            forwardA = 2'b10;
        else if (mem_wb_reg_write && mem_wb_rd != 0 && mem_wb_rd == id_ex_rs1)
            forwardA = 2'b01;
    end

    always @(*) begin
        forwardB = 2'b00;
        if (ex_mem_reg_write && ex_mem_rd != 0 && ex_mem_rd == id_ex_rs2)
            forwardB = 2'b10;
        else if (mem_wb_reg_write && mem_wb_rd != 0 && mem_wb_rd == id_ex_rs2)
            forwardB = 2'b01;
    end

    // =====================================================
    // LOAD-USE HAZARD DETECTION
    // =====================================================
    
    assign load_use_hazard =
        id_ex_mem_read &&
        ((id_ex_rd == rs1) || (id_ex_rd == rs2)) &&
        (id_ex_rd != 0);

    // =====================================================
    // EX STAGE (DATAPATH)
    // =====================================================
    data_path dp(
        .clk(clk),
        .rst(reset),

        .rd(id_ex_rd),

        .beq_control(beq_control),
        .bne_control(bneq_control),
        .bgeq_control(bgeq_control),
        .blt_control(blt_control),

        .mem_to_reg(id_ex_mem_to_reg),

        .auipc_control(id_ex_auipc),

        .jalr_control(id_ex_jalr),
        .jal_control(id_ex_jal),


        .ex_pc(id_ex_pc),
        .ex_rs1_val(id_ex_rs1_val),
        .ex_rs2_val(id_ex_rs2_val),
        .ex_imm_i(id_ex_imm_i),
        .ex_imm_u(id_ex_imm_u),
        .ex_imm_b(id_ex_imm_b),
        .ex_imm_j(id_ex_imm_j),
        .ex_imm_s(id_ex_imm_s),


        .ex_alu_control(id_ex_alu_control),
        .ex_reg_write(id_ex_reg_write),

        .forwardA(forwardA),
        .forwardB(forwardB),

        .ex_mem_alu_result(ex_mem_alu_result),
        .mem_wb_write_data(wb_write_data),

        .mem_read_data_in(mem_read_data_in),


        .beq(beq),
        .bneq(bneq),
        .bge(bge),
        .blt(blt),
        .alu_result(alu_result),
        .next_pc(next_pc),
        .store_data(store_data),
        .pc_plus4(pc_plus4)
    );

    // =====================================================
    // EX / MEM PIPELINE REGISTER
    // =====================================================
   
    always @(posedge clk or posedge reset) begin
        if (reset ) begin
            // FLUSH EX/MEM ON BRANCH
            ex_mem_alu_result <= 0;
            ex_mem_store_data <= 0;
            ex_mem_rd         <= 0;
            ex_mem_mem_to_reg <= 0;
            ex_mem_mem_read   <= 0;
            ex_mem_mem_write  <= 0;
            ex_mem_reg_write  <= 0;
            ex_mem_pc_plus4   <= 0;
            ex_mem_jal        <= 0;
            ex_mem_jalr       <= 0;
            ex_mem_lui        <= 0;
            ex_mem_imm_u      <= 0;
        end 
		  else if (branch_taken) begin
            // FLUSH EX/MEM ON BRANCH
            ex_mem_alu_result <= 0;
            ex_mem_store_data <= 0;
            ex_mem_rd         <= 0;
            ex_mem_mem_to_reg <= 0;
            ex_mem_mem_read   <= 0;
            ex_mem_mem_write  <= 0;
            ex_mem_reg_write  <= 0;
            ex_mem_pc_plus4   <= 0;
            ex_mem_jal        <= 0;
            ex_mem_jalr       <= 0;
            ex_mem_lui        <= 0;
            ex_mem_imm_u      <= 0;
        end else begin
            ex_mem_alu_result <= alu_result;
            ex_mem_store_data <= store_data;
            ex_mem_rd         <= id_ex_rd;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;
            ex_mem_mem_read   <= id_ex_mem_read;
            ex_mem_mem_write  <= id_ex_mem_write;
            ex_mem_reg_write  <= id_ex_reg_write;
            ex_mem_pc_plus4 <= pc_plus4;
            ex_mem_jal  <= id_ex_jal;
            ex_mem_jalr <= id_ex_jalr;
            ex_mem_lui  <= id_ex_lui;
            ex_mem_imm_u <= id_ex_imm_u;

        end
    end


    // =====================================================
    // MEM / WB PIPELINE REGISTER
    // =====================================================
    

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_wb_alu_result <= 0;
            mem_wb_mem_data   <= 0;
            mem_wb_rd         <= 0;
            mem_wb_mem_to_reg <= 0;
            mem_wb_reg_write  <= 0;
            mem_wb_pc_plus4   <= 0;
            mem_wb_jal        <=0;
            mem_wb_jalr       <= 0;
            mem_wb_lui        <= 0;
            mem_wb_imm_u      <= 0;

        end else begin
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data   <= mem_read_data_in;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
            mem_wb_reg_write  <= ex_mem_reg_write;
            mem_wb_pc_plus4   <= ex_mem_pc_plus4;
            mem_wb_jal  <= ex_mem_jal;
            mem_wb_jalr <= ex_mem_jalr;
            mem_wb_lui  <= ex_mem_lui;
            mem_wb_imm_u  <= ex_mem_imm_u;

        end
    end

    // =====================================================
    // WRITE BACK
    // =====================================================
    assign wb_write_data =
                            (mem_wb_jal || mem_wb_jalr) ? mem_wb_pc_plus4 :
                            mem_wb_lui                 ? mem_wb_imm_u :
                            mem_wb_mem_to_reg          ? mem_wb_mem_data :
                                                        mem_wb_alu_result;

    assign write_back_data = wb_write_data;

    // =====================================================
    // BRANCH TAKEN
    // =====================================================
    
    assign branch_taken = jal_control | jalr_control | beq | bneq | bge | blt;
	 
	 assign forwardA_debug = forwardA; //For debug
	 assign forwardB_debug = forwardB; //For debug
	 assign load_use_hazard_debug = load_use_hazard; //For debug

endmodule
