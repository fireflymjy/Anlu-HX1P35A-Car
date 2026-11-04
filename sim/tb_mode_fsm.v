`timescale 1ns / 1ps

module tb_mode_fsm;

    reg  clk;
    reg  rst_n;
    reg  key_in;
    wire key_pulse;
    reg  [1:0] mode;

    // 例化按键消抖
    key_remove_shakes u_key (
        .I_clk          (clk),
        .I_rst_n        (rst_n),
        .I_key_in       (key_in),
        .O_key_trig_out (key_pulse)
    );

    always #10 clk = ~clk;   // 50MHz

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mode <= 2'd0;
        else if (key_pulse) begin
            if (mode == 2'd1)
                mode <= 2'd0;
            else
                mode <= mode + 1'b1;
        end
    end

    initial begin
        clk = 0; rst_n = 0; key_in = 1;
        #200; rst_n = 1;
        #1000;

        // 第一次按键
        key_in = 0;
        #20_000_000;   // 20ms
        key_in = 1;
        #1_000_000;

        // 第二次按键
        key_in = 0;
        #20_000_000;
        key_in = 1;
        #1_000_000;

        $stop;
    end

    always @(posedge clk) begin
        if (key_pulse)
            $display("Time=%t, key pressed, mode=%d", $time, mode);
    end

endmodule