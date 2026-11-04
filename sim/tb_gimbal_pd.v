`timescale 1ns / 1ps
// Verify plan B (PD damping) and plan C (target prediction).
// The centroid is latched on the frame edge, exactly like the real wrapper does,
// otherwise the "previous frame error" comparison is meaningless.
module tb_gimbal_pd;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg frame_toggle = 0;

    reg        tgt_v  = 0;
    reg [11:0] tgt_cx = 12'd640;
    reg [11:0] tgt_cy = 12'd360;

    // ---- mimic wrapper: 2-stage sync + latch centroid on frame edge ----
    reg ft1 = 0, ft2 = 0;
    reg [11:0] tgt_cx_q = 12'd640, tgt_cy_q = 12'd360;
    wire frame_tick_tb = ft1 ^ ft2;
    always @(posedge clk) begin
        ft1 <= frame_toggle;
        ft2 <= ft1;
        if (ft1 ^ ft2) begin
            tgt_cx_q <= tgt_cx;
            tgt_cy_q <= tgt_cy;
        end
    end

    wire pan_pwm, tilt_pwm;

    gimbal_ctrl #(
        .CLK_HZ(1_000_000), .PWM_HZ(50), .IMG_W(1280), .IMG_H(720),
        .PAN_CENTER(20000), .TILT_CENTER(10000),
        .PAN_LIMIT_MIN(100), .PAN_LIMIT_MAX(40000),
        .TILT_LIMIT_MIN(100), .TILT_LIMIT_MAX(40000),
        .PAN_SWEEP_SPAN(15000), .TILT_SWEEP_SPAN(8000),
        .PAN_SWEEP_STEP(200), .TILT_SWEEP_STEP(100),
        .PAN_KP_NUM(660), .TILT_KP_NUM(990), .PAN_KD_NUM(330), .TILT_KD_NUM(495),
        .PAN_STEP_MAX(4000), .TILT_STEP_MAX(4000),
        .DEAD_X(20), .DEAD_Y(20),
        .PAN_DIR(1), .TILT_DIR(-1),
        .HOMING_FRAMES(3), .LOST_DELAY_FRAMES(5),
        .SWEEP_PASSES(2), .COAST_DWELL_FRAMES(3),
        .LIMIT_ZONE(100), .LIMIT_BACKOFF_FRAMES(5), .LIMIT_BACKOFF_STEP(200)
    ) u (
        .I_clk(clk), .I_rst_n(rst_n), .I_frame_toggle(frame_toggle),
        .I_red_valid(tgt_v), .I_red_cx(tgt_cx_q), .I_red_cy(tgt_cy_q),
        .I_blu_valid(1'b0), .I_blu_cx(12'd0), .I_blu_cy(12'd0),
        .O_pan_pwm(pan_pwm), .O_tilt_pwm(tilt_pwm)
    );

    integer n, p0, pure, actual, fail_cnt;
    task frame; begin frame_toggle = ~frame_toggle; #400; end endtask
    task chk(input ok, input [255:0] msg); begin
        if (!ok) begin fail_cnt = fail_cnt + 1; $display("  FAIL %0s", msg); end
    end endtask

    initial begin
        fail_cnt = 0;
        tgt_v = 1; tgt_cx = 12'd640;
        rst_n = 0; #200; rst_n = 1;
        for (n = 0; n < 40; n = n + 1) frame;
        $display("S0 settled : pan=%0d err=%0d err_pf=%0d lead=%0d", u.pan_pulse, u.pan_err_r, u.pan_err_pf, u.pan_lead);

        // ---------- plan C: target jumps 640 -> 900 ----------
        tgt_cx = 12'd900;
        frame;
        $display("S1 jump    : lead=%0d err=%0d (prediction ON)", u.pan_lead, u.pan_err_r);
        chk(u.pan_lead == 13'sd128, "C: lead clamped to +128");
        chk(u.pan_err_r >= 12'd200, "C: filtered+predicted error must exceed raw-240 minus filter softening");

        // ---------- target keeps moving AWAY (+40/frame): error grows -> damping adds ----------
        for (n = 0; n < 4; n = n + 1) begin tgt_cx = tgt_cx + 12'd40; frame; end
        tgt_cx = tgt_cx + 12'd40; frame;
        pure = (u.pan_err_r * 660) >> 8;
        p0 = u.pan_pulse;
        for (n = 0; n < 3; n = n + 1) begin tgt_cx = tgt_cx + 12'd40; frame; end
        actual = u.pan_pulse - p0;
        $display("S2 growing : err=%0d err_pf=%0d lead=%0d pure3=%0d actual3=%0d grow=%0d",
                 u.pan_err_r, u.pan_err_pf, u.pan_lead, pure*3, actual, u.pan_grow);
        chk(u.pan_lead != 13'sd0, "C: lead must be non-zero (prediction ON)");
        chk(u.pan_err_pf < u.pan_err_r, "B: err_pf must be the PREVIOUS frame error");
        chk(u.pan_grow == 1'b1, "B: growing error must be flagged grow");
        chk(actual > pure*3, "B: growing error must apply damping boost");

        // ---------- target moves TOWARD center (-40/frame): error shrinks -> damping brakes ----------
        for (n = 0; n < 4; n = n + 1) begin tgt_cx = tgt_cx - 12'd40; frame; end
        tgt_cx = tgt_cx - 12'd40; frame;
        pure = (u.pan_err_r * 660) >> 8;
        p0 = u.pan_pulse;
        for (n = 0; n < 3; n = n + 1) begin tgt_cx = tgt_cx - 12'd40; frame; end
        actual = u.pan_pulse - p0;
        $display("S3 closing : err=%0d err_pf=%0d lead=%0d pure3=%0d actual3=%0d grow=%0d",
                 u.pan_err_r, u.pan_err_pf, u.pan_lead, pure*3, actual, u.pan_grow);
        chk(u.pan_lead != 13'sd0, "C: lead must be non-zero (prediction ON)");
        chk(u.pan_grow == 1'b0, "B: shrinking error must be flagged shrink");
        chk(actual < pure*3, "B: shrinking error must be braked");

        $display("S4 cap     : PAN_STEP_MAX=%0d (wrapper sets 800)", u.PAN_STEP_MAX);
        if (fail_cnt == 0) $display("PDBC: PASS=9 FAIL=0  ALL PASS");
        else               $display("PDBC: FAIL=%0d", fail_cnt);
        $finish;
    end
endmodule