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

        for (i = 0; i < transaction; i++) begin
            a = $urandom();
            b = $urandom();
            c = $urandom();
            @(posedge clk);
            // if (z == myrealtobits(k)) begin
            //     $display("%t sample %d OK it match: a = 0x%0h:%2.20e; b = 0x%0h:%2.20e; z = 0x%0h:%2.20e, expt = 0x%0h:%2.20e",$time,i,a,x,b,y,z,mybitstoreal(z),myrealtobits(k),k);
            // end
            // else begin
            //     $display("%t sample %d ERROR they don't match: a = 0x%0h:%2.20e; b = 0x%0h:%2.20e; z = 0x%0h:%2.20e, expt = 0x%0h:%2.20e",$time,i,a,x,b,y,z,mybitstoreal(z),myrealtobits(k),k);
            //     fail = 1'b1;
            // end
        end
        // start_push = 1;
        // while ((cnt_in < transaction) && (timeout < 100)) begin
        //     @(posedge clk);
        //     timeout = (x_vld || y_vld) ? 0 : timeout + 1;
        // end

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

    ip_tree #(.P_SIZE(P_SIZE))
                ip_tree(.a,
                        .b,
                        .c,
                        .out0,
                        .out1);



endmodule
