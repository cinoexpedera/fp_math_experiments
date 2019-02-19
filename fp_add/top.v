`timescale 1ns/1ps

module top;

	parameter P_EXP     = 5;   // 8;
    parameter P_FRAC    = 10;  // 23;
    parameter P_BIAS    = 15; // 127;
	parameter P_WORD    = 1+P_FRAC+P_EXP;

	wire                clk;
    reg                 rst;
    integer             seed;
    integer             transaction;
    reg                 start_push;
    integer             push_rate;
    integer             timeout;
    reg                 done;
    integer             cnt_in;

    reg [P_WORD-1:0]    a,b;
    wire [P_WORD-1:0]   z;
    wire [7:0]          status;
    reg [2:0]           rnd;
    reg                 op;
    real                x,y,k;
    reg                 x_vld, y_vld;

    assign #2 clk = clk === 0;

    initial begin
        reg [P_WORD-1:0] tmp1,tmp2;
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
        x = 0.0;
        x_vld = 0;
        y = 0.0;
        y_vld = 0;

        rnd = 0;
        op  = 1'b0;

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
//        tmp1 = {1'b0,8'b00000000, 23'b10000000000000000000000};
        tmp1 = {1'b0,5'b00000, 10'b0000000001};
        x    = mybitstoreal(tmp1); // bitstoshortreal($urandom());
        y    = mybitstoreal(tmp1); // bitstoshortreal($urandom());
        k = x + y;
        tmp2 = myrealtobits(x);
        $display("tmp1 = 0x%0h; x = %2.30e, tmp2 = 0x%0h",tmp1,x,tmp2);
        repeat (5) @(posedge clk);
//        tmp1 = {1'b0,8'b00000001, 23'b00000000000000000000000};
        tmp1 = {1'b0,5'b00001, 10'b0000000000};
        x    = mybitstoreal(tmp1); // bitstoshortreal($urandom());
        tmp2 = myrealtobits(a);
        $display("tmp1 = 0x%0h; x = %2.30e; tmp2 = 0x%0h",tmp1,x,tmp2);
        repeat (5) @(posedge clk);
//        tmp1 = {1'b0,8'b11111110, 23'b11111111111111111111111};
        tmp1 = {1'b0,5'b11110, 10'b1111111111};
        x     = mybitstoreal(tmp1); // bitstoshortreal($urandom());
        tmp2 = myrealtobits(a);
        $display("tmp1 = 0x%0h; x = %2.30e; tmp2 = 0x%0h",tmp1,x,tmp2);
        repeat (5) @(posedge clk);
//        tmp1 = {1'b0,8'b11111110, 23'b11111111111111111111110};
        tmp1 = {1'b0,5'b11110, 10'b1111111110};
        x     = mybitstoreal(tmp1); // bitstoshortreal($urandom());
        tmp2 = myrealtobits(a);
        $display("tmp1 = 0x%0h; x = %2.30e; tmp2 = 0x%0h",tmp1,x,tmp2);
        repeat (5) @(posedge clk);
//        tmp1 = {1'b0,8'b11111111, 23'b11111111111111111111110};
        tmp1 = {1'b0,5'b11111, 10'b1111111110};
        x     = mybitstoreal(tmp1); // bitstoshortreal($urandom());
        tmp2 = myrealtobits(a);
        $display("tmp1 = 0x%0h; x = %2.30e; tmp2 = 0x%0h",tmp1,x,tmp2);
        repeat (5) @(posedge clk);

        a = {1'b1,5'b10000, 10'b0100000000};
        b = {1'b0,5'b10000, 10'b1000000000};
        for (i = 0; i < 1000; i++) begin
            a = $urandom();
            b = $urandom();
            x = mybitstoreal(a);
            y = mybitstoreal(b);
            k = x + y;
            @(posedge clk);
            if (z == myrealtobits(k)) begin
                $display("%t sample %d OK it match: a = 0x%0h:%2.20e; b = 0x%0h:%2.20e; z = 0x%0h:%2.20e, expt = 0x%0h:%2.20e",$time,i,a,x,b,y,z,mybitstoreal(z),myrealtobits(k),k);
            end
            else begin
                $display("%t sample %d ERROR they don't match: a = 0x%0h:%2.20e; b = 0x%0h:%2.20e; z = 0x%0h:%2.20e, expt = 0x%0h:%2.20e",$time,i,a,x,b,y,z,mybitstoreal(z),myrealtobits(k),k);
            end
        end
        // start_push = 1;
        // while ((cnt_in < transaction) && (timeout < 100)) begin
        //     @(posedge clk);
        //     timeout = (x_vld || y_vld) ? 0 : timeout + 1;
        // end

        repeat (500) @(posedge clk);
        $display("======================================");
        $display("=       TEST COMPLETED                ");
        $display("======================================");
        $finish;
    end

    ip_fp_addsub #(.P_EXP(P_EXP),
                   .P_FRAC(P_FRAC),
                   .P_BIAS(P_BIAS))
            ip_fp_addsub(.clk,
                         .rnd,
                         .a,
                         .b,
                         .z,
                         .op,
                         .status);

    always @(posedge clk) begin
        #1;
        if (start_push && cnt_in < transaction) begin
            if (($urandom() % 100) < push_rate) begin
                x_vld  = 1'b1;
                x      = mybitstoreal({1'b0,5'b00000, 11'b00000000001}); // bitstoshortreal($urandom());
                y_vld  = 1'b1;
                y      = mybitstoreal($urandom());
                cnt_in = cnt_in + 1;
                $display("%t: sample = %0d, x = %e; y = %e",$time, cnt_in, x,y);
            end
            else begin
                x_vld = 1'b0;
                x     = 0.0;
                y_vld = 1'b0;
                y     = 0.0;
            end
        end
    end

    function real mybitstoreal;
        input [P_WORD:0] bits;

        reg              sign;
        reg [P_EXP-1:0]  exp;
        integer          exps;
        reg [P_FRAC-1:0] frac;
        real             sr;
        reg [P_FRAC:0]   xfrac;
        real tmp;

        sign = bits[P_WORD-1];
        exp  = bits[P_EXP+P_FRAC-1:P_FRAC];
        frac = bits[P_FRAC-1: 0];

        if (exp != 0) begin
            // Normal case
            xfrac = {1'b1, frac};
            sr = real'(xfrac) / (2**P_FRAC);
        end
        else begin
            // Denormal case
            xfrac = {1'b0, frac};
            sr = real'(xfrac) / (2**(P_FRAC-1));
        end

    //    $display("CINO exp = %0d, xfrac = %0db%b; sr = %e", exp, P_FRAC+1, xfrac, sr);
    //    sr = sr / 8388608.0;  // 0x800000 == 1 << 24
        exps = exp - P_BIAS;
        tmp = (2.0 ** exps);
        sr = sr * tmp;
    //    $display("CINO exps = %d, tmp = %e", exps, tmp);

        mybitstoreal = bits == 0 ? 0.0 : 
                       exp == {P_EXP{1'b1}} ? (sign ? $ln(0.0) : 1.0/0.0) : sign ? -1.0 * sr : sr;
    //    $display("CINO mybitstoreal = %2.30e, sr = %e, exp = %0d", mybitstoreal, sr, exp);
    endfunction

    function [P_WORD-1:0] myrealtobits;
        input real r;
        reg sign;
        reg [P_EXP-1:0] exp;
        reg [P_FRAC-1:0] frac;
        integer iexp;
        real abs, ffrac, ffracd;

//        $display("CINO myrealtobits: r = %2.30e", r);
        sign  = r < 0.0 ? 1 : 0;
        abs   = sign ? -1.0*r : r;
        iexp  = $floor($ln(abs) / $ln(2));
        ffrac  = abs / $pow(2,iexp);
        ffracd = abs / $pow(2,-P_BIAS);
//        $display("CINO abs = %e, iexp = %0d, ffrac = %2.20e, ffracd = %2.20e",abs, iexp, ffrac, ffracd);
        if (iexp > -P_BIAS) begin
            // Normal case
            exp = (r==0) ? 0 : P_BIAS + iexp;
            ffrac = ffrac - 1.0;
            frac = ffrac * (2**P_FRAC);
        end
        else begin
            // denormal case
            // $display("DENORMAL");
            exp  = 0;
            frac = ffracd * (2**(P_FRAC-1));
        end
//        $display("CINO myrealtobits sign = %b, exp = %0h, ffrac = %0h",sign,exp,frac);
        if (r == 1.0/0.0) 
            myrealtobits = 1.0/0.0;
        else if (r == $ln(0.0)) 
            myrealtobits = $ln(0.0);
        else
            myrealtobits = {sign, exp, frac};

    endfunction


endmodule
