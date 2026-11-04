`timescale 1ns / 1ps
// 针对"冲极限 + 纯水平自检两圈 + tilt 不动"的验证
module tb_gimbal_ctrl;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg frame_toggle = 0;
    reg        tgt_v  = 0;
    reg [11:0] tgt_cx = 12'd640;
    reg [11:0] tgt_cy = 12'd360;
    wire pan_pwm, tilt_pwm;

    gimbal_ctrl #(
        .CLK_HZ(1_000_000), .PWM_HZ(50), .IMG_W(1280), .IMG_H(720),
        .PAN_CENTER(1250), .TILT_CENTER(1250),
        .PAN_LIMIT_MIN(600), .PAN_LIMIT_MAX(1900),
        .TILT_LIMIT_MIN(900), .TILT_LIMIT_MAX(1600),
        .PAN_SWEEP_SPAN(650), .TILT_SWEEP_SPAN(350),
        .PAN_SWEEP_STEP(200), .TILT_SWEEP_STEP(100),
        .PAN_KP_NUM(100), .TILT_KP_NUM(100),
        .PAN_STEP_MAX(100), .TILT_STEP_MAX(100),
        .DEAD_X(20), .DEAD_Y(20),
        .PAN_DIR(1), .TILT_DIR(-1),
        .HOMING_FRAMES(3), .LOST_DELAY_FRAMES(5),
        .SWEEP_PASSES(2), .COAST_DWELL_FRAMES(3),
        .LIMIT_ZONE(100), .LIMIT_BACKOFF_FRAMES(5), .LIMIT_BACKOFF_STEP(200)
    ) u (
        .I_clk(clk), .I_rst_n(rst_n), .I_frame_toggle(frame_toggle),
        .I_red_valid(tgt_v), .I_red_cx(tgt_cx), .I_red_cy(tgt_cy),
        .I_blu_valid(1'b0), .I_blu_cx(12'd0), .I_blu_cy(12'd0),
        .O_pan_pwm(pan_pwm), .O_tilt_pwm(tilt_pwm)
    );

    integer n, n_coast, n_sweep, n_lost, n_center, n_idle, n_other;
    integer smin, smax, tmin, tmax;
    integer coast_exit_pan, coast_exit_tilt;
    reg [2:0] st_prev;
    reg       coast_seen, coast_exited, bad;
    integer fail_cnt;

    task frame; begin
        frame_toggle = ~frame_toggle;
        #200;
    end endtask

    task chk(input ok, input [255:0] msg);
    begin
        if (!ok) begin
            fail_cnt = fail_cnt + 1;
            $display("  FAIL %0s", msg);
        end
    end endtask

    initial begin
        fail_cnt = 0; n_coast = 0; n_sweep = 0; n_lost = 0; n_center = 0; n_idle = 0; n_other = 0;
        smin = 999999; smax = 0; tmin = 999999; tmax = 0;
        coast_seen = 0; coast_exited = 0; coast_exit_pan = -1; coast_exit_tilt = -1;
        rst_n = 0; #200; rst_n = 1;

        // 1) 上电：中位静置
        for (n = 0; n < 4; n = n + 1) frame;
        $display("T1 homing : pan=%0d tilt=%0d (expect 1250/1250)", u.pan_pulse, u.tilt_pulse);

        // 2) 目标偏右 -> pan 沿 + 方向跟踪
        tgt_v = 1; tgt_cx = 12'd900; tgt_cy = 12'd360;
        for (n = 0; n < 3; n = n + 1) frame;
        $display("T2 track  : pan=%0d tilt=%0d (pan should be > 1250 and < 1900)", u.pan_pulse, u.tilt_pulse);
        chk(u.pan_pulse > 18'd1250, "tracking did not move pan to +");
        chk(u.pan_pulse < 18'd1900, "tracking already saturated (TB wants mid-range before loss)");

        // 3) 丢目标：LOST -> COAST(沿最后方向冲到 PAN_LIMIT_MAX) -> SWEEP
        tgt_v = 0;
        st_prev = u.state;
        for (n = 0; n < 90; n = n + 1) begin
            frame;
            if (u.state == 3'd6) begin n_coast = n_coast + 1; coast_seen = 1; end
            if (st_prev == 3'd6 && u.state != 3'd6 && !coast_exited) begin
                coast_exited    = 1;
                coast_exit_pan  = u.pan_pulse;
                coast_exit_tilt = u.tilt_pulse;
            end
            if (u.state == 3'd2) n_lost   = n_lost   + 1;
            if (u.state == 3'd3) begin
                n_sweep = n_sweep + 1;
                if (u.pan_pulse  < smin) smin = u.pan_pulse;
                if (u.pan_pulse  > smax) smax = u.pan_pulse;
                if (u.tilt_pulse < tmin) tmin = u.tilt_pulse;
                if (u.tilt_pulse > tmax) tmax = u.tilt_pulse;
            end
            if (u.state == 3'd4) n_center = n_center + 1;
            if (u.state == 3'd5) n_idle   = n_idle   + 1;
            if (u.state != 3'd1 && u.state != 3'd2 && u.state != 3'd3 && u.state != 3'd6 && u.state != 3'd4 && u.state != 3'd5) n_other = n_other + 1;
            st_prev = u.state;
        end
        $display("T3 coast  : frames=%0d  exit pan=%0d tilt=%0d (expect pan=1900=PAN_LIMIT_MAX)", n_coast, coast_exit_pan, coast_exit_tilt);
        chk(coast_seen,   "COAST state never entered");
        chk(coast_exited, "COAST never exited");
        chk(coast_exit_pan == 1900, "COAST did not end at PAN_LIMIT_MAX");

        $display("T4 sweep  : frames=%0d  pan range=%0d..%0d  tilt range=%0d..%0d", n_sweep, smin, smax, tmin, tmax);
        chk(smin <= 605,  "sweep did not reach PAN_LIMIT_MIN end");
        chk(smax >= 1895, "sweep did not reach PAN_LIMIT_MAX end");
        chk(tmin == tmax, "tilt MOVED during sweep (must stay flat)");

        // 4) 扫完 -> 回正 -> 静置
        for (n = 0; n < 200; n = n + 1) frame;
        $display("T5 final  : state=%0d pan=%0d tilt=%0d (expect IDLE=5, 1250/1250)", u.state, u.pan_pulse, u.tilt_pulse);
        chk(u.state == 3'd5, "did not reach ST_IDLE");
        chk(u.pan_pulse == 1250 && u.tilt_pulse == 1250, "did not return to center");
        $display("frames per state: LOST=%0d COAST=%0d SWEEP=%0d CENTER=%0d IDLE=%0d other=%0d", n_lost, n_coast, n_sweep, n_center, n_idle, n_other);
        if (fail_cnt == 0) $display("PASS=%0d FAIL=0  ALL PASS", 8);
        else               $display("FAIL=%0d", fail_cnt);
        $finish;
    end
endmodule