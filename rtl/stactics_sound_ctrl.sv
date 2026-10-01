// SPDX-License-Identifier: GPL-3.0-or-later
// CPU-visible sound controls for Sega/Gremlin Space Tactics.
//
// MAME documents the LS259 latch at 0x6010-0x6017. The original ROM also
// writes five secondary trigger groups from 0x60a0 through 0x60ef; their exact
// effect names and active behavior remain to be established from schematics.
module stactics_sound_ctrl (
    input  logic        clk,
    input  logic        reset,
    input  logic        cpu_wr,
    input  logic [15:0] cpu_addr,
    input  logic [7:0]  cpu_dout,
    output logic [7:0]  audio_latch,
    output logic [4:0]  sound2_pulse,
    output logic        player_shot_pulse
);
    always_ff @(posedge clk) begin
        if (reset) begin
            audio_latch      <= 8'h00;
            sound2_pulse     <= 5'b00000;
            player_shot_pulse <= 1'b0;
        end else begin
            sound2_pulse      <= 5'b00000;
            player_shot_pulse <= 1'b0;

            if (cpu_wr && cpu_addr[15:12] == 4'h6) begin
                // Addressed LS259: data bit 0 is stored in the selected output.
                if (cpu_addr[7:4] == 4'h1)
                    audio_latch[cpu_addr[2:0]] <= cpu_dout[0];

                // The fire-beam trigger also starts the player-shot sound path.
                if (cpu_addr[7:4] == 4'h4)
                    player_shot_pulse <= 1'b1;

                // Preserve the five currently-undecoded secondary sound events.
                case (cpu_addr[7:4])
                    4'ha: sound2_pulse[0] <= 1'b1;
                    4'hb: sound2_pulse[1] <= 1'b1;
                    4'hc: sound2_pulse[2] <= 1'b1;
                    4'hd: sound2_pulse[3] <= 1'b1;
                    4'he: sound2_pulse[4] <= 1'b1;
                    default: ;
                endcase
            end
        end
    end
endmodule
