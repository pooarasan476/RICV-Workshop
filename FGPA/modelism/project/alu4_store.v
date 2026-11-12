`timescale 1ns/1ps

// 4-bit ALU + memory to store results
// Each memory location holds 6 bits: {zero, carry_borrow, result[3:0]}
module alu4_store (
    input  wire       clk,
    input  wire       we,        // write enable (1 = store ALU output)
    input  wire [3:0] addr,      // memory address (0 to 15)
    input  wire [3:0] A,
    input  wire [3:0] B,
    input  wire [2:0] opcode,
    output reg  [5:0] dout       // data read back from memory
);

    // Original ALU (alu4.v is used as it is)
    wire [3:0] result;
    wire       carry_borrow;
    wire       zero;

    alu4 alu (
        .A(A),
        .B(B),
        .opcode(opcode),
        .result(result),
        .carry_borrow(carry_borrow),
        .zero(zero)
    );

    // Memory: 16 locations, 6 bits each
    reg [5:0] mem [0:15];

    always @(posedge clk) begin
        if (we)
            mem[addr] <= {zero, carry_borrow, result};   // store data
        dout <= mem[addr];                               // read data
    end

endmodule
