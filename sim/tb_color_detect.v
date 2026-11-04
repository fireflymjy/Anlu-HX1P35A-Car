`timescale 1ns / 1ps
//==========================================================================
// tb_color_detect - 4 通道 HSV 检测（动态参数版）
//==========================================================================
module tb_color_detect;

    reg         clk = 0, rst_n;
    reg  [95:0] tdata;
    reg         tvalid, tuser, tlast;
    reg  [10:0] x_grp, y_pos;

    // 动态参数
    reg  [7:0]  I_V_MIN      = 8'd30;
    reg  [7:0]  I_V_MAX_HI   = 8'd255;    // 不限制上限，避免 255 被拒
    reg  [3:0]  I_S_SHIFT    = 4'd1;      // S > 0.5
    reg  [3:0]  I_H_TAN_NUM  = 4'd2;      // ±16°
    reg  [3:0]  I_H_TAN_DEN  = 4'd7;
    reg  [7:0]  I_YEL_MIN_B  = 8'd100;
    reg  [15:0] I_MIN_PIXELS = 16'd4;

    wire [11:0] rxmin, rxmax, rymin, rymax;
    wire [31:0] rcnt, rxsum, rysum;
    wire        rvalid;
    wire [11:0] yxmin, yxmax, yymin, yymax;
    wire [31:0] ycnt, yxsum, yysum;
    wire        yvalid;
    wire [11:0] gxmin, gxmax, gymin, gymax;
    wire [31:0] gcnt, gxsum, gysum;
    wire        gvalid;
    wire [11:0] bxmin, bxmax, bymin, bymax;
    wire [31:0] bcnt, bxsum, bysum;
    wire        bvalid;

    always #5 clk = ~clk;   // 100MHz

    color_detect #(
        .IMG_WIDTH  (1280),
        .IMG_HEIGHT (720)
    ) dut (
        .I_clk(clk), .I_rst_n(rst_n),
        .I_tdata(tdata), .I_tvalid(tvalid), .I_tuser(tuser), .I_tlast(tlast),
        .I_x_grp(x_grp), .I_y_pos(y_pos),

        .I_V_MIN     (I_V_MIN),
        .I_V_MAX_HI  (I_V_MAX_HI),
        .I_S_SHIFT   (I_S_SHIFT),
        .I_H_TAN_NUM (I_H_TAN_NUM),
        .I_H_TAN_DEN (I_H_TAN_DEN),
        .I_YEL_MIN_B (I_YEL_MIN_B),
        .I_MIN_PIXELS(I_MIN_PIXELS),

        .O_red_x_min(rxmin), .O_red_x_max(rxmax),
        .O_red_y_min(rymin), .O_red_y_max(rymax),
        .O_red_cnt(rcnt), .O_red_xsum(rxsum), .O_red_ysum(rysum),
        .O_red_valid(rvalid),

        .O_yel_x_min(yxmin), .O_yel_x_max(yxmax),
        .O_yel_y_min(yymin), .O_yel_y_max(yymax),
        .O_yel_cnt(ycnt), .O_yel_xsum(yxsum), .O_yel_ysum(yysum),
        .O_yel_valid(yvalid),

        .O_grn_x_min(gxmin), .O_grn_x_max(gxmax),
        .O_grn_y_min(gymin), .O_grn_y_max(gymax),
        .O_grn_cnt(gcnt), .O_grn_xsum(gxsum), .O_grn_ysum(gysum),
        .O_grn_valid(gvalid),

        .O_blu_x_min(bxmin), .O_blu_x_max(bxmax),
        .O_blu_y_min(bymin), .O_blu_y_max(bymax),
        .O_blu_cnt(bcnt), .O_blu_xsum(bxsum), .O_blu_ysum(bysum),
        .O_blu_valid(bvalid)
    );

    integer errors = 0;

    //------------------------------------------------------------------
    // 驱动一组 4 像素
    //   LSB = 最左（pix0），MSB = 最右（pix3）
    //------------------------------------------------------------------
    task drv_grp;
        input [10:0] xg, yp;
        input [7:0] r0,g0,b0, r1,g1,b1, r2,g2,b2, r3,g3,b3;
        input        fs;     // frame_start (tuser)
        begin
            @(posedge clk);
            x_grp  <= xg;
            y_pos  <= yp;
            tdata  <= {r3,g3,b3, r2,g2,b2, r1,g1,b1, r0,g0,b0};
            tvalid <= 1'b1;
            tuser  <= fs;
            tlast  <= 1'b0;
        end
    endtask

    // 用下一帧的 tuser 触发 color_detect 内部的帧首发布
    task next_frame;
        begin
            @(posedge clk);
            tvalid <= 1'b0; tuser <= 1'b0; tlast <= 1'b0; tdata <= 96'd0;
            repeat(3) @(posedge clk);
            // 一个空拍带 tuser=1 & tvalid=1，让 frame_start 触发
            @(posedge clk);
            tvalid <= 1'b1; tuser <= 1'b1; tlast <= 1'b0; tdata <= 96'd0;
            @(posedge clk);
            tvalid <= 1'b0; tuser <= 1'b0;
            repeat(2) @(posedge clk);
        end
    endtask

    task chk;
        input        cond;
        input [255:0] name;
        begin
            if (!cond) begin
                $display("  [FAIL] %0s (t=%0t)", name, $time);
                errors = errors + 1;
            end else begin
                $display("  [PASS] %0s", name);
            end
        end
    endtask

    initial begin
        rst_n = 0;
        tdata = 96'd0; tvalid = 0; tuser = 0; tlast = 0;
        x_grp = 0; y_pos = 0;
        repeat(10) @(posedge clk); rst_n = 1;
        repeat(5)  @(posedge clk);

        //==================================================================
        // T1: 亮红 (240,0,0) × 12
        //==================================================================
        $display("\n=== T1: red (240,0,0) 12px ===");
        drv_grp(11'd0, 11'd0, 240,0,0, 240,0,0, 240,0,0, 240,0,0, 1'b1);  // 帧首
        drv_grp(11'd1, 11'd0, 240,0,0, 240,0,0, 240,0,0, 240,0,0, 1'b0);
        drv_grp(11'd2, 11'd0, 240,0,0, 240,0,0, 240,0,0, 240,0,0, 1'b0);
        next_frame;
        chk(rvalid === 1'b1,  "T1 red_valid");
        chk(rcnt   == 32'd12, "T1 red_cnt=12");
        chk(rxmin  == 12'd0,  "T1 x_min=0");
        chk(rxmax  == 12'd11, "T1 x_max=11");
        chk(rymin  == 12'd0,  "T1 y_min=0");
        chk(rymax  == 12'd0,  "T1 y_max=0");
        chk(yvalid === 1'b0,  "T1 yellow=0");
        chk(gvalid === 1'b0,  "T1 green=0");
        chk(bvalid === 1'b0,  "T1 blue=0");

        //==================================================================
        // T2: 纯黄 (240,240,0) × 8
        //==================================================================
        $display("\n=== T2: yellow (240,240,0) 8px ===");
        drv_grp(11'd0, 11'd10, 240,240,0, 240,240,0, 240,240,0, 240,240,0, 1'b1);
        drv_grp(11'd1, 11'd10, 240,240,0, 240,240,0, 240,240,0, 240,240,0, 1'b0);
        next_frame;
        chk(yvalid === 1'b1,  "T2 yellow_valid");
        chk(ycnt   == 32'd8,  "T2 yellow_cnt=8");
        chk(yymin  == 12'd10, "T2 yellow_y_min=10");
        chk(rvalid === 1'b0,  "T2 red=0");

        //==================================================================
        // T3: 纯绿 (0,240,0) × 8
        //==================================================================
        $display("\n=== T3: green (0,240,0) 8px ===");
        drv_grp(11'd3, 11'd20, 0,240,0, 0,240,0, 0,240,0, 0,240,0, 1'b1);
        drv_grp(11'd4, 11'd20, 0,240,0, 0,240,0, 0,240,0, 0,240,0, 1'b0);
        next_frame;
        chk(gvalid === 1'b1,  "T3 green_valid");
        chk(gcnt   == 32'd8,  "T3 green_cnt=8");
        chk(gymin  == 12'd20, "T3 green_y_min=20");
        chk(gxmin  == 12'd12, "T3 green_x_min=12");
        chk(gxmax  == 12'd19, "T3 green_x_max=19");

        //==================================================================
        // T4: 纯蓝 (0,0,240) × 8
        //==================================================================
        $display("\n=== T4: blue (0,0,240) 8px ===");
        drv_grp(11'd5, 11'd30, 0,0,240, 0,0,240, 0,0,240, 0,0,240, 1'b1);
        drv_grp(11'd6, 11'd30, 0,0,240, 0,0,240, 0,0,240, 0,0,240, 1'b0);
        next_frame;
        chk(bvalid === 1'b1,  "T4 blue_valid");
        chk(bcnt   == 32'd8,  "T4 blue_cnt=8");
        chk(bymin  == 12'd30, "T4 blue_y_min=30");

        //==================================================================
        // T5: 中性灰 (150,150,150) → 全部拒绝
        //==================================================================
        $display("\n=== T5: gray (150,150,150) → reject all ===");
        drv_grp(11'd0, 11'd0, 150,150,150, 150,150,150, 150,150,150, 150,150,150, 1'b1);
        drv_grp(11'd1, 11'd0, 150,150,150, 150,150,150, 150,150,150, 150,150,150, 1'b0);
        next_frame;
        chk(rvalid === 1'b0, "T5 gray no red");
        chk(yvalid === 1'b0, "T5 gray no yellow");
        chk(gvalid === 1'b0, "T5 gray no green");
        chk(bvalid === 1'b0, "T5 gray no blue");

        $display("\n=============================================");
        $display("  Errors = %0d", errors);
        if (errors == 0) $display("  >>> ALL PASS <<<");
        else             $display("  >>> FAILED <<<");
        $display("=============================================");
        $finish;
    end

    initial begin
        #1_000_000;
        $display("[TIMEOUT]");
        $finish;
    end

endmodule