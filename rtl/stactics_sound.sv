// SPDX-License-Identifier: GPL-3.0-or-later
// First-pass Space Tactics sound generator.
//
// This milestone implements a recognizable player-shot voice. It intentionally
// keeps the five secondary triggers available but silent until their schematic
// functions are verified.
module stactics_sound (
    input  logic               clk,
    input  logic               reset,
    input  logic [7:0]         audio_latch,
    input  logic [4:0]         sound2_pulse,
    input  logic               player_shot_pulse,
    input  logic               diagnostic_trigger,
    output logic signed [15:0] audio_sample
);
    localparam integer SAMPLE_DIV = 1024;

    logic [9:0] sample_div;
    logic [15:0] phase;
    logic [15:0] envelope;
    logic [14:0] noise_lfsr;
    logic diagnostic_d;
    logic diagnostic_bypass;
    logic signed [16:0] mixed_sample;

    wire sample_tick = sample_div == SAMPLE_DIV - 1;
    wire diagnostic_rise = diagnostic_trigger && !diagnostic_d;
    wire sound_enabled = (audio_latch[7] && !audio_latch[0]) ||
                         diagnostic_bypass;

    always_comb begin
        // A swept square wave plus quieter LFSR noise gives a useful first-pass
        // laser/shot timbre without placing multipliers in the audio path.
        mixed_sample = phase[15] ? $signed({1'b0, envelope[15:1]}) :
                                   -$signed({1'b0, envelope[15:1]});
        if (noise_lfsr[0])
            mixed_sample = mixed_sample + $signed({2'b00, envelope[15:2]});
        else
            mixed_sample = mixed_sample - $signed({2'b00, envelope[15:2]});
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            sample_div        <= 10'd0;
            phase             <= 16'd0;
            envelope          <= 16'd0;
            noise_lfsr        <= 15'h4a35;
            diagnostic_d      <= 1'b0;
            diagnostic_bypass <= 1'b0;
            audio_sample      <= 16'sd0;
        end else begin
            diagnostic_d <= diagnostic_trigger;
            if (sample_tick)
                sample_div <= 10'd0;
            else
                sample_div <= sample_div + 1'b1;

            if (player_shot_pulse || diagnostic_rise) begin
                phase      <= 16'd0;
                envelope   <= 16'h7fff;
                noise_lfsr <= 15'h4a35;
                if (diagnostic_rise)
                    diagnostic_bypass <= 1'b1;
            end else if (sample_tick && envelope != 0) begin
                // Pitch falls with the envelope over roughly 128 ms.
                phase <= phase + 16'd900 + {6'd0, envelope[15:6]};
                noise_lfsr <= {noise_lfsr[13:0],
                               noise_lfsr[14] ^ noise_lfsr[13]};
                if (envelope > 16'd128)
                    envelope <= envelope - 16'd128;
                else begin
                    envelope          <= 16'd0;
                    diagnostic_bypass <= 1'b0;
                end
            end

            if (sample_tick) begin
                if (!sound_enabled || envelope == 0)
                    audio_sample <= 16'sd0;
                else if (mixed_sample > 17'sd32767)
                    audio_sample <= 16'sh7fff;
                else if (mixed_sample < -17'sd32768)
                    audio_sample <= 16'sh8000;
                else
                    audio_sample <= mixed_sample[15:0];
            end
        end
    end
endmodule
