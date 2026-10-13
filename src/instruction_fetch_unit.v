`timescale 1ns / 1ps

module instruction_fetch_unit(
    input         clk,
    input         reset,
    input  [31:0] next_pc,
    input         pc_enable,
    output reg [31:0] pc,
    output reg [31:0] pc_plus4
);

always @(posedge clk) begin
    if (reset) begin
        pc <= 32'd0;
        pc_plus4 <= 32'd4;
    end else if (pc_enable) begin
        pc <= next_pc;
        pc_plus4 <= next_pc + 4;
    end
end

endmodule
