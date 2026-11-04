`timescale 1ns / 1ps

module tb_edge_detect;

    reg         clk;
    reg         rst_n;
    reg  [95:0] i_tdata;
    reg         i_tvalid;
    reg         i_tlast;
    reg         i_tuser;
    reg         i_tready;
    wire [95:0] o_tdata;
    wire        o_tvalid;
    wire        o_tlast;
    wire        o_tuser;
    wire        o_tready;

    edge_detect_96 #(
        .IMG_WIDTH  (16),
        .IMG_HEIGHT (16),
        .EDGE_TH    (11'd80)
    ) u_dut (
        .I_clk    (clk),
        .I_rst_n  (rst_n),
        .I_tdata  (i_tdata),
        .I_tvalid (i_tvalid),
        .I_tlast  (i_tlast),
        .I_tuser  (i_tuser),
        .I_tready (i_tready),
        .O_tdata  (o_tdata),
        .O_tvalid (o_tvalid),
        .O_tlast  (o_tlast),
        .O_tuser  (o_tuser),
        .O_tready (o_tready)
    );

    always #5 clk = ~clk;

    function [95:0] pack_pixel;
        input [23:0] p0, p1, p2, p3;
        begin
            pack_pixel = {p0, p1, p2, p3};
        end
    endfunction

    integer i;
    initial begin
        clk = 0;
        rst_n = 0;
        i_tdata = 0;
        i_tvalid = 0;
        i_tlast = 0;
        i_tuser = 0;
        i_tready = 1;

        #100;
        rst_n = 1;
        #50;

        for (i = 0; i < 16; i = i + 1) begin
            i_tvalid = 1;
            if (i == 0) i_tuser = 1; else i_tuser = 0;
            if (i == 15) i_tlast = 1; else i_tlast = 0;

            if (i < 8)
                i_tdata = pack_pixel(24'h000000, 24'h000000, 24'h000000, 24'h000000);
            else
                i_tdata = pack_pixel(24'hFFFFFF, 24'hFFFFFF, 24'hFFFFFF, 24'hFFFFFF);

            #10;
        end

        i_tvalid = 0;
        i_tlast = 0;
        i_tuser = 0;
        #100;
        $stop;
    end

    always @(posedge clk) begin
        if (o_tvalid)
            $display("Time=%t, O_tdata=%h", $time, o_tdata);
    end

endmodule