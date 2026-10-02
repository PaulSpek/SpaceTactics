`timescale 1ns/1ps
module tb_stactics_board;
    logic clk = 0;
    always #10 clk = ~clk;
    logic reset = 1;
    logic [15:0] cpu_addr = 0, rom_addr = 0;
    logic [7:0] cpu_dout = 0, rom_data = 0;
    logic cpu_wr = 0, cpu_int_ack = 0, rom_wr = 0;
    logic diag_sound = 0;
    logic [7:0] in0 = 8'h7f, in1 = 8'h3f, in2 = 8'hf0, in3 = 8'h7d;
    logic [1:0] joy_ud_n = 2'b11;
    wire [7:0] cpu_din, red, green, blue;
    wire irq_n, ce_pixel, hs, vs, de;
    wire signed [15:0] audio_sample;

    stactics_board dut (.*);

    task automatic write_cpu(input [15:0] address, input [7:0] value);
        @(negedge clk);
        cpu_addr = address;
        cpu_dout = value;
        cpu_wr = 1;
        @(negedge clk);
        cpu_wr = 0;
    endtask
    task automatic load_rom(input [15:0] address, input [7:0] value);
        @(negedge clk);
        rom_addr = address;
        rom_data = value;
        rom_wr = 1;
        @(negedge clk);
        rom_wr = 0;
    endtask
    task automatic check_read(input [15:0] address, input [7:0] expected);
        @(negedge clk);
        cpu_addr = address;
        @(negedge clk);
        if (cpu_din !== expected)
            $fatal(1, "read %04x: expected %02x, got %02x", address, expected, cpu_din);
    endtask

    initial begin
        load_rom(16'h0000, 8'hc3);
        load_rom(16'h3011, 8'h01); // pen 0x11 becomes red
        load_rom(16'h3800, 8'h01); // beam state 0, LED 0 on
        @(negedge clk);
        reset = 0;
        check_read(16'h0000, 8'hc3);
        write_cpu(16'h400a, 8'h5a);
        check_read(16'h470a, 8'h5a); // 256-byte mirror
        write_cpu(16'h8405, 8'h01);
        if (dut.scroll_d !== 8'h05) $fatal(1, "scroll register");
        write_cpu(16'h8400, 8'h01); // restore zero scroll for pixel test
        write_cpu(16'hb03f, 8'h10); // source y=8: rightmost B tile in row 1
        write_cpu(16'hb880, 8'h01); // code 0x10, rightmost pixel in glyph row 0
        write_cpu(16'hd03f, 8'h00);
        write_cpu(16'he03f, 8'h00);
        write_cpu(16'hf03f, 8'h00);
        write_cpu(16'hd800, 8'h00);
        write_cpu(16'he800, 8'h00);
        write_cpu(16'hf800, 8'h00);
        @(negedge clk);
        dut.h_count = 0;
        dut.v_count = 0;
        dut.pixel_phase = 0;
        repeat (8) @(negedge clk);
        if (red !== 8'hff || green !== 0 || blue !== 0)
            $fatal(1, "PROM / video lookup: %02x %02x %02x", red, green, blue);

        // The dashboard and aiming light are cabinet play indicators: neither
        // appears while the motor is off / a game is not in progress.
        @(negedge clk);
        dut.h_count = 128;
        dut.v_count = 78;
        #1;
        if (dut.sight_pixel || dut.dashboard_active)
            $fatal(1, "play indicators visible with motor off");

        // Motor-on plus joystick up must move the emulated mirror, and that
        // position must feed the source coordinate used by the renderer.
        write_cpu(16'h6016, 8'h01);
        joy_ud_n = 2'b10;
        @(negedge clk);
        dut.h_count = 327;
        dut.v_count = 231;
        dut.pixel_phase = 9;
        @(negedge clk);
        if (dut.vert_pos !== -1)
            $fatal(1, "mirror movement not applied: pos=%0d source_y=%0d",
                   dut.vert_pos, dut.source_y_calc);
        joy_ud_n = 2'b11;
        @(negedge clk);
        dut.h_count = 0;
        dut.v_count = 100;
        #1;
        if (dut.playfield_y !== 108 || dut.source_y_calc !== 109)
            $fatal(1, "cropped mirror coordinate: y=%0d source_y=%0d",
                   dut.playfield_y, dut.source_y_calc);

        // A lit bit from epr-217 is overlaid at the bottom of the two beam
        // rails while a shot is in flight.
        @(negedge clk);
        dut.shot_standby = 0;
        dut.beam_state = 0;
        dut.h_count = 0;
        dut.v_count = 180;
        dut.pixel_phase = 0;
        repeat (8) @(negedge clk);
        if (red !== 8'h20 || green !== 8'hff || blue !== 8'h40)
            $fatal(1, "beam overlay: %02x %02x %02x", red, green, blue);

        // Motor-on lights one precise red aiming pixel over the playfield.
        @(negedge clk);
        dut.h_count = 127;
        dut.v_count = 78;
        #1;
        if (dut.sight_pixel)
            $fatal(1, "red sight corner should be transparent");
        @(negedge clk);
        dut.h_count = 128;
        dut.v_count = 78;
        dut.pixel_phase = 0;
        repeat (8) @(negedge clk);
        if (red !== 8'hff || green !== 8'h18 || blue !== 8'h10)
            $fatal(1, "red sight dot: %02x %02x %02x", red, green, blue);

        // Dashboard values are the real active-low game display latches.
        write_cpu(16'h6061, 8'hfd); // score digit 2
        write_cpu(16'h6069, 8'h0f); // light first barrier indicator
        @(negedge clk);
        dut.h_count = 106;
        dut.v_count = 220;
        dut.pixel_phase = 0;
        repeat (8) @(negedge clk);
        if (red !== 8'hff || green !== 8'h20 || blue !== 8'h10)
            $fatal(1, "dashboard score digit: %02x %02x %02x", red, green, blue);
        @(negedge clk);
        dut.h_count = 29;
        dut.v_count = 227;
        dut.pixel_phase = 0;
        repeat (8) @(negedge clk);
        if (red !== 8'hff || green !== 8'h38 || blue !== 8'h18)
            $fatal(1, "barrier indicator: %02x %02x %02x", red, green, blue);
        @(negedge clk);
        dut.h_count = 327;
        dut.v_count = 231;
        dut.pixel_phase = 9;
        @(negedge clk);
        if (irq_n !== 0) $fatal(1, "vblank interrupt");
        cpu_int_ack = 1;
        @(negedge clk);
        if (irq_n !== 1) $fatal(1, "interrupt acknowledge");
        $display("PASS: ROM, RAM, movement, beam, sight, dashboard, video and interrupt");
        $finish;
    end
endmodule
