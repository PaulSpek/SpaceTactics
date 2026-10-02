// SPDX-License-Identifier: GPL-3.0-or-later
// Sixteen-line in-raster representation of the Space Tactics dashboard.
module stactics_dashboard (
    input  logic [8:0] x,
    input  logic [8:0] y,
    input  logic       enabled,
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

    function automatic logic micro_glyph(
        input logic [7:0] character,
        input integer row,
        input integer column
    );
        logic [14:0] glyph;
        begin
            case (character)
                "A": glyph = 15'b010_101_111_101_101;
                "B": glyph = 15'b110_101_110_101_110;
                "D": glyph = 15'b110_101_101_101_110;
                "E": glyph = 15'b111_100_110_100_111;
                "G": glyph = 15'b011_100_101_101_011;
                "I": glyph = 15'b111_010_010_010_111;
                "N": glyph = 15'b101_111_111_111_101;
                "O": glyph = 15'b010_101_101_101_010;
                "R": glyph = 15'b110_101_110_101_101;
                "U": glyph = 15'b101_101_101_101_111;
                "Y": glyph = 15'b101_101_010_010_010;
                default: glyph = 15'd0;
            endcase
            if (row >= 0 && row < 5 && column >= 0 && column < 3)
                micro_glyph = glyph[14 - (row * 3 + column)];
            else
                micro_glyph = 1'b0;
        end
    endfunction

    function automatic [7:0] barrier_char(input integer position);
        begin
            case (position)
                0: barrier_char = "E";  1: barrier_char = "N";
                2: barrier_char = "E";  3: barrier_char = "R";
                4: barrier_char = "G";  5: barrier_char = "Y";
                7: barrier_char = "B";  8: barrier_char = "A";
                9: barrier_char = "R"; 10: barrier_char = "R";
               11: barrier_char = "I"; 12: barrier_char = "E";
               13: barrier_char = "R";
                default: barrier_char = 8'h20;
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
                (segments[0] && py == 0 && px >= 1 && px <= 3) ||
                (segments[1] && px == 4 && py >= 1 && py <= 3) ||
                (segments[2] && px == 4 && py >= 5 && py <= 7) ||
                (segments[3] && py == 8 && px >= 1 && px <= 3) ||
                (segments[4] && px == 0 && py >= 5 && py <= 7) ||
                (segments[5] && px == 0 && py >= 1 && py <= 3) ||
                (segments[6] && py == 4 && px >= 1 && px <= 3);
        end
    endfunction

    // One-line micro-labels, compact score digits, and two rows of live lamps.
    always @* begin
        active = enabled && (x < 256 && y >= 216 && y < 232);
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
            border_on = (y == 216) ||
                        (((x == 16 || x == 85) && y >= 217 && y <= 230) ||
                         ((y == 217 || y == 230) && x >= 16 && x <= 85)) ||
                        (((x == 89 || x == 167) && y >= 217 && y <= 230) ||
                         ((y == 217 || y == 230) && x >= 89 && x <= 167)) ||
                        (((x == 171 || x == 240) && y >= 217 && y <= 230) ||
                         ((y == 217 || y == 230) && x >= 171 && x <= 240));

            for (integer i = 0; i < 14; i = i + 1)
                if (x >= 27 + i*4 && x < 30 + i*4 && y >= 219 && y < 224)
                    label_on = label_on |
                        micro_glyph(barrier_char(i), y-219, x-(27+i*4));
            for (integer i = 0; i < 5; i = i + 1)
                if (x >= 191 + i*4 && x < 194 + i*4 && y >= 219 && y < 224)
                    label_on = label_on |
                        micro_glyph(round_char(i), y-219, x-(191+i*4));

            for (integer i = 0; i < 12; i = i + 1) begin
                if (x == 29 + i*4 && y >= 226 && y <= 228) begin
                    indicator_area = 1'b1;
                    case (i / 4)
                        0: indicator_on = indicator_on | indicator_bit(display_9, i % 4);
                        1: indicator_on = indicator_on | indicator_bit(display_10, i % 4);
                        default: indicator_on = indicator_on | indicator_bit(display_11, i % 4);
                    endcase
                end
            end
            for (integer i = 0; i < 16; i = i + 1) begin
                if (x == 177 + i*3 && y >= 226 && y <= 228) begin
                    indicator_area = 1'b1;
                    case (i / 4)
                        0: indicator_on = indicator_on | indicator_bit(display_12, i % 4);
                        1: indicator_on = indicator_on | indicator_bit(display_13, i % 4);
                        2: indicator_on = indicator_on | indicator_bit(display_14, i % 4);
                        default: indicator_on = indicator_on | indicator_bit(display_15, i % 4);
                    endcase
                end
            end

            for (integer i = 0; i < 6; i = i + 1) begin
                case (i)
                    0: seg_mask = seven_seg(~display_1[3:0]);
                    1: seg_mask = seven_seg(~display_2[3:0]);
                    2: seg_mask = seven_seg(~display_3[3:0]);
                    3: seg_mask = seven_seg(~display_4[3:0]);
                    4: seg_mask = seven_seg(~display_5[3:0]);
                    default: seg_mask = seven_seg(~display_6[3:0]);
                endcase
                if (x >= 105 + i*8 && x < 110 + i*8 &&
                    y >= 220 && y < 229)
                    score_on = score_on |
                        segment_pixel(seg_mask, x-(105+i*8), y-220);
            end

            if (x >= 93 && x <= 163 && y >= 219 && y <= 229) begin
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
