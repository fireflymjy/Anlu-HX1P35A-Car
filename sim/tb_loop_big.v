`timescale 1ns / 1ps
// Closed-loop "large rotation" test.
// Object is fixed in the world at the side of the frame; the gimbal must do a BIG pan.
// Servo is modelled as a 1st-order lag; the camera projection maps gimbal position to image position.
// Measures the residual oscillation AFTER arrival -- which is the on-board "violent jitter".
module tb_loop_big;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg frq = 0;
    reg ft1 = 0, ft2 = 0;
    always @(posedge clk) begin ft1 <= frq; ft2 <= ft1; end

    real K = 28.0;            // PWM counts per image pixel
    real obj = 1000.0;        // object image position if gimbal sat at PAN_CENTER
    real pan_act = 20000.0;   // actual gimbal position (servo output)
    real cxr = 640.0;
    real t, amp, d0;
    reg [11:0] cx = 12'd640;

    wire [17:0] cmd;
    wire pan_pwm, tilt_pwm;

    gimbal_ctrl #(
        .CLK_HZ(1_000_000), .PWM_HZ(50), .IMG_W(1280), .IMG_H(720),
        .PAN_CENTER(20000), .TILT_CENTER(10000),
        .PAN_LIMIT_MIN(100), .PAN_LIMIT_MAX(40000),
        .TILT_LIMIT_MIN(100), .TILT_LIMIT_MAX(40000),
        .PAN_SWEEP_SPAN(15000), .TILT_SWEEP_SPAN(8000),
        .PAN_SWEEP_STEP(200), .TILT_SWEEP_STEP(100),
        .PAN_KP_NUM(1150), .TILT_KP_NUM(1700),
        .PAN_KD_NUM(900),  .TILT_KD_NUM(1350),
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
    assign cmd = u.pan_pulse;

    integer n, settle;
    task frame; begin
        // model update once per frame (servo lag + camera projection), then one DUT frame
        pan_act = pan_act + (cmd - pan_act) / 4.0;
        cxr = obj + (20000.0 - pan_act) / K;
        if (cxr < 0.0)    cxr = 0.0;
        if (cxr > 1279.0) cxr = 1279.0;
        cx = cxr;
        frq = ~frq;
        #200;
    end endtask

    initial begin
        amp = 0.0; settle = -1;
        rst_n = 0; #200; rst_n = 1;
        for (n = 0; n < 3; n = n + 1) frame;
        for (n = 0; n < 140; n = n + 1) begin
            frame;
            t = cxr - 640.0; if (t < 0.0) t = -t;
            if (settle < 0 && t < 40.0) settle = n;      // first arrival
            if (settle >= 0 && n > settle + 3) begin     // residual oscillation after arrival
                if (t > amp) amp = t;
            end
        end
        $display("LOOP2 obj=%0f px  settle_frame=%0d  post_arrival_max_dev=%0f px", obj, settle, amp);
        $finish;
    end
endmodule