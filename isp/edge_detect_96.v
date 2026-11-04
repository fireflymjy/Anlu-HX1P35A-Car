// edge_detect_96: Sobel 边缘与区域填充

module edge_detect_96 #(
    parameter IMG_WIDTH  = 1280,
    parameter IMG_HEIGHT = 720,
    parameter EDGE_TH    = 11'd80,
    parameter FILL_TH    = 11'd96
)(
    input               I_clk,
    input               I_rst_n,
    input               I_tlast,
    input               I_tuser,
    input      [95:0]   I_tdata,
    input               I_tvalid,
    input               I_tready,
    output reg          O_tlast,
    output reg          O_tuser,
    output reg [95:0]   O_tdata,
    output reg          O_tvalid,
    output              O_tready,
    output reg [15:0]   O_luma,
    output reg [1:0]    O_hi
);

assign O_tready = I_tready;

wire [23:0] pix0 = I_tdata[95:72];
wire [23:0] pix1 = I_tdata[71:48];
wire [23:0] pix2 = I_tdata[47:24];
wire [23:0] pix3 = I_tdata[23:0];

wire [7:0] gray0 = {2'b0,pix0[23:18]} + {1'b0,pix0[15:9]} + {2'b0,pix0[7:2]};
wire [7:0] gray1 = {2'b0,pix1[23:18]} + {1'b0,pix1[15:9]} + {2'b0,pix1[7:2]};
wire [7:0] gray2 = {2'b0,pix2[23:18]} + {1'b0,pix2[15:9]} + {2'b0,pix2[7:2]};
wire [7:0] gray3 = {2'b0,pix3[23:18]} + {1'b0,pix3[15:9]} + {2'b0,pix3[7:2]};

localparam IMG_WIDTH_GRP = (IMG_WIDTH >> 2);

wire [8:0] pair_sum0 = {1'b0,gray0} + {1'b0,gray1};
wire [8:0] pair_sum1 = {1'b0,gray2} + {1'b0,gray3};
wire [7:0] pair0 = pair_sum0[8:1];
wire [7:0] pair1 = pair_sum1[8:1];

(* ram_style = "block" *) reg [15:0] line1_mem [0:IMG_WIDTH_GRP-1];
(* ram_style = "block" *) reg [15:0] line2_mem [0:IMG_WIDTH_GRP-1];

reg [10:0] x_grp;
reg [10:0] y_pos;

wire [15:0] top_word = line2_mem[x_grp];
wire [15:0] mid_word = line1_mem[x_grp];
wire [15:0] bot_word = {pair0,pair1};

wire [7:0] top0 = top_word[15:8];
wire [7:0] top1 = top_word[7:0];
wire [7:0] mid0 = mid_word[15:8];
wire [7:0] mid1 = mid_word[7:0];

reg [7:0] top_prev2, top_prev1;
reg [7:0] mid_prev2, mid_prev1;
reg [7:0] bot_prev2, bot_prev1;

function [13:0] sobel_mag;
    input [7:0] a00, a01, a02;
    input [7:0] a10, a11, a12;
    input [7:0] a20, a21, a22;
    reg signed [12:0] gx_f;
    reg signed [12:0] gy_f;
    reg [12:0] abs_gx_f;
    reg [12:0] abs_gy_f;
    begin
        gx_f = -$signed({1'b0,a00}) + $signed({1'b0,a02})
             - ($signed({1'b0,a10}) <<< 1) + ($signed({1'b0,a12}) <<< 1)
             - $signed({1'b0,a20}) + $signed({1'b0,a22});
        gy_f =  $signed({1'b0,a00}) + ($signed({1'b0,a01}) <<< 1) + $signed({1'b0,a02})
             - $signed({1'b0,a20}) - ($signed({1'b0,a21}) <<< 1) - $signed({1'b0,a22});
        abs_gx_f = gx_f[12] ? (~gx_f + 1'b1) : gx_f;
        abs_gy_f = gy_f[12] ? (~gy_f + 1'b1) : gy_f;
        sobel_mag = abs_gx_f + abs_gy_f;
    end
endfunction

wire [13:0] mag0 = sobel_mag(top_prev2,top_prev1,top0,
                             mid_prev2,mid_prev1,mid0,
                             bot_prev2,bot_prev1,pair0);
wire [13:0] mag1 = sobel_mag(top_prev1,top0,top1,
                             mid_prev1,mid0,mid1,
                             bot_prev1,pair0,pair1);

wire window_valid = (y_pos >= 11'd2) && (x_grp != 11'd0) && !I_tuser;
wire edge0 = window_valid && (mag0 >= EDGE_TH);
wire edge1 = window_valid && (mag1 >= EDGE_TH);

wire [23:0] out0 = edge0 ? 24'hffffff : 24'h000000;
wire [23:0] out1 = edge1 ? 24'hffffff : 24'h000000;

wire edgeh0 = window_valid && (mag0 >= FILL_TH);
wire edgeh1 = window_valid && (mag1 >= FILL_TH);

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        O_tlast  <= 1'b0;
        O_tuser  <= 1'b0;
        O_tdata  <= 96'd0;
        O_tvalid <= 1'b0;
        O_luma   <= 16'd0;
        O_hi     <= 2'b00;
        x_grp    <= 11'd0;
        y_pos    <= 11'd0;
        top_prev2 <= 8'd0; top_prev1 <= 8'd0;
        mid_prev2 <= 8'd0; mid_prev1 <= 8'd0;
        bot_prev2 <= 8'd0; bot_prev1 <= 8'd0;
    end else begin
        O_tlast  <= I_tlast;
        O_tuser  <= I_tuser;
        O_tvalid <= I_tvalid;

        if(I_tvalid) begin
            O_tdata <= {out0,out0,out1,out1};
            O_luma  <= mid_word;  // Sobel 中心行（与 out0/out1 同一行）
            O_hi    <= {edgeh0,edgeh1};

            line2_mem[x_grp] <= mid_word;
            line1_mem[x_grp] <= bot_word;

            if(I_tuser) begin
                x_grp <= 11'd1;
                y_pos <= 11'd0;
                top_prev2 <= 8'd0; top_prev1 <= 8'd0;
                mid_prev2 <= 8'd0; mid_prev1 <= 8'd0;
                bot_prev2 <= 8'd0; bot_prev1 <= 8'd0;
            end else if(x_grp == IMG_WIDTH_GRP - 1) begin
                x_grp <= 11'd0;
                if(y_pos == IMG_HEIGHT - 1)
                    y_pos <= 11'd0;
                else
                    y_pos <= y_pos + 1'b1;
                top_prev2 <= 8'd0; top_prev1 <= 8'd0;
                mid_prev2 <= 8'd0; mid_prev1 <= 8'd0;
                bot_prev2 <= 8'd0; bot_prev1 <= 8'd0;
            end else begin
                x_grp <= x_grp + 1'b1;
                top_prev2 <= top0; top_prev1 <= top1;
                mid_prev2 <= mid0; mid_prev1 <= mid1;
                bot_prev2 <= pair0; bot_prev1 <= pair1;
            end
        end else begin
            O_tdata <= 96'd0;
            O_luma  <= 16'd0;
            O_hi    <= 2'b00;
        end
    end
end

endmodule

module edge_fill (
    input               I_clk,
    input               I_rst_n,
    input      [95:0]   I_edge_pix,
    input      [95:0]   I_src_pix,
    input       [1:0]   I_hi,
    input               I_tvalid,
    input               I_tuser,
    input               I_tlast,
    input       [1:0]   I_style,
    output reg [95:0]   O_tdata,
    output reg          O_tvalid,
    output reg          O_tuser,
    output reg          O_tlast
);

    function [7:0] F_luma;
        input [23:0] p;
        begin
            F_luma = {2'b0,p[23:18]} + {1'b0,p[15:9]} + {2'b0,p[7:2]};
        end
    endfunction

    function [23:0] F_heat;
        input [7:0] L;
        reg   [7:0] t;
        begin
            if (L < 8'd64) begin
                F_heat = {8'd0, {L[5:0], 2'b00}, 8'hFF};
            end else if (L < 8'd128) begin
                t = (L - 8'd64) << 2;
                F_heat = {8'd0, 8'hFF, 8'd255 - t};
            end else if (L < 8'd192) begin
                t = (L - 8'd128) << 2;
                F_heat = {t, 8'hFF, 8'd0};
            end else begin
                t = (L - 8'd192) << 2;
                F_heat = {8'hFF, 8'd255 - t, 8'd0};
            end
        end
    endfunction

    function [7:0] F_mix;
        input [7:0] a;
        input [7:0] b;
        reg [8:0] s;
        begin
            s = {1'b0,a} + {1'b0,b};
            F_mix = s[8:1];
        end
    endfunction

    wire [23:0] e0 = I_edge_pix[95:72];
    wire [23:0] e1 = I_edge_pix[71:48];
    wire [23:0] e2 = I_edge_pix[47:24];
    wire [23:0] e3 = I_edge_pix[23:0];

    wire [23:0] c0 = F_heat(F_luma(I_src_pix[95:72]));
    wire [23:0] c1 = F_heat(F_luma(I_src_pix[71:48]));
    wire [23:0] c2 = F_heat(F_luma(I_src_pix[47:24]));
    wire [23:0] c3 = F_heat(F_luma(I_src_pix[23:0]));

    wire [23:0] o0 = {F_mix(e0[23:16],c0[23:16]), F_mix(e0[15:8],c0[15:8]), F_mix(e0[7:0],c0[7:0])};
    wire [23:0] o1 = {F_mix(e1[23:16],c1[23:16]), F_mix(e1[15:8],c1[15:8]), F_mix(e1[7:0],c1[7:0])};
    wire [23:0] o2 = {F_mix(e2[23:16],c2[23:16]), F_mix(e2[15:8],c2[15:8]), F_mix(e2[7:0],c2[7:0])};
    wire [23:0] o3 = {F_mix(e3[23:16],c3[23:16]), F_mix(e3[15:8],c3[15:8]), F_mix(e3[7:0],c3[7:0])};

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_tdata <= 96'd0; O_tvalid <= 1'b0; O_tuser <= 1'b0; O_tlast <= 1'b0;
        end else begin
            O_tvalid <= I_tvalid;
            O_tuser  <= I_tuser;
            O_tlast  <= I_tlast;
            O_tdata  <= I_tvalid ? {o0,o1,o2,o3} : 96'd0;
        end
    end

endmodule
