// SPDX-License-Identifier: GPL-3.0-or-later
// Hardware behavior based on MAME src/mame/sega/stactics.cpp (BSD-3-Clause).
// The original game ROMs and PROM are supplied by the user at run time.
module stactics_board (
    input  logic        clk, reset,
    input  logic [15:0] cpu_addr,
    input  logic [7:0]  cpu_dout,
    input  logic        cpu_wr, cpu_int_ack,
    output logic [7:0]  cpu_din,
    output logic        irq_n,
    input  logic [7:0]  in0, in1, in2, in3,
    input  logic [1:0]  joy_ud_n,
    input  logic        diag_sound,
    input  logic        rom_wr,
    input  logic [15:0] rom_addr,
    input  logic [7:0]  rom_data,
    output logic        ce_pixel,
    output logic [7:0]  red, green, blue,
    output logic        hs, vs, de,
    output logic signed [15:0] audio_sample
);
    logic [7:0] program_rom [0:12287];
    logic [7:0] color_prom [0:2047];
    logic [7:0] beam_rom [0:2047];
    logic [7:0] work_ram [0:255];
    logic [7:0] vram_b [0:4095];
    logic [7:0] vram_d [0:4095];
    logic [7:0] vram_e [0:4095];
    logic [7:0] vram_f [0:4095];
    logic [7:0] rom_q, ram_q, b_cpu_q, d_cpu_q, e_cpu_q, f_cpu_q;
    logic [7:0] b_video_q, d_video_q, e_video_q, f_video_q, beam_q;
    logic [7:0] tile_b, tile_d, tile_e, tile_f;
    logic [7:0] gfx_b, gfx_d, gfx_e, gfx_f, prom_q;
    logic [9:0] pen;
    logic [3:0] pixel_phase = 0;
    logic [8:0] h_count = 0, v_count = 0;
    logic [7:0] scroll_d, scroll_e, scroll_f;
    logic [7:0] out_latch, audio_latch, lamp_latch;
    logic [4:0] sound2_pulse;
    logic player_shot_pulse;
    logic [7:0] display_latch [0:15];
    logic [3:0] frame_count;
    logic [7:0] rng = 8'h5a;
    logic signed [8:0] vert_pos, horiz_pos;
    logic [8:0] beam_state;
    logic [3:0] beam_step;
    logic shot_standby, shot_arrive, irq_pending;
    logic dashboard_active;
    logic [7:0] dashboard_red, dashboard_green, dashboard_blue;
    integer reset_index;

    // The real cabinet moves its monitor and mirror mechanically. MAME draws
    // the composed picture at (x-horiz_pos, y+vert_pos), then applies the
    // cabinet's horizontal flip. Work backwards from each output pixel here
    // so that the same motion is visible on a conventional display. The game
    // raster is scaled into 192 lines, reserving 40 lines for the dashboard.
    wire playfield_area = h_count < 256 && v_count < 192;
    wire [16:0] playfield_y_product = v_count[7:0] * 9'd309;
    wire [8:0] playfield_y = playfield_y_product[16:8];
    wire signed [9:0] source_x_calc = $signed({1'b0, ~h_count[7:0]}) + horiz_pos;
    wire signed [9:0] source_y_calc = $signed({1'b0, playfield_y}) - vert_pos;
    wire source_valid = playfield_area &&
                        source_x_calc >= 0 && source_x_calc < 256 &&
                        source_y_calc >= 0 && source_y_calc < 256;
    wire [7:0] video_x = source_x_calc[7:0];
    wire [7:0] video_y = source_y_calc[7:0];
    wire [7:0] yd = video_y - scroll_d;
    wire [7:0] ye = video_y - scroll_e;
    wire [7:0] yf = video_y - scroll_f;
    wire [9:0] tile_addr_b = {video_y[7:3], video_x[7:3]};
    wire [9:0] tile_addr_d = {yd[7:3], video_x[7:3]};
    wire [9:0] tile_addr_e = {ye[7:3], video_x[7:3]};
    wire [9:0] tile_addr_f = {yf[7:3], video_x[7:3]};
    wire [11:0] video_addr_b = pixel_phase < 2 ? {2'b00, tile_addr_b} :
                                 {1'b1, tile_b, video_y[2:0]};
    wire [11:0] video_addr_d = pixel_phase < 2 ? {2'b00, tile_addr_d} :
                                 {1'b1, tile_d, yd[2:0]};
    wire [11:0] video_addr_e = pixel_phase < 2 ? {2'b00, tile_addr_e} :
                                 {1'b1, tile_e, ye[2:0]};
    wire [11:0] video_addr_f = pixel_phase < 2 ? {2'b00, tile_addr_f} :
                                 {1'b1, tile_f, yf[2:0]};
    wire frame_tick = pixel_phase == 9 && h_count == 327 && v_count == 231;
    wire cpu_we = cpu_wr && !reset;

    // The cabinet fire beam consists of two mirrored banks of 64 LEDs. Map
    // them into the visible raster as converging rails. The inexpensive shift
    // approximations follow the geometry in MAME's stactics artwork layout.
    wire beam_y_visible = playfield_area &&
                          playfield_y >= 94 && playfield_y <= 188;
    wire [7:0] beam_delta = 8'd188 - playfield_y[7:0];
    wire [7:0] beam_index_calc = beam_delta - (beam_delta >> 2) - (beam_delta >> 4);
    wire [5:0] beam_index = beam_index_calc > 62 ? 6'd62 : beam_index_calc[5:0];
    wire [8:0] beam_x_left = beam_delta + (beam_delta >> 2) +
                             (beam_delta >> 4) + (beam_delta >> 6);
    wire [8:0] beam_x_right = 9'd255 - beam_x_left;
    wire beam_location = beam_y_visible &&
                         ((h_count >= beam_x_left && h_count <= beam_x_left + 2) ||
                          (h_count + 2 >= beam_x_right && h_count <= beam_x_right));
    wire [10:0] beam_rom_addr = {beam_index[3], beam_index[5:4], beam_state[7:0]};
    wire beam_pixel = !shot_standby && beam_location && beam_q[beam_index[2:0]];
    wire sight_pixel = audio_latch[6] && h_count >= 126 && h_count <= 129 &&
                       v_count >= 76 && v_count <= 79;

    stactics_sound_ctrl sound_ctrl (
        .clk(clk),
        .reset(reset),
        .cpu_wr(cpu_we),
        .cpu_addr(cpu_addr),
        .cpu_dout(cpu_dout),
        .audio_latch(audio_latch),
        .sound2_pulse(sound2_pulse),
        .player_shot_pulse(player_shot_pulse)
    );

    stactics_sound sound (
        .clk(clk),
        .reset(reset),
        .audio_latch(audio_latch),
        .sound2_pulse(sound2_pulse),
        .player_shot_pulse(player_shot_pulse),
        .diagnostic_trigger(diag_sound),
        .audio_sample(audio_sample)
    );

    stactics_dashboard dashboard (
        .x(h_count), .y(v_count),
        .display_1(display_latch[1]),
        .display_2(display_latch[2]),
        .display_3(display_latch[3]),
        .display_4(display_latch[4]),
        .display_5(display_latch[5]),
        .display_6(display_latch[6]),
        .display_9(display_latch[9]),
        .display_10(display_latch[10]),
        .display_11(display_latch[11]),
        .display_12(display_latch[12]),
        .display_13(display_latch[13]),
        .display_14(display_latch[14]),
        .display_15(display_latch[15]),
        .active(dashboard_active),
        .red(dashboard_red),
        .green(dashboard_green),
        .blue(dashboard_blue)
    );

    // CPU and renderer each have a synchronous read port on the video RAM.
    always_ff @(posedge clk) begin
        rom_q <= program_rom[cpu_addr[13:0]];
        ram_q <= work_ram[cpu_addr[7:0]];
        b_cpu_q <= vram_b[cpu_addr[11:0]];
        d_cpu_q <= vram_d[cpu_addr[11:0]];
        e_cpu_q <= vram_e[cpu_addr[11:0]];
        f_cpu_q <= vram_f[cpu_addr[11:0]];
        b_video_q <= vram_b[video_addr_b];
        d_video_q <= vram_d[video_addr_d];
        e_video_q <= vram_e[video_addr_e];
        f_video_q <= vram_f[video_addr_f];
        beam_q <= beam_rom[beam_rom_addr];
        if (rom_wr) begin
            if (rom_addr < 16'h3000) program_rom[rom_addr] <= rom_data;
            else if (rom_addr < 16'h3800) color_prom[rom_addr - 16'h3000] <= rom_data;
            else if (rom_addr < 16'h4000) beam_rom[rom_addr - 16'h3800] <= rom_data;
        end
        if (cpu_we) begin
            case (cpu_addr[15:12])
                4'h4: work_ram[cpu_addr[7:0]] <= cpu_dout;
                4'hb: vram_b[cpu_addr[11:0]] <= cpu_dout;
                4'hd: vram_d[cpu_addr[11:0]] <= cpu_dout;
                4'he: vram_e[cpu_addr[11:0]] <= cpu_dout;
                4'hf: vram_f[cpu_addr[11:0]] <= cpu_dout;
                default: ;
            endcase
        end
    end

    always_comb begin
        cpu_din = 8'hff;
        if (!cpu_int_ack) case (cpu_addr[15:12])
            4'h0, 4'h1, 4'h2: cpu_din = rom_q;
            4'h4: if (!cpu_addr[11]) cpu_din = ram_q;
            4'h5: cpu_din = {(!audio_latch[6] && ((vert_pos != 0) || (horiz_pos != 0))), in0[6:0]};
            4'h6: cpu_din = in1;
            4'h7: cpu_din = {in2[7:4], frame_count[3], rng[2:0]};
            4'h8: cpu_din = {!shot_arrive, in3[6:2], shot_standby, in3[0]};
            4'h9: cpu_din = 8'h70 - vert_pos[7:0];
            4'ha: cpu_din = horiz_pos[7:0] + 8'h88;
            4'hb: cpu_din = b_cpu_q;
            4'hd: cpu_din = d_cpu_q;
            4'he: cpu_din = e_cpu_q;
            4'hf: cpu_din = f_cpu_q;
            default: ;
        endcase
    end

    function automatic [3:0] beam_speed(input logic [7:0] value);
        integer i;
        logic [2:0] edges;
        begin
            edges = 0;
            for (i = 0; i < 8; i = i + 1)
                if (value[i] && !value[(i+1)%8]) edges = edges + 1'b1;
            case (edges)
                3'd1: beam_speed = 4'd2;
                3'd2: beam_speed = 4'd4;
                3'd3: beam_speed = 4'd7;
                3'd4: beam_speed = 4'd9;
                default: beam_speed = 4'd0;
            endcase
        end
    endfunction

    always_ff @(posedge clk) begin
        if (reset) begin
            scroll_d <= 0; scroll_e <= 0; scroll_f <= 0;
            out_latch <= 0; lamp_latch <= 0;
            for (reset_index = 0; reset_index < 16; reset_index = reset_index + 1)
                display_latch[reset_index] <= 0;
            frame_count <= 0; vert_pos <= 0; horiz_pos <= 0;
            beam_state <= 0; beam_step <= 0;
            shot_standby <= 1; shot_arrive <= 0; irq_pending <= 0;
        end else begin
            rng <= {rng[6:0], rng[7] ^ rng[5] ^ rng[4] ^ rng[3]};
            if (cpu_int_ack) irq_pending <= 0;
            if (frame_tick) begin
                irq_pending <= 1;
                frame_count <= frame_count + 1'b1;
                if (!shot_standby) begin
                    if ((beam_state < 9'h08b && beam_state + beam_step >= 9'h08b) ||
                        (beam_state < 9'h0ca && beam_state + beam_step >= 9'h0ca)) shot_arrive <= 1;
                    if (beam_state + beam_step >= 9'h100) begin
                        beam_state <= 0;
                        shot_standby <= 1;
                    end else beam_state <= beam_state + beam_step;
                end
                if (audio_latch[6]) begin
                    if (!joy_ud_n[0] && vert_pos > -9'sd128) vert_pos <= vert_pos - 1'b1;
                    else if (!joy_ud_n[1] && vert_pos < 9'sd127) vert_pos <= vert_pos + 1'b1;
                    if (!in3[5] && horiz_pos < 9'sd127) horiz_pos <= horiz_pos + 1'b1;
                    else if (!in3[6] && horiz_pos > -9'sd128) horiz_pos <= horiz_pos - 1'b1;
                end else begin
                    if (vert_pos > 0) vert_pos <= vert_pos - 1'b1;
                    else if (vert_pos < 0) vert_pos <= vert_pos + 1'b1;
                    if (horiz_pos > 0) horiz_pos <= horiz_pos - 1'b1;
                    else if (horiz_pos < 0) horiz_pos <= horiz_pos + 1'b1;
                end
            end
            if (cpu_we && cpu_addr[15:12] == 4'h6) begin
                case (cpu_addr[7:4])
                    4'h0: out_latch[cpu_addr[2:0]] <= cpu_dout[0];
                    4'h2: lamp_latch[cpu_addr[2:0]] <= cpu_dout[0];
                    4'h3: beam_step <= beam_speed(cpu_dout);
                    4'h4: shot_standby <= 0;
                    4'h5: shot_arrive <= 0;
                    4'h6: display_latch[cpu_addr[3:0]] <= cpu_dout;
                    default: ;
                endcase
            end
            if (cpu_we && cpu_addr[15:12] == 4'h8 && cpu_dout[0]) begin
                case (cpu_addr[10:8])
                    3'd4: scroll_d <= cpu_addr[7:0];
                    3'd5: scroll_e <= cpu_addr[7:0];
                    3'd6: scroll_f <= cpu_addr[7:0];
                    default: ;
                endcase
            end
        end
    end
    assign irq_n = !irq_pending;

    // One video read port per plane, time-shared across tile and graphics.
    always_ff @(posedge clk) begin
        if (pixel_phase == 1) begin
            tile_b <= b_video_q;
            tile_d <= d_video_q;
            tile_e <= e_video_q;
            tile_f <= f_video_q;
        end
        if (pixel_phase == 3) begin
            gfx_b <= b_video_q;
            gfx_d <= d_video_q;
            gfx_e <= e_video_q;
            gfx_f <= f_video_q;
        end
        if (pixel_phase == 4)
            pen <= {out_latch[7:6], gfx_d[~video_x[2:0]], gfx_e[~video_x[2:0]],
                    gfx_f[~video_x[2:0]], gfx_b[~video_x[2:0]], tile_b[7:4]};
        if (pixel_phase == 5) prom_q <= color_prom[pen];
        if (pixel_phase == 6) begin
            if (dashboard_active) begin
                red <= dashboard_red;
                green <= dashboard_green;
                blue <= dashboard_blue;
            end else if (sight_pixel) begin
                red <= 8'hff;
                green <= 8'h18;
                blue <= 8'h10;
            end else if (beam_pixel) begin
                red <= 8'h20;
                green <= 8'hff;
                blue <= 8'h40;
            end else if (!source_valid) begin
                red <= 0;
                green <= 0;
                blue <= 0;
            end else begin
                red <= {8{prom_q[0]}};
                green <= prom_q[1] ? (prom_q[3] ? 8'h33 : 8'hff) : 8'h00;
                blue <= {8{prom_q[2]}};
            end
        end
        if (pixel_phase == 9) begin
            pixel_phase <= 0;
            if (h_count == 327) begin
                h_count <= 0;
                if (v_count == 261) v_count <= 0;
                else v_count <= v_count + 1'b1;
            end else h_count <= h_count + 1'b1;
        end else pixel_phase <= pixel_phase + 1'b1;
    end
    assign ce_pixel = pixel_phase == 9;
    assign de = h_count < 256 && v_count < 232;
    assign hs = !(h_count >= 272 && h_count < 304);
    assign vs = !(v_count >= 240 && v_count < 244);
endmodule
