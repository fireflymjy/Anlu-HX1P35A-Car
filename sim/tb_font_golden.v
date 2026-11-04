`timescale 1ns / 1ps
// OSD 字库"逐位基准"导出（纯测试，不改任何 RTL）：
//   3 个查表函数从 hdmi_mixer.v 原样抽取；osd_char_lib 直接实例化。
//   输出 font_golden.txt 供以后任何 OSD 改动做逐位比对。
module tb_font_golden;
    // ==== 从 hdmi_mixer.v 原样抽取的模块级常量 ====
    localparam CHAR_AN           = 8'h80;
localparam CHAR_LU           = 8'h81;
localparam CHAR_C            = 8'h43;
localparam CHAR_N            = 8'h4e;
localparam CHAR_T            = 8'h54;
localparam CHAR_0            = 8'h30;
localparam CHAR_COLON        = 8'h3a;

    // ==== 从 hdmi_mixer.v 原样抽取的查表函数 ====
    function [7:0] F_ascii8x11;
    input [7:0] I_char;
    input [3:0] I_row;
    begin
        case(I_char)
            8'h41: begin // A
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h0E;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h11;
                    4'd4: F_ascii8x11 = 8'h1F;
                    4'd5: F_ascii8x11 = 8'h11;
                    4'd6: F_ascii8x11 = 8'h11;
                    4'd7: F_ascii8x11 = 8'h11;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h42: begin // B
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h1E;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h11;
                    4'd4: F_ascii8x11 = 8'h1E;
                    4'd5: F_ascii8x11 = 8'h11;
                    4'd6: F_ascii8x11 = 8'h11;
                    4'd7: F_ascii8x11 = 8'h1E;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h43: begin // C
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h0F;
                    4'd2: F_ascii8x11 = 8'h10;
                    4'd3: F_ascii8x11 = 8'h10;
                    4'd4: F_ascii8x11 = 8'h10;
                    4'd5: F_ascii8x11 = 8'h10;
                    4'd6: F_ascii8x11 = 8'h10;
                    4'd7: F_ascii8x11 = 8'h0F;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h44: begin // D
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h1E;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h11;
                    4'd4: F_ascii8x11 = 8'h11;
                    4'd5: F_ascii8x11 = 8'h11;
                    4'd6: F_ascii8x11 = 8'h11;
                    4'd7: F_ascii8x11 = 8'h1E;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h45: begin // E
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h1F;
                    4'd2: F_ascii8x11 = 8'h10;
                    4'd3: F_ascii8x11 = 8'h10;
                    4'd4: F_ascii8x11 = 8'h1E;
                    4'd5: F_ascii8x11 = 8'h10;
                    4'd6: F_ascii8x11 = 8'h10;
                    4'd7: F_ascii8x11 = 8'h1F;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h47: begin // G
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h0F;
                    4'd2: F_ascii8x11 = 8'h10;
                    4'd3: F_ascii8x11 = 8'h10;
                    4'd4: F_ascii8x11 = 8'h13;
                    4'd5: F_ascii8x11 = 8'h11;
                    4'd6: F_ascii8x11 = 8'h11;
                    4'd7: F_ascii8x11 = 8'h0F;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h48: begin // H
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h11;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h11;
                    4'd4: F_ascii8x11 = 8'h1F;
                    4'd5: F_ascii8x11 = 8'h11;
                    4'd6: F_ascii8x11 = 8'h11;
                    4'd7: F_ascii8x11 = 8'h11;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h49: begin // I
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h1F;
                    4'd2: F_ascii8x11 = 8'h04;
                    4'd3: F_ascii8x11 = 8'h04;
                    4'd4: F_ascii8x11 = 8'h04;
                    4'd5: F_ascii8x11 = 8'h04;
                    4'd6: F_ascii8x11 = 8'h04;
                    4'd7: F_ascii8x11 = 8'h1F;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h4C: begin // L
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h10;
                    4'd2: F_ascii8x11 = 8'h10;
                    4'd3: F_ascii8x11 = 8'h10;
                    4'd4: F_ascii8x11 = 8'h10;
                    4'd5: F_ascii8x11 = 8'h10;
                    4'd6: F_ascii8x11 = 8'h10;
                    4'd7: F_ascii8x11 = 8'h1F;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h4D: begin // M
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h11;
                    4'd2: F_ascii8x11 = 8'h1B;
                    4'd3: F_ascii8x11 = 8'h15;
                    4'd4: F_ascii8x11 = 8'h11;
                    4'd5: F_ascii8x11 = 8'h11;
                    4'd6: F_ascii8x11 = 8'h11;
                    4'd7: F_ascii8x11 = 8'h11;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h4E: begin // N
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h11;
                    4'd2: F_ascii8x11 = 8'h19;
                    4'd3: F_ascii8x11 = 8'h15;
                    4'd4: F_ascii8x11 = 8'h13;
                    4'd5: F_ascii8x11 = 8'h11;
                    4'd6: F_ascii8x11 = 8'h11;
                    4'd7: F_ascii8x11 = 8'h11;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h4F: begin // O
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h0E;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h11;
                    4'd4: F_ascii8x11 = 8'h11;
                    4'd5: F_ascii8x11 = 8'h11;
                    4'd6: F_ascii8x11 = 8'h11;
                    4'd7: F_ascii8x11 = 8'h0E;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h51: begin // Q
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h0E;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h11;
                    4'd4: F_ascii8x11 = 8'h11;
                    4'd5: F_ascii8x11 = 8'h15;
                    4'd6: F_ascii8x11 = 8'h12;
                    4'd7: F_ascii8x11 = 8'h0D;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h52: begin // R
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h1E;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h11;
                    4'd4: F_ascii8x11 = 8'h1E;
                    4'd5: F_ascii8x11 = 8'h14;
                    4'd6: F_ascii8x11 = 8'h12;
                    4'd7: F_ascii8x11 = 8'h11;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h53: begin // S
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h0F;
                    4'd2: F_ascii8x11 = 8'h10;
                    4'd3: F_ascii8x11 = 8'h10;
                    4'd4: F_ascii8x11 = 8'h0E;
                    4'd5: F_ascii8x11 = 8'h01;
                    4'd6: F_ascii8x11 = 8'h01;
                    4'd7: F_ascii8x11 = 8'h1E;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
                8'h54: begin // T
                    case(I_row)
                        4'd1: F_ascii8x11 = 8'h1F;
                        4'd2: F_ascii8x11 = 8'h04;
                        4'd3: F_ascii8x11 = 8'h04;
                        4'd4: F_ascii8x11 = 8'h04;
                        4'd5: F_ascii8x11 = 8'h04;
                        4'd6: F_ascii8x11 = 8'h04;
                        4'd7: F_ascii8x11 = 8'h04;
                        default: F_ascii8x11 = 8'h00;
                    endcase
                end
                        8'h46: begin // F
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h1F;
                    4'd2: F_ascii8x11 = 8'h10;
                    4'd3: F_ascii8x11 = 8'h10;
                    4'd4: F_ascii8x11 = 8'h1E;
                    4'd5: F_ascii8x11 = 8'h10;
                    4'd6: F_ascii8x11 = 8'h10;
                    4'd7: F_ascii8x11 = 8'h10;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h50: begin // P
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h1E;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h11;
                    4'd4: F_ascii8x11 = 8'h1E;
                    4'd5: F_ascii8x11 = 8'h10;
                    4'd6: F_ascii8x11 = 8'h10;
                    4'd7: F_ascii8x11 = 8'h10;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h6D: begin // m (小写)
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h00;
                    4'd2: F_ascii8x11 = 8'h00;
                    4'd3: F_ascii8x11 = 8'h00;
                    4'd4: F_ascii8x11 = 8'h1A;
                    4'd5: F_ascii8x11 = 8'h15;
                    4'd6: F_ascii8x11 = 8'h15;
                    4'd8: F_ascii8x11 = 8'h15;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h73: begin // s (小写)
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h00;
                    4'd2: F_ascii8x11 = 8'h00;
                    4'd3: F_ascii8x11 = 8'h00;
                    4'd4: F_ascii8x11 = 8'h0E;
                    4'd5: F_ascii8x11 = 8'h10;
                    4'd6: F_ascii8x11 = 8'h0E;
                    4'd7: F_ascii8x11 = 8'h01;
                    4'd8: F_ascii8x11 = 8'h1E;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end     
            8'h59: begin // Y
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h11;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h0A;
                    4'd4: F_ascii8x11 = 8'h04;
                    4'd5: F_ascii8x11 = 8'h04;
                    4'd6: F_ascii8x11 = 8'h04;
                    4'd7: F_ascii8x11 = 8'h04;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
                        8'h3A: begin // :
                case(I_row)
                    4'd2: F_ascii8x11 = 8'h08;
                    4'd5: F_ascii8x11 = 8'h08;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h30: begin // 0
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h0E;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h13;
                    4'd4: F_ascii8x11 = 8'h15;
                    4'd5: F_ascii8x11 = 8'h19;
                    4'd6: F_ascii8x11 = 8'h11;
                    4'd7: F_ascii8x11 = 8'h0E;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h31: begin // 1
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h04;
                    4'd2: F_ascii8x11 = 8'h0C;
                    4'd3: F_ascii8x11 = 8'h04;
                    4'd4: F_ascii8x11 = 8'h04;
                    4'd5: F_ascii8x11 = 8'h04;
                    4'd6: F_ascii8x11 = 8'h04;
                    4'd7: F_ascii8x11 = 8'h0E;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h32: begin // 2
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h0E;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h01;
                    4'd4: F_ascii8x11 = 8'h06;
                    4'd5: F_ascii8x11 = 8'h08;
                    4'd6: F_ascii8x11 = 8'h10;
                    4'd7: F_ascii8x11 = 8'h1F;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h33: begin // 3
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h1E;
                    4'd2: F_ascii8x11 = 8'h01;
                    4'd3: F_ascii8x11 = 8'h01;
                    4'd4: F_ascii8x11 = 8'h0E;
                    4'd5: F_ascii8x11 = 8'h01;
                    4'd6: F_ascii8x11 = 8'h01;
                    4'd7: F_ascii8x11 = 8'h1E;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h34: begin // 4
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h02;
                    4'd2: F_ascii8x11 = 8'h06;
                    4'd3: F_ascii8x11 = 8'h0A;
                    4'd4: F_ascii8x11 = 8'h12;
                    4'd5: F_ascii8x11 = 8'h1F;
                    4'd6: F_ascii8x11 = 8'h02;
                    4'd7: F_ascii8x11 = 8'h02;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h35: begin // 5
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h1F;
                    4'd2: F_ascii8x11 = 8'h10;
                    4'd3: F_ascii8x11 = 8'h1E;
                    4'd4: F_ascii8x11 = 8'h01;
                    4'd5: F_ascii8x11 = 8'h01;
                    4'd6: F_ascii8x11 = 8'h11;
                    4'd7: F_ascii8x11 = 8'h0E;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h36: begin // 6
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h06;
                    4'd2: F_ascii8x11 = 8'h08;
                    4'd3: F_ascii8x11 = 8'h10;
                    4'd4: F_ascii8x11 = 8'h1E;
                    4'd5: F_ascii8x11 = 8'h11;
                    4'd6: F_ascii8x11 = 8'h11;
                    4'd7: F_ascii8x11 = 8'h0E;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h37: begin // 7
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h1F;
                    4'd2: F_ascii8x11 = 8'h01;
                    4'd3: F_ascii8x11 = 8'h02;
                    4'd4: F_ascii8x11 = 8'h04;
                    4'd5: F_ascii8x11 = 8'h08;
                    4'd6: F_ascii8x11 = 8'h08;
                    4'd7: F_ascii8x11 = 8'h08;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h38: begin // 8
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h0E;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h11;
                    4'd4: F_ascii8x11 = 8'h0E;
                    4'd5: F_ascii8x11 = 8'h11;
                    4'd6: F_ascii8x11 = 8'h11;
                    4'd7: F_ascii8x11 = 8'h0E;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h39: begin // 9
                case(I_row)
                    4'd1: F_ascii8x11 = 8'h0E;
                    4'd2: F_ascii8x11 = 8'h11;
                    4'd3: F_ascii8x11 = 8'h11;
                    4'd4: F_ascii8x11 = 8'h0F;
                    4'd5: F_ascii8x11 = 8'h01;
                    4'd6: F_ascii8x11 = 8'h02;
                    4'd7: F_ascii8x11 = 8'h1C;
                    default: F_ascii8x11 = 8'h00;
                endcase
            end
            8'h20: F_ascii8x11 = 8'h00;  // 空格
            default: F_ascii8x11 = 8'h00;
        endcase
    end
endfunction

    function [7:0] F_algo_word;
    input [3:0] I_char_idx;   // 0~7
    input [2:0] I_mode;
    begin
        case(I_mode)
            3'd0: begin // ORIGINAL
                case(I_char_idx)
                    4'd0: F_algo_word = 8'h4F; // O
                    4'd1: F_algo_word = 8'h52; // R
                    4'd2: F_algo_word = 8'h49; // I
                    4'd3: F_algo_word = 8'h47; // G
                    4'd4: F_algo_word = 8'h49; // I
                    4'd5: F_algo_word = 8'h4E; // N
                    4'd6: F_algo_word = 8'h41; // A
                    4'd7: F_algo_word = 8'h4C; // L
                    default: F_algo_word = 8'h20;
                endcase
            end
            3'd1: begin // EDGE
                case(I_char_idx)
                    4'd0: F_algo_word = 8'h45; // E
                    4'd1: F_algo_word = 8'h44; // D
                    4'd2: F_algo_word = 8'h47; // G
                    4'd3: F_algo_word = 8'h45; // E
                    default: F_algo_word = 8'h20;
                endcase
            end
            3'd2: begin // COLOR
                case(I_char_idx)
                    4'd0: F_algo_word = 8'h43; // C
                    4'd1: F_algo_word = 8'h4F; // O
                    4'd2: F_algo_word = 8'h4C; // L
                    4'd3: F_algo_word = 8'h4F; // O
                    4'd4: F_algo_word = 8'h52; // R
                    default: F_algo_word = 8'h20;
                endcase
            end
            3'd3: begin // CARTOON
                case(I_char_idx)
                    4'd0: F_algo_word = 8'h43; // C
                    4'd1: F_algo_word = 8'h41; // A
                    4'd2: F_algo_word = 8'h52; // R
                    4'd3: F_algo_word = 8'h54; // T
                    4'd4: F_algo_word = 8'h4F; // O
                    4'd5: F_algo_word = 8'h4F; // O
                    4'd6: F_algo_word = 8'h4E; // N
                    default: F_algo_word = 8'h20;
                endcase
            end
            3'd4: begin // MEDIAN
                case(I_char_idx)
                    4'd0: F_algo_word = 8'h4D; // M
                    4'd1: F_algo_word = 8'h45; // E
                    4'd2: F_algo_word = 8'h44; // D
                    4'd3: F_algo_word = 8'h49; // I
                    4'd4: F_algo_word = 8'h41; // A
                    4'd5: F_algo_word = 8'h4E; // N
                    default: F_algo_word = 8'h20;
                endcase
            end
            3'd5: begin // BINARY
                case(I_char_idx)
                    4'd0: F_algo_word = 8'h42; // B
                    4'd1: F_algo_word = 8'h49; // I
                    4'd2: F_algo_word = 8'h4E; // N
                    4'd3: F_algo_word = 8'h41; // A
                    4'd4: F_algo_word = 8'h52; // R
                    4'd5: F_algo_word = 8'h59; // Y
                    default: F_algo_word = 8'h20;
                endcase
            end
            3'd6: begin // SIGN
                case(I_char_idx)
                    4'd0: F_algo_word = 8'h53; // S
                    4'd1: F_algo_word = 8'h49; // I
                    4'd2: F_algo_word = 8'h47; // G
                    4'd3: F_algo_word = 8'h4E; // N
                    default: F_algo_word = 8'h20;
                endcase
            end
            default: F_algo_word = 8'h20;
        endcase
    end
endfunction

    function [15:0] F_mode_char;
    input [3:0] I_row;
    input [2:0] I_char;
    input [2:0] I_mode;
    begin
        case(I_char)
            3'd0: begin // M
                case(I_row)
                    4'd0:  F_mode_char = 16'h0000;
                    4'd1:  F_mode_char = 16'h0000;
                    4'd2:  F_mode_char = 16'h0000;
                    4'd3:  F_mode_char = 16'h0077;
                    4'd4:  F_mode_char = 16'h0036;
                    4'd5:  F_mode_char = 16'h0036;
                    4'd6:  F_mode_char = 16'h0036;
                    4'd7:  F_mode_char = 16'h0036;
                    4'd8:  F_mode_char = 16'h0036;
                    4'd9:  F_mode_char = 16'h002A;
                    4'd10: F_mode_char = 16'h002A;
                    4'd11: F_mode_char = 16'h002A;
                    4'd12: F_mode_char = 16'h002A;
                    4'd13: F_mode_char = 16'h006B;
                    4'd14: F_mode_char = 16'h0000;
                    4'd15: F_mode_char = 16'h0000;
                    default: F_mode_char = 16'h0000;
                endcase
            end
            3'd1: begin // O
                case(I_row)
                    4'd0:  F_mode_char = 16'h0000;
                    4'd1:  F_mode_char = 16'h0000;
                    4'd2:  F_mode_char = 16'h0000;
                    4'd3:  F_mode_char = 16'h001C;
                    4'd4:  F_mode_char = 16'h0022;
                    4'd5:  F_mode_char = 16'h0041;
                    4'd6:  F_mode_char = 16'h0041;
                    4'd7:  F_mode_char = 16'h0041;
                    4'd8:  F_mode_char = 16'h0041;
                    4'd9:  F_mode_char = 16'h0041;
                    4'd10: F_mode_char = 16'h0041;
                    4'd11: F_mode_char = 16'h0041;
                    4'd12: F_mode_char = 16'h0022;
                    4'd13: F_mode_char = 16'h001C;
                    4'd14: F_mode_char = 16'h0000;
                    4'd15: F_mode_char = 16'h0000;
                    default: F_mode_char = 16'h0000;
                endcase
            end
            3'd2: begin // D
                case(I_row)
                    4'd0:  F_mode_char = 16'h0000;
                    4'd1:  F_mode_char = 16'h0000;
                    4'd2:  F_mode_char = 16'h0000;
                    4'd3:  F_mode_char = 16'h001F;
                    4'd4:  F_mode_char = 16'h0022;
                    4'd5:  F_mode_char = 16'h0042;
                    4'd6:  F_mode_char = 16'h0042;
                    4'd7:  F_mode_char = 16'h0042;
                    4'd8:  F_mode_char = 16'h0042;
                    4'd9:  F_mode_char = 16'h0042;
                    4'd10: F_mode_char = 16'h0042;
                    4'd11: F_mode_char = 16'h0042;
                    4'd12: F_mode_char = 16'h0022;
                    4'd13: F_mode_char = 16'h001F;
                    4'd14: F_mode_char = 16'h0000;
                    4'd15: F_mode_char = 16'h0000;
                    default: F_mode_char = 16'h0000;
                endcase
            end
            3'd3: begin // E
                case(I_row)
                    4'd0:  F_mode_char = 16'h0000;
                    4'd1:  F_mode_char = 16'h0000;
                    4'd2:  F_mode_char = 16'h0000;
                    4'd3:  F_mode_char = 16'h003F;
                    4'd4:  F_mode_char = 16'h0042;
                    4'd5:  F_mode_char = 16'h0012;
                    4'd6:  F_mode_char = 16'h0012;
                    4'd7:  F_mode_char = 16'h001E;
                    4'd8:  F_mode_char = 16'h0012;
                    4'd9:  F_mode_char = 16'h0012;
                    4'd10: F_mode_char = 16'h0002;
                    4'd11: F_mode_char = 16'h0042;
                    4'd12: F_mode_char = 16'h0042;
                    4'd13: F_mode_char = 16'h003F;
                    4'd14: F_mode_char = 16'h0000;
                    4'd15: F_mode_char = 16'h0000;
                    default: F_mode_char = 16'h0000;
                endcase
            end
            3'd4: begin // :
                case(I_row)
                    4'd0:  F_mode_char = 16'h0000;
                    4'd1:  F_mode_char = 16'h0000;
                    4'd2:  F_mode_char = 16'h0000;
                    4'd3:  F_mode_char = 16'h0000;
                    4'd4:  F_mode_char = 16'h0000;
                    4'd5:  F_mode_char = 16'h0000;
                    4'd6:  F_mode_char = 16'h0018;
                    4'd7:  F_mode_char = 16'h0018;
                    4'd8:  F_mode_char = 16'h0000;
                    4'd9:  F_mode_char = 16'h0000;
                    4'd10: F_mode_char = 16'h0000;
                    4'd11: F_mode_char = 16'h0000;
                    4'd12: F_mode_char = 16'h0018;
                    4'd13: F_mode_char = 16'h0018;
                    4'd14: F_mode_char = 16'h0000;
                    4'd15: F_mode_char = 16'h0000;
                    default: F_mode_char = 16'h0000;
                endcase
            end
            3'd5: F_mode_char = 16'h0000;
            3'd6: begin
                if(I_mode == 3'd0) begin
                    case(I_row)
                        4'd0:  F_mode_char = 16'h0000;
                        4'd1:  F_mode_char = 16'h0000;
                        4'd2:  F_mode_char = 16'h0000;
                        4'd3:  F_mode_char = 16'h0018;
                        4'd4:  F_mode_char = 16'h0024;
                        4'd5:  F_mode_char = 16'h0042;
                        4'd6:  F_mode_char = 16'h0042;
                        4'd7:  F_mode_char = 16'h0042;
                        4'd8:  F_mode_char = 16'h0042;
                        4'd9:  F_mode_char = 16'h0042;
                        4'd10: F_mode_char = 16'h0042;
                        4'd11: F_mode_char = 16'h0042;
                        4'd12: F_mode_char = 16'h0024;
                        4'd13: F_mode_char = 16'h0018;
                        4'd14: F_mode_char = 16'h0000;
                        4'd15: F_mode_char = 16'h0000;
                        default: F_mode_char = 16'h0000;
                    endcase
                end
                else if(I_mode == 3'd1) begin
                    case(I_row)
                        4'd0:  F_mode_char = 16'h0000;
                        4'd1:  F_mode_char = 16'h0000;
                        4'd2:  F_mode_char = 16'h0000;
                        4'd3:  F_mode_char = 16'h0010;
                        4'd4:  F_mode_char = 16'h001C;
                        4'd5:  F_mode_char = 16'h0010;
                        4'd6:  F_mode_char = 16'h0010;
                        4'd7:  F_mode_char = 16'h0010;
                        4'd8:  F_mode_char = 16'h0010;
                        4'd9:  F_mode_char = 16'h0010;
                        4'd10: F_mode_char = 16'h0010;
                        4'd11: F_mode_char = 16'h0010;
                        4'd12: F_mode_char = 16'h0010;
                        4'd13: F_mode_char = 16'h007C;
                        4'd14: F_mode_char = 16'h0000;
                        4'd15: F_mode_char = 16'h0000;
                        default: F_mode_char = 16'h0000;
                    endcase
                end
                else if(I_mode == 3'd2) begin
                    case(I_row)
                        4'd0:  F_mode_char = 16'h0000;
                        4'd1:  F_mode_char = 16'h0000;
                        4'd2:  F_mode_char = 16'h0000;
                        4'd3:  F_mode_char = 16'h003C;
                        4'd4:  F_mode_char = 16'h0042;
                        4'd5:  F_mode_char = 16'h0042;
                        4'd6:  F_mode_char = 16'h0042;
                        4'd7:  F_mode_char = 16'h0040;
                        4'd8:  F_mode_char = 16'h0020;
                        4'd9:  F_mode_char = 16'h0010;
                        4'd10: F_mode_char = 16'h0008;
                        4'd11: F_mode_char = 16'h0004;
                        4'd12: F_mode_char = 16'h0042;
                        4'd13: F_mode_char = 16'h007E;
                        4'd14: F_mode_char = 16'h0000;
                        4'd15: F_mode_char = 16'h0000;
                        default: F_mode_char = 16'h0000;
                    endcase
                end
                else begin
                    F_mode_char = 16'h0000;
                end  
          end
            default: F_mode_char = 16'h0000;
        endcase
    end
endfunction

    // ==== 被实例化的字库模块（原样） ====
    reg  [7:0]  ch = 8'd0;
    reg  [3:0]  rw = 4'd0;
    wire [15:0] lib_row;
    osd_char_lib u_lib (.I_char(ch), .I_row(rw), .O_row_bits(lib_row));

    integer i, j, k, fd;
    initial begin
        fd = $fopen("font_golden.txt", "w");
        // osd_char_lib：全部 256 字符 × 16 行
        for (i = 0; i < 256; i = i + 1) begin
            ch = i[7:0];
            for (j = 0; j < 16; j = j + 1) begin
                rw = j[3:0];
                #1;
                $fwrite(fd, "LIB %0d %0d %04x\n", i, j, lib_row);
            end
        end
        // F_ascii8x11：全部 256 字符 × 16 行
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 16; j = j + 1)
                $fwrite(fd, "A8X11 %0d %0d %02x\n", i, j, F_ascii8x11(i[7:0], j[3:0]));
        // F_algo_word：16 索引 × 8 模式
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 8; j = j + 1)
                $fwrite(fd, "ALGO %0d %0d %02x\n", i, j, F_algo_word(i[3:0], j[2:0]));
        // F_mode_char：16 行 × 8 字符 × 8 模式
        for (k = 0; k < 8; k = k + 1)
            for (i = 0; i < 8; i = i + 1)
                for (j = 0; j < 16; j = j + 1)
                    $fwrite(fd, "MODE %0d %0d %0d %04x\n", k, i, j, F_mode_char(j[3:0], i[2:0], k[2:0]));
        $fclose(fd);
        $display("GOLDEN DONE");
        $finish;
    end
endmodule