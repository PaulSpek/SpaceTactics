//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);


assign ADC_BUS = 'z;
assign USER_OUT = '1;
assign {UART_RTS, UART_DTR} = 2'b00;
assign UART_TXD = 1'b1;
assign {SD_SCK, SD_MOSI, SD_CS} = 3'b111;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE,
        SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS,
        SDRAM_nRAS, SDRAM_nCS} = 'z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN,
        DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;
`ifdef MISTER_DUAL_SDRAM
assign {SDRAM2_CLK, SDRAM2_A, SDRAM2_BA, SDRAM2_DQ,
        SDRAM2_nCS, SDRAM2_nCAS, SDRAM2_nRAS, SDRAM2_nWE} = 'z;
`endif
`ifdef MISTER_FB
assign {FB_EN, FB_FORMAT, FB_WIDTH, FB_HEIGHT, FB_BASE, FB_STRIDE, FB_FORCE_BLANK} = '0;
`ifdef MISTER_FB_PALETTE
assign {FB_PAL_CLK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;
`endif
`endif

wire clk_sys, pll_locked;
pll core_pll (
    .refclk(CLK_50M),
    .rst(1'b0),
    .outclk_0(clk_sys),
    .outclk_1(),
    .locked(pll_locked)
);
assign CLK_VIDEO = clk_sys;
assign VGA_F1 = 1'b0;
assign VGA_SL = 2'b00;
assign VGA_SCALER = 1'b0;
assign VGA_DISABLE = 1'b0;
assign VIDEO_ARX = 13'd4;
assign VIDEO_ARY = 13'd3;
assign HDMI_FREEZE = 1'b0;
assign HDMI_BLACKOUT = 1'b0;
assign HDMI_BOB_DEINT = 1'b0;
assign LED_USER = !rom_loaded;
assign LED_POWER = 2'b00;
assign LED_DISK = 2'b00;
assign BUTTONS = 2'b00;
wire signed [15:0] core_audio, core_audio_front, core_audio_back;
assign AUDIO_L = core_audio_front;
assign AUDIO_R = core_audio_back;
assign AUDIO_S = 1'b1;
assign AUDIO_MIX = 2'b00;

localparam CONF_STR = {
    "Space Tactics;;",
    "F1,ROM,Load assembled ROM;",
    "P1,Game;",
    "P1O[1],Free play,Off,On;",
    "P1O[2],Barriers,4,6;",
    "P1O[3],Bonus barriers,1,2;",
    "P1O[4],Extended play,On,Off;",
    "T[5],Test player-shot sound;",
    "T[0],Reset;",
    "R[0],Reset and close OSD;",
    "J,Fire,Button 2,Button 3,Button 4,Button 5,Button 6,Button 7,Coin,Start;",
    "jn,A,B,X,Y,L,R,,Select,Start;",
    "V,v1"
};
wire [127:0] status;
wire [1:0] buttons;
wire [31:0] joystick_0;
wire ioctl_download, ioctl_wr;
wire [26:0] ioctl_addr;
wire [7:0] ioctl_dout;
wire [15:0] ioctl_index;

hps_io #(.CONF_STR(CONF_STR)) hps_io (
    .clk_sys(clk_sys),
    .HPS_BUS(HPS_BUS),
    .status(status),
    .buttons(buttons),
    .joystick_0(joystick_0),
    .ioctl_download(ioctl_download),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_index(ioctl_index),
    .ioctl_wait(1'b0)
);

reg rom_loaded = 0;
reg downloading_d = 0;
always @(posedge clk_sys) begin
    downloading_d <= ioctl_download;
    if (downloading_d && !ioctl_download && ioctl_index == 16'd1)
        rom_loaded <= 1;
end
wire reset_core = RESET || status[0] || buttons[1] || !pll_locked ||
                  !rom_loaded || ioctl_download;

reg [4:0] cpu_div = 0;
always @(posedge clk_sys) begin
    if (reset_core || cpu_div == 25) cpu_div <= 0;
    else cpu_div <= cpu_div + 1'b1;
end
wire cpu_ce = cpu_div == 25;
wire [15:0] cpu_addr;
wire [7:0] cpu_din, cpu_dout;
wire m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n;
wire int_ack = !m1_n && !iorq_n;
wire irq_n;

tv80s #(.Mode(2)) cpu (
    .reset_n(!reset_core),
    .clk(clk_sys),
    .cen(cpu_ce),
    .wait_n(1'b1),
    .int_n(irq_n),
    .nmi_n(1'b1),
    .busrq_n(1'b1),
    .busak_n(busak_n),
    .m1_n(m1_n),
    .mreq_n(mreq_n),
    .iorq_n(iorq_n),
    .rd_n(rd_n),
    .wr_n(wr_n),
    .rfsh_n(rfsh_n),
    .halt_n(halt_n),
    .A(cpu_addr),
    .di(cpu_din),
    .dout(cpu_dout)
);

// J1 buttons occupy joystick bits 4 and up in the order declared above.
wire [7:0] in0 = {1'b0, ~joystick_0[5], ~joystick_0[12],
                 ~joystick_0[6], ~joystick_0[7], ~joystick_0[8],
                 ~joystick_0[9], ~joystick_0[10]};
wire [7:0] in1 = 8'h3f; // Coin A/B 1:1; demo and initials enabled.
wire [7:0] in2 = {1'b1, !status[1], 1'b1, ~joystick_0[11], 4'b0000};
    wire [7:0] in3 = {1'b0, ~joystick_0[2], ~joystick_0[3],
                  status[4], !status[3], !status[2], 1'b0, ~joystick_0[4]};

stactics_board board (
    .clk(clk_sys),
    .reset(reset_core),
    .cpu_addr(cpu_addr),
    .cpu_dout(cpu_dout),
    .cpu_wr(cpu_ce && !mreq_n && !wr_n),
    .cpu_int_ack(int_ack),
    .cpu_din(cpu_din),
    .irq_n(irq_n),
    .in0(in0), .in1(in1), .in2(in2), .in3(in3),
        .joy_ud_n({~joystick_0[1], ~joystick_0[0]}),
    .diag_sound(status[5]),
    .rom_wr(ioctl_download && ioctl_wr && ioctl_index == 16'd1),
    .rom_addr(ioctl_addr[15:0]),
    .rom_data(ioctl_dout),
    .ce_pixel(CE_PIXEL),
    .red(VGA_R), .green(VGA_G), .blue(VGA_B),
    .hs(VGA_HS), .vs(VGA_VS), .de(VGA_DE),
    .audio_sample(core_audio),
    .audio_front(core_audio_front),
    .audio_back(core_audio_back)
);
endmodule
