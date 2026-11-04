`timescale 1ns / 1ps

module tb_hdmi_mixer_frame;

    (* keep = "true" *) reg         clk;
    (* keep = "true" *) reg         rst_n;
    (* keep = "true" *) reg         i_vsync;
    (* keep = "true" *) reg         i_hsync;
    (* keep = "true" *) reg         i_de;
    (* keep = "true" *) reg         i_user;
    (* keep = "true" *) reg         i_last;
    (* keep = "true" *) reg  [23:0] i_rd_data;
    (* keep = "true" *) reg  [5:0]  i_debug_status;
    (* keep = "true" *) reg         i_red_valid;
    (* keep = "true" *) reg  [11:0] i_red_x_min, i_red_x_max;
    (* keep = "true" *) reg  [11:0] i_red_y_min, i_red_y_max;
    (* keep = "true" *) reg         i_blu_valid;
    (* keep = "true" *) reg  [11:0] i_blu_x_min, i_blu_x_max;
    (* keep = "true" *) reg  [11:0] i_blu_y_min, i_blu_y_max;
    (* keep = "true" *) wire [23:0] o_hdmi_data;
    (* keep = "true" *) wire        o_hdmi_de;

    // ===== 例化 hdmi_mixer =====
    hdmi_mixer #(
        .H_OFFSET   (0),
        .V_OFFSET   (0),
        .IMG_WIDTH  (1280),
        .IMG_HEIGHT (720),
        .DEBUG_MODE (0)
    ) u_dut (
        .I_clk           (clk),
        .I_rst_n         (rst_n),
        .I_video_vsync   (i_vsync),
        .I_video_hsync   (i_hsync),
        .I_video_de      (i_de),
        .I_video_user    (i_user),
        .I_video_last    (i_last),
        .I_debug_status  (i_debug_status),
        .O_video_rd_en   (),
        .I_video_rd_data (i_rd_data),
        .O_hdmi_vsync    (),
        .O_hdmi_hsync    (),
        .O_hdmi_de       (o_hdmi_de),
        .O_hdmi_data     (o_hdmi_data),
        // 颜色坐标
        .I_red_valid     (i_red_valid),
        .I_red_x_min     (i_red_x_min),
        .I_red_x_max     (i_red_x_max),
        .I_red_y_min     (i_red_y_min),
        .I_red_y_max     (i_red_y_max),
        .I_blu_valid     (i_blu_valid),
        .I_blu_x_min     (i_blu_x_min),
        .I_blu_x_max     (i_blu_x_max),
        .I_blu_y_min     (i_blu_y_min),
        .I_blu_y_max     (i_blu_y_max)
    );

    // 74.25MHz 像素时钟
    always #6.734 clk = ~clk;

    integer x, y;

    initial begin
        clk = 0; rst_n = 0;
        i_vsync = 0; i_hsync = 0; i_de = 0; i_user = 0; i_last = 0;
        i_rd_data = 24'h808080;
        i_debug_status = 6'd0;

        // 设置一个红色目标框：(x 200~400, y 100~300)
        i_red_valid = 1'b1;
        i_red_x_min = 12'd200;
        i_red_x_max = 12'd400;
        i_red_y_min = 12'd100;
        i_red_y_max = 12'd300;

        // 蓝色目标关闭
        i_blu_valid = 1'b0;
        i_blu_x_min = 12'd0;
        i_blu_x_max = 12'd0;
        i_blu_y_min = 12'd0;
        i_blu_y_max = 12'd0;

        #200; rst_n = 1;
        #100;

        // ===== 造一帧：1280x720，但只跑中间几行看效果 =====
        // 从 y=95 到 y=310，覆盖红色框上下边界
        for (y = 95; y < 310; y = y + 1) begin
            i_user = (y == 95) ? 1'b1 : 1'b0;
            for (x = 0; x < 1280; x = x + 1) begin
                i_de = 1;
                i_hsync = (x < 100) ? 1'b0 : 1'b1;
                i_last = (x == 1279) ? 1'b1 : 1'b0;
                i_rd_data = 24'h808080;   // 原图灰色
                #13.468;                  // 74.25MHz 周期
            end
            i_de = 0;
            i_last = 0;
        end

        i_user = 0; i_de = 0;
        #1000;
        $stop;
    end

    // 打印框边界处输出的颜色
    always @(posedge clk) begin
        if (o_hdmi_de) begin
            if (o_hdmi_data == 24'hFF0000)
                $display("Time=%t, 红色框像素", $time);
            else if (o_hdmi_data == 24'h0000FF)
                $display("Time=%t, 蓝色框像素", $time);
        end
    end

endmodule