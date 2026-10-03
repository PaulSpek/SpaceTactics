// SPDX-License-Identifier: GPL-3.0-or-later
// Game-specific approximation of the SN76477 section used by Space Tactics.
module stactics_76477 (
    input  logic clk, reset, sample_tick, enable,
    input  logic [1:0] distance,
    input  logic noise_bit,
    output logic signed [20:0] sample
);
    logic [15:0] vco_phase, slf_phase, envelope, vco_step;
    logic signed [17:0] filtered_noise;
    logic signed [20:0] tone;

    always_comb begin
        case (distance)
            2'b00: vco_step = 16'd430;
            2'b01: vco_step = 16'd535;
            2'b10: vco_step = 16'd675;
            default: vco_step = 16'd850;
        endcase
        if (slf_phase[15]) vco_step = vco_step + 16'd42;
        else vco_step = vco_step - 16'd42;
        tone = vco_phase[15] ? ($signed({5'b0, envelope}) >>> 3) :
                               -($signed({5'b0, envelope}) >>> 3);
        sample = tone + (filtered_noise >>> 2);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            vco_phase <= 0; slf_phase <= 0; envelope <= 0; filtered_noise <= 0;
        end else if (sample_tick) begin
            slf_phase <= slf_phase + 16'd19;
            if (enable) begin
                vco_phase <= vco_phase + vco_step;
                if (envelope < 16'h7000) envelope <= envelope + 16'h0400;
                if (noise_bit)
                    filtered_noise <= filtered_noise + ((18'sd5000 - filtered_noise) >>> 3);
                else
                    filtered_noise <= filtered_noise + ((-18'sd5000 - filtered_noise) >>> 3);
            end else begin
                if (envelope > 16'h0100) envelope <= envelope - 16'h0100;
                else envelope <= 0;
                filtered_noise <= filtered_noise - (filtered_noise >>> 3);
            end
        end
    end
endmodule
