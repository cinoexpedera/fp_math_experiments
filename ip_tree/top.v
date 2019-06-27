`timescale 1ns/1ps

module top;

	parameter P_SIZE     = 16;   // 8;

	wire                clk;
    reg                 rst;
    integer             seed;
    integer             transaction;
    reg                 start_push;
    integer             push_rate;
    integer             timeout;
    reg                 done;
    integer             cnt_in;

    reg [P_SIZE-1:0]    a,b,c;
    wire [P_SIZE-1:0]   sum;
    wire [P_SIZE-1:0]   exp_sum;
    wire [P_SIZE-1:0]   out0, out1;
    reg                 fail;

    assign #2 clk = clk === 0;

    initial begin
        integer rate, s, i;
        $timeformat(-9, 0, " ns", 8);
        seed = 1;
        transaction = 10;
        rst = 0;
        push_rate = 50;
        start_push = 0;
        done = 0;
        cnt_in = 0;
        timeout = 0;
        a = 'd11;
        b = 'd22;
        c = 'd33;

        fail = 1'b0;

       `ifdef ICS
        $display("\nHELLO IICS\n");
        $dumpfile("test.fst");
        $dumpvars(0,top);
        `endif
        `ifdef VCS
        $display("\nHELLO VCS\n");
        $vcdplusfile ("waves.vpd");
        $vcdpluson();
        $vcdplusmemon;
        `endif
        if ($value$plusargs("seed=%d", s)) begin
            seed = s;
        end
        if ($value$plusargs("transaction=%d", s)) begin
            transaction = s;
        end
        if ($value$plusargs("push_rate=%d", rate)) begin
            push_rate = rate;
        end
        $display("======================================");
        $display("=         SIM started                =");
        $display("= seed        = %0d", seed);
        $display("= transaction = %0d", transaction);
        $display("= push_rate   = %0d", push_rate);
        $display("======================================");
        $urandom(seed);
        repeat (5) @(posedge clk);
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;
        repeat (5) @(posedge clk);

        start_push = 1;
        while ((cnt_in < transaction) && (timeout < 100)) begin
            @(posedge clk);
            // timeout = (x_vld || y_vld) ? 0 : timeout + 1;
        end
        done = 1;
        repeat (500) @(posedge clk);
        $display("==============================================");
        if (fail) begin
            $display("=       TEST FAILED: go and debug it!        =");
        end
        else begin
            $display("=       TEST PASSS!!!!!!!                    =");
        end
        $display("==============================================");
        $finish;
    end

    always @(posedge clk) begin
        if (start_push && (cnt_in < transaction)) begin
            a = $urandom();
            b = $urandom();
            c = $urandom();
        end
    end

    ip_tree #(.P_SIZE(P_SIZE))
                ip_tree(.a,
                        .b,
                        .c,
                        .out0,
                        .out1);

    assign sum = out0 + (out1 << 1);
    assign exp_sum = a + b + c;

    always @(posedge clk) begin
        #1;
        if (start_push) begin
            cnt_in <= cnt_in + 1;
            if (!done) begin
                if (sum == exp_sum) begin
                    $display("%t OK sum match sum = %0d, a + b + c = %0d", $time, sum, exp_sum);
                end
                else begin
                    $display("%t ERROR sum doesnt' match sum = %0d, a + b + c = %0d", $time, sum, exp_sum);
                    fail <= 1;
                    #10;
                    $finish;
                end
            end
        end
    end

endmodule
