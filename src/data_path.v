`timescale 1ns / 1ps

module data_path(
    /* ================================
       GLOBAL / CONTROL INPUTS
       ================================ */
    input         clk,
    input         rst,

    // Destination register (not used inside datapath logic yet)
    input  [4:0]  rd,

    // Control signals affecting EX stage behavior
    input         beq_control,
    input         bne_control,
    input         bgeq_control,
    input         blt_control,
    input         mem_to_reg,

    input         auipc_control,

    input         jalr_control,
    input         jal_control,


    /* ================================
       ID/EX PIPELINE INPUTS (EX STAGE)
       ================================ */
    input [31:0] ex_pc,         // PC of instruction in EX stage
    input [31:0] ex_rs1_val,    // Value of rs1 latched in ID/EX
    input [31:0] ex_rs2_val,    // Value of rs2 latched in ID/EX
    input [31:0] ex_imm_i,      // I-type immediate latched in ID/EX
    input [31:0] ex_imm_u,      // U-type immediate latched in ID/EX
    input [31:0] ex_imm_b,      // B-type immediate latched in ID/EX
    input [31:0] ex_imm_j,      // J-type immediate latched in ID/EX
    input [31:0] ex_imm_s,      // S-type immediate latched in ID/EX
    input [5:0]  ex_alu_control,
    input        ex_reg_write,


    /* ================================
       FORWARDING CONTROL (FROM TOP)
       ================================ */
    input [1:0] forwardA,       // Forward select for rs1
    input [1:0] forwardB,       // Forward select for rs2

    /* ================================
       FORWARDING DATA SOURCES
       ================================ */
    input [31:0] ex_mem_alu_result,   // From EX/MEM stage
    input [31:0] mem_wb_write_data,   // From MEM/WB stage

    /* ================================
       MEMORY INTERFACE (COMBINATIONAL)
       ================================ */
    input  [31:0] mem_read_data_in, // Not used here (WB handles it)


    /* ================================
       OUTPUTS BACK TO TOP
       ================================ */
    output        beq,
    output        bneq,
    output        bge,
    output        blt,
    output [31:0] alu_result,
    output [31:0] next_pc,
    output [31:0] store_data,
    output [31:0] pc_plus4
);

    /* ============================================================
       BASIC PC CALCULATION (EX STAGE)
       ============================================================ */
   assign pc_plus4 = ex_pc + 32'd4;

    /* ============================================================
       MEMORY SIGNAL GENERATION
       ============================================================ */
    // Store data is always rs2 (after forwarding happens earlier)
    assign store_data =
                        forwardB == 2'b10 ? ex_mem_alu_result :
                        forwardB == 2'b01 ? mem_wb_write_data :
                                             ex_rs2_val;


   

   

    /* ============================================================
       FORWARDING: ALU SRC1 (rs1)
       ============================================================ */
    reg [31:0] alu_src1_forwarded;

    always @(*) begin
        case (forwardA)
            2'b00: alu_src1_forwarded = ex_rs1_val;        // No hazard
            2'b10: alu_src1_forwarded = ex_mem_alu_result; // From EX/MEM
            2'b01: alu_src1_forwarded = mem_wb_write_data; // From MEM/WB
            default: alu_src1_forwarded = ex_rs1_val;
        endcase
    end

    /* ============================================================
       FORWARDING: ALU SRC2 REGISTER VERSION (rs2)
       ============================================================ */
    reg [31:0] alu_src2_reg_forwarded;

    always @(*) begin
        case (forwardB)
            2'b00: alu_src2_reg_forwarded = ex_rs2_val;
            2'b10: alu_src2_reg_forwarded = ex_mem_alu_result;
            2'b01: alu_src2_reg_forwarded = mem_wb_write_data;
            default: alu_src2_reg_forwarded = ex_rs2_val;
        endcase
    end

    /* ============================================================
       ALU SRC2 FINAL MUX (REG vs IMM)
       ============================================================ */
    reg [31:0] alu_src2_mux;

    always @(*) begin
        case (ex_alu_control)
            // ALU ops that use immediate
            6'b001011, 6'b001100, 6'b001101, 6'b001110,
            6'b001111, 6'b010000, 6'b010001, 6'b010010,
            6'b010011, 6'b010101, 6'b011000, 6'b011010:
                alu_src2_mux = ex_imm_i;

            // Otherwise use register value (possibly forwarded)
            default:
                alu_src2_mux = alu_src2_reg_forwarded;
        endcase
    end

   reg [31:0] alu_src2 ;

    always @(*) begin
      if (auipc_control)
         alu_src2 = ex_imm_u;
      else
         alu_src2 = alu_src2_mux;
   end



    wire [31:0] alu_src1;

    assign alu_src1 =
      auipc_control ? ex_pc : alu_src1_forwarded;

    /* ============================================================
       JAL
       ============================================================ */
      wire [31:0] jal_target;
      assign jal_target = ex_pc + ex_imm_j;

    /* ============================================================
       JALR
       ============================================================ */
      wire [31:0] jalr_target;
      assign jalr_target = (alu_src1_forwarded + ex_imm_i) & 32'hFFFFFFFE;
    /* ============================================================
       ALU
       ============================================================ */
    alu alu_unit (
        .src1(alu_src1),
        .src2(alu_src2),
        .alu_control(ex_alu_control),
        .imm_val_r(ex_imm_i),
        .shamt(ex_imm_i[3:0]),
        .result(alu_result)
    );

    /* ============================================================
       BRANCH DECISION (USING ALU RESULT)
       ============================================================ */
    assign beq  = (alu_result == 1) & beq_control;
    assign bneq = (alu_result == 1) & bne_control;
    assign bge  = (alu_result == 1) & bgeq_control;
    assign blt  = (alu_result == 1) & blt_control;

    /* ============================================================
       NEXT PC SELECTION (EX STAGE)
       ============================================================ */
    reg [31:0] next_pc_reg;

    always @(*) begin

        if(jal_control)
            next_pc_reg = jal_target;

        else if(jalr_control)
            next_pc_reg = jalr_target;

        else if (beq | bneq | bge | blt)
            next_pc_reg = ex_pc + ex_imm_b;
        else
            next_pc_reg = pc_plus4;
    end

    assign next_pc = next_pc_reg;


endmodule
