//============================================================================
// 
//  Port to MiSTer.
//  Copyright (C) 2020 Sorgelig
//
//  Time Pilot '84 for MiSTer
//  Copyright (C) 2020 Ace, loloC2C, Ash Evans (aka ElectronAsh/OzOnE)
//  and Kitrinx (aka Rysha)
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the 
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
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
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	// Use framebuffer from DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// stride is modulo 256 of bytes

	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,    // 1 - signed audio samples, 0 - unsigned

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

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);

assign VGA_F1    = 0;
assign USER_OUT  = '1;

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VIDEO_ARX = status[14] ? 8'd16 : status[13] ? 8'd4 : 8'd3;
assign VIDEO_ARY = status[14] ? 8'd9  : status[13] ? 8'd3 : 8'd4;

`include "build_id.v"
parameter CONF_STR = {
	"A.TP84;;",
	"H0OE,Aspect Ratio,Original,Wide;",
	"H0OD,Orientation,Vert,Horz;",
	"OFH,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Shot,Missile,Start P1,Coin,Start P2;",
	"jn,B,A,Start,R,Select;",
	"V,v",`BUILD_DATE
};

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_index;

wire [10:0] ps2_key;
wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(CLK_49M),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.status_menumask(direct_video),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.ps2_key(ps2_key)
);

////////////////////   CLOCKS   ///////////////////

wire CLK_49M;
wire CLK_14M;
wire locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(CLK_49M),
	.outclk_1(CLK_14M),
	.locked(locked)
);

wire reset = RESET | status[0] | buttons[1];

///////////////////         Keyboard           //////////////////

reg btn_up       = 0;
reg btn_down     = 0;
reg btn_left     = 0;
reg btn_right    = 0;
reg btn_shot     = 0;
reg btn_missile  = 0;
reg btn_coin1    = 0;
reg btn_coin2    = 0;
reg btn_1p_start = 0;
reg btn_2p_start = 0;
reg btn_service  = 0;

wire pressed = ps2_key[9];
wire [7:0] code = ps2_key[7:0];
always @(posedge CLK_49M) begin
	reg old_state;
	old_state <= ps2_key[10];
	if(old_state != ps2_key[10]) begin
		case(code)
			'h16: btn_1p_start <= pressed; // 1
			'h1E: btn_2p_start <= pressed; // 2
			'h2E: btn_coin1    <= pressed; // 5
			'h36: btn_coin2    <= pressed; // 6
			'h46: btn_service  <= pressed; // 9

			'h75: btn_up      <= pressed; // up
			'h72: btn_down    <= pressed; // down
			'h6B: btn_left    <= pressed; // left
			'h74: btn_right   <= pressed; // right
			'h14: btn_shot    <= pressed; // ctrl						
			'h11: btn_missile <= pressed; // alt						
		endcase
	end
end

//////////////////  Arcade Buttons/Interfaces   ///////////////////////////

//Player 1
wire m_up1      = btn_up      | joystick_0[3];
wire m_down1    = btn_down    | joystick_0[2];
wire m_left1    = btn_left    | joystick_0[1];
wire m_right1   = btn_right   | joystick_0[0];
wire m_shot1    = btn_shot    | joystick_0[4];
wire m_missile1 = btn_missile | joystick_0[5];

//Player 2
wire m_up2      = btn_up      | joystick_1[3];
wire m_down2    = btn_down    | joystick_1[2];
wire m_left2    = btn_left    | joystick_1[1];
wire m_right2   = btn_right   | joystick_1[0];
wire m_shot2    = btn_shot    | joystick_1[4];
wire m_missile2 = btn_missile | joystick_1[5];

//Start/coin
wire m_start1   = btn_1p_start | joy[6];
wire m_start2   = btn_2p_start | joy[8];
wire m_coin1    = btn_coin1    | joy[7];
wire m_coin2    = btn_coin2;

reg [7:0] dip_sw[8];	// Active-LOW
always @(posedge CLK_49M) begin
	if(ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3])
		dip_sw[ioctl_addr[2:0]] <= ioctl_dout;
end

///////////////                 Video                  ////////////////

wire hblank, vblank;
wire hs, vs;
wire [3:0] r,g,b;

reg ce_pix;
always @(posedge CLK_49M) begin
	reg [2:0] div;
	
	div <= div + 1'd1;
	ce_pix <= !div;
end

wire rotate_ccw = 0;
wire no_rotate = status[13] | direct_video;
screen_rotate screen_rotate(.*);

arcade_video #(256,12) arcade_video
(
	.*,

	.clk_video(CLK_49M),

	.RGB_in({r,g,b}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(~hs),
	.VSync(~vs),

	.fx(status[17:15])
);

//Instantiate Time Pilot '84 top-level module
TimePilot84 TP84_inst
(
	.reset(~reset),                                        // input reset

	.clk_49m(CLK_49M),                                     // input clk_49m
	.clk_14m(CLK_14M),                                     // input clk_14m
	
	.coin({~m_coin2, ~m_coin1}),                           // input [1:0] coin
	
	.start_buttons({~m_start2, ~m_start1}),                // input [1:0] start_buttons
	
	.p1_joystick({~m_right1, ~m_left1, ~m_down1, ~m_up1}),
	.p2_joystick({~m_right2, ~m_left2, ~m_down2, ~m_up2}),
	.p1_buttons({1'b1, ~m_missile1, ~m_shot1}),
	.p2_buttons({~m_missile2, ~m_shot2}),
	
	.btn_service(~btn_service),

	.dip_sw({~dip_sw[2], ~dip_sw[1], ~dip_sw[0]}),         // input [23:0] dip_sw
	
	.sound(audio),                                         // output [15:0] sound
	
	.video_hsync(hs),                                      // output video_hsync
	.video_vsync(vs),                                      // output video_vsync
	.video_vblank(vblank),                                 // output video_vblank
	.video_hblank(hblank),                                 // output video_hblank
	
	.video_r(r),                                           // output [3:0] video_r
	.video_g(g),                                           // output [3:0] video_g
	.video_b(b),                                           // output [3:0] video_b
	
	.ioctl_addr(ioctl_addr),
	.ioctl_wr(ioctl_wr && !ioctl_index),
	.ioctl_data(ioctl_dout)
);

wire [15:0] audio;

assign AUDIO_L = audio;
assign AUDIO_R = audio;
assign AUDIO_S = 1;

endmodule
