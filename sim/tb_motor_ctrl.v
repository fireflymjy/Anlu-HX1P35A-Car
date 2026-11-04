`timescale 1ns / 1ps

module tb_motor_ctrl;

    (* keep = "true" *) reg         clk, rst_n;
    (* keep = "true" *) reg  [2:0]  i_action;
    (* keep = "true" *) reg  [7:0]  i_speed_pct;
    (* keep = "true" *) wire        o_left_fwd, o_left_bwd;
    (* keep = "true" *) wire        o_right_fwd, o_right_bwd;
    (* keep = "true" *) wire        o_left_pwm, o_right_pwm;

    motor_ctrl #(
        .PWM_PERIOD (16'd100)     // 缩小周期，方便仿真
    ) u_dut (
        .I_clk        (clk),
        .I_rst_n      (rst_n),
        .I_action     (i_action),
        .I_speed_pct  (i_speed_pct),
        .O_left_fwd   (o_left_fwd),
        .O_left_bwd   (o_left_bwd),
        .O_right_fwd  (o_right_fwd),
        .O_right_bwd  (o_right_bwd),
        .O_left_pwm   (o_left_pwm),
        .O_right_pwm  (o_right_pwm)
    );

    always #5 clk = ~clk;

    // 统计高电平拍数
    integer left_high, right_high;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            left_high  <= 0;
            right_high <= 0;
        end
        else begin
            if (o_left_pwm)  left_high  <= left_high  + 1;
            if (o_right_pwm) right_high <= right_high + 1;
        end
    end

    initial begin
        clk = 0; rst_n = 0;
        i_action = 3'd0;
        i_speed_pct = 8'd0;

        #100; rst_n = 1; #50;

        // 场景1：直行，50% 速度
        i_action = 3'd1;
        i_speed_pct = 8'd50;
        left_high = 0; right_high = 0;
        #2000;
        $display("直行50%%：左轮=%d 右轮=%d（期望 50,50）", left_high, right_high);

        // 场景2：左转，50% 速度 
        i_action = 3'd2;
        left_high = 0; right_high = 0;
        #2000;
        $display("左转50%%：左轮=%d 右轮=%d（期望 25,50）", left_high, right_high);

        // 场景3：右转，50% 速度 
        i_action = 3'd3;
        left_high = 0; right_high = 0;
        #2000;
        $display("右转50%%：左轮=%d 右轮=%d（期望 50,25）", left_high, right_high);

        // 场景4：停车 
        i_action = 3'd0;
        left_high = 0; right_high = 0;
        #2000;
        $display("停车：左轮=%d 右轮=%d（期望 0,0）", left_high, right_high);

        #500;
        $stop;
    end

endmodule