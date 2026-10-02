// SPDX-License-Identifier: GPL-3.0-or-later
// Space Tactics player-shot sound approximation.
//
// The cabinet schematic identifies PLAYER SHOT SOUND and SHOT ARRIVE PULSE as
// separate signals.  Model them as separate voices: the 6040 fire write starts
// the bright shot, while the beam's physical arrival positions start the lower,
// longer arrival voice.  This deliberately avoids joining two oscillator stages
// into one synthetic chirp.
module stactics_sound #(
    parameter integer SAMPLE_DIV = 1024,
    parameter logic [14:0] HIGH_SAMPLES = 15'd2304,
    parameter logic [14:0] LOW_SAMPLES = 15'd8192
) (
    input  logic               clk,
    input  logic               reset,
    input  logic [7:0]         audio_latch,
    input  logic [4:0]         sound2_pulse,
    input  logic               player_shot_pulse,
    input  logic               shot_arrive_pulse,
    input  logic               diagnostic_trigger,
    output logic signed [15:0] audio_sample
);
    logic [9:0] sample_div;
    logic [15:0] high_phase, low_phase;
    logic [14:0] high_age, low_age;
    logic high_active, low_active;
    logic [14:0] noise_lfsr;
    logic diagnostic_d, diagnostic_bypass;
    logic [15:0] high_step, low_step, high_envelope, low_envelope;
    logic signed [16:0] high_sample, low_sample, mixed_sample;

    wire sample_tick = sample_div == SAMPLE_DIV - 1;
    wire diagnostic_rise = diagnostic_trigger && !diagnostic_d;
    wire sound_enabled = (audio_latch[7] && !audio_latch[0]) ||
                         diagnostic_bypass;

    always_comb begin
        // The reference recording begins with a quick 3 kHz-ish descending
        // fire tone.  The low component starts only from SHOT ARRIVE PULSE.
        high_step = 16'd5000 - {3'b000, high_age[14:2]};
        high_envelope = (high_age < 15'd2048) ?
                        (16'h7000 - {high_age[11:0], 3'b000}) : 16'h0800;
        low_step = 16'd2200 - {3'b000, low_age[14:3]} -
                   {4'b0000, low_age[14:4]};
        low_envelope = (low_age < 15'd6144) ?
                       (16'h7000 - {low_age[12:0], 2'b00}) : 16'h0800;

        high_sample = high_phase[15] ?
                      $signed({1'b0, high_envelope[15:1]}) :
                      -$signed({1'b0, high_envelope[15:1]});
        low_sample = low_phase[15] ?
                     $signed({1'b0, low_envelope[15:1]}) :
                     -$signed({1'b0, low_envelope[15:1]});
        // The arrival circuit passes through the cabinet's BBD/amp path; a
        // modest noise component gives it a distinct, less pure character.
        if (noise_lfsr[0])
            low_sample = low_sample + $signed({3'b000, low_envelope[15:3]});
        else
            low_sample = low_sample - $signed({3'b000, low_envelope[15:3]});
        mixed_sample = (high_active ? high_sample : 17'sd0) +
                       (low_active ? low_sample : 17'sd0);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            sample_div        <= 10'd0;
            high_phase        <= 16'd0;
            low_phase         <= 16'd0;
            high_age          <= 15'd0;
            low_age           <= 15'd0;
            high_active       <= 1'b0;
            low_active        <= 1'b0;
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
                high_phase        <= 16'd0;
                high_age          <= 15'd0;
                high_active       <= 1'b1;
                diagnostic_bypass <= diagnostic_rise;
            end else if (sample_tick && high_active) begin
                high_phase <= high_phase + high_step;
                if (high_age >= HIGH_SAMPLES - 1'b1) begin
                    high_active       <= 1'b0;
                    diagnostic_bypass <= 1'b0;
                end else
                    high_age <= high_age + 1'b1;
            end

            if (shot_arrive_pulse) begin
                low_phase  <= 16'd0;
                low_age    <= 15'd0;
                low_active <= 1'b1;
                noise_lfsr <= 15'h4a35;
            end else if (sample_tick && low_active) begin
                low_phase <= low_phase + low_step;
                noise_lfsr <= {noise_lfsr[13:0],
                               noise_lfsr[14] ^ noise_lfsr[13]};
                if (low_age >= LOW_SAMPLES - 1'b1)
                    low_active <= 1'b0;
                else
                    low_age <= low_age + 1'b1;
            end

            if (sample_tick) begin
                if (!sound_enabled || (!high_active && !low_active))
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

    // Secondary sound triggers remain reserved until every analogue voice is
    // characterized.  Keeping the port preserves the hardware address map.
    wire unused_sound2 = &{1'b0, sound2_pulse};
endmodule
