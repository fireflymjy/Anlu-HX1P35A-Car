`timescale 1ns / 1ps
//==========================================================================
// tb_target_tracker - 4 通道质心 + bbox 中心
//==========================================================================
module tb_target_tracker;

    reg         clk = 0, rst_n;
    reg         frame_start;

    reg         rv, yv, gv, bv;
    reg [11:0]  r_xmin, r_xmax, r_ymin, r_ymax;
    reg [31:0]  r_xsum, r_ysum, r_cnt;
    reg [11:0]  y_xmin, y_xmax, y_ymin, y_ymax;
    reg [31:0]  y_xsum, y_ysum, y_cnt;
    reg [11:0]  g_xmin, g_xmax, g_ymin, g_ymax;
    reg [31:0]  g_xsum, g_ysum, g_cnt;
    reg [11:0]  b_xmin, b_xmax, b_ymin, b_ymax;
    reg [31:0]  b_xsum, b_ysum, b_cnt;

    wire [11:0] rcx, rcy, rbx, rby;
    wire        rtv;
    wire [11:0] ycx, ycy, ybx, yby;
    wire        ytv;
    wire [11:0] gcx, gcy, gbx, gby;
    wire        gtv;
    wire [11:0] bcx, bcy, bbx, bby;
    wire        btv;

    always #5 clk = ~clk;

    target_tracker #(
        .LOST_THRESH (4'd10)
    ) dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_frame_start(frame_start),

        .I_red_valid(rv),
        .I_red_x_min(r_xmin), .I_red_x_max(r_xmax),
        .I_red_y_min(r_ymin), .I_red_y_max(r_ymax),
        .I_red_xsum(r_xsum),  .I_red_ysum(r_ysum),  .I_red_cnt(r_cnt),

        .I_yel_valid(yv),
        .I_yel_x_min(y_xmin), .I_yel_x_max(y_xmax),
        .I_yel_y_min(y_ymin), .I_yel_y_max(y_ymax),
        .I_yel_xsum(y_xsum),  .I_yel_ysum(y_ysum),  .I_yel_cnt(y_cnt),

        .I_grn_valid(gv),
        .I_grn_x_min(g_xmin), .I_grn_x_max(g_xmax),
        .I_grn_y_min(g_ymin), .I_grn_y_max(g_ymax),
        .I_grn_xsum(g_xsum),  .I_grn_ysum(g_ysum),  .I_grn_cnt(g_cnt),

        .I_blu_valid(bv),
        .I_blu_x_min(b_xmin), .I_blu_x_max(b_xmax),
        .I_blu_y_min(b_ymin), .I_blu_y_max(b_ymax),
        .I_blu_xsum(b_xsum),  .I_blu_ysum(b_ysum),  .I_blu_cnt(b_cnt),

        .O_red_cx(rcx), .O_red_cy(rcy),
        .O_red_bbox_cx(rbx), .O_red_bbox_cy(rby),
        .O_red_track_valid(rtv),

        .O_yel_cx(ycx), .O_yel_cy(ycy),
        .O_yel_bbox_cx(ybx), .O_yel_bbox_cy(yby),
        .O_yel_track_valid(ytv),

        .O_grn_cx(gcx), .O_grn_cy(gcy),
        .O_grn_bbox_cx(gbx), .O_grn_bbox_cy(gby),
        .O_grn_track_valid(gtv),

        .O_blu_cx(bcx), .O_blu_cy(bcy),
        .O_blu_bbox_cx(bbx), .O_blu_bbox_cy(bby),
        .O_blu_track_valid(btv)
    );

    integer errors = 0;

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

    task run_frame;
        begin
            @(posedge clk);
            frame_start <= 1'b1;
            @(posedge clk);
            frame_start <= 1'b0;
            repeat(200) @(posedge clk);   // 8 个除法 × 14 拍 = 112，留余量
        end
    endtask

    initial begin
        rst_n = 0; frame_start = 0;
        rv=0; yv=0; gv=0; bv=0;
        r_xmin=0; r_xmax=0; r_ymin=0; r_ymax=0; r_xsum=0; r_ysum=0; r_cnt=0;
        y_xmin=0; y_xmax=0; y_ymin=0; y_ymax=0; y_xsum=0; y_ysum=0; y_cnt=0;
        g_xmin=0; g_xmax=0; g_ymin=0; g_ymax=0; g_xsum=0; g_ysum=0; g_cnt=0;
        b_xmin=0; b_xmax=0; b_ymin=0; b_ymax=0; b_xsum=0; b_ysum=0; b_cnt=0;
        repeat(10) @(posedge clk); rst_n = 1;
        repeat(5)  @(posedge clk);

        //------------------------------------------------------------------
        // T1: 红 bbox x∈[100,299] y∈[50,149] cnt=20000
        //     cx = 3990000/20000 = 199.5 → 199
        //     cy = 1990000/20000 = 99.5  → 99
        //     bbox_cx = (100+299)/2 = 199
        //     bbox_cy = (50+149)/2  = 99
        //------------------------------------------------------------------
        $display("\n=== T1: red bbox + centroid ===");
        rv=1; r_xmin=100; r_xmax=299; r_ymin=50; r_ymax=149;
        r_xsum=32'd3_990_000; r_ysum=32'd1_990_000; r_cnt=32'd20_000;
        run_frame;
        chk(rtv===1'b1,   "T1 red_valid");
        chk(rcx==12'd199, "T1 cx=199");
        chk(rcy==12'd99,  "T1 cy=99");
        chk(rbx==12'd199, "T1 bbox_cx=199");
        chk(rby==12'd99,  "T1 bbox_cy=99");
        chk(ytv===1'b0,   "T1 yellow=0");
        chk(gtv===1'b0,   "T1 green=0");
        chk(btv===1'b0,   "T1 blue=0");

        //------------------------------------------------------------------
        // T2: 黄 bbox x∈[500,699] y∈[200,299] cnt=20000
        //     cx=599, cy=249
        //------------------------------------------------------------------
        $display("\n=== T2: yellow ===");
        rv=0; yv=1;
        y_xmin=500; y_xmax=699; y_ymin=200; y_ymax=299;
        y_xsum=32'd11_990_000; y_ysum=32'd4_990_000; y_cnt=32'd20_000;
        run_frame;
        chk(ytv===1'b1,   "T2 yellow_valid");
        chk(ycx==12'd599, "T2 yellow cx=599");
        chk(ycy==12'd249, "T2 yellow cy=249");

        //------------------------------------------------------------------
        // T3: 绿 bbox x∈[300,499] y∈[100,199] cnt=20000
        //     cx=399, cy=149
        //------------------------------------------------------------------
        $display("\n=== T3: green ===");
        yv=0; gv=1;
        g_xmin=300; g_xmax=499; g_ymin=100; g_ymax=199;
        g_xsum=32'd7_990_000; g_ysum=32'd2_990_000; g_cnt=32'd20_000;
        run_frame;
        chk(gtv===1'b1,   "T3 green_valid");
        chk(gcx==12'd399, "T3 green cx=399");
        chk(gcy==12'd149, "T3 green cy=149");

        //------------------------------------------------------------------
        // T4: 蓝 bbox x∈[800,999] y∈[400,499] cnt=20000
        //     cx=899, cy=449
        //------------------------------------------------------------------
        $display("\n=== T4: blue ===");
        gv=0; bv=1;
        b_xmin=800; b_xmax=999; b_ymin=400; b_ymax=499;
        b_xsum=32'd17_990_000; b_ysum=32'd8_990_000; b_cnt=32'd20_000;
        run_frame;
        chk(btv===1'b1,   "T4 blue_valid");
        chk(bcx==12'd899, "T4 blue cx=899");
        chk(bcy==12'd449, "T4 blue cy=449");

        //------------------------------------------------------------------
        // T5: 丢帧平滑 → 前 5 帧保持有效，累计 11 帧后失效
        //------------------------------------------------------------------
        $display("\n=== T5: lost-count smoothing ===");
        bv=0;
        run_frame; run_frame; run_frame;
        run_frame; run_frame;
        chk(btv===1'b1, "T5 丢 5 帧仍有效");
        run_frame; run_frame; run_frame;
        run_frame; run_frame; run_frame;
        chk(btv===1'b0, "T5 超时失效");

        //------------------------------------------------------------------
        // T6: 除零保护（cnt=0 但 valid=1）
        //------------------------------------------------------------------
        $display("\n=== T6: zero-div guard ===");
        rv=1;
        r_xmin=0; r_xmax=0; r_ymin=0; r_ymax=0;
        r_xsum=0; r_ysum=0; r_cnt=0;
        run_frame;
        chk(rtv===1'b1,   "T6 red_valid");
        chk(rcx==12'd0,   "T6 cx=0");
        chk(rcy==12'd0,   "T6 cy=0");

        $display("\n=============================================");
        $display("  Errors = %0d", errors);
        if (errors == 0) $display("  >>> ALL PASS <<<");
        else             $display("  >>> FAILED <<<");
        $display("=============================================");
        $finish;
    end

    initial begin
        #10_000_000;
        $display("[TIMEOUT]");
        $finish;
    end

endmodule