`timescale 1ns / 1ps

module instruction_memory(
    input  wire        clk,
    input  wire [31:0] pc,
    input  wire        reset,
    output wire [31:0] instruction_code
);

    // Instruction ROM - 1024 bytes (256 instructions)
    reg [7:0] memory [0:1023];
    
    // Word-aligned access check
    wire [31:0] word_addr = {pc[31:2], 2'b00}; // Force word alignment
    
    // Combinational read - little endian assembly
    assign instruction_code = (word_addr < 1021) ? 
        {memory[word_addr+3], memory[word_addr+2], memory[word_addr+1], memory[word_addr]} : 
        32'h00000013; // NOP instruction

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            // Initialize all memory to NOP instructions (ADDI x0, x0, 0)
            for (i = 0; i < 1024; i = i + 1) begin
                memory[i] <= 8'h00;
            end
            
            // Load sample program
            // ADDI x1, x0, 10      -> 0x00a00093
            memory[0] <= 8'h93; memory[1] <= 8'h00; memory[2] <= 8'ha0; memory[3] <= 8'h00;
            
            // ADDI x2, x0, 20      -> 0x01400113
            memory[4] <= 8'h13; memory[5] <= 8'h01; memory[6] <= 8'h40; memory[7] <= 8'h01;
            
            // ADD x3, x1, x2       -> 0x002081b3
            memory[8] <= 8'hb3; memory[9] <= 8'h81; memory[10] <= 8'h20; memory[11] <= 8'h00;
            
            // SW x3, 0(x0)         -> 0x00302023
            memory[12] <= 8'h23; memory[13] <= 8'h20; memory[14] <= 8'h30; memory[15] <= 8'h00;
            
            // LW x4, 0(x0)         -> 0x00002203
            memory[16] <= 8'h03; memory[17] <= 8'h22; memory[18] <= 8'h00; memory[19] <= 8'h00;
            
            // BEQ x3, x4, 8        -> 0x00418463
            memory[20] <= 8'h63; memory[21] <= 8'h84; memory[22] <= 8'h41; memory[23] <= 8'h00;
            
            // JAL x0, 0 (infinite loop) -> 0x0000006f
            memory[24] <= 8'h6f; memory[25] <= 8'h00; memory[26] <= 8'h00; memory[27] <= 8'h00;
        end
    end

endmodule
