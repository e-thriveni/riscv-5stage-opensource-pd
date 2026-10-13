`timescale 1ns / 1ps

module control_unit(
    input         reset,
    input  [6:0]  funct7,
    input  [2:0]  funct3,
    input  [6:0]  opcode,
    output reg [5:0] alu_control,
    output reg    lb,
    output reg    mem_to_reg,
    output reg    bneq_control,
    output reg    beq_control,
    output reg    bgeq_control,
    output reg    blt_control,
    output reg    sw,
    output reg    lui_control,
    output reg    reg_write,
    output reg    auipc_control,
    output reg    jalr_control,
    output reg    jal_control
);

always @(*) begin
    // Default all controls to inactive
    {lb, mem_to_reg, bneq_control, beq_control, bgeq_control,
     blt_control, sw, lui_control, reg_write, auipc_control, jal_control, jalr_control} = 12'd0;
    alu_control = 6'd0;

    if (reset) begin
        // All outputs already defaulted to 0
    end 
    else begin
        case (opcode)
            7'b0110011: begin // R-type instructions
                reg_write = 1;
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: alu_control = 6'b000001; // ADD
                    {7'b0100000, 3'b000}: alu_control = 6'b000010; // SUB
                    {7'b0000000, 3'b001}: alu_control = 6'b000011; // SLL
                    {7'b0000000, 3'b010}: alu_control = 6'b000100; // SLT
                    {7'b0000000, 3'b011}: alu_control = 6'b000101; // SLTU
                    {7'b0000000, 3'b100}: alu_control = 6'b000110; // XOR
                    {7'b0000000, 3'b101}: alu_control = 6'b000111; // SRL
                    {7'b0100000, 3'b101}: alu_control = 6'b001000; // SRA
                    {7'b0000000, 3'b110}: alu_control = 6'b001001; // OR
                    {7'b0000000, 3'b111}: alu_control = 6'b001010; // AND
                    default: alu_control = 6'b000001; // Default to ADD
                endcase
            end

            7'b0010011: begin // I-type ALU instructions
                reg_write = 1;
                case (funct3)
                    3'b000: alu_control = 6'b001011; // ADDI
                    3'b001: alu_control = 6'b001100; // SLLI
                    3'b010: alu_control = 6'b001101; // SLTI
                    3'b011: alu_control = 6'b001110; // SLTIU
                    3'b100: alu_control = 6'b001111; // XORI
                    3'b101: begin
                        if (funct7[5] == 0)
                            alu_control = 6'b010000; // SRLI
                        else
                            alu_control = 6'b010000; // SRAI (same for now)
                    end
                    3'b110: alu_control = 6'b010001; // ORI
                    3'b111: alu_control = 6'b010010; // ANDI
                    default: alu_control = 6'b001011; // Default to ADDI
                endcase
            end

            7'b0000011: begin // Load instructions
                mem_to_reg = 1;
                lb = 1;
                reg_write = 1;
                case (funct3)
                    3'b000: alu_control = 6'b010011; // LB - Fixed: was 6'b010013
        			3'b001: alu_control = 6'b010100; // LH - Fixed: was 6'b010013  
					3'b010: alu_control = 6'b010101; // LW
					3'b100: alu_control = 6'b010110; // LBU - Fixed: was 6'b010013
					3'b101: alu_control = 6'b010111; // LHU - Fixed: was 6'b010013
					default: alu_control = 6'b010101; // Default to LW
                endcase
            end

            7'b0100011: begin // Store instructions (CORRECTED OPCODE)
                sw = 1;
                case (funct3)
                    3'b000: alu_control = 6'b011000; // SB
                    3'b001: alu_control = 6'b011000; // SH (use same as SB for now)
                    3'b010: alu_control = 6'b011010; // SW
                    default: alu_control = 6'b011010; // Default to SW
                endcase
            end

            7'b1100011: begin // Branch instructions
                case (funct3)
                    3'b000: begin
                        alu_control = 6'b011011;
                        beq_control = 1;
                    end // BEQ
                    3'b001: begin
                        alu_control = 6'b011100;
                        bneq_control = 1;
                    end // BNE
                    3'b100: begin
                        alu_control = 6'b100000;
                        blt_control = 1;
                    end // BLT
                    3'b101: begin
                        alu_control = 6'b011111;
                        bgeq_control = 1;
                    end // BGE
                    3'b110: begin
                        alu_control = 6'b100000;
                        blt_control = 1;
                    end // BLTU (use same logic)
                    3'b111: begin
                        alu_control = 6'b011111;
                        bgeq_control = 1;
                    end // BGEU (use same logic)
                    default: begin
                        alu_control = 6'b011011;
                        beq_control = 1;
                    end
                endcase
            end

            7'b0110111: begin // LUI
                lui_control = 1;
                reg_write = 1;
                alu_control = 6'b100001;
            end

            7'b0010111: begin // AUIPC
                reg_write = 1;
                alu_control = 6'b001011; // Use ADDI logic (PC + immediate)
                auipc_control = 1;

            end

            7'b1101111: begin // JAL
                jal_control = 1;
                reg_write = 1;
                alu_control = 6'b100010;
            end

            7'b1100111: begin // JALR
                jalr_control = 1;
                reg_write = 1;
                alu_control = 6'b100010;
            end

            default: begin
                // NOP or unsupported instruction
                alu_control = 6'b000001; // Default to ADD
            end
        endcase
    end
end

endmodule
