// SPDX-License-Identifier: GPL-3.0-or-later
// Analogue-style Space Tactics sound approximation.
//
// The sound-board documentation names individual fire, arrival, UFO, invader,
// warning, rocket, hit, bomb, explosion and character paths, plus BBD echo.
// MAME documents the trigger addresses but leaves the secondary trigger names
// undecoded, so their five event-to-effect assignments below are provisional.
module stactics_sound #(
    parameter integer SAMPLE_DIV = 1024,
    parameter logic [14:0] HIGH_SAMPLES = 15'd3840,
    parameter logic [14:0] LOW_SAMPLES = 15'd12288
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
    // Two MN3005 BBDs provide the cabinet's audible repeat. At the approximately
    // 49 kHz internal sample rate, 2048 stages model a 41 ms echo; feedback
    // supplies subsequent quieter repeats without requiring a large netlist.
    logic signed [15:0] echo_ram [0:2047];
    logic [10:0] echo_ptr;
    logic signed [15:0] echo_delay;
    logic echo_ready;

    logic [9:0] sample_div;
    logic [15:0] high_phase, low_phase, event_phase;
    logic [15:0] ufo_phase, invader_phase, warning_phase, rocket_phase;
    logic [14:0] high_age, low_age, event_age;
    logic high_active, low_active, event_active;
    logic [2:0] event_kind;
    logic [14:0] noise_lfsr;
    logic diagnostic_d, diagnostic_bypass;

    logic [15:0] high_step, low_step, event_step;
    logic [15:0] high_envelope, low_envelope, event_envelope;
    logic [14:0] event_duration;
    logic signed [20:0] high_sample, low_sample, event_sample;
    logic signed [20:0] ufo_sample, invader_sample, warning_sample, rocket_sample;
    logic signed [20:0] dry_sample, wet_sample;

    wire sample_tick = sample_div == SAMPLE_DIV - 1;
    wire diagnostic_rise = diagnostic_trigger && !diagnostic_d;
    wire sound_enabled = (audio_latch[7] && !audio_latch[0]) || diagnostic_bypass;

    function automatic logic signed [15:0] clamp16(
        input logic signed [20:0] value
    );
        begin
            if (value > 21'sd32767)
                clamp16 = 16'sh7fff;
            else if (value < -21'sd32768)
                clamp16 = 16'sh8000;
            else
                clamp16 = value[15:0];
        end
    endfunction

    always_comb begin
        // Fire is deliberately longer and less click-like than the previous
        // version. The two true arrival events are lower and slower.
        high_step = 16'd4400 - {3'b000, high_age[14:2]};
        high_envelope = (high_age < 15'd3072) ?
                        (16'h6800 - {high_age[11:0], 3'b000}) : 16'h0800;
        low_step = 16'd1500 - {4'b0000, low_age[14:4]};
        low_envelope = (low_age < 15'd10240) ?
                       (16'h6800 - {low_age[13:0], 1'b0}) : 16'h0600;

        high_sample = high_phase[15] ?
                      $signed({1'b0, high_envelope[15:1]}) :
                      -$signed({1'b0, high_envelope[15:1]});
        low_sample = low_phase[15] ?
                     $signed({1'b0, low_envelope[15:1]}) :
                     -$signed({1'b0, low_envelope[15:1]});
        if (noise_lfsr[0])
            low_sample = low_sample + $signed({3'b000, low_envelope[15:3]});
        else
            low_sample = low_sample - $signed({3'b000, low_envelope[15:3]});

        // Secondary event voices: bomb, UFO hit, invader hit, explosion, and
        // character. Their address order is an explicitly provisional mapping.
        case (event_kind)
            3'd0: begin // bomb: falling, noisy low pulse
                event_step = 16'd1250 - {4'b0000, event_age[14:3]};
                event_envelope = (event_age < 15'd8192) ?
                                 (16'h5000 - {event_age[12:0], 2'b00}) : 16'h0400;
                event_duration = 15'd9216;
            end
            3'd1: begin // UFO hit: bright short upward chirp
                event_step = 16'd3000 + {4'b0000, event_age[14:4]};
                event_envelope = (event_age < 15'd2304) ?
                                 (16'h5200 - {event_age[10:0], 4'b0000}) : 16'h0400;
                event_duration = 15'd2560;
            end
            3'd2: begin // invader hit: clipped high noise pop
                event_step = 16'd2450 - {5'b00000, event_age[14:5]};
                event_envelope = (event_age < 15'd2048) ?
                                 (16'h4800 - {event_age[10:0], 4'b0000}) : 16'h0400;
                event_duration = 15'd2304;
            end
            3'd3: begin // explosion: long lower noise burst
                event_step = 16'd700 - {5'b00000, event_age[14:5]};
                event_envelope = (event_age < 15'd11264) ?
                                 (16'h6000 - {event_age[13:0], 1'b0}) : 16'h0400;
                event_duration = 15'd12288;
            end
            default: begin // character: warbling score / word chirp
                event_step = event_age[10] ? 16'd2200 : 16'd1800;
                event_envelope = (event_age < 15'd4096) ?
                                 (16'h4400 - {event_age[11:0], 3'b000}) : 16'h0400;
                event_duration = 15'd4608;
            end
        endcase
        event_sample = event_phase[15] ?
                       $signed({1'b0, event_envelope[15:1]}) :
                       -$signed({1'b0, event_envelope[15:1]});
        if (event_kind == 3'd0 || event_kind == 3'd2 || event_kind == 3'd3) begin
            if (noise_lfsr[1])
                event_sample = event_sample + $signed({3'b000, event_envelope[15:3]});
            else
                event_sample = event_sample - $signed({3'b000, event_envelope[15:3]});
        end

        // Addressed latch paths are level-controlled analogue oscillators.
        ufo_sample = audio_latch[3] ? (ufo_phase[15] ? 21'sd4200 : -21'sd4200) : 21'sd0;
        invader_sample = audio_latch[4] ? (invader_phase[15] ? 21'sd3500 : -21'sd3500) : 21'sd0;
        warning_sample = audio_latch[5] ?
                         (warning_phase[13] ? (warning_phase[15] ? 21'sd3800 : -21'sd3800) :
                                               (warning_phase[15] ? 21'sd2000 : -21'sd2000)) : 21'sd0;
        rocket_sample = audio_latch[6] ?
                        (rocket_phase[15] ? 21'sd2500 : -21'sd2500) : 21'sd0;
        if (audio_latch[6]) begin
            if (noise_lfsr[2]) rocket_sample = rocket_sample + 21'sd900;
            else rocket_sample = rocket_sample - 21'sd900;
        end

        dry_sample = (high_active ? high_sample : 21'sd0) +
                     (low_active ? low_sample : 21'sd0) +
                     (event_active ? event_sample : 21'sd0) +
                     ufo_sample + invader_sample + warning_sample + rocket_sample;
        wet_sample = dry_sample + (echo_ready ? (echo_delay >>> 1) : 21'sd0);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            sample_div        <= 10'd0;
            high_phase        <= 16'd0; low_phase <= 16'd0; event_phase <= 16'd0;
            ufo_phase         <= 16'd0; invader_phase <= 16'd0;
            warning_phase     <= 16'd0; rocket_phase <= 16'd0;
            high_age          <= 15'd0; low_age <= 15'd0; event_age <= 15'd0;
            high_active       <= 1'b0; low_active <= 1'b0; event_active <= 1'b0;
            event_kind        <= 3'd0;
            noise_lfsr        <= 15'h4a35;
            diagnostic_d      <= 1'b0; diagnostic_bypass <= 1'b0;
            echo_ptr          <= 11'd0; echo_delay <= 16'sd0; echo_ready <= 1'b0;
            audio_sample      <= 16'sd0;
        end else begin
            diagnostic_d <= diagnostic_trigger;
            if (sample_tick) sample_div <= 10'd0;
            else sample_div <= sample_div + 1'b1;

            if (player_shot_pulse || diagnostic_rise) begin
                high_phase <= 16'd0; high_age <= 15'd0; high_active <= 1'b1;
                diagnostic_bypass <= diagnostic_rise;
            end else if (sample_tick && high_active) begin
                high_phase <= high_phase + high_step;
                if (high_age >= HIGH_SAMPLES - 1'b1) begin
                    high_active <= 1'b0;
                    diagnostic_bypass <= 1'b0;
                end else high_age <= high_age + 1'b1;
            end

            if (shot_arrive_pulse) begin
                low_phase <= 16'd0; low_age <= 15'd0; low_active <= 1'b1;
            end else if (sample_tick && low_active) begin
                low_phase <= low_phase + low_step;
                if (low_age >= LOW_SAMPLES - 1'b1) low_active <= 1'b0;
                else low_age <= low_age + 1'b1;
            end

            if (|sound2_pulse) begin
                event_phase <= 16'd0; event_age <= 15'd0; event_active <= 1'b1;
                if (sound2_pulse[0]) event_kind <= 3'd0;
                else if (sound2_pulse[1]) event_kind <= 3'd1;
                else if (sound2_pulse[2]) event_kind <= 3'd2;
                else if (sound2_pulse[3]) event_kind <= 3'd3;
                else event_kind <= 3'd4;
            end else if (sample_tick && event_active) begin
                event_phase <= event_phase + event_step;
                if (event_age >= event_duration - 1'b1) event_active <= 1'b0;
                else event_age <= event_age + 1'b1;
            end

            if (sample_tick) begin
                ufo_phase <= ufo_phase + 16'd430;
                invader_phase <= invader_phase + 16'd620;
                warning_phase <= warning_phase + 16'd780;
                rocket_phase <= rocket_phase + 16'd250;
                noise_lfsr <= {noise_lfsr[13:0], noise_lfsr[14] ^ noise_lfsr[13]};
                echo_delay <= echo_ram[echo_ptr];
                echo_ptr <= echo_ptr + 1'b1;
                if (&echo_ptr) echo_ready <= 1'b1;
                if (sound_enabled) begin
                    echo_ram[echo_ptr] <= clamp16(dry_sample + (echo_delay >>> 2));
                    audio_sample <= clamp16(wet_sample);
                end else begin
                    echo_ram[echo_ptr] <= 16'sd0;
                    audio_sample <= 16'sd0;
                end
            end
        end
    end
endmodule
