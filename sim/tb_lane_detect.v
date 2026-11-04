`timescale 1ns / 1ps
// ============================================================================
// 【注意】本文件是旧激励，已过期：只做了"端口/参数对齐"以保证全工程可编译，
//   结论请勿采信。新版本的验证请看 tb_lane_track.v / tb_decision_arbiter_v2.v。
// ============================================================================

module tb_lane_detect;

    (* keep = "true" *) reg         clk, rst_n;
    (* keep = "true" *) reg  [95:0] i_edge_data;
    (* keep = "true" *) reg         i_edge_valid, i_edge_user;
    (* keep = "true" *) reg  [10:0] i_x_grp, i_y_pos;
    (* keep = "true" *) wire [11:0] o_lane_center, o_lane_offset;
    (* keep = "true" *) wire [11:0] o_lane_heading, o_lane_width;
    (* keep = "true" *) wire        o_lane_lost;
    (* keep = "true" *) wire        o_lane_valid;

    lane_detect #(
        .IMG_WIDTH  (1280),
        .IMG_HEIGHT (720),
        .Y_FAR_A       (300)      ,
        .Y_FAR_B       (340)      ,
        .MIN_EDGE      (16'd8)        // 测试用小阈值
    ) u_dut (
        .I_clk         (clk),
        .I_rst_n       (rst_n),
        .I_edge_data   (i_edge_data),
        .I_edge_valid  (i_edge_valid),
        .I_edge_user   (i_edge_user),
        .I_x_grp       (i_x_grp),
        .I_y_pos       (i_y_pos),
        .O_lane_center (o_lane_center),
        .O_lane_offset (o_lane_offset),
                .O_lane_valid  (o_lane_valid),
        .O_lane_heading(o_lane_heading),
        .O_lane_width  (o_lane_width),
        .O_lane_lost   (o_lane_lost)
    );

    always #5 clk = ~clk;

    // 打包 4 像素
    // 白色 = 24'hFFFFFF（边缘）
    // 黑色 = 24'h000000（非边缘）
    function [95:0] pack4_edge;
        input e0, e1, e2, e3;
        begin
            pack4_edge = {
                e0 ? 24'hFFFFFF : 24'h000000,
                e1 ? 24'hFFFFFF : 24'h000000,
                e2 ? 24'hFFFFFF : 24'h000000,
                e3 ? 24'hFFFFFF : 24'h000000
            };
        end
    endfunction

    integer x, y;
    initial begin
        clk = 0; rst_n = 0;
        i_edge_data = 0;
        i_edge_valid = 0;
        i_edge_user = 0;
        i_x_grp = 0;
        i_y_pos = 0;

        #100; rst_n = 1; #50;

        // ===== 造一帧：只在 y=500~620 范围做文章 =====
        // 车道线：
        //   左车道线：x_grp = 80  （对应 x = 320）
        //   右车道线：x_grp = 240 （对应 x = 960）
        // 其他位置：全黑
        for (y = 0; y < 720; y = y + 1) begin
            i_edge_user = (y == 0) ? 1'b1 : 1'b0;

            for (x = 0; x < 320; x = x + 1) begin
                i_edge_valid = 1;
                i_x_grp = x[10:0];
                i_y_pos = y[10:0];

                // 只在 ROI 范围内，且只在 x_grp=80 或 240 处有边缘
                if (y >= 500 && y <= 620) begin
                    if (x == 80 || x == 240)
                        i_edge_data = pack4_edge(1, 1, 1, 1);   // 全白
                    else
                        i_edge_data = pack4_edge(0, 0, 0, 0);   // 全黑
                end
                else begin
                    i_edge_data = pack4_edge(0, 0, 0, 0);
                end

                #10;
            end
        end

        i_edge_valid = 0;
        i_edge_user = 0;

        // 补一个 tuser 脉冲触发结果输出
        #100;
        i_edge_user = 1; #10; i_edge_user = 0; #10;

        #200;

        // 期望：
        //   左车道线 x = 80 * 4 = 320
        //   右车道线 x = 240 * 4 = 960
        //   车道中心 = (320+960)/2 = 640
        //   偏移量 = 640 - 640 = 0
        $display("=== 车道检测结果 ===");
        $display("lane_center=%d  lane_offset=%d  lane_valid=%d",
                 o_lane_center, o_lane_offset, o_lane_valid);
        $display("期望：lane_center=640, lane_offset=0, lane_valid=1");

        #200;
        $stop;
    end

endmodule