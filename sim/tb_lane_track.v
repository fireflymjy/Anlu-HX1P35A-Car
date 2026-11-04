`timescale 1ns / 1ps
// ============================================================================
// tb_lane_track —— 新 lane_detect（三段扫描 + 预瞄航向 + 丢线外推）自检仿真
//   不喂图像，直接按几何造"边缘流"：每行 320 拍、1 group = 4 像素、每拍 4 像素，
//   黑线只造两条边（左边界 2px + 右边界 2px），与真实边缘图一致。
//   每个场景：连跑 2 帧（第 1 帧让跟踪窗自启动），帧首脉冲后立刻比对结果。
// ============================================================================
module tb_lane_track;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #5 clk = ~clk;              // 100MHz，功能验证够用

    reg  [95:0] edge_data;
    reg         edge_valid;
    reg         edge_user;
    reg  [11:0] x_grp, y_pos;

    wire [11:0] o_center, o_offset, o_heading, o_width;
    wire        o_valid, o_lost;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    lane_detect #(
        .IMG_WIDTH (1280), .IMG_HEIGHT(720),
        .Y_FAR_A   (300),  .Y_FAR_B  (340),
        .Y_MID_A   (420),  .Y_MID_B  (460),
        .Y_NEAR_A  (620),  .Y_NEAR_B (660),
        .MIN_EDGE  (16'd8),
        .WIN       (10'd200),
        .MAX_W     (10'd120)
    ) dut (
        .I_clk        (clk),
        .I_rst_n      (rst_n),
        .I_edge_data  (edge_data),
        .I_edge_valid (edge_valid),
        .I_edge_user  (edge_user),
        .I_x_grp      (x_grp),
        .I_y_pos      (y_pos),
        .O_lane_center(o_center),
        .O_lane_offset(o_offset),
        .O_lane_heading(o_heading),
        .O_lane_width (o_width),
        .O_lane_valid (o_valid),
        .O_lane_lost  (o_lost)
    );

    // ---- 一致线模型：第 y 行线中心 xc(y) = cx0 + sl*(y-360)/100，线宽 w ----
    function [95:0] make_beat;
        input integer y;
        input integer g;
        input integer cx0;
        input integer sl;
        input integer w;
        input integer ymin;
        input integer full;              // 1 = 整行都是边（十字/大面积）
        integer xc, xl, xr, k, px;
        reg [95:0] d;
        begin
            d = 96'd0;
            if (full == 1) begin
                d = {96{1'b1}};
            end
            else if (y >= ymin) begin
                xc = cx0 + (sl * (y - 360)) / 100;
                xl = xc - (w / 2);
                xr = xc + (w / 2);
                for (k = 0; k < 4; k = k + 1) begin
                    px = g * 4 + k;
                    if (((px >= xl) && (px <= xl + 1)) ||
                        ((px >= xr - 1) && (px <= xr))) begin
                        case (k)
                            0: d[95:72] = 24'hFFFFFF;
                            1: d[71:48] = 24'hFFFFFF;
                            2: d[47:24] = 24'hFFFFFF;
                            default: d[23:0] = 24'hFFFFFF;
                        endcase
                    end
                end
            end
            make_beat = d;
        end
    endfunction

    integer y, g;
    integer i;

    // ---- 流一整帧的数据（不含帧首脉冲）----
    task stream_rows;
        input integer cx0, sl, w, ymin, full;
        begin
            for (y = 0; y < 720; y = y + 1) begin
                // 只流三个扫描段所在的行（模块按 I_y_pos 分段，不依赖行连续）
                // 这样一帧从 23 万拍降到 3.8 万拍，仿真快 6 倍
                if (((y >= 300) && (y <= 340)) || ((y >= 420) && (y <= 460)) ||
                    ((y >= 620) && (y <= 660))) begin
                    for (g = 0; g < 320; g = g + 1) begin
                        edge_data  = make_beat(y, g, cx0, sl, w, ymin, full);
                        edge_valid = 1'b1;
                        y_pos      = y[11:0];
                        x_grp      = g[11:0];
                        @(negedge clk);
                    end
                end
            end
            edge_valid = 1'b0;
            edge_data  = 96'd0;
            repeat (3) @(negedge clk);
        end
    endtask

    // ---- 帧首脉冲：模块在这一拍结算上一帧并更新输出 ----
    task start_pulse;
        begin
            edge_user  = 1'b1;
            edge_valid = 1'b0;
            @(negedge clk);
            edge_user  = 1'b0;
            repeat (3) @(negedge clk);
        end
    endtask

    integer off_v, hd_v;

    task check;
        input [8*40:1] name;
        input integer e_off, e_hd, e_lost, e_valid, tol;
        begin
            off_v = $signed(o_offset);
            hd_v  = $signed(o_heading);
            if ((o_valid === e_valid[0]) && (o_lost === e_lost[0]) &&
                (off_v >= e_off - tol) && (off_v <= e_off + tol) &&
                (hd_v  >= e_hd  - tol) && (hd_v  <= e_hd  + tol)) begin
                pass_cnt = pass_cnt + 1;
                $display("PASS  %0s  offset=%0d(exp %0d) heading=%0d(exp %0d) lost=%b valid=%b width=%0d",
                         name, off_v, e_off, hd_v, e_hd, o_lost, o_valid, o_width);
            end
            else begin
                fail_cnt = fail_cnt + 1;
                $display("FAIL  %0s  offset=%0d(exp %0d) heading=%0d(exp %0d) lost=%b(exp %b) valid=%b(exp %b) width=%0d",
                         name, off_v, e_off, hd_v, e_hd, o_lost, e_lost, o_valid, e_valid, o_width);
            end
        end
    endtask

    initial begin
        edge_data = 96'd0; edge_valid = 1'b0; edge_user = 1'b0;
        x_grp = 12'd0; y_pos = 12'd0;
        rst_n = 1'b0;
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (5) @(negedge clk);

        // ================= S1 直线居中（xc=640，斜率 0，线宽 24px）=================
        //   期望：offset≈0、heading≈0、lost=0、valid=1
        stream_rows(640, 0, 24, 0, 0); start_pulse;   // 第1帧：窗口自启动
        stream_rows(640, 0, 24, 0, 0); start_pulse;   // 第2帧
        check("S1 straight center  ", 0, 0, 0, 1, 8);

        // ================= S2 直线右偏 200px（xc=840）=================
        stream_rows(840, 0, 24, 0, 0); start_pulse;
        stream_rows(840, 0, 24, 0, 0); start_pulse;
        check("S2 offset +200px   ", 200, 0, 0, 1, 8);

        // ================= S3 均匀弯道（每行 +0.5px）=================
        //   远段(y=320) xc≈620 → 近段(y=640) xc≈780
        //   期望：offset≈+140、heading≈-160、lost=0、valid=1
        stream_rows(640, 50, 24, 0, 0); start_pulse;
        stream_rows(640, 50, 24, 0, 0); start_pulse;
        check("S3 curve (preview) ", 140, -160, 0, 1, 20);

        // ================= S4 急弯：远段无线 + 近段在快速漂移 =================
        //   线只存在于 y>=400，远段(300~340)什么都没有 → lost=1
        //   先让近段稳定在 800，再跳到 900 → 漂移 +100/帧 → 外推远段 ≈ +200
        stream_rows(800, 0, 24, 400, 0); start_pulse;
        stream_rows(800, 0, 24, 400, 0); start_pulse;
        stream_rows(900, 0, 24, 400, 0); start_pulse;
        //   检查"方向正确且外推生效"（正值=向右弯）
        if ((o_lost === 1'b1) && (o_valid === 1'b1) && ($signed(o_heading) >= 100)) begin
            pass_cnt = pass_cnt + 1;
            $display("PASS  S4 sharp turn extrapolate  offset=%0d heading=%0d lost=%b valid=%b",
                     $signed(o_offset), $signed(o_heading), o_lost, o_valid);
        end
        else begin
            fail_cnt = fail_cnt + 1;
            $display("FAIL  S4 sharp turn extrapolate  offset=%0d heading=%0d lost=%b valid=%b (exp lost=1 valid=1 heading>=100)",
                     $signed(o_offset), $signed(o_heading), o_lost, o_valid);
        end

        // ================= S5 整行都是边（十字/大面积黑）=================
        //   线宽闸门应把三段全判无效 → valid=0、lost=1
        stream_rows(640, 0, 24, 0, 1); start_pulse;
        stream_rows(640, 0, 24, 0, 1); start_pulse;
        check("S5 wide edge (cross)", $signed(o_offset), $signed(o_heading), 1, 0, 2000);

        // ================= S6 完全没有线 =================
        stream_rows(640, 0, 0, 720, 0); start_pulse;   // ymin=720 → 整帧无线
        stream_rows(640, 0, 0, 720, 0); start_pulse;
        check("S6 no line         ", $signed(o_offset), $signed(o_heading), 1, 0, 2000);

        $display("--------------------------------------------------");
        $display("  lane_detect sim:  PASS=%0d  FAIL=%0d", pass_cnt, fail_cnt);
        $display("--------------------------------------------------");
        if (fail_cnt == 0) $display("ALL PASS");
        else               $display("SOME FAILED");
        $finish;
    end

    initial begin
        #120000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule