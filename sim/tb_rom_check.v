`timescale 1ns / 1ps
module tb_rom_check;
    reg clk = 0; always #5 clk = ~clk;
    reg [11:0] a12 = 0; reg [9:0] a10 = 0; reg [6:0] a7 = 0;
    wire [15:0] d_lib, d_mode; wire [7:0] d_a8, d_al;
    osd_char_lib_rom u1 (.I_clk(clk), .I_addr(a12), .O_data(d_lib));
    ascii8x11_rom    u2 (.I_clk(clk), .I_addr(a12), .O_data(d_a8));
    mode_char_rom    u3 (.I_clk(clk), .I_addr(a10), .O_data(d_mode));
    algo_word_rom    u4 (.I_clk(clk), .I_addr(a7),  .O_data(d_al));
    integer i, fd;
    initial begin
        fd = $fopen("rom_check.txt","w");
        for (i=0;i<4096;i=i+1) begin a12=i[11:0]; @(posedge clk); #1; $fwrite(fd,"LIB %0d %0d %04x\n", i>>4, i&15, d_lib); end
        for (i=0;i<4096;i=i+1) begin a12=i[11:0]; @(posedge clk); #1; $fwrite(fd,"A8X11 %0d %0d %02x\n", i>>4, i&15, d_a8); end
        for (i=0;i<1024;i=i+1) begin a10=i[9:0]; @(posedge clk); #1; $fwrite(fd,"MODE %0d %0d %0d %04x\n", i/128, (i/16)%8, i%16, d_mode); end
        for (i=0;i<128;i=i+1) begin a7=i[6:0]; @(posedge clk); #1; $fwrite(fd,"ALGO %0d %0d %02x\n", i/8, i%8, d_al); end
        $fclose(fd); $display("ROMCHECK DONE"); $finish;
    end
endmodule