//============================================================================
// 
//  Time Pilot '84 main PCB replica
//  Copyright (C) 2020 Ace
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

//Module declaration, I/O ports
module TimePilot84_CPU
(
	input         reset,
	input         clk_49m, //Actual frequency: 49.152MHz
	output  [3:0] red, green, blue, //12-bit RGB, 4 bits per color
	output        video_hsync, video_vsync, video_csync, //CSync not needed for MISTer
	output        video_hblank, video_vblank,
	
	input   [7:0] sndbrd_D,
	output  [7:0] cpubrd_D,
	output        cpubrd_A5, cpubrd_A6,
	output        n_sda, n_son,
	output        in5, in6, ioen,
	
	input         ep1_cs_i,
	input         ep2_cs_i,
	input         ep3_cs_i,
	input         ep4_cs_i,
	input         ep5_cs_i,
	input         ep7_cs_i,
	input         ep8_cs_i,
	input         ep9_cs_i,
	input         ep10_cs_i,
	input         ep11_cs_i,
	input         ep12_cs_i,
	input         cp1_cs_i,
	input         cp2_cs_i,
	input         cp3_cs_i,
	input         cl_cs_i,
	input         sl_cs_i,
	input  [24:0] ioctl_addr,
	input   [7:0] ioctl_data,
	input         ioctl_wr
);

//Assign active high HBlank and VBlank outputs
assign video_hblank = ({n_h256, h128, h64, h32, h16, h8, h4, h2, h1} > 137 && {n_h256, h128, h64, h32, h16, h8, h4, h2, h1} < 269);
assign video_vblank = vblk;

//Output IN5, IN6, IOEN to sound board
assign in5 = n_in5;
assign in6 = n_in6;
assign ioen = n_ioen;

//Output primary MC6809E address lines A5 and A6 to sound board
assign cpubrd_A5 = mA[5];
assign cpubrd_A6 = mA[6];
				
//Assign CPU board data output to sound board
assign cpubrd_D = mD_out;

//------------------------------------------------- Chip-level logic modelling -------------------------------------------------//

//Blue color PROM
wire [7:0] color_A;
color_prom_3 u1E
(
	.ADDR(color_A),
	.CLK(clk_12m),
	.DATA(blue),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(cp3_cs_i),
	.WR(ioctl_wr)
);

//Character lookup PROM
wire [5:0] char_lut_A;
wire [3:0] char_lut_D;
char_lut_prom u1F
(
	.ADDR({vcol1, vcol0, char_lut_A}),
	.CLK(clk_12m),
	.DATA(char_lut_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(cl_cs_i),
	.WR(ioctl_wr)
);

//Multiplex character ROM data outputs
wire [7:0] charrom_D = ~n_charrom0_ce ? eprom7_D : eprom8_D;

//Konami 083 custom chip 1/2 - this one shifts the pixel data from character ROMs
k083 u1G
(
	.CK(clk2x),
	.LOAD(ld),
	.FLIP(charrom_flip),
	.DB0i(charrom_D),
	.DSH0(char_lut_A[1:0])
);

//Character ROM 2/2
wire [12:0] charrom_A;
wire [7:0] eprom8_D;
eprom_8 u1J
(
	.ADDR(charrom_A),
	.CLK(pixel_clk),
	.DATA(eprom8_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(ep8_cs_i),
	.WR(ioctl_wr)
);

//Latch VCOL lines and color address bus bits A[6:4]
wire vcol0, vcol1;
ls174 u2B
(
	.d({1'b0, mD_out[3], mD_out[4], mD_out[2:0]}),
	.clk(n_col0),
	.mr(n_res),
	.q({1'bZ, vcol0, vcol1, color_A[6:4]})
);

//Red color PROM
color_prom_1 u2C
(
	.ADDR(color_A),
	.CLK(clk_12m),
	.DATA(red),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(cp1_cs_i),
	.WR(ioctl_wr)
);

//Green color PROM
color_prom_2 u2D
(
	.ADDR(color_A),
	.CLK(clk_12m),
	.DATA(green),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(cp2_cs_i),
	.WR(ioctl_wr)
);

//Latch SH and SF busses
wire [3:0] SH, SF;
ls273 u2E
(
	.d({SS, SH[0], SH[1], SH[2], SH[3]}),
	.clk(clk2x),
	.res(1'b1),
	.q({SH, SF[0], SF[1], SF[2], SF[3]})
);

//Latch S and SS busses
wire [3:0] S, SS;
ls273 u2F
(
	.d({S[0], S[1], S[2], S[3], char_lut_D}),
	.clk(clk2x),
	.res(1'b1),
	.q({SS[0], SS[1], SS[2], SS[3], S})
);

//Latch address lines A[5:2] for character lookup PROM, load for character ROM 083 custom chip,
wire charrom_flip, scroll_l2, scroll_l3;
ls377 u2G
(
	.d({char_flip, scroll_l, scroll_l2, 1'b0, charram1_Dl2}),
	.clk(clk2x),
	.e(n_ld),
	.q({charrom_flip, scroll_l2, scroll_l3, 1'bZ, char_lut_A[5:2]})
);

//Character ROM 1/2
wire [7:0] eprom7_D;
eprom_7 u2J
(
	.ADDR(charrom_A),
	.CLK(pixel_clk),
	.DATA(eprom7_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(ep7_cs_i),
	.WR(ioctl_wr)
);

//Address decoding for primary MC6809E (2/2)
wire n_in6, n_in5, n_ioen, n_sound, n_irq_en, n_col0, n_mafr;
ls138 u3A
(
	.n_e1(n_io_dec),
	.n_e2(n_io_dec),
	.e3(meq),
	.a({m_rw, mA[12:11]}),
	.o({n_in6, n_in5, n_ioen, 1'bZ, n_sound, n_irq_en, n_col0, n_mafr})
);

//Generate primary MC6809E VBlank IRQ clear and H/V flip signals
wire vrev, hrev, vblk_irq_clr;
ls259 u3B
(
	.d(mD_out[0]),
	.n_clr(n_res),
	.n_g(n_irq_en),
	.s(mA[2:0]),
	.q({2'bZZ, vrev, hrev, 3'bZZZ, vblk_irq_clr})
);

//Latch address lines A7 and A[3:0] for color PROMs, mux enable
wire vmux_en;
ls174 u3C
(
	.d({vmux, char_spr_D[0], char_spr_D[2:1], char_spr_D[3], ch_sp_sel}),
	.clk(clk2),
	.mr(n_vblk),
	.q({vmux_en, color_A[0], color_A[2:1], color_A[3], color_A[7]})
);

//Multiplex character and sprite data
wire [3:0] char_spr_D;
ls157 u3D
(
	.i0({sprite_D[0], sprite_D[2], sprite_D[3], sprite_D[1]}),
	.i1({char_D[0], char_D[2], char_D[3], char_D[1]}),
	.n_e(n_gfx_en),
	.s(ch_sp_sel),
	.z({char_spr_D[0], char_spr_D[2], char_spr_D[3], char_spr_D[1]})
);

//Multiplex lower 2 bits of character data
wire [3:0] char_D;
ls153 u3E
(
	.i_a({S[0], SS[0], SH[0], SF[0]}),
	.i_b({S[1], SS[1], SH[1], SF[1]}),
	.n_e(2'b00),
	.s({char_sel1, char_sel0}),
	.z(char_D[1:0])
);

//Multiplex upper 2 bits of character data
ls153 u3F
(
	.i_a({S[2], SS[2], SH[2], SF[2]}),
	.i_b({S[3], SS[3], SH[3], SF[3]}),
	.n_e(2'b00),
	.s({char_sel1, char_sel0}),
	.z(char_D[3:2])
);

//Latch lowest 4 bits of already-latched character RAM data output and SCROLL
wire [3:0] charram1_Dl2;
wire scroll_l;
ls174 u3G
(
	.d({1'b0, scroll_lat, charram1_Dlat[3:0]}),
	.clk(n_h2),
	.mr(1'b1),
	.q({1'bZ, scroll_l, charram1_Dl2})
);

//Latch address lines A[11:4] for character ROMs
ls273 u3H
(
	.d({charram0_Dlat[4], charram0_Dlat[5], charram0_Dlat[6], charram0_Dlat[7], charram0_Dlat[0], charram0_Dlat[1], charram0_Dlat[2], charram0_Dlat[3]}),
	.clk(n_h2),
	.res(1'b1),
	.q({charrom_A[8], charrom_A[9], charrom_A[10], charrom_A[11], charrom_A[4], charrom_A[5], charrom_A[6], charrom_A[7]})
);

//Generate lower 4 address lines for character ROMs
ls86 u3J
(
	.a1(ha2l),
	.b1(char_hflip),
	.y1(charrom_A[3]),
	.a2(va2l),
	.b2(char_vflip),
	.y2(charrom_A[1]),
	.a3(char_vflip),
	.b3(va1l),
	.y3(charrom_A[0]),
	.a4(va4l),
	.b4(char_vflip),
	.y4(charrom_A[2])
);

//Generate OCOLL clear signal
wire n_ocoll_clr, cara_256;
ls74 u4A
(
	.n_pre1(1'b1),
	.n_clr1(1'b1),
	.clk1(clk2),
	.d1(cara_256),
	.q1(n_ocoll_clr),
	.n_pre2(1'b1),
	.n_clr2(1'b1),
	.clk2(n_cara),
	.d2(n_h256),
	.q2(cara_256)
);

//Generate enable for character/sprite mux
wire vmux, n_gfx_en, gfx_en;
ls74 u4B
(
	.n_pre1(1'b1),
	.n_clr1(gfx_en),
	.clk1(scroll_l2),
	.d1(1'b1),
	.q1(vmux),
	.n_pre2(1'b1),
	.n_clr2(n_ocoll_clr),
	.clk2(n_ocoll),
	.d2(n_h256),
	.q2(gfx_en),
	.n_q2(n_gfx_en)
);

//Latch primary MC6809E data bus for J bus and SHFx lines
wire [7:2] J;
wire shf0, shf1;
ls374 u4C
(
	.d({mD_out[3], mD_out[7], mD_out[0], mD_out[2], mD_out[6], mD_out[1], mD_out[5:4]}),
	.clk(jbus_lat),
	.out_ctl(scroll_lat),
	.q({J[3], J[7], shf0, J[2], J[6], shf1, J[5:4]})
);

//Latch primary MC6809E data bus for L bus
wire [7:0] L;
ls374 u4D
(
	.d({mD_out[2], mD_out[0], mD_out[3], mD_out[7], mD_out[4], mD_out[6:5], mD_out[1]}),
	.clk(lbus_lat),
	.out_ctl(scroll_lat),
	.q({L[2], L[0], L[3], L[7], L[4], L[6:5], L[1]})
);

//Multiplex address lines A[3:0] for character RAM
ls157 u4E
(
	.i0({mA[2], mA[3], mA[1:0]}),
	.i1({ha[5], ha[6], ha[4:3]}),
	.n_e(1'b0),
	.s(n_h2),
	.z({charram_A[2], charram_A[3], charram_A[1:0]})
);

//Character RAM bank 1
wire [10:0] charram_A;
wire [7:0] charram1_D;
spram #(8, 11) u4F
(
	.clk(h1),
	.we(~n_charram1_we & ~n_charram1_en & n_charram_oe),
	.addr(charram_A),
	.data(mD_out),
	.q(charram1_D)
);

//Latch data output from character RAM bank 1
wire [7:0] charram1_Dlat;
ls273 u4G
(
	.d({charram1_D[7:6], charram1_D[4], charram1_D[5], charram1_D[3:0]}),
	.clk(h2),
	.res(1'b1),
	.q({charram1_Dlat[7:6], charram1_Dlat[4], charram1_Dlat[5], charram1_Dlat[3:0]})
);

//Latch data output from character RAM bank 0
wire [7:0] charram0_Dlat;
ls273 u4H
(
	.d({charram0_D[4], charram0_D[5], charram0_D[6], charram0_D[7], charram0_D[0], charram0_D[1], charram0_D[2], charram0_D[3]}),
	.clk(h2),
	.res(1'b1),
	.q({charram0_Dlat[4], charram0_Dlat[5], charram0_Dlat[6], charram0_Dlat[7], charram0_Dlat[0], charram0_Dlat[1], charram0_Dlat[2], charram0_Dlat[3]})
);

//Latch character ROM address lines A[3:0], character ROM address line A12, character ROM chip enable, character H/V flip bits
wire n_charrom0_ce, char_hflip, char_vflip, va1l, va2l, va4l, ha2l;
ls273 u4J
(
	.d({charram1_Dlat[5:4], charram1_Dlat[6], charram1_Dlat[7], va1, va2, va4, ha[2]}),
	.clk(n_h2),
	.res(1'b1),
	.q({n_charrom0_ce, charrom_A[12], char_hflip, char_vflip, va1l, va2l, va4l, ha2l})
);

//XOR horizontal counter bits [5:2] with HREV
wire h4x, h8x, h16x, h32x;
ls86 u5A
(
	.a1(h4),
	.b1(hrev),
	.y1(h4x),
	.a2(h16),
	.b2(hrev),
	.y2(h16x),
	.a3(hrev),
	.b3(h32),
	.y3(h32x),
	.a4(hrev),
	.b4(h8),
	.y4(h8x)
);

//XOR horizontal counter bits 6 and 7 with HREV, invert bit 3 of the horizontal counter and XOR 128H with !256H
wire h64x, h128x, h128_256, n_h8;
ls86 u5B
(
	.a1(h64),
	.b1(hrev),
	.y1(h64x),
	.a2(n_h256),
	.b2(h128),
	.y2(h128_256),
	.a3(h8),
	.b3(1'b0),
	.y3(n_h8),
	.a4(hrev),
	.b4(h128),
	.y4(h128x)
);

//Sum XORed horizontal counter bits [5:2] with J bus bits [5:2]
wire [7:2] ha;
wire ha_carry;
ls283 u5C
(
	.a({h32x, h16x, h8x, h4x}),
	.b(J[5:2]),
	.c_in(scroll_lat),
	.sum(ha[5:2]),
	.c_out(ha_carry)
);

//Sum XORed vertical counter bits [3:0] with L bus bits [3:0]
wire va1, va2, va4, va8, va_carry;
ls283 u5D
(
	.a({v8x, v4x, v2x, v1x}),
	.b(L[3:0]),
	.c_in(scroll_lat),
	.sum({va8, va4, va2, va1}),
	.c_out(va_carry)
);

//Multiplex address lines A[7:4] for character RAM
ls157 u5E
(
	.i0({mA[6], mA[7], mA[5:4]}),
	.i1({va16, va32, va8, ha[7]}),
	.n_e(1'b0),
	.s(n_h2),
	.z({charram_A[6], charram_A[7], charram_A[5:4]})
);

//Character RAM bank 0
wire [7:0] charram0_D;
spram #(8, 11) u5F
(
	.clk(h1),
	.we(~n_charram0_we & ~n_charram0_en & n_charram_oe),
	.addr(charram_A),
	.data(mD_out),
	.q(charram0_D)
);

//Generate read enable lines for character RAM banks and chip enable for character RAM bank 0
wire charram0_rd, charram1_rd, n_charram0_en;
ls27 u5G
(
	.a1(n_m_rw),
	.b1(n_h2),
	.c1(n_vr2),
	.y1(charram1_rd),
	.a2(n_h2),
	.b2(n_m_rw),
	.c2(n_vr1),
	.y2(charram0_rd),
	.a3(charram0_we),
	.b3(charram0_rd),
	.c3(1'b0),
	.y3(n_charram0_en)
);

//5H and 5J are 74LS245s used to send data to/from character RAM and the primary MC6809E - not needed for this implementation

//Konami 082 custom chip - responsible for all video timings
wire vblk, n_vblk, h1, h2, h4, h8, h16, h32, h64, h128, n_h256, v1, v2, v4, v8, v16, v32, v64, v128;
k082 u6A
(
	.clk(pixel_clk),
	.n_vsync(video_vsync),
	.sync(video_csync),
	.n_hsync(video_hsync),
	.vblk(vblk),
	.n_vblk(n_vblk),
	.h1(h1),
	.h2(h2),
	.h4(h4),
	.h8(h8),
	.h16(h16),
	.h32(h32),
	.h64(h64),
	.h128(h128),
	.n_h256(n_h256),
	.v1(v1),
	.v2(v2),
	.v4(v4),
	.v8(v8),
	.v16(v16),
	.v32(v32),
	.v64(v64),
	.v128(v128)
);

//Sum XORed horizontal counter bits [7:6] with J bus bits [7:6]
//Upper 2 adders unused, pull inputs low
ls283 u6C
(
	.a({2'b00, h128x, h64x}),
	.b({2'b00, J[7:6]}),
	.c_in(ha_carry),
	.sum({2'bZZ, ha[7:6]})
);

//Sum XORed vertical counter bits [7:4] with L bus bits [7:4]
wire va16, va32, va64, va128;
ls283 u6D
(
	.a({v128x, v64x, v32x, v16x}),
	.b(L[7:4]),
	.c_in(va_carry),
	.sum({va128, va64, va32, va16})
);

//Multiplex address lines A[10:8] and output enable for character RAM
wire n_charram_oe;
ls157 u6E
(
	.i0({mA[10], n_m_rw, mA[9:8]}),
	.i1({scroll_lat, 1'b0, va128, va64}),
	.n_e(1'b0),
	.s(n_h2),
	.z({charram_A[10], n_charram_oe, charram_A[9:8]})
);

//Invert combined output enable signal for shared RAM, write enables for character RAM banks, read/write output from primary MC6809E,
//generate redundant CLK2
//Inverter 1 inverts the character ROM chip enable to select which of the two character ROMs to enable - this has been replaced with
//direct multiplexing
wire n_charram0_we, n_charram1_we, n_sharedram_oe, clk2x, n_m_rw;
ls04 u6F
(
	//.a1(n_charrom0_ce),
	//.y1(n_charrom1_ce),
	.a2(charram0_we),
	.y2(n_charram0_we),
	.a3(charram1_we),
	.y3(n_charram1_we),
	.a4(sharedram_oe),
	.y4(n_sharedram_oe),
	.a5(n_clk2),
	.y5(clk2x),
	.a6(m_rw),
	.y6(n_m_rw)
);

//Generate write enables for both character RAM banks and chip enable for character RAM bank 1
wire charram0_we, charram1_we, n_charram1_en;
ls27 u6G
(
	.a1(n_vr2),
	.b1(charram0_wr1),
	.c1(m_rw),
	.y1(charram1_we),
	.a2(charram1_we),
	.b2(charram1_rd),
	.c2(1'b0),
	.y2(n_charram1_en),
	.a3(charram0_wr1),
	.b3(n_vr1),
	.c3(m_rw),
	.y3(charram0_we)
);

//Latch vertical counter bits from 082 custom chip
wire [7:0] vcnt_lat;
ls273 u7B
(
	.d({v128, v64, v8, v4, v2, v1, v32, v16}),
	.clk(n_h256),
	.res(1'b1),
	.q({vcnt_lat[7:6], vcnt_lat[3:0], vcnt_lat[5:4]})
);

//XOR latched vertical counter bits [3:0] with VREV
wire v1x, v2x, v4x, v8x;
ls86 u7C
(
	.a1(vcnt_lat[1]),
	.b1(vrev),
	.y1(v2x),
	.a2(vcnt_lat[0]),
	.b2(vrev),
	.y2(v1x),
	.a3(vrev),
	.b3(vcnt_lat[3]),
	.y3(v8x),
	.a4(vrev),
	.b4(vcnt_lat[2]),
	.y4(v4x)
);

//XOR latched vertical counter bits [7:4] with VREV
wire v16x, v32x, v64x, v128x;
ls86 u7D
(
	.a1(vcnt_lat[5]),
	.b1(vrev),
	.y1(v32x),
	.a2(vcnt_lat[4]),
	.b2(vrev),
	.y2(v16x),
	.a3(vrev),
	.b3(vcnt_lat[7]),
	.y3(v128x),
	.a4(vrev),
	.b4(vcnt_lat[6]),
	.y4(v64x)
);

//Multiplex address lines A[3:0] for shared RAM
ls157 u7E
(
	.i0({mA[2], mA[3], mA[1:0]}),
	.i1({sA[2], sA[3], sA[1:0]}),
	.n_e(1'b0),
	.s(n_h2),
	.z({sharedram_A[2], sharedram_A[3], sharedram_A[1:0]})
);

//Generate write enables for sprite RAM
wire lbus_lat, jbus_lat, n_spriteram0_we, n_spriteram1_we;
ls139 u7F
(
	.n_e({n_spriteram_dec_en, n_sound}),
	.a0({sA[1], mA[9]}),
	.a1({sprram_en0, mA[10]}),
	.o0({lbus_lat, jbus_lat, n_sda, n_son}),
	.o1({n_spriteram0_we, n_spriteram1_we, 2'bZZ})
);

//Generate sprite RAM address line A8, write 1 for character RAM bank 0, sprite RAM decoder enable, enable for sprite RAM bank 1
wire charram0_wr1, n_spriteram_dec_en, sprram_en1;
ls32 u7G
(
	.a1(sA[9]),
	.b1(h2),
	.y1(spriteram_A[8]),
	.a2(n_h2),
	.b2(h1d),
	.y2(charram0_wr1),
	.a3(h2),
	.b3(n_ora),
	.y3(n_spriteram_dec_en),
	.a4(sprram_en0),
	.b4(s_rw),
	.y4(sprram_en1)
);

//Primary CPU ROM 1/4 (there is a 5th ROM socket on the original PCB at 6J, but is unpopulated)
wire [7:0] eprom1_D;
eprom_1 u7J
(
	.ADDR(mA[12:0]),
	.CLK(mq),
	.DATA(eprom1_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(ep1_cs_i),
	.WR(ioctl_wr)
);

//Invert all clocks and bit 1 of the horizontal counter outpt from the 082 custom chip
//Gates 1 and 6 part of circuit to drive 18.432MHz crystal on the original PCB and gate 5
//inverts this clock, omit these gates
wire n_h2, clk1, clk2;
ls368 u8A
(
	.n_g1(1'b0),
	.a2(h2),
	.y2(n_h2),
	.a3(n_clk2),
	.y3(clk2),
	.a4(n_clk1),
	.y4(clk1)
);

//Sprite RAM bank 0 (upper 4 bits)
wire [15:0] spriteram_D;
wire [9:0] spriteram_A;
spram #(4, 10) u8B
(
	.clk(pixel_clk),
	.we(~n_spriteram0_we & ~n_spriteram0_en),
	.addr(spriteram_A),
	.data(sD_out[7:4]),
	.q(spriteram_D[7:4])
);

//Sprite RAM bank 1 (upper 4 bits)
spram #(4, 10) u8C
(
	.clk(pixel_clk),
	.we(~n_spriteram1_we & ~n_spriteram1_en),
	.addr(spriteram_A),
	.data(sD_out[7:4]),
	.q(spriteram_D[15:12])
);

//Multiplex address lines A[3:0] for sprite RAM
ls157 u8D
(
	.i0({h32, h64, h16, h4}),
	.i1({sA[3], sA[4], sA[2], sA[0]}),
	.n_e(1'b0),
	.s(n_h2),
	.z({spriteram_A[2], spriteram_A[3], spriteram_A[1:0]})
);

//Multiplex address lines A[7:4] for shared RAM
ls157 u8E
(
	.i0({mA[6], mA[7], mA[5:4]}),
	.i1({sA[6], sA[7], sA[5:4]}),
	.n_e(1'b0),
	.s(n_h2),
	.z({sharedram_A[6], sharedram_A[7], sharedram_A[5:4]})
);

//Generate enable lines for shared RAM data bus multiplexing and LD0 signal for 502 custom chip
wire n_mcpu_sharedram_en, n_scpu_sharedram_en, n_ld0;
ls10 u8F
(
	.a1(n_h2),
	.b1(n_sharedram_rd),
	.c1(scr),
	.y1(n_scpu_sharedram_en),
	.a2(n_sharedram_rd),
	.b2(mcr),
	.c2(h2),
	.y2(n_mcpu_sharedram_en),
	.a3(h4),
	.b3(h2),
	.c3(h1),
	.y3(n_ld0)
);

//NAND shared RAM output enable with inverted latched H1 bit of horizontal counter, generate read
//enable for shared RAM and active-low LD signal, enable for watchdog timer reset
wire sharedram_h1, n_sharedram_rd, n_ld, watchdog_timer_rst;
ls00 u8G
(
	.a1(n_h1d),
	.b1(n_sharedram_oe),
	.y1(sharedram_h1),
	.a2(sharedram_h1),
	.b2(n_sharedram_oe),
	.y2(n_sharedram_rd),
	.a3(1),
	.b3(watchdog_timer_trig),
	.y3(watchdog_timer_rst),
	.a4(h1),
	.b4(h2),
	.y4(n_ld)
);

//Primary CPU ROM 2/4 (there is a 5th ROM socket on the original PCB at 6J, but is unpopulated)
wire [7:0] eprom2_D;
eprom_2 u8J
(
	.ADDR(mA[12:0]),
	.CLK(mq),
	.DATA(eprom2_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(ep2_cs_i),
	.WR(ioctl_wr)
);

//Clock divider
//The PCB uses a 74LS107 located at 9A to divide 18.432MHz by 3 to obtain the required 6.144MHz pixel
//clock - this implementation replaces the 74LS107 by a 74LS163 to divide a faster 49.152MHzclock by
//4 for clocking PROMs and the sprite line buffer RAM at 12.288MHz and by 8 to obtain the 6.144MHz
//pixel clock
wire clk_12m, pixel_clk, n_clk1, n_clk2;
ls163 u9A
(
	.n_clr(1'b1),
	.clk(clk_49m),
	.din(4'h0),
	.enp(1'b1),
	.ent(1'b1),
	.n_load(1'b1),
	.q({1'bZ, pixel_clk, clk_12m, 1'bZ})
);
assign n_clk1 = ~pixel_clk;
assign n_clk2 = ~pixel_clk;

//Sprite RAM bank 0 (lower 4 bits)
spram #(4, 10) u9B
(
	.clk(pixel_clk),
	.we(~n_spriteram0_we & ~n_spriteram0_en),
	.addr(spriteram_A),
	.data(sD_out[3:0]),
	.q(spriteram_D[3:0])
);

//Sprite RAM bank 1 (lower 4 bits)
spram #(4, 10) u9C
(
	.clk(pixel_clk),
	.we(~n_spriteram1_we & ~n_spriteram1_en),
	.addr(spriteram_A),
	.data(sD_out[3:0]),
	.q(spriteram_D[11:8])
);

//Multiplex address lines A[7:4] for sprite RAM
ls157 u9D
(
	.i0({2'b11, h128, h128_256}),
	.i1({sA[7], sA[8], sA[6:5]}),
	.n_e(1'b0),
	.s(n_h2),
	.z({spriteram_A[6], spriteram_A[7], spriteram_A[5:4]})
);

//Multiplex output enable lines and address lines A[10:8] for shared RAM
wire sharedram_oe;
ls157 u9E
(
	.i0({mA[10], m_rw, mA[9:8]}),
	.i1({sA[10], s_rw, sA[9:8]}),
	.n_e(1'b0),
	.s(n_h2),
	.z({sharedram_A[10], sharedram_oe, sharedram_A[9:8]})
);

//Multplex data from CPUs to shared RAM (handled by the 74LS245s at 10G and 10F on the PCB)
wire [7:0] sharedram_Din = h2 ? mD_out : sD_out;

//Shared RAM for the two MC6809E CPUs
wire [10:0] sharedram_A;
wire [7:0] sharedram_D;
spram #(8, 11) u9F
(
	.clk(h1),
	.we(~n_sharedram_we),
	.addr(sharedram_A),
	.data(sharedram_Din),
	.q(sharedram_D)
);

//More address decoding for both MC6809Es
wire n_spriteram0_en, n_spriteram1_en, n_mcr, n_vr2, n_vr1;
ls139 u9G
(
	.n_e({n_mcpu_ram_en, n_spriteram_dec_en}),
	.a0({mA[11], sA[1]}),
	.a1({mA[12], sprram_en1}),
	.o0({n_spriteram0_en, n_spriteram1_en, 2'bZZ}),
	.o1({1'bZ, n_mcr, n_vr2, n_vr1})
);

//Primary CPU ROM 3/4 (there is a 5th ROM socket on the original PCB at 6J, but is unpopulated)
wire [7:0] eprom3_D;
eprom_3 u9J
(
	.ADDR(mA[12:0]),
	.CLK(mq),
	.DATA(eprom3_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(ep3_cs_i),
	.WR(ioctl_wr)
);

//Secondary CPU ROM
wire [7:0] eprom5_D;
eprom_5 u10D
(
	.ADDR(sA[12:0]),
	.CLK(sq),
	.DATA(eprom5_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(ep5_cs_i),
	.WR(ioctl_wr)
);

//Primary CPU ROM 4/4 (there is a 5th ROM socket on the original PCB at 6J, but is unpopulated)
wire [7:0] eprom4_D;
eprom_4 u10J
(
	.ADDR(mA[12:0]),
	.CLK(mq),
	.DATA(eprom4_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(ep4_cs_i),
	.WR(ioctl_wr)
);

//Konami 503 custom chip - generates sprite addresses for lower half of sprite ROMs, sprite
//data + collision control and enables for sprite write and 083 custom chip
wire csobj, k083_ctl, n_cara, n_ocoll;
k503 u11A
(
	.OB(spriteram_D[7:0]),
	.VCNT(vcnt_lat),
	.H4(h4),
	.H8(n_h8),
	.LD(n_ld),
	.OCS(csobj),
	.NE83(k083_ctl),
	.ODAT(n_cara),
	.OCOL(n_ocoll),
	.R(spriterom_A[5:0])
);

//Latch address lines A[12:6] and chip enables for sprite ROMs from sprite RAM bank 1
wire n_spriterom0_en;
ls273 u11C
(
	.d({spriteram_D[12], spriteram_D[13], spriteram_D[14], spriteram_D[15], spriteram_D[11:8]}),
	.clk(n_cara),
	.res(1'b1),
	.q({spriterom_A[10], spriterom_A[11], spriterom_A[12], n_spriterom0_en, spriterom_A[9:6]})
);

//11D is a 74LS244 used to buffer bits [12:5] of the address bus from the secondary MC6809E, not needed for this implementation

//11E is a 74LS367 used to buffer bits [4:0] of the address bus from the secondary MC6809E and its R/W signal, not needed for this
//implementation

//11F is a 74LS245 used to buffer the data bus from the secondary MC6809E, not needed for this implementation

//11G is a 74LS244 used to buffer bits [12:5] of the address bus from the primary MC6809E, not needed for this implementation

//11H is a 74LS367 used to buffer bits [4:0] of the address bus from the primary MC6809E and its R/W signal, not needed for this
//implementation

//11J is a 74LS245 used to buffer the data bus from the primary MC6809E, not needed for this implementation

//Sprite ROM 1/4
wire [12:0] spriterom_A;
wire [7:0] eprom9_D;
eprom_9 u12A
(
	.ADDR(spriterom_A),
	.CLK(pixel_clk),
	.DATA(eprom9_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(ep9_cs_i),
	.WR(ioctl_wr)
);

//Generate upper half of sprite line buffer bank 0 address bus
ls163 u12C
(
	.n_clr(n_sprite_lbuff0_clr),
	.clk(clk2),
	.din(spriteram_D[15:12]),
	.enp(sprite_lbuff0_carry),
	.ent(sprite_lbuff0_carry),
	.n_load(n_sprite_lbuff0_ld),
	.q(sprite_lbuff0_A[7:4])
);

//Latch address lines A[7:4] for sprite lookup PROM, enable for sprite line buffer, XORed SHFx signals
//latch SCROLL again twice
wire shf0_l, shf1_l, sprite_lbuff_sel, sprrom_flip;
ls377 u12D
(
	.d({spriteram_D[3:0], shf0_rev, shf1_rev, csobj, k083_ctl}),
	.clk(clk2),
	.e(n_ocoll),
	.q({sprite_lut_A[7:4], shf0_l, shf1_l, sprite_lbuff_sel, sprrom_flip})
);

//Secondary CPU - Motorola MC6809E (uses modified version of John E. Kent's CPU09 by B. Cuzeau)
wire [15:0] sA;
wire [7:0] sD_out;
wire s_rw;
cpu09 u12E
(
	.clk(se),
	.ce(1'b1),
	.rst(~n_res),
	.rw(s_rw),
	.addr(sA),
	.data_in(sD_in),
	.data_out(sD_out),
	.halt(1'b0),
	.irq(~n_sirq),
	.firq(1'b0),
	.nmi(1'b0)
);
//Multiplex data inputs to primary MC6809E
wire [7:0] mD_in =
		sndbrd_dir                       ? sndbrd_D:
		(~n_charram0_en & ~n_charram_oe) ? charram0_D:
		(~n_charram1_en & ~n_charram_oe) ? charram1_D:
		~n_mcpu_sharedram_en             ? sharedram_D:
		~n_rom1_en                       ? eprom1_D:
		~n_rom2_en                       ? eprom2_D:
		~n_rom3_en                       ? eprom3_D:
		~n_rom4_en                       ? eprom4_D:
		8'hFF;

//Primary CPU - Motorola MC6809E (uses modified version of John E. Kent's CPU09 by B. Cuzeau)
wire [15:0] mA;
wire [7:0] mD_out;
wire m_rw;
cpu09 u12G
(
	.clk(me),
	.ce(1'b1),
	.rst(~n_res),
	.rw(m_rw),
	.addr(mA),
	.data_in(mD_in),
	.data_out(mD_out),
	.halt(1'b0),
	.irq(~n_mirq),
	.firq(1'b0),
	.nmi(1'b0)
);
//Multiplex data inputs to secondary MC6809E
wire [7:0] sD_in =
		~n_rom5_en                         ? eprom5_D:
		~n_scpu_sharedram_en               ? sharedram_D:
		~n_spriteram1_en & n_spriteram1_we ? spriteram_D[15:8]:
		~n_spriteram0_en & n_spriteram0_we ? spriteram_D[7:0]:
		~n_beam_en                         ? vcnt_lat:
		8'hFF;

//Address decoding for primary MC6809E (1/2)
wire n_rom1_en, n_rom2_en, n_rom3_en, n_rom4_en, n_mcpu_ram_en, n_io_dec;
ls138 u12J
(
	.n_e1(1'b0),
	.n_e2(1'b0),
	.e3(meq),
	.a(mA[15:13]),
	.o({n_rom4_en, n_rom3_en, n_rom2_en, n_rom1_en, 1'bZ, n_mcpu_ram_en, n_io_dec, 1'bZ})
);

//Sprite ROM 3/4
wire [7:0] eprom10_D;
eprom_10 u13A
(
	.ADDR(spriterom_A),
	.CLK(pixel_clk),
	.DATA(eprom10_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(ep10_cs_i),
	.WR(ioctl_wr)
);

//Generate lower half of sprite line buffer bank 0 address bus
wire sprite_lbuff0_carry;
ls163 u13C
(
	.n_clr(n_sprite_lbuff0_clr),
	.clk(clk2),
	.din(spriteram_D[11:8]),
	.enp(1'b1),
	.ent(1'b1),
	.n_load(n_sprite_lbuff0_ld),
	.q(sprite_lbuff0_A[3:0]),
	.rco(sprite_lbuff0_carry)
);

//Sprite line buffer bank 0
wire [7:0] sprite_lbuff0_A;
wire [3:0] sprite_lbuff0_D;
spram #(4, 10) u13D
(
	.clk(clk_12m),
	.we(~clk2 & ~n_sprite_lbuff0_en),
	.addr({2'b00, sprite_lbuff0_A}),
	.data(sprite_lbuff_Do[3:0]),
	.q(sprite_lbuff0_D)
);

//Address decoding for secondary MC6809E
wire n_rom5_en, n_scr, n_ora, n_scpu_irq, n_beam_en, n_safr;
ls138 u13E
(
	.n_e1(1'b0),
	.n_e2(1'b0),
	.e3(seq),
	.a(sA[15:13]),
	.o({n_rom5_en, 2'bZZ, n_scr, n_ora, n_scpu_irq, n_beam_en, n_safr})
);

//Invert E and Q clocks for secondary MC6809E, MCR and SCR
//Inverter 5 inverts the chip enable for sprite ROMS - this is not required here and has
//been omitted
wire scr, se, sq, ld, mcr;
ls04 u13F
(
	.a1(n_scr),
	.y1(scr),
	.a2(n_sq),
	.y2(sq),
	.a3(n_se),
	.y3(se),
	.a4(n_ld),
	.y4(ld),
	.a6(n_mcr),
	.y6(mcr)
);

//NAND horizontal counter bits [6:4], watchdog timer + power-on reset
wire res, n_h32_128, sndbrd_dir;
ls10 u13G
(
	.a1(h32),
	.b1(h128),
	.c1(h64),
	.y1(n_h32_128),
	.a2(n_in6),
	.b2(n_ioen),
	.c2(n_in5),
	.y2(sndbrd_dir),
	.a3(n_watchdog_timer),
	.b3(n_por_timer_out),
	.c3(reset),
	.y3(res)
);

//Invert reset line for the entire PCB, E and Q clocks for primary MC6809E, power-on reset timer output,
//watchdog timer output
wire n_res, me, mq, sprite_lbuff_h, n_por_timer_out, n_watchdog_timer;
ls04 u13H
(
	.a1(res),
	.y1(n_res),
	.a2(n_me),
	.y2(me),
	.a3(n_mq),
	.y3(mq),
	.a4(sprite_lbuff_l),
	.y4(sprite_lbuff_h),
	.a5(por_timer_out),
	.y5(n_por_timer_out),
	.a6(watchdog_timer),
	.y6(n_watchdog_timer)
);

//Generate the following signals
//Interrupt for primary MC6809E, latch for scrolling/static screen area
wire n_mirq, scroll_lat;
ls74 u13J
(
	.n_pre1(vblk_irq_clr),
	.n_clr1(1'b1),
	.clk1(vblk),
	.d1(1'b0),
	.q1(n_mirq),
	.n_pre2(1'b1),
	.n_clr2(1'b1),
	.clk2(h16),
	.d2(scroll),
	.n_q2(scroll_lat)
);

//Sprite ROM 2/4
wire [7:0] eprom11_D;
eprom_11 u14A
(
	.ADDR(spriterom_A),
	.CLK(pixel_clk),
	.DATA(eprom11_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(ep11_cs_i),
	.WR(ioctl_wr)
);

//Generate upper half of sprite line buffer bank 1 address bus
ls163 u14C
(
	.n_clr(n_sprite_lbuff1_clr),
	.clk(clk2),
	.din(spriteram_D[15:12]),
	.enp(sprite_lbuff1_carry),
	.ent(sprite_lbuff1_carry),
	.n_load(n_sprite_lbuff1_ld),
	.q(sprite_lbuff1_A[7:4])
);

//Sprite line buffer bank 1
wire [7:0] sprite_lbuff1_A;
wire [3:0] sprite_lbuff1_D;
spram #(4, 10) u14D
(
	.clk(clk_12m),
	.we(~clk2 & ~n_sprite_lbuff1_en),
	.addr({2'b00, sprite_lbuff1_A}),
	.data(sprite_lbuff_Do[7:4]),
	.q(sprite_lbuff1_D)
);

//Invert H256 signal for Konami 502, XOR shf0 and shf1 with inverted HREV, generate character flip signal
wire shf1_rev, h256, char_flip, shf0_rev;
ls86 u14E
(
	.a1(shf1),
	.b1(n_hrev),
	.y1(shf1_rev),
	.a2(n_h256),
	.b2(1'b0),
	.y2(h256),
	.a3(n_hrev),
	.b3(char_hflip),
	.y3(char_flip),
	.a4(n_hrev),
	.b4(shf0),
	.y4(shf0_rev)
);

//Generate interrupt and interrupt clear for secondary MC6809E
wire n_sirq, s_vblk_irq_clr;
ls74 u14F
(
	.n_pre1(s_vblk_irq_clr),
	.n_clr1(1'b1),
	.clk1(vblk),
	.d1(1'b0),
	.q1(n_sirq),
	.n_pre2(1'b1),
	.n_clr2(n_res),
	.clk2(n_scpu_irq),
	.d2(sD_out[0]),
	.q2(s_vblk_irq_clr)
);

//Generate E and Q clocks for both MC6809Es
wire n_me, n_mq, n_se, n_sq;
ls74 u14G
(
	.n_pre1(1'b1),
	.n_clr1(1'b1),
	.clk1(clk2),
	.d1(h2),
	.q1(n_mq),
	.n_q1(n_sq),
	.n_pre2(1'b1),
	.n_clr2(1'b1),
	.clk2(clk2),
	.d2(n_mq),
	.q2(n_me),
	.n_q2(n_se)
);

//Watchdog timer
wire watchdog_timer_fb, watchdog_timer;
ls293 u14H
(
	.clk1(vblk),
	.clk2(watchdog_timer_fb),
	.clr1(watchdog_timer_rst),
	.clr2(watchdog_timer_rst),
	.q({watchdog_timer, 2'bZZ, watchdog_timer_fb})
);

//Latch least significant bit of horizontal counter, latch for watchdog timer
wire h1d, n_h1d, watchdog_lat;
ls74 u14J
(
	.n_pre1(1'b1),
	.n_clr1(1'b1),
	.clk1(n_clk1),
	.d1(h1),
	.q1(h1d),
	.n_q1(n_h1d),
	.n_pre2(watchdog_lat_pre),
	.n_clr2(n_res),
	.clk2(n_safr),
	.d2(watchdog_safr),
	.q2(watchdog_lat)
);

//Sprite ROM 4/4
wire [7:0] eprom12_D;
eprom_12 u15A
(
	.ADDR(spriterom_A),
	.CLK(pixel_clk),
	.DATA(eprom12_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(ep12_cs_i),
	.WR(ioctl_wr)
);

//Generate lower half of sprite line buffer bank 1 address bus
wire sprite_lbuff1_carry;
ls163 u15C
(
	.n_clr(n_sprite_lbuff1_clr),
	.clk(clk2),
	.din(spriteram_D[11:8]),
	.enp(1'b1),
	.ent(1'b1),
	.n_load(n_sprite_lbuff1_ld),
	.q(sprite_lbuff1_A[3:0]),
	.rco(sprite_lbuff1_carry)
);

//Konami 502 custom chip, responsible for generating sprites
wire [7:0] sprite_lbuff_Do;
wire [4:0] sprite_D;
wire sprite_lbuff_l, sprite_lbuff_dec0, sprite_lbuff_dec1;
k502 u15D
(
	.CK1(clk1),
	.CK2(k502_ck2),
	.LD0(n_ld0),
	.H2(h2),
	.H256(h256),
	.SPAL(sprite_lut_D),
	.SPLBi({sprite_lbuff1_D, sprite_lbuff0_D}),
	.SPLBo(sprite_lbuff_Do),
	.OSEL(sprite_lbuff_l),
	.OLD(sprite_lbuff_dec1),
	.OCLR(sprite_lbuff_dec0),
	.COL(sprite_D)
);

//Generate inverted HREV signal, 
wire n_hrev, vmux0, vmux1, sprram_en0;
ls02 u15F
(
	.a1(hrev),
	.b1(1'b0),
	.y1(n_hrev),
	.a2(shf1_l),
	.b2(scroll_l3),
	.y2(vmux1),
	.a3(shf0_l),
	.b3(scroll_l3),
	.y3(vmux0),
	.a4(s_rw),
	.b4(h1d),
	.y4(sprram_en0)
);

//Generate character data select lines, combined EQ clocks for each CPU
wire char_sel0, char_sel1, meq, seq;
ls32 u15G
(
	.a1(vmux1),
	.b1(vmux_en),
	.y1(char_sel1),
	.a2(n_sq),
	.b2(n_se),
	.y2(meq),
	.a3(n_me),
	.b3(n_mq),
	.y3(seq),
	.a4(vmux_en),
	.b4(vmux0),
	.y4(char_sel0)
);

//15H contains an NE555 timer which takes approximately 326ms to pull the board out of reset.  Model this as a
//32-bit counter that pulls the core out of reset when its value reaches 1998221
reg [31:0] por_timer;
always_ff @(posedge pixel_clk) begin
	if(por_timer < 1998221)
		por_timer <= por_timer + 1;
end
wire por_timer_out = (por_timer < 1998220);

//Generate watchdog latch preset, watchdog timer trigger, sprite RAM address line A9, watchdog latch SAFR input
wire watchdog_lat_pre, watchdog_timer_trig, watchdog_safr;
ls32 u15J
(
	.a1(n_sq),
	.b1(n_mafr),
	.y1(watchdog_lat_pre),
	.a2(n_mafr),
	.b2(watchdog_lat),
	.y2(watchdog_timer_trig),
	.a3(sA[10]),
	.b3(h2),
	.y3(spriteram_A[9]),
	.a4(1'b0),
	.b4(n_safr),
	.y4(watchdog_safr)
);

//Multiplex sprite ROM data outputs
wire [15:0] spriterom_D = ~n_spriterom0_en ? {eprom11_D, eprom9_D} : {eprom12_D, eprom10_D};

//Konami 083 custom chip 2/2 - this one shifts the pixel data from sprite ROMs
k083 u16A
(
	.CK(clk2),
	.LOAD(ld),
	.FLIP(sprrom_flip),
	.DB0i(spriterom_D[7:0]),
	.DB1i(spriterom_D[15:8]),
	.DSH0(sprite_lut_A[1:0]),
	.DSH1(sprite_lut_A[3:2])
);

//Sprite lookup PROM
wire [7:0] sprite_lut_A;
wire [3:0] sprite_lut_D;
sprite_lut_prom u16C
(
	.ADDR(sprite_lut_A),
	.CLK(clk_12m),
	.DATA(sprite_lut_D),
	.ADDR_DL(ioctl_addr),
	.CLK_DL(clk_49m),
	.DATA_IN(ioctl_data),
	.CS_DL(sl_cs_i),
	.WR(ioctl_wr)
);

//Generate load and clear signals for 74LS163s generating addresses for sprite line buffer
wire n_sprite_lbuff0_ld, n_sprite_lbuff1_ld, n_sprite_lbuff0_clr, n_sprite_lbuff1_clr;
ls139 u16D
(
	.n_e({n_ld, n_ocoll}),
	.a0({sprite_lbuff_dec0, sprite_lbuff_dec1}),
	.a1({sprite_lbuff_dec1, 1'b0}),
	.o0({2'bZZ, n_sprite_lbuff1_ld, n_sprite_lbuff0_ld}),
	.o1({1'bZ, n_sprite_lbuff0_clr, n_sprite_lbuff1_clr, 1'bZ})
);

//Generate clock for 502 custom chip, select line for character/sprite MUX, color MUX enable
wire k502_ck2, ch_sp_sel, n_sharedram_we, color_mux;
ls32 u16E
(
	.a1(1'b0),
	.b1(clk2),
	.y1(k502_ck2),
	.a2(sprite_D[4]),
	.b2(color_mux),
	.y2(ch_sp_sel),
	.a3(sharedram_en),
	.b3(sharedram_h1),
	.y3(n_sharedram_we),
	.a4(scroll_l3),
	.b4(vmux_en),
	.y4(color_mux)
);

//Generate combined shared RAM enable, sprite line buffer enables, scroll data to be latched
wire sharedram_en, n_sprite_lbuff0_en, n_sprite_lbuff1_en, scroll;
ls08 u16F
(
	.a1(n_mcpu_sharedram_en),
	.b1(n_scpu_sharedram_en),
	.y1(sharedram_en),
	.a2(sprite_lbuff_l),
	.b2(sprite_lbuff_sel),
	.y2(n_sprite_lbuff0_en),
	.a3(sprite_lbuff_h),
	.b3(sprite_lbuff_sel),
	.y3(n_sprite_lbuff1_en),
	.a4(n_h256),
	.b4(n_h32_128),
	.y4(scroll)
);

endmodule
