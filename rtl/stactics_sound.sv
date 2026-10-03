// SPDX-License-Identifier: GPL-3.0-or-later
// Space Tactics sound-board model. Digital controls follow the game hardware;
// oscillator constants remain bounded approximations pending cabinet captures.
module stactics_sound #(
    parameter integer SAMPLE_DIV = 1024,
    parameter logic [14:0] HIGH_SAMPLES = 15'd3840,
    parameter logic [14:0] LOW_SAMPLES = 15'd6144
) (
    input  logic clk, reset,
    input  logic [7:0] audio_latch,
    input  logic [4:0] sound2_pulse,
    input  logic [3:0] sound2_subaddr,
    input  logic player_shot_pulse, shot_arrive_pulse, diagnostic_trigger,
    output logic signed [15:0] audio_sample,
    output logic signed [15:0] audio_front,
    output logic signed [15:0] audio_back
);
    logic [9:0] sample_div;
    wire sample_tick = sample_div == SAMPLE_DIV - 1;
    logic diagnostic_d, diagnostic_bypass;
    wire diagnostic_rise = diagnostic_trigger && !diagnostic_d;
    wire sound_enabled = (audio_latch[7] && !audio_latch[0]) || diagnostic_bypass;

    logic [15:0] high_phase, low_phase, ufo_phase, warning_phase, rocket_phase;
    logic [15:0] event_phase [0:4];
    logic [14:0] high_age, low_age;
    logic [14:0] event_age [0:4];
    logic [3:0] event_variant [0:4];
    logic high_active, low_active;
    logic [4:0] event_active;
    logic [14:0] noise_lfsr;
    logic signed [17:0] explosion_noise;

    logic [15:0] high_step, low_step, high_envelope, low_envelope;
    logic signed [20:0] high_voice, low_voice, ufo_voice, warning_voice, rocket_voice;
    logic signed [20:0] invader_voice;
    logic signed [20:0] event_voice [0:4];
    logic signed [20:0] explosion_upper, explosion_lower;
    logic signed [20:0] dry_front, dry_back, echo_send, echo_wet;
    logic signed [20:0] front_mix, back_mix, mono_mix;
    integer i;

    function automatic logic [15:0] decay_env(
        input logic [15:0] start_level,
        input logic [15:0] floor_level,
        input logic [14:0] age,
        input integer shift
    );
        logic [31:0] drop;
        begin
            drop = {17'd0, age} << shift;
            if (drop >= start_level - floor_level) decay_env = floor_level;
            else decay_env = start_level - drop[15:0];
        end
    endfunction

    function automatic logic signed [20:0] square_voice(
        input logic [15:0] phase,
        input logic [15:0] amplitude
    );
        logic signed [20:0] magnitude;
        begin
            magnitude = $signed({5'b0, amplitude});
            square_voice = phase[15] ? magnitude : -magnitude;
        end
    endfunction

    function automatic logic signed [15:0] clamp16(input logic signed [20:0] value);
        begin
            if (value > 21'sd32767) clamp16 = 16'sh7fff;
            else if (value < -21'sd32768) clamp16 = 16'sh8000;
            else clamp16 = value[15:0];
        end
    endfunction

    stactics_76477 invader_76477 (
        .clk(clk), .reset(reset), .sample_tick(sample_tick),
        .enable(audio_latch[4]), .distance(audio_latch[2:1]),
        .noise_bit(noise_lfsr[0]), .sample(invader_voice)
    );

    stactics_echo bbd_echo (
        .clk(clk), .reset(reset), .sample_tick(sample_tick),
        .enable(sound_enabled), .send_sample(echo_send), .wet_sample(echo_wet)
    );

    always_comb begin
        high_step = 16'd4400 - {3'b000, high_age[14:2]};
        low_step = 16'd1500 - {4'b0000, low_age[14:4]};
        high_envelope = decay_env(16'h3400, 16'h0400, high_age, 2);
        low_envelope = decay_env(16'h3400, 16'h0300, low_age, 2);
        high_voice = square_voice(high_phase, high_envelope);
        low_voice = square_voice(low_phase, low_envelope);
        if (noise_lfsr[1]) low_voice = low_voice + ($signed({5'b0, low_envelope}) >>> 3);
        else low_voice = low_voice - ($signed({5'b0, low_envelope}) >>> 3);

        // A-E retain ROM address order. Effect names are provisional until
        // every sound-board input net has been traced from the schematic.
        event_voice[0] = square_voice(event_phase[0], decay_env(16'h2800, 16'h0200, event_age[0], 1));
        if (noise_lfsr[2]) event_voice[0] = event_voice[0] + 21'sd2400;
        else event_voice[0] = event_voice[0] - 21'sd2400;

        event_voice[1] = square_voice(event_phase[1], decay_env(16'h2400, 16'h0200, event_age[1], 3));
        if (noise_lfsr[3]) event_voice[1] = event_voice[1] + 21'sd1200;

        event_voice[2] = square_voice(event_phase[2], decay_env(16'h2200, 16'h0200, event_age[2], 3));
        if (noise_lfsr[4]) event_voice[2] = event_voice[2] +
                                                (event_variant[2] == 4'h4 ? 21'sd2200 : 21'sd1400);
        else event_voice[2] = event_voice[2] - 21'sd1400;

        // Filtered noise gives the explosion the deep, rough cabinet character
        // instead of a bright click riding on a square wave.
        explosion_lower = square_voice(event_phase[3], decay_env(16'h0800, 16'h0100, event_age[3], 1)) + explosion_noise;
        explosion_upper = square_voice(event_phase[3] + 16'h2800,
                                       decay_env(16'h0600, 16'h0100, event_age[3], 1));
        explosion_upper = explosion_upper + (explosion_noise >>> 1);
        event_voice[3] = explosion_lower;

        event_voice[4] = square_voice(event_phase[4], decay_env(16'h2000, 16'h0200, event_age[4], 2));
        if (event_age[4][9]) event_voice[4] = event_voice[4] >>> 1;

        ufo_voice = audio_latch[3] ?
                    square_voice(ufo_phase, ufo_phase[13] ? 16'h0d00 : 16'h1100) : 21'sd0;
        warning_voice = audio_latch[5] ?
                        square_voice(warning_phase, warning_phase[13] ? 16'h0f00 : 16'h0800) : 21'sd0;
        rocket_voice = audio_latch[6] ? square_voice(rocket_phase, 16'h0700) : 21'sd0;
        if (audio_latch[6]) begin
            if (noise_lfsr[7]) rocket_voice = rocket_voice + 21'sd650;
            else rocket_voice = rocket_voice - 21'sd650;
        end

        dry_front = (high_active ? high_voice : 21'sd0) +
                    (low_active ? low_voice : 21'sd0) +
                    (event_active[0] ? event_voice[0] : 21'sd0) +
                    (event_active[1] ? event_voice[1] : 21'sd0) +
                    (event_active[2] ? event_voice[2] : 21'sd0) +
                    (event_active[3] ? explosion_upper : 21'sd0) +
                    (event_active[4] ? event_voice[4] : 21'sd0) +
                    ufo_voice + invader_voice + warning_voice + rocket_voice;
        dry_back = (high_active ? (high_voice >>> 1) : 21'sd0) +
                   (low_active ? low_voice : 21'sd0) +
                   (event_active[0] ? event_voice[0] : 21'sd0) +
                   (event_active[1] ? event_voice[1] : 21'sd0) +
                   (event_active[2] ? event_voice[2] : 21'sd0) +
                   (event_active[3] ? explosion_lower : 21'sd0) +
                   (event_active[4] ? (event_voice[4] >>> 1) : 21'sd0) +
                   (ufo_voice >>> 1) + (invader_voice >>> 1) + warning_voice + rocket_voice;

        // Do not send the sustained motor/warning beds around the feedback loop.
        echo_send = (high_active ? high_voice : 21'sd0) +
                    (low_active ? low_voice : 21'sd0) +
                    (event_active[0] ? event_voice[0] : 21'sd0) +
                    (event_active[1] ? event_voice[1] : 21'sd0) +
                    (event_active[2] ? event_voice[2] : 21'sd0) +
                    (event_active[3] ? explosion_lower : 21'sd0) +
                    (event_active[4] ? event_voice[4] : 21'sd0);
        front_mix = dry_front + (echo_wet >>> 2);
        back_mix = dry_back + (echo_wet >>> 1);
        mono_mix = (front_mix >>> 1) + (back_mix >>> 1);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            sample_div <= 0;
            high_phase <= 0; low_phase <= 0; ufo_phase <= 0;
            warning_phase <= 0; rocket_phase <= 0;
            high_age <= 0; low_age <= 0;
            high_active <= 0; low_active <= 0; event_active <= 0;
            noise_lfsr <= 15'h4a35;
            explosion_noise <= 0;
            diagnostic_d <= 0; diagnostic_bypass <= 0;
            audio_sample <= 0; audio_front <= 0; audio_back <= 0;
            for (i = 0; i < 5; i = i + 1) begin
                event_phase[i] <= 0; event_age[i] <= 0; event_variant[i] <= 0;
            end
        end else begin
            diagnostic_d <= diagnostic_trigger;
            if (sample_tick) sample_div <= 0;
            else sample_div <= sample_div + 1'b1;

            if (diagnostic_rise) begin
                high_phase <= 0; high_age <= 0; high_active <= 1;
                diagnostic_bypass <= 1;
            end else if (player_shot_pulse) begin
                // The cabinet's audible pair is produced by the shot-arrival
                // circuit. Do not add the modern-core's misleading initial blip.
                high_active <= 0; diagnostic_bypass <= 0;
            end else if (sample_tick && high_active) begin
                high_phase <= high_phase + high_step;
                if (high_age >= HIGH_SAMPLES - 1'b1) begin
                    high_active <= 0; diagnostic_bypass <= 0;
                end else high_age <= high_age + 1'b1;
            end

            if (shot_arrive_pulse) begin
                low_phase <= 0; low_age <= 0; low_active <= 1;
            end else if (sample_tick && low_active) begin
                low_phase <= low_phase + low_step;
                if (low_age >= LOW_SAMPLES - 1'b1) low_active <= 0;
                else low_age <= low_age + 1'b1;
            end

            for (i = 0; i < 5; i = i + 1) begin
                if (sound2_pulse[i]) begin
                    event_phase[i] <= 0; event_age[i] <= 0; event_active[i] <= 1;
                    event_variant[i] <= sound2_subaddr;
                end else if (sample_tick && event_active[i]) begin
                    case (i)
                        0: event_phase[i] <= event_phase[i] + (16'd1250 - {4'b0, event_age[i][14:3]});
                        1: event_phase[i] <= event_phase[i] + (16'd3000 + {4'b0, event_age[i][14:4]});
                        2: event_phase[i] <= event_phase[i] + (16'd2450 - {5'b0, event_age[i][14:5]});
                        3: event_phase[i] <= event_phase[i] + (16'd240 - {5'b0, event_age[i][14:5]});
                        default: event_phase[i] <= event_phase[i] + (event_age[i][10] ? 16'd2200 : 16'd1800);
                    endcase
                    event_age[i] <= event_age[i] + 1'b1;
                    case (i)
                        0: if (event_age[i] >= 15'd9215) event_active[i] <= 0;
                        1: if (event_age[i] >= 15'd2559) event_active[i] <= 0;
                        2: if (event_age[i] >= 15'd2303) event_active[i] <= 0;
                        3: if (event_age[i] >= 15'd12287) event_active[i] <= 0;
                        default: if (event_age[i] >= 15'd4607) event_active[i] <= 0;
                    endcase
                end
            end

            if (sample_tick) begin
                ufo_phase <= ufo_phase + (ufo_phase[12] ? 16'd405 : 16'd455);
                warning_phase <= warning_phase + (warning_phase[13] ? 16'd690 : 16'd850);
                rocket_phase <= rocket_phase + 16'd250;
                noise_lfsr <= {noise_lfsr[13:0], noise_lfsr[14] ^ noise_lfsr[13]};
                if (event_active[3]) begin
                    if (noise_lfsr[5]) explosion_noise <= explosion_noise + ((18'sd12000 - explosion_noise) >>> 2);
                    else explosion_noise <= explosion_noise + ((-18'sd12000 - explosion_noise) >>> 2);
                end else explosion_noise <= explosion_noise - (explosion_noise >>> 4);
                if (sound_enabled) begin
                    audio_front <= clamp16(front_mix);
                    audio_back <= clamp16(back_mix);
                    audio_sample <= clamp16(mono_mix);
                end else begin
                    audio_front <= 0; audio_back <= 0; audio_sample <= 0;
                end
            end
        end
    end
endmodule
