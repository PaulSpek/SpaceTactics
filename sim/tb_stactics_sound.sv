`timescale 1ns/1ps
module tb_stactics_sound;
    logic clk = 0;
    always #10 clk = ~clk;

    logic reset = 1;
    logic cpu_wr = 0;
    logic [15:0] cpu_addr = 0;
    logic [7:0] cpu_dout = 0;
    logic diagnostic_trigger = 0;
    wire [7:0] audio_latch;
    wire [4:0] sound2_pulse;
    wire player_shot_pulse;
    wire signed [15:0] audio_sample;
    integer nonzero_samples;

    stactics_sound_ctrl ctrl (
        .clk(clk), .reset(reset), .cpu_wr(cpu_wr),
        .cpu_addr(cpu_addr), .cpu_dout(cpu_dout),
        .audio_latch(audio_latch), .sound2_pulse(sound2_pulse),
        .player_shot_pulse(player_shot_pulse)
    );

    stactics_sound #(.SAMPLE_DIV(8)) sound (
        .clk(clk), .reset(reset), .audio_latch(audio_latch),
        .sound2_pulse(sound2_pulse),
        .player_shot_pulse(player_shot_pulse),
        .diagnostic_trigger(diagnostic_trigger),
        .audio_sample(audio_sample)
    );

    task automatic write_cpu(input [15:0] address, input [7:0] value);
        @(negedge clk);
        cpu_addr = address;
        cpu_dout = value;
        cpu_wr = 1;
        @(negedge clk);
        cpu_wr = 0;
    endtask

    initial begin
        repeat (3) @(negedge clk);
        reset = 0;

        // Enable sound, leave mute inactive, and verify the motor bit remains
        // available to the board through the shared audio latch.
        write_cpu(16'h6017, 8'h01);
        write_cpu(16'h6010, 8'h00);
        write_cpu(16'h6016, 8'h01);
        if (audio_latch !== 8'hc0)
            $fatal(1, "audio latch expected c0, got %02x", audio_latch);

        // Secondary trigger writes are pulses even when the low nibble differs.
        @(negedge clk);
        cpu_addr = 16'h60c4;
        cpu_dout = 8'h40;
        cpu_wr = 1;
        @(posedge clk);
        #1;
        if (sound2_pulse !== 5'b00100)
            $fatal(1, "secondary trigger C not decoded: %05b", sound2_pulse);
        @(negedge clk);
        cpu_wr = 0;
        @(posedge clk);
        #1;
        if (sound2_pulse !== 0)
            $fatal(1, "secondary trigger did not clear");

        // A 6040 write starts an audible player-shot envelope.
        write_cpu(16'h6040, 8'h00);
        nonzero_samples = 0;
        repeat (5000) begin
            @(posedge clk);
            if (audio_sample != 0)
                nonzero_samples = nonzero_samples + 1;
        end
        if (nonzero_samples == 0)
            $fatal(1, "player-shot voice produced no audio");
        if (sound.envelope == 0)
            $fatal(1, "player-shot envelope ended too quickly");

        // Mute suppresses gameplay audio.
        write_cpu(16'h6010, 8'h01);
        write_cpu(16'h6040, 8'h00);
        // The output is sample-and-hold; allow one complete sample interval
        // for the muted zero to replace the previous non-zero sample.
        repeat (1100) @(posedge clk);
        repeat (2200) begin
            @(posedge clk);
            if (audio_sample != 0)
                $fatal(1, "mute failed: sample %0d", audio_sample);
        end

        // The diagnostic trigger bypasses the game latch for installation tests.
        @(negedge clk);
        diagnostic_trigger = 1;
        @(negedge clk);
        diagnostic_trigger = 0;
        nonzero_samples = 0;
        repeat (5000) begin
            @(posedge clk);
            if (audio_sample != 0)
                nonzero_samples = nonzero_samples + 1;
        end
        if (nonzero_samples == 0)
            $fatal(1, "diagnostic trigger produced no audio");

        $display("PASS: sound latch, secondary triggers, shot voice, mute and diagnostic");
        $finish;
    end
endmodule
