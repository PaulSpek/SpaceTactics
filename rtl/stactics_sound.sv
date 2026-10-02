// SPDX-License-Identifier: GPL-3.0-or-later
// First-pass Space Tactics sound generator.
//
// The player-shot voice follows the separate high/low actions heard in reference
// recordings of the cabinet. A short quiet interval and phase restart make the
// second circuit's attack distinct. The five secondary triggers remain available
// but silent until their schematic functions are verified.
module stactics_sound #(
    parameter integer SAMPLE_DIV = 1024,
    parameter logic [14:0] HIGH_SAMPLES = 15'd3072,
    parameter logic [14:0] GAP_SAMPLES = 15'd768,
    parameter logic [14:0] TOTAL_SAMPLES = 15'd16384
) (
    input  logic               clk,
    input  logic               reset,
    input  logic [7:0]         audio_latch,
    input  logic [4:0]         sound2_pulse,
    input  logic               player_shot_pulse,
    input  logic               diagnostic_trigger,
    output logic signed [15:0] audio_sample
);
    logic [9:0] sample_div;
    logic [15:0] phase;
    logic [14:0] shot_age;
    logic        shot_active;
    logic [14:0] noise_lfsr;
    logic diagnostic_d;
    logic diagnostic_bypass;
    logic signed [16:0] mixed_sample;
    logic [15:0] voice_envelope;
    logic [15:0] phase_step;
    logic [14:0] low_age;

    wire sample_tick = sample_div == SAMPLE_DIV - 1;
    wire diagnostic_rise = diagnostic_trigger && !diagnostic_d;
    wire [14:0] low_start = HIGH_SAMPLES + GAP_SAMPLES;
    wire gap_stage = shot_age >= HIGH_SAMPLES && shot_age < low_start;
    wire low_stage = shot_age >= low_start;
    wire sound_enabled = (audio_latch[7] && !audio_latch[0]) ||
                         diagnostic_bypass;

    always_comb begin
        low_age = shot_age - low_start;
        if (!low_stage) begin
            // Bright first action: about 3.6 kHz down to 2.5 kHz for 62 ms.
            phase_step = 16'd4800 - {2'b00, shot_age[14:1]};
            voice_envelope = 16'h7fff - {shot_age[11:0], 3'b000};
        end else begin
            // Independent second attack: about 1.65 kHz, falling toward
            // 475 Hz. Its envelope starts fresh after the quiet interval.
            phase_step = 16'd2200 - {4'b0000, low_age[14:3]};
            voice_envelope = 16'h6fff - {low_age, 1'b0};
        end

        mixed_sample = phase[15] ?
                       $signed({1'b0, voice_envelope[15:1]}) :
                       -$signed({1'b0, voice_envelope[15:1]});
        if (noise_lfsr[0])
            mixed_sample = mixed_sample +
                           $signed({3'b000, voice_envelope[15:3]});
        else
            mixed_sample = mixed_sample -
                           $signed({3'b000, voice_envelope[15:3]});
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            sample_div        <= 10'd0;
            phase             <= 16'd0;
            shot_age          <= 15'd0;
            shot_active       <= 1'b0;
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
                phase             <= 16'd0;
                shot_age          <= 15'd0;
                shot_active       <= 1'b1;
                noise_lfsr        <= 15'h4a35;
                diagnostic_bypass <= diagnostic_rise;
            end else if (sample_tick && shot_active) begin
                if (shot_age == low_start - 1'b1)
                    phase <= 16'd0;
                else
                    phase <= phase + phase_step;
                noise_lfsr <= {noise_lfsr[13:0],
                               noise_lfsr[14] ^ noise_lfsr[13]};
                if (shot_age >= TOTAL_SAMPLES - 1'b1) begin
                    shot_active       <= 1'b0;
                    diagnostic_bypass <= 1'b0;
                end else
                    shot_age <= shot_age + 1'b1;
            end

            if (sample_tick) begin
                if (!sound_enabled || !shot_active || gap_stage)
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
