//
// Copyright 2018 Expedera, Inc.
// All Rights Reserved
//

module ip_fp_addsub
        #(parameter P_EXP     = 5,
          parameter P_FRAC    = 10,
          parameter P_BIAS    = 15, // 127;
          parameter P_WORD    = 1+P_FRAC+P_EXP,
          parameter P_PFRAC   = P_FRAC + 1,
          parameter P_PIPE    = 0)
        (
        input                  clk,
        input [2:0]            rnd,   // Rounding
        input                  op,    // 0 add, 1 sub
        input [P_WORD-1:0]     a,
        input [P_WORD-1:0]     b,
        output [P_WORD-1:0]    z,
        output [7:0]           status
        );

    wire              a_sign, b_sign;
    wire [P_EXP-1:0]  a_exp,  b_exp;
    wire [P_FRAC-1:0] a_frac, b_frac;

    reg               l_sign, s_sign;
    reg [P_EXP-1:0]   l_exp,  s_exp;
    reg [P_PFRAC-1:0] l_frac, s_frac;

    wire [P_EXP-1:0]  ls_exp;  // alwys positive so no need to sign extend
    // Close path signals
    wire [P_PFRAC:0]       c_s_frac_shift;
    wire [P_PFRAC:0]       c_ls_frac, c_ls_frac0, c_ls_frac1;
    wire                   c_ls_frac_sign;
    wire [P_EXP-1:0]       c_z_exp;
    wire [P_PFRAC:0]       c_z_frac;
    wire                   c_z_sticky;

    wire [$clog2(P_PFRAC+1)-1:0] c_lzc;
    wire [$clog2(P_PFRAC+1)-1:0] c_lzc_cap;

    // Far path signals
    wire [P_PFRAC+3-1:0]     f_s_frac_shift;
    wire [P_PFRAC+3-1:0]     f_s_frac_shift_comp;
    wire [P_PFRAC+3-1:0]     f_s_frac_shift_mux;
    wire [P_PFRAC-1:0]       f_s_frac;
    wire                     f_g_bit;
    wire                     f_r_bit;
    wire                     f_s_bit;
    wire [P_PFRAC:0]         f_subadd_frac;
    reg [P_EXP-1:0]          f_z_exp;
    reg [P_PFRAC:0]          f_z_frac;
    reg                      f_z_sticky;

    // Signals post recombinations:
    reg [P_EXP-1:0]          cf_z_exp;
    reg [P_PFRAC:0]          cf_z_frac;
    reg                      cf_z_sign;
    reg                      cf_z_sticky;

    wire [1:0]               rs;
    wire [P_EXP+P_FRAC-1:0]  z_exp_frac;
    reg [P_EXP+P_FRAC-1:0]   z_exp_frac_rnd;

    // Expand the numbers in their componets
    assign a_frac = a[P_FRAC-1:0];
    assign a_exp  = a[P_EXP-1+P_FRAC:P_FRAC];
    assign a_sign = a[P_WORD-1];

    assign b_frac = b[P_FRAC-1:0];
    assign b_exp  = b[P_EXP-1+P_FRAC:P_FRAC];
    assign b_sign = b[P_WORD-1];

    // Is an effective sub?
    assign eff_sub = op ^ a_sign ^ b_sign;

    // let's calculate the exp difference between the two numbers and swap
    always @(*) begin
        if (a_exp >= b_exp) begin
            l_sign  = a_sign;
            l_exp   = a_exp;
            l_frac  = a_exp == 'd0 ? {1'b0, a_frac} : {1'b1, a_frac};
            s_sign  = b_sign;
            s_exp   = b_exp;
            s_frac  = b_exp == 'd0 ? {1'b0, b_frac} : {1'b1, b_frac};
        end
        else begin
            l_sign  = b_sign;
            l_exp   = b_exp;
            l_frac  = b_exp == 'd0 ? {1'b0, b_frac} : {1'b1, b_frac};
            s_sign  = a_sign;
            s_exp   = a_exp;
            s_frac  = a_exp == 'd0 ? {1'b0, a_frac} : {1'b1, a_frac};
        end
    end

    // calculate delta exp it will always positive
    assign ls_exp = l_exp - s_exp;

    // Decide if we use the close or the far path
    assign c_path = eff_sub && ((l_exp == s_exp) || (ls_exp == 'd1));

    //
    // Close Path
    //

    // Shifth by 1 in case
    assign c_s_frac_shift  = ls_exp == 'd0 ? {s_frac,1'b0} : {1'b0, s_frac};
    // Sub the two farc numbers in both comb l - s and s -l
    assign c_ls_frac0      = {l_frac, 1'b0} - c_s_frac_shift;
    assign c_ls_frac1      = c_s_frac_shift - {l_frac, 1'b0};
    assign c_ls_frac_sign  = c_ls_frac0[P_PFRAC] == 1'b1;
    // Pick the correct one
    assign c_ls_frac       = c_ls_frac_sign == 1'b0 ? c_ls_frac0 : c_ls_frac1;
    // Calculate how many 0s need to be canceled out
    assign c_lzc           = lzc(c_ls_frac);
    // Result is denormal?
    assign c_denormal      = l_exp < c_lzc;
    // Cap the max shift
    assign c_lzc_cap       = c_denormal ? l_exp : c_lzc;
    // calculate Z exponent
    assign c_z_exp         = l_exp - c_lzc_cap;
    // Left shift by the correct amount
    assign c_z_frac        = c_ls_frac << c_lzc;
    assign c_z_sticky      = 1'b0;

    //
    // Far Path
    //

    // Shift smaller number by the exp delta
    assign f_s_frac_shift      = shift_right(s_frac,ls_exp);
    assign f_s_frac_shift_comp = ~f_s_frac_shift + 1;
    assign f_s_frac_shift_mux  = eff_sub ? f_s_frac_shift_comp : f_s_frac_shift;
    // Split f_s_frac_shift into 3 parts:
    assign f_s_frac = f_s_frac_shift_mux[P_PFRAC+3-1:3];
    assign f_g_bit  = f_s_frac_shift_mux[2];
    assign f_r_bit  = f_s_frac_shift_mux[1];
    assign f_s_bit  = f_s_frac_shift_mux[0];

    // Add or sub the two fracions
    assign f_subadd_frac = {1'b0,l_frac} + {eff_sub && f_s_frac[P_PFRAC-1],f_s_frac};

    // Prenorm step
    always @(*) begin
        casez (f_subadd_frac[P_PFRAC:P_PFRAC-1])
            2'b1?: begin
                // Addition carry out it set: need to shift down by 1
                f_z_exp    = l_exp + 1;
                f_z_frac   = f_subadd_frac[P_PFRAC:0];
                f_z_sticky = f_g_bit || f_r_bit || f_s_bit;
            end
            2'b01: begin
                // Addition carry out is not set: no shift is required
                f_z_exp    = l_exp;
                f_z_frac   = {f_subadd_frac[P_PFRAC-1:0], f_g_bit};
                f_z_sticky = f_r_bit || f_s_bit;
            end
            2'b00: begin
                //It was Substraction that lead at one bit cancellation
                f_z_exp    = l_exp - 1;
                f_z_frac   = {f_subadd_frac[P_PFRAC-2:0], f_g_bit, f_r_bit};
                f_z_sticky = f_s_bit;
            end
        endcase
    end

    //
    // Combine the two paths now
    //

    always @(*) begin
        if (c_path) begin
            cf_z_sign   = l_sign ^ c_ls_frac_sign;
            cf_z_exp    = c_z_exp;
            cf_z_frac   = c_z_frac;
            cf_z_sticky = c_z_sticky;
        end
        else begin
            cf_z_sign   = l_sign;
            cf_z_exp    = f_z_exp;
            cf_z_frac   = f_z_frac;
            cf_z_sticky = f_z_sticky;
        end
    end

    // Now rounding and normilized the final Result
    assign z_exp_frac     = {cf_z_exp, cf_z_frac[P_PFRAC-1:1]};
    assign rs            = {cf_z_frac[0],cf_z_sticky};
    always @(*) begin
        if (rs[1:0] == 2'b11) begin
            // Round Up
         //   $display("Rounding up");
            z_exp_frac_rnd = z_exp_frac + 1;
        end
        else if (rs == 3'b10) begin
            // tie EVEN only
         //   $display("Tie Rounding up/down");
            z_exp_frac_rnd = z_exp_frac[2] == 1'b1 ? z_exp_frac + 1 : z_exp_frac;
        end
        else begin
            // Round down
         //   $display("Rounding down");
            z_exp_frac_rnd = z_exp_frac;
        end
    end
    assign z_sign         = cf_z_sign;

    // Finally results is
    assign z = {z_sign, z_exp_frac_rnd};

    /////////////////////////////////////////////
    /// Functions
    /////////////////////////////////////////////

    function [P_PFRAC-1+3:0] shift_right;
        input [P_PFRAC-1:0] din;
        input [P_EXP-1:0]   lft;
        reg [P_PFRAC-1+3:0] tmp;
        reg                 fln_off;
        begin
            tmp = {din, 3'b000};
            for (int i=0; i<lft; i++) begin
                {tmp, fln_off} = tmp;
                tmp = tmp | fln_off;
            end
            shift_right = tmp;
        end
    endfunction

    function [$clog2(P_PFRAC+1)-1:0] lzc;
        input [P_PFRAC:0] x;
        reg found;
        integer tmp;
        begin
            tmp   = 'd0;
            found = 1'b0;
            for (int i = P_PFRAC; i >= 0; i=i-1) begin
                if (found == 1'b0) begin
                    tmp = tmp + (x[i] == 1'b0);
                    if (x[i] == 1'b1) begin
                        found = 1'b1;
                    end
                end
            end
            lzc = tmp;
        end
    endfunction

endmodule
