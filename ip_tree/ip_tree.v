module ip_tree
    #(parameter P_SIZE = 16)
    (
    input [P_SIZE-1:0] a,
    input [P_SIZE-1:0] b,
    input [P_SIZE-1:0] c,
    output [P_SIZE-1:0] out0,
    output [P_SIZE-1:0] out1
    );

    assign out0 = ((a ^ b) & ~c) | (~(a ^ b) & c);
    assign out1 = ((a ^ b) & c) | (~(a ^ b) & a);

endmodule
