// SPDX-License-Identifier: GPL-3.0-or-later
// Compact in-raster representation of the Space Tactics physical dashboard.
module stactics_dashboard (
    input  logic [8:0] x,
    input  logic [8:0] y,
    input  logic [7:0] display_1,
    input  logic [7:0] display_2,
    input  logic [7:0] display_3,
    input  logic [7:0] display_4,
    input  logic [7:0] display_5,
    input  logic [7:0] display_6,
    input  logic [7:0] display_9,
    input  logic [7:0] display_10,
    input  logic [7:0] display_11,
    input  logic [7:0] display_12,
    input  logic [7:0] display_13,
    input  logic [7:0] display_14,
    input  logic [7:0] display_15,
    output logic       active,
    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue
);
    logic border_on, label_on, indicator_area, indicator_on, score_on;
    logic [6:0] seg_mask;

    function automatic [6:0] seven_seg(input logic [3:0] value);
        begin
            case (value)
                4'h0: seven_seg = 7'h3f;
                4'h1: seven_seg = 7'h06;
                4'h2: seven_seg = 7'h5b;
                4'h3: seven_seg = 7'h4f;
                4'h4: seven_seg = 7'h66;
                4'h5: seven_seg = 7'h6d;
                4'h6: seven_seg = 7'h7c;
                4'h7: seven_seg = 7'h07;
                4'h8: seven_seg = 7'h7f;
                4'h9: seven_seg = 7'h67;
                4'ha: seven_seg = 7'h58;
                4'hb: seven_seg = 7'h4c;
                4'hc: seven_seg = 7'h62;
                4'hd: seven_seg = 7'h69;
                4'he: seven_seg = 7'h78;
                default: seven_seg = 7'h00;
            endcase
        end
    endfunction

    function automatic logic indicator_bit(
        input logic [7:0] value,
        input integer position
    );
        logic [6:0] segments;
        begin
            segments = seven_seg(~value[3:0]);
            case (position)
                0: indicator_bit = segments[2];
                1: indicator_bit = segments[6];
                2: indicator_bit = segments[5];
                default: indicator_bit = segments[4];
            endcase
        end
    endfunction

    function automatic logic glyph_pixel(
        input logic [7:0] character,
        input integer row,
        input integer column
    );
        logic [34:0] glyph;
        begin
            case (character)
                8'h41: glyph = {5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001}; // A
                8'h42: glyph = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110}; // B
                8'h43: glyph = {5'b01110,5'b10001,5'b10000,5'b10000,5'b10000,5'b10001,5'b01110}; // C
                8'h44: glyph = {5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110}; // D
                8'h45: glyph = {5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111}; // E
                8'h47: glyph = {5'b01110,5'b10001,5'b10000,5'b10111,5'b10001,5'b10001,5'b01110}; // G
                8'h49: glyph = {5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b11111}; // I
                8'h4e: glyph = {5'b10001,5'b11001,5'b11001,5'b10101,5'b10011,5'b10011,5'b10001}; // N
                8'h4f: glyph = {5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110}; // O
                8'h52: glyph = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001}; // R
                8'h53: glyph = {5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110}; // S
                8'h55: glyph = {5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110}; // U
                8'h59: glyph = {5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100}; // Y
                default: glyph = 35'd0;
            endcase
            if (row >= 0 && row < 7 && column >= 0 && column < 5)
                glyph_pixel = glyph[34 - (row * 5 + column)];
            else
                glyph_pixel = 1'b0;
        end
    endfunction

    function automatic [7:0] energy_char(input integer position);
        begin
            case (position)
                0: energy_char = "E"; 1: energy_char = "N";
                2: energy_char = "E"; 3: energy_char = "R";
                4: energy_char = "G"; default: energy_char = "Y";
            endcase
        end
    endfunction

    function automatic [7:0] barrier_char(input integer position);
        begin
            case (position)
                0: barrier_char = "B"; 1: barrier_char = "A";
                2: barrier_char = "R"; 3: barrier_char = "R";
                4: barrier_char = "I"; 5: barrier_char = "E";
                default: barrier_char = "R";
            endcase
        end
    endfunction

    function automatic [7:0] score_char(input integer position);
        begin
            case (position)
                0: score_char = "S"; 1: score_char = "C";
                2: score_char = "O"; 3: score_char = "R";
                default: score_char = "E";
            endcase
        end
    endfunction

    function automatic [7:0] round_char(input integer position);
        begin
            case (position)
                0: round_char = "R"; 1: round_char = "O";
                2: round_char = "U"; 3: round_char = "N";
                default: round_char = "D";
            endcase
        end
    endfunction

    function automatic logic segment_pixel(
        input logic [6:0] segments,
        input integer px,
        input integer py
    );
        begin
            segment_pixel =
                (segments[0] && py <= 1 && px >= 2 && px <= 6) ||
                (segments[1] && px >= 7 && py >= 2 && py <= 7) ||
                (segments[2] && px >= 7 && py >= 9 && py <= 14) ||
                (segments[3] && py >= 15 && px >= 2 && px <= 6) ||
                (segments[4] && px <= 1 && py >= 9 && py <= 14) ||
                (segments[5] && px <= 1 && py >= 2 && py <= 7) ||
                (segments[6] && py >= 7 && py <= 8 && px >= 2 && px <= 6);
        end
    endfunction

    // Quartus 17 treats a procedural loop index as state inside always_comb.
    // This is a fully assigned combinational renderer; use the equivalent
    // Verilog sensitivity form for compatibility with that legacy release.
    always @* begin
        active = (x < 256 && y >= 192 && y < 232);
        red = 8'h07;
        green = 8'h12;
        blue = 8'h18;
        border_on = 1'b0;
        label_on = 1'b0;
        indicator_area = 1'b0;
        indicator_on = 1'b0;
        score_on = 1'b0;
        seg_mask = 7'd0;

        if (active) begin
            border_on = (y == 192) ||
                        (((x == 3 || x == 81) && y >= 194 && y <= 229) ||
                         ((y == 194 || y == 229) && x >= 3 && x <= 81)) ||
                        (((x == 85 || x == 174) && y >= 194 && y <= 229) ||
                         ((y == 194 || y == 229) && x >= 85 && x <= 174)) ||
                        (((x == 178 || x == 252) && y >= 194 && y <= 229) ||
                         ((y == 194 || y == 229) && x >= 178 && x <= 252));

            for (integer i = 0; i < 6; i = i + 1)
                if (x >= 8 + i*6 && x < 13 + i*6 && y >= 196 && y < 203)
                    label_on = label_on |
                        glyph_pixel(energy_char(i), y-196, x-(8+i*6));
            for (integer i = 0; i < 7; i = i + 1)
                if (x >= 8 + i*6 && x < 13 + i*6 && y >= 204 && y < 211)
                    label_on = label_on |
                        glyph_pixel(barrier_char(i), y-204, x-(8+i*6));
            for (integer i = 0; i < 5; i = i + 1) begin
                if (x >= 112 + i*6 && x < 117 + i*6 && y >= 196 && y < 203)
                    label_on = label_on |
                        glyph_pixel(score_char(i), y-196, x-(112+i*6));
                if (x >= 199 + i*6 && x < 204 + i*6 && y >= 196 && y < 203)
                    label_on = label_on |
                        glyph_pixel(round_char(i), y-196, x-(199+i*6));
            end

            // Red LED rows, dim when off and bright when selected by the
            // original 7448/display-latch wiring.
            for (integer i = 0; i < 12; i = i + 1) begin
                if (x >= 8 + i*5 && x <= 10 + i*5 && y >= 216 && y <= 218) begin
                    indicator_area = 1'b1;
                    case (i / 4)
                        0: indicator_on = indicator_on | indicator_bit(display_9, i % 4);
                        1: indicator_on = indicator_on | indicator_bit(display_10, i % 4);
                        default: indicator_on = indicator_on | indicator_bit(display_11, i % 4);
                    endcase
                end
            end
            for (integer i = 0; i < 16; i = i + 1) begin
                if (x >= 183 + i*4 && x <= 185 + i*4 && y >= 216 && y <= 218) begin
                    indicator_area = 1'b1;
                    case (i / 4)
                        0: indicator_on = indicator_on | indicator_bit(display_12, i % 4);
                        1: indicator_on = indicator_on | indicator_bit(display_13, i % 4);
                        2: indicator_on = indicator_on | indicator_bit(display_14, i % 4);
                        default: indicator_on = indicator_on | indicator_bit(display_15, i % 4);
                    endcase
                end
            end

            // Six active-low 7448 digits in the dashboard's red score window.
            for (integer i = 0; i < 6; i = i + 1) begin
                case (i)
                    0: seg_mask = seven_seg(~display_1[3:0]);
                    1: seg_mask = seven_seg(~display_2[3:0]);
                    2: seg_mask = seven_seg(~display_3[3:0]);
                    3: seg_mask = seven_seg(~display_4[3:0]);
                    4: seg_mask = seven_seg(~display_5[3:0]);
                    default: seg_mask = seven_seg(~display_6[3:0]);
                endcase
                if (x >= 91 + i*13 && x < 100 + i*13 &&
                    y >= 207 && y < 224)
                    score_on = score_on |
                        segment_pixel(seg_mask, x-(91+i*13), y-207);
            end

            if (x >= 89 && x <= 169 && y >= 205 && y <= 225) begin
                red = 8'h1c;
                green = 8'h02;
                blue = 8'h04;
            end
            if (border_on || label_on) begin
                red = 8'hd8;
                green = 8'he8;
                blue = 8'he0;
            end
            if (indicator_area) begin
                red = indicator_on ? 8'hff : 8'h38;
                green = indicator_on ? 8'h38 : 8'h05;
                blue = indicator_on ? 8'h18 : 8'h08;
            end
            if (score_on) begin
                red = 8'hff;
                green = 8'h20;
                blue = 8'h10;
            end
        end
    end
endmodule
