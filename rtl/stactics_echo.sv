// SPDX-License-Identifier: GPL-3.0-or-later
// One MN3005-style 4096-stage delay, driven by an MN3101-style sample clock.
module stactics_echo (
    input  logic clk, reset, sample_tick, enable,
    input  logic signed [20:0] send_sample,
    output logic signed [20:0] wet_sample
);
    logic signed [15:0] delay_ram [0:4095];
    logic [11:0] delay_ptr;
    logic delay_ready;
    logic signed [20:0] input_filter, output_filter;
    logic signed [15:0] delayed;

    function automatic logic signed [15:0] clamp16(input logic signed [20:0] value);
        begin
            if (value > 21'sd32767) clamp16 = 16'sh7fff;
            else if (value < -21'sd32768) clamp16 = 16'sh8000;
            else clamp16 = value[15:0];
        end
    endfunction

    always_ff @(posedge clk) begin
        if (reset) begin
            delay_ptr <= 0; delay_ready <= 0; delayed <= 0;
            input_filter <= 0; output_filter <= 0; wet_sample <= 0;
        end else if (sample_tick) begin
            delayed <= delay_ram[delay_ptr];
            delay_ptr <= delay_ptr + 1'b1;
            if (&delay_ptr) delay_ready <= 1'b1;
            if (enable) begin
                input_filter <= input_filter + ((send_sample - input_filter) >>> 2);
                if (delay_ready) begin
                    output_filter <= output_filter + (($signed(delayed) - output_filter) >>> 2);
                    delay_ram[delay_ptr] <= clamp16(input_filter + ($signed(delayed) >>> 1));
                    wet_sample <= output_filter;
                end else begin
                    // RAM power-up contents are undefined. Fill a complete
                    // pass before admitting either delayed data or feedback.
                    output_filter <= 0;
                    delay_ram[delay_ptr] <= clamp16(input_filter);
                    wet_sample <= 0;
                end
            end else begin
                input_filter <= 0; output_filter <= 0;
                delay_ram[delay_ptr] <= 0; wet_sample <= 0;
            end
        end
    end
endmodule
