`timescale 1ns / 1ps

module tb_binarize;

    (* keep = "true" *) reg         clk, rst_n;
    (* keep = "true" *) reg  [95:0] i_tdata;
    (* keep = "true" *) reg         i_tvalid, i_tuser;
    (* keep = "true" *) wire [95:0] o_tdata;
    (* keep = "true" *) wire        o_tvalid, o_tuser;

    binarize #(
        .THRESHOLD (8'd128)
    ) u_dut (
        .I_clk    (clk),
        .I_rst_n  (rst_n),
        .I_tdata  (i_tdata),
        .I_tvalid (i_tvalid),
        .I_tuser  (i_tuser),
        .O_tdata  (o_tdata),
        .O_tvalid (o_tvalid),
        .O_tuser  (o_tuser)
    );

    always #5 clk = ~clk;

    function [95:0] pack_rgb;
        input [7:0] r, g, b;
        begin
            pack_rgb = {r,g,b, r,g,b, r,g,b, r,g,b};
        end
    endfunction

    initial begin
        clk = 0; rst_n = 0;
        i_tdata = 0; i_tvalid = 0; i_tuser = 0;

        #100; rst_n = 1; #50;

        // 第 1 拍：暗色 R=G=B=50（期望输出黑 0x00）
        i_tvalid = 1; i_tuser = 1;
        i_tdata = pack_rgb(8'd50, 8'd50, 8'd50);
        #10;

        // 第 2 拍：亮色 R=G=B=200（期望输出白 0xFF）
        i_tuser = 0;
        i_tdata = pack_rgb(8'd200, 8'd200, 8'd200);
        #10;

        // 第 3 拍：纯红 R=255,G=0,B=0（灰度 = 255/4 ≈ 64，输出黑）
        i_tdata = pack_rgb(8'd255, 8'd0, 8'd0);
        #10;

        i_tvalid = 0; i_tuser = 0;
        #200;

        $display("=== 二值化结果 ===");
        $display("暗色(50) → 输出 %h（期望 00）", o_tdata[23:16]);
        $display("亮色(200) → 输出 %h（期望 FF）", o_tdata[23:16]);

        #200;
        $stop;
    end

endmodule