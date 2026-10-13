`timescale 1ns / 1ps

module register_file(
    input         clk,
    input         rst,
    input  [4:0]  read_reg_num1,    // rs1
    input  [4:0]  read_reg_num2,    // rs2
    input  [4:0]  write_reg_num,    // rd
    input  [31:0] write_data,       // Data to write
    input         reg_write,        // Write enable

    output [31:0] read_data1,       // rs1 output
    output [31:0] read_data2       // rs2 output

);

    // 32 registers of 32 bits each
    reg [31:0] registers [31:0];
    integer i;

    // Combinational read - register 0 is always 0
    assign read_data1 = (read_reg_num1 == 5'd0) ? 32'd0 : registers[read_reg_num1];
    assign read_data2 = (read_reg_num2 == 5'd0) ? 32'd0 : registers[read_reg_num2];


    // Synchronous write
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'd0;
        end else begin
            if (reg_write && write_reg_num != 5'd0) begin
                registers[write_reg_num] <= write_data;
            end
        end
    end


endmodule
