`timescale 1ns / 1ps
// Generic closed-loop oscillation probe.
// Usage: vsim ... +K=<counts per image pixel>
// Measures: settle frame, and the residual peak-to-peak jitter (px) after arrival.
// Only COMMON parameters are overridden, so the same TB compiles against:
//   (a) the 17:30 baseline gimbal (no filter / no D / no prediction)
//   (b) intermediate versions (D + prediction)
//   (c) current (filter + D + prediction + direction gate)
module tb_loop_probe;
    reg clk = 0;
    always #5 clk = ~clk;

    real K = 28.0;             // counts per image pixel (smaller = narrower FOV = higher loop gain)
    real obj = 1000.0;
    real pan_act = 20000.0;
    real cxr = 640.0;
    real t, dev, maxdev, minv, maxv, peak;
    reg [11:0] cx = 12'd640;

    reg rst_n = 0;
    reg frq = 0;
    reg ft1 = 0, ft2 = 0;
    always @(posedge clk) begin ft1 <= frq; ft2 <= ft1; end

    wire pan_pwm, tilt_pwm;

    gimbal_ctrl #(
        .CLK_HZ(1_000_000), .PWM_HZ(50), .IMG_W(1280), .IMG_H(720),
        .PAN_CENTER(20000), .TILT_CENTER(10000),
        .PAN_LIMIT_MIN(100), .PAN_LIMIT_MAX(40000),
        .TILT_LIMIT_MIN(100), .TILT_LIMIT_MAX(40000),
        .PAN_SWEEP_SPAN(15000), .TILT_SWEEP_SPAN(8000),
        .PAN_SWEEP_STEP(200), .TILT_SWEEP_STEP(100),
        .PAN_KP_NUM(1150), .TILT_KP_NUM(1700),
        .PAN_STEP_MAX(1200), .TILT_STEP_MAX(1600),
        .DEAD_X(20), .DEAD_Y(20),
        .PAN_DIR(1), .TILT_DIR(-1),
        .HOMING_FRAMES(3), .LOST_DELAY_FRAMES(5)
    ) u (
        .I_clk(clk), .I_rst_n(rst_n), .I_frame_toggle(frq),
        .I_red_valid(1'b1), .I_red_cx(cx), .I_red_cy(12'd360),
        .I_blu_valid(1'b0), .I_blu_cx(12'd0), .I_blu_cy(12'd0),
        .O_pan_pwm(pan_pwm), .O_tilt_pwm(tilt_pwm)
    );

    integer n, settle, ncyc, dummy, crossed;
    task frame; begin
        pan_act = pan_act + (u.pan_pulse - pan_act) / 4.0;
        cxr = obj + (20000.0 - pan_act) / K;
        if (cxr < 0.0)    cxr = 0.0;
        if (cxr > 1279.0) cxr = 1279.0;
        cx = cxr;
        frq = ~frq;
        #200;
    end endtask

    initial begin
        dummy = $value$plusargs("K=%f", K);
        maxdev = 0.0; minv = 99999.0; maxv = -99999.0; settle = -1; ncyc = 0; crossed = 0;
        peak = 0.0;
        rst_n = 0; #200; rst_n = 1;
        for (n = 0; n < 3; n = n + 1) frame;
        for (n = 0; n < 200; n = n + 1) begin
            frame;
            t = cxr - 640.0; if (t < 0.0) t = -t;
            if (crossed == 0 && cxr <= 640.0) crossed = 1;
            if (crossed == 1 && t > peak) peak = t;
            if (settle < 0 && t < 40.0) settle = n;
            if (settle >= 0 && n > settle + 5) begin
                if (t > maxdev) maxdev = t;
                if (cxr < minv) minv = cxr;
                if (cxr > maxv) maxv = cxr;
                ncyc = ncyc + 1;
            end
        end
        $display("PROBE K=%0f  settle=%0d  overshoot_peak=%0f px  post_arrival_max_dev=%0f px  p2p=%0f px",
                 K, settle, peak, maxdev, maxv - minv);
        $finish;
    end
endmodule