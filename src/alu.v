`timescale 1ns / 1ps

module alu(
    input  [31:0] src1,
    input  [31:0] src2,
    input  [5:0]  alu_control,
    input  [31:0] imm_val_r,
    input  [3:0]  shamt,
    output reg [31:0] result
);

always @(*) begin
    case (alu_control)
        // R-type operations (register-register)
        6'b000001: result = src1 + src2;                            // ADD
        6'b000010: result = src1 - src2;                            // SUB
        6'b000011: result = src1 << src2[4:0];                      // SLL
        6'b000100: result = ($signed(src1) < $signed(src2)) ? 1 : 0; // SLT (signed)
        6'b000101: result = (src1 < src2) ? 1 : 0;                  // SLTU (unsigned)
        6'b000110: result = src1 ^ src2;                            // XOR
        6'b000111: result = src1 >> src2[4:0];                      // SRL
        6'b001000: result = $signed(src1) >>> src2[4:0];            // SRA
        6'b001001: result = src1 | src2;                            // OR
        6'b001010: result = src1 & src2;                            // AND

        // I-type immediate operations
        6'b001011: result = src1 + imm_val_r;                       // ADDI
        6'b001100: result = src1 << shamt;                          // SLLI
        6'b001101: result = ($signed(src1) < $signed(imm_val_r)) ? 1 : 0; // SLTI
        6'b001110: result = (src1 < imm_val_r) ? 1 : 0;             // SLTIU
        6'b001111: result = src1 ^ imm_val_r;                       // XORI
        6'b010000: result = src1 >> imm_val_r[4:0];                 // SRLI
        6'b010001: result = src1 | imm_val_r;                       // ORI
        6'b010010: result = src1 & imm_val_r;                       // ANDI

        // Branch comparisons
        6'b011011: result = (src1 == src2) ? 1 : 0;                 // BEQ
        6'b011100: result = (src1 != src2) ? 1 : 0;                 // BNE
        6'b011111: result = ($signed(src1) >= $signed(src2)) ? 1 : 0; // BGE
        6'b100000: result = ($signed(src1) < $signed(src2)) ? 1 : 0;  // BLT

        // Load/Store address calculation
        6'b010011: result = src1 + imm_val_r;                       // LB address
        6'b010101: result = src1 + imm_val_r;                       // LW address
        6'b011000: result = src1 + imm_val_r;                       // SB address
        6'b011010: result = src1 + imm_val_r;                       // SW address

        // Special operations
        6'b100001: result = imm_val_r;                              // LUI
        6'b100010: result = src1 + 4;                               // JAL (PC+4)

        default:   result = 32'd0;
    endcase
end

endmodule
