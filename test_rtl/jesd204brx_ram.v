/********************************************************************

* Copyright (c) 2014 by GIS Chip, Inc.
* All rights reserved.
* GIS Chip Confidential Proprietary.
*
* Created by:        stevenchung@bj7
* Creation date:     Tue Mar 11 11:07:49 CST 2014
* Description:       Generated from GIS memory wrapper template
*  
*
********************************************************************/

`timescale 1ns/100ps

    module jesd204brx_ram ( // Port declaration
    q,
    addr,
    clk,
    d,
    cen,
    oen,
    wen,

    bist_mode,
    scan_mode,

    bist_addr,
    bist_d,
    bist_cen,
    bist_oen,
    bist_wen,
        q_b,
    addr_b,
    clk_b,
    d_b,
    cen_b,
    oen_b,
    wen_b

);
output [36-1:0]    q;
input [8-1:0]    addr;
input     clk;
input [36-1:0]    d;
input     cen;
input     oen;
input [1-1:0]    wen;

input     bist_mode;
input     scan_mode;
input [8-1:0]    bist_addr;
input [36-1:0]    bist_d;
input     bist_cen;
input     bist_oen;
input [1-1:0]    bist_wen;
    output [36-1:0]    q_b;
input [8-1:0]    addr_b;
input     clk_b;
input [36-1:0]    d_b;
input     cen_b;
input     oen_b;
input [1-1:0]    wen_b;



wire  [8-1:0]    ADDR;
wire  [36-1:0]    D;
wire      CEN;
wire      OEN;
wire  [1-1:0]    WEN;

`ifndef SRAM 
reg [36-1:0]    Q;
`else
wire [36-1:0]    Q;
`endif
assign ADDR = bist_mode ? bist_addr : addr;
assign D = bist_mode ? bist_d : d;
assign CEN = bist_mode ? bist_cen : cen;
assign OEN = bist_mode ? bist_oen : oen;
assign WEN = bist_mode ? bist_wen : wen;
assign q = scan_mode ? D : Q;

    wire  [8-1:0]    ADDR_B;
wire  [36-1:0]    D_B;
wire      CEN_B;
wire      OEN_B;
wire  [1-1:0]    WEN_B;
wire [36-1:0]    Q_B;

assign ADDR_B = bist_mode ? bist_addr : addr_b;
assign D_B = bist_mode ? bist_d : d_b;
assign CEN_B = bist_mode ? bist_cen : cen_b;
assign OEN_B = bist_mode ? bist_oen : oen_b;
assign WEN_B = bist_mode ? bist_wen : wen_b;
assign q_b = scan_mode ? D_B : Q_B;
`ifndef SRAM 
reg [36-1:0] mem [0:256-1];
always @(posedge clk)
begin
        if (WEN & CEN)
		mem[ADDR] <= D;
end

always @(posedge clk)
begin
        if (CEN)
            Q <= mem[ADDR];
end

`else
    RADP1024X36M8 instance_0 (
        .DAOUT      (Q),
    .DBOUT      (Q_B),
    .ADA        (ADDR),
    .ADB        (ADDR_B),
    .CENA       (CEN),
    .CENB       (CEN_B),
    .CLKA       (clk),
    .CLKB       (clk_b),

    .DAIN       (D),
    .DBIN       (D_B),
    .OEA        (OEN),
    .OEB        (OEN_B),
    .WEA        (WEN),
    .WEB        (WEN_B)
        );
`endif

endmodule
