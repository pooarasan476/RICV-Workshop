`timescale 1ns/1ps

module alu4_store_tb;

    reg        clk, we;
    reg  [3:0] addr;
    reg  [3:0] A, B;
    reg  [2:0] opcode;
    wire [5:0] dout;          // {zero, carry_borrow, result[3:0]}

    alu4_store uut (
        .clk(clk),
        .we(we),
        .addr(addr),
        .A(A),
        .B(B),
        .opcode(opcode),
        .dout(dout)
    );

    // Clock: 10 ns period
    always #5 clk = ~clk;

    // Call this task to run the ALU and STORE the result at address ad
    task store_result(input [3:0] a_in, input [3:0] b_in,
                      input [2:0] op,   input [3:0] ad);
        begin
            @(negedge clk);
            A = a_in; B = b_in; opcode = op; addr = ad; we = 1;
            @(negedge clk);
            we = 0;
        end
    endtask

    // Call this task to READ the stored result from address ad
    task read_result(input [3:0] ad);
        begin
            @(negedge clk);
            addr = ad; we = 0;
            @(negedge clk);
            $display("  %2d     %b    %2d         %b          %b",
                     ad, dout[3:0], dout[3:0], dout[4], dout[5]);
        end
    endtask

    integer i;

    initial begin
        clk = 0; we = 0; addr = 0; A = 0; B = 0; opcode = 0;

        // ---------------- STORE ----------------
        store_result(4'd5,  4'd3, 3'b000, 4'd0);   // ADD : 5 + 3
        store_result(4'd15, 4'd1, 3'b000, 4'd1);   // ADD : 15 + 1 (carry)
        store_result(4'd5,  4'd3, 3'b001, 4'd2);   // SUB : 5 - 3
        store_result(4'd3,  4'd5, 3'b001, 4'd3);   // SUB : 3 - 5 (borrow)
        store_result(4'd5,  4'd3, 3'b010, 4'd4);   // AND : 5 & 3
        store_result(4'd5,  4'd3, 3'b011, 4'd5);   // OR  : 5 | 3
        store_result(4'd5,  4'd3, 3'b100, 4'd6);   // XOR : 5 ^ 3
        store_result(4'd5,  4'd5, 3'b001, 4'd7);   // SUB : 5 - 5 (zero)

        // ---------------- READ BACK ----------------
        $display("==============================================");
        $display("   STORED ALU RESULTS (read from memory)");
        $display("==============================================");
        $display("  Addr  Result  Dec   Carry/Borrow  Zero");
        $display("----------------------------------------------");

        for (i = 0; i < 8; i = i + 1)
            read_result(i[3:0]);

        $display("==============================================");
        #10 $finish;
    end

endmodule
