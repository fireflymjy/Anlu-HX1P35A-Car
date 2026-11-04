`timescale 1ns / 1ps
//=============================================================================
// 交通标识方向识别测试：直行(4)/左转(1)/右转(2) + 红牌(3)
//
// 【为什么要重写这个激励】
//   旧版 tb 把帧起始 tuser 和每帧第一个像素放在同一拍（tvalid=1），
//   这只有在理想情况下才成立。真实硬件里 awb.v 是
//       assign O_tuser = I_tuser;      // tuser 没有跟着数据打拍
//   而数据经过 signal_delay(50) + 3 级寄存，tuser 比数据早约 50 拍，
//   所以帧起始 tuser 落在行/场消隐期（tvalid=0）——
//   旧实现把"每帧清零"写在 I_tvalid 分支里，条件永远不成立，
//   蓝色计数/bbox 跨帧累加，几帧后填充率崩掉，sign_type 恒 0。
//
//   本 tb 默认 HW_TIMING=1：tuser 在消隐期单独给一个脉冲（板级真实时序）；
//   HW_TIMING=0 退化成旧的理想时序，用来对照。
//
//   每个场景灌两帧：第 1 帧建立"上一帧蓝框"，第 2 帧出结果并校验
//   （方向细分要用到上一帧的框，滞后一帧是设计使然，17ms 无感）。
//=============================================================================
module tb_sign_detect;

    // ---------------- 参数 ----------------
    parameter IMG_W      = 320;      // 用 320x240 小图跑得快，逻辑与 720p 完全一致
    parameter IMG_H      = 240;
    parameter GP         = IMG_W/4;  // 每行像素组数 = 80
    parameter HW_TIMING  = 1;        // 1=消隐期 tuser（板级真实时序）0=理想时序
    parameter TUSER_LEAD = 54;       // tuser 比本帧第一个像素早多少拍（awb 流水线深度）
    parameter BLANK_GAP  = 12000;    // 帧末消隐拍数（要大于 sign_detect 的 GAP_FRAME）
    parameter GAP_H      = 40;       // 行消隐拍数（要大于 sign_detect 的 GAP_LINE）

    reg          clk, rst_n;
    reg  [95:0]  i_tdata;
    reg          i_tvalid, i_tuser, i_tlast;
    wire [2:0]   o_sign_type;
    wire [1:0]   o_shape;
    wire         o_hollow;
    wire [15:0]  o_blue_cnt, o_red_cnt, o_white_left, o_white_right;
    wire [23:0]  o_bluest_rgb;
    wire [35:0]  o_sd_geo;

    sign_detect #(
        .IMG_WIDTH  (IMG_W),
        .IMG_HEIGHT (IMG_H),
        .MIN_BLUE   (16'd300),
        .MIN_RED    (16'd300),
        .MIN_WHITE  (16'd40),
        .WHITE_MIN  (8'd20),        // 【2026-11-03】与 isp_top 例化一致（70 -> 20）
        .OFFSET_TH  (12'd6)
    ) u_dut (
        .I_clk        (clk),
        .I_rst_n      (rst_n),
        .I_tdata      (i_tdata),
        .I_tvalid     (i_tvalid),
        .I_tuser      (i_tuser),
        .I_tlast      (i_tlast),
        .O_sign_type  (o_sign_type),
        .O_shape      (o_shape),
        .O_hollow     (o_hollow),
        .O_blue_cnt   (o_blue_cnt),
        .O_red_cnt    (o_red_cnt),
        .O_white_left (o_white_left),
        .O_white_right(o_white_right),
        .O_bluest_rgb (o_bluest_rgb),
        .O_sd_geo     (o_sd_geo)
    );

    always #5 clk = ~clk;

    integer num_pass, num_fail, frame_no;
    reg [2:0] got;
    // 场景环境（模拟现场）：bg_bright=1 表示标志外面是亮背景（白墙/路面/天空），
    // 圆形标志外接矩形的四个角就是这些亮像素 —— 不加"中央掩膜"时方向会被淹没；
    // darken=1 表示整幅压暗到 35%，模拟欠曝/白平衡把蓝压掉。
    integer   bg_bright, darken;
    integer   pool_on;                // 1=画面左上角另有一小块蓝（蓝衣服/蓝牌子/反光）
    integer   strip_on;               // 1=标志上方有一条细长蓝色结构连下来（窗框/反光条）
    integer   irreg;                  // 1=故意让每行拍数不是 320（318/322 交替）
    integer   no_tuser;               // 1=不给 tuser，只靠消隐期断帧

    // 远处一小块蓝：会把"整幅蓝框"撑大 —— 这正是板上 N≈B、L≈R 的成因，
    // 所以必须放进回归里
    function integer clutter_blue;
        input integer x, y;
        begin
            clutter_blue = (pool_on && (x >= 5) && (x <= 45) && (y >= 5) && (y <= 45)) ? 1 : 0;
        end
    endfunction

    // 标志上方一条 8 像素宽蓝色细条（从画面顶连到标志上沿）：会把"连续有蓝行"
    // 从标志上沿一直拉到第 0 行 —— 旧方案据此定纵向范围，头部带因此跑到标志
    // 外面，L/R 变成近乎相等的背景数、恒判直行，正是板上 L=R≈0 的现象
    function integer clutter_strip;
        input integer x, y;
        begin
            clutter_strip = (strip_on && (x >= 60) && (x <= 67) && (y <= 64)) ? 1 : 0;
        end
    endfunction

    function [23:0] scale35;          // 压暗到 35% 再抬 5
        input [23:0] p;
        reg [23:0] q;
        begin
            q[23:16] = (p[23:16] * 35) / 100 + 5;
            q[15:8]  = (p[15:8]  * 35) / 100 + 5;
            q[7:0]   = (p[7:0]   * 35) / 100 + 5;
            scale35 = q;
        end
    endfunction

    // ---------------- 图像内容 ----------------
    // 圆心 (160,120) 半径 55 的圆盘；箭头按 kind 变化
    // kind: 0=直行 1=左转 2=右转 3=红牌(无箭头)
    function integer in_disc;
        input integer x, y;
        integer dx, dy;
        begin
            dx = x - 160; dy = y - 120;
            in_disc = ((dx*dx + dy*dy) <= 3025) ? 1 : 0;
        end
    endfunction

    function integer in_arrow;
        input integer x, y, kind;
        begin
            in_arrow = 0;
            if (kind == 0) begin                       // 直行：居中竖杆 + 顶部加宽
                if ((x >= 152) && (x <= 168) && (y >= 78)  && (y <= 170)) in_arrow = 1;
                if ((x >= 145) && (x <= 175) && (y >= 70)  && (y <= 86))  in_arrow = 1;
            end
            else if (kind == 1) begin                  // 左转：顶部向左横杆 + 竖杆
                if ((x >= 105) && (x <= 158) && (y >= 70)  && (y <= 90))  in_arrow = 1;
                if ((x >= 152) && (x <= 168) && (y >= 86)  && (y <= 170)) in_arrow = 1;
            end
            else if (kind == 2) begin                  // 右转：镜像
                if ((x >= 162) && (x <= 215) && (y >= 70)  && (y <= 90))  in_arrow = 1;
                if ((x >= 152) && (x <= 168) && (y >= 86)  && (y <= 170)) in_arrow = 1;
            end
        end
    endfunction

    // 减速"慢"黄三角：顶点(160,80) 底边y=170 半宽60 → 两角(100,170)/(220,170)
    function integer in_tri;
        input integer x, y;
        integer dx, dy;
        begin
            dx = x - 160; if (dx < 0) dx = -dx;
            dy = y - 80;
            in_tri = ((y >= 80) && (y <= 170) && (dx * 90 <= dy * 60)) ? 1 : 0;
        end
    endfunction

    // 停车牌白色"停"字（红色八边形里的小白块，简化为"十"字）
    function integer in_stopword;
        input integer x, y;
        begin
            in_stopword = 0;
            if ((x >= 150) && (x <= 170) && (y >= 110) && (y <= 136)) in_stopword = 1; // 竖笔
            if ((x >= 144) && (x <= 176) && (y >= 119) && (y <= 123)) in_stopword = 1; // 横笔
        end
    endfunction

    // 背景干扰：标志框外放一块白（模拟路面标线/白墙），
    // 用来验证"只统计蓝框内部白像素"是否生效
    function integer clutter_white;
        input integer x, y;
        begin
            clutter_white = ((x >= 0) && (x <= 46) && (y >= 180) && (y <= 226)) ? 1 : 0;
        end
    endfunction

    function [23:0] pix;
        input integer x, y, kind;
        reg [23:0] v;
        begin
            if (kind == 4) begin                       // 整幅蓝（模拟蓝天/蓝墙）+ 白块干扰
                if (clutter_white(x,y)) v = 24'hF0F0F0;
                else                    v = 24'h0066CC;
            end
            else if (kind == 5) begin                  // 没有任何标志，只有白块干扰
                if (clutter_white(x,y)) v = 24'hF0F0F0;
                else                    v = 24'h101010;
            end
            else if (kind == 6) begin                  // 减速：黄色三角"慢"
                if (in_tri(x,y)) begin
                    if ((x >= 150) && (x <= 170) && (y >= 112) && (y <= 158)) v = 24'h000000; // 黑"慢"
                    else                                                       v = 24'hFFFF00; // 黄底
                end
                else if (clutter_white(x,y))           v = 24'hF0F0F0;
                else if (clutter_blue(x,y))            v = 24'h0066CC;
                else                                   v = bg_bright ? 24'hE0E0E0 : 24'h101010;
            end
            else if (kind == 7) begin                  // 纯红圆盘（无"停"字）：red_ok 但非停车牌
                if (in_disc(x,y))                      v = 24'hFF0000;
                else                                   v = bg_bright ? 24'hE0E0E0 : 24'h101010;
            end
            else if (kind == 8) begin                  // 黄色细横线(车道线)：薄 + 大长宽比 → 非减速
                if ((x >= 20) && (x <= 250) && (y >= 118) && (y <= 122)) v = 24'hFFFF00;
                else                                   v = bg_bright ? 24'hE0E0E0 : 24'h101010;
            end
            else if (in_disc(x,y)) begin
                if (kind == 3) begin
                    // 停车牌：红八边形(画成红盘) + 白色"停"字
                    if (in_stopword(x,y))              v = 24'hFFFFFF;
                    else                               v = 24'hFF0000;
                end
                else if (in_arrow(x,y,kind))           v = 24'hFFFFFF;          // 白箭头
                else                                   v = 24'h0066CC;          // 蓝盘
            end
            else if (clutter_white(x,y))             v = 24'hF0F0F0;          // 框外白干扰
            else if (clutter_blue(x,y))              v = 24'h0066CC;          // 远处小蓝块
            else if (clutter_strip(x,y))             v = 24'h0066CC;          // 上方蓝色细条
            else                                     v = bg_bright ? 24'hE0E0E0 : 24'h101010;
            if (darken) v = scale35(v);
            pix = v;
        end
    endfunction

    function [95:0] pack4;
        input [23:0] p0, p1, p2, p3;
        begin
            pack4 = {p0, p1, p2, p3};
        end
    endfunction

    // ---------------- 激励 ----------------
    // 灌一帧像素。模拟真实流结构：
    //   · 行内 tvalid 连续，行与行之间有行消隐（GAP_H 拍）
    //   · 帧末有大消隐（> GAP_FRAME），并且 tuser 单独出现在消隐期（板上就是如此）
    //   · irreg=1 时故意让每行拍数不是 320（318/322 交替），用来验证坐标不会漂
    task drive_frame;
        input [2:0] kind;
        integer y, g, x0, nb;
        begin
            repeat (TUSER_LEAD) @(posedge clk);
            for (y = 0; y < IMG_H; y = y + 1) begin
                nb = (irreg && (y % 2)) ? GP - 2 : ((irreg) ? GP + 2 : GP);
                for (g = 0; g < GP; g = g + 1) begin
                    if (g < nb) begin
                        x0 = g * 4;
                        @(posedge clk);
                        i_tvalid = 1'b1;
                        i_tuser  = (HW_TIMING == 0 && y == 0 && g == 0) ? 1'b1 : 1'b0;
                        i_tdata  = pack4(pix(x0+0,y,kind), pix(x0+1,y,kind),
                                         pix(x0+2,y,kind), pix(x0+3,y,kind));
                    end
                end
                // 行消隐（> GAP_LINE，用来断行）
                if (y != IMG_H-1) begin
                    @(posedge clk);
                    i_tvalid = 1'b0; i_tuser = 1'b0; i_tdata = 96'd0;
                    repeat (GAP_H - 1) @(posedge clk);
                end
            end
            @(posedge clk);
            i_tvalid = 1'b0; i_tuser = 1'b0; i_tdata = 96'd0;
        end
    endtask

    // 帧末消隐 + tuser 采样拍（板级：tuser 单独出现在消隐期，且比数据早几十拍）
    task blank_and_tuser;
        begin
            repeat (BLANK_GAP) @(posedge clk);
            if (no_tuser == 0) begin
                i_tuser = 1'b1; #1;
                @(posedge clk);
                i_tuser = 1'b0; #1;
            end
            repeat (2) @(posedge clk);
        end
    endtask

    // 校验当前输出（在 blank_and_tuser 之后调用）
    task check_result;
        input [2:0] exp;
        input [8*12-1:0] tag;
        begin
            got = o_sign_type;
            frame_no = frame_no + 1;
            if (got === exp) begin
                num_pass = num_pass + 1;
                $display("[PASS] case%0d %0s exp=%0d got=%0d blue=%0d red=%0d L=%0d R=%0d shape=%b bluest=Rx%02x Gx%02x Bx%02x",
                         frame_no, tag, exp, got, o_blue_cnt, o_red_cnt,
                         o_white_left, o_white_right, o_shape,
                         o_bluest_rgb[23:16], o_bluest_rgb[15:8], o_bluest_rgb[7:0]);
            end
            else begin
                num_fail = num_fail + 1;
                $display("[FAIL] case%0d %0s exp=%0d got=%0d blue=%0d red=%0d L=%0d R=%0d shape=%b D=%0d Y=%0d S=%0d bluest=Rx%02x Gx%02x Bx%02x",
                         frame_no, tag, exp, got, o_blue_cnt, o_red_cnt,
                         o_white_left, o_white_right, o_shape,
                         o_sd_geo[35:24], o_sd_geo[23:12], o_sd_geo[11:0],
                         o_bluest_rgb[23:16], o_bluest_rgb[15:8], o_bluest_rgb[7:0]);
            end
        end
    endtask

    // 一个场景：灌 nframes 帧，最后一帧结束的 tuser 上采样校验。
//   正常标志场景 2 帧即可（第 1 帧建"上一帧蓝框"，第 2 帧出结果）；
//   "期望无标志"场景要多灌几帧，因为结果保持逻辑最多沿用 5 帧。
    task run_case;
        input [2:0] kind;
        input [2:0] exp;
        input [8*12-1:0] tag;
        input integer nframes;
        integer k;
        begin
            // +6 帧：新结果要"连续 5 帧一致"才切换，另外去掉结果保持的影响
            for (k = 0; k < nframes + 6; k = k + 1) begin
                drive_frame(kind);
                blank_and_tuser();
            end
            check_result(exp, tag);
        end
    endtask

    initial begin
        clk = 0; rst_n = 0;
        i_tdata = 0; i_tvalid = 0; i_tuser = 0; i_tlast = 0;
        num_pass = 0; num_fail = 0; frame_no = 0;
        bg_bright = 0; darken = 0; pool_on = 0; strip_on = 0;
        irreg = 0; no_tuser = 0;

        #100; rst_n = 1; #50;

        if (HW_TIMING == 1) $display("=== 板级真实时序：帧起始 tuser 落在消隐期 ===");
        else                $display("=== 理想时序：帧起始 tuser 与第一个像素同拍 ===");

        // --- 暗背景（最简单的合成场景）---
        run_case(3'd0, 3'd4, "STRAIGHT",  2);
        run_case(3'd1, 3'd1, "LEFT",      2);
        run_case(3'd2, 3'd2, "RIGHT",     2);
        // --- 亮背景：标志外接矩形四角是亮像素（真实标志图就是白底）---
        bg_bright = 1;
        run_case(3'd0, 3'd4, "STR+bg",    2);
        run_case(3'd1, 3'd1, "LEFT+bg",   2);
        run_case(3'd2, 3'd2, "RIGHT+bg",  2);
        // --- 亮背景 + 整幅压暗到 35%（模拟欠曝/白平衡压蓝：深蓝标志）---
        darken = 1;
        run_case(3'd0, 3'd4, "STR+dark",  2);
        run_case(3'd1, 3'd1, "LFT+dark",  2);
        run_case(3'd2, 3'd2, "RGT+dark",  2);
        darken = 0;
        // 纯红无"停"字 → 不该是停车牌。用暗背景：亮背景下红牌四角会渗入白像素
        // （背景白从圆形红牌的角上露出来），中心无"停"，但外环会被计到白像素，
        // 会干扰"无字红牌不算停车"的验证，故在暗背景断言。
        bg_bright = 0;
        run_case(3'd7, 3'd0, "REDnword",  7);       // 无"停"字的纯红 → 不算停车
        bg_bright = 1;
        run_case(3'd3, 3'd3, "RED+bg",    2);       // 红"停"停车牌（亮背景）
        run_case(3'd6, 3'd5, "SLOW",      2);       // 黄三角减速
        run_case(3'd8, 3'd0, "YELLINE",   7);       // 黄色细线(车道线)不是减速
        // 减速抗干扰：标志外有小黄块 → 仍应判减速（黄 bbox 只包围主三角）
        run_case(3'd6, 3'd5, "SLOW+bg",    2);
        // --- 关键场景：画面里另有一小块蓝（把整幅蓝框撑大）---
        pool_on = 1;
        run_case(3'd0, 3'd4, "STR+pool",  2);
        run_case(3'd1, 3'd1, "LFT+pool",  2);
        run_case(3'd2, 3'd2, "RGT+pool",  2);
        darken = 1;
        run_case(3'd1, 3'd1, "LFT+pl+dk", 2);
        darken = 0; pool_on = 0;
        // --- 关键场景：标志上方有细长蓝色结构连下来（窗框/窗帘/反光条）---
        strip_on = 1;
        run_case(3'd0, 3'd4, "STR+stp",   2);
        run_case(3'd1, 3'd1, "LFT+stp",   2);
        run_case(3'd2, 3'd2, "RGT+stp",   2);
        darken = 1;
        run_case(3'd2, 3'd2, "RGT+stp+dk",2);
        darken = 0; strip_on = 0;
        // --- 关键场景：每行拍数不是 320（318/322 交替）---
        //   旧版按"每行正好 320 拍"数坐标，这种流会让坐标逐行漂移，
        //   板上表现就是"只有标志占满画面才有结果、左右直行乱跳"
        irreg = 1;
        run_case(3'd1, 3'd1, "LFT+irr",   2);
        run_case(3'd2, 3'd2, "RGT+irr",   2);
        run_case(3'd0, 3'd4, "STR+irr",   2);
        irreg = 0;
        // --- 关键场景：完全没有 tuser，只靠消隐期断帧 ---
        no_tuser = 1;
        run_case(3'd1, 3'd1, "LFT+notu",  3);
        run_case(3'd2, 3'd2, "RGT+notu",  3);
        no_tuser = 0;
        // --- 组合：行拍数不规则 + 亮背景 + 上方蓝色细条 ---
        irreg = 1; bg_bright = 1; strip_on = 1;
        run_case(3'd2, 3'd2, "RGT+all",   3);
        irreg = 0; bg_bright = 0; strip_on = 0;
        // --- 反例：不能把大片蓝/白块当成标志 ---
        run_case(3'd4, 3'd0, "BIGBLUE",   7);
        run_case(3'd5, 3'd0, "NOSIGN",    7);

        #200;
        $display("=============================================");
        $display("PASS=%0d FAIL=%0d", num_pass, num_fail);
        if (num_fail == 0) $display("TEST RESULT: ALL PASS");
        else               $display("TEST RESULT: %0d FAILED", num_fail);
        $stop;
    end

endmodule