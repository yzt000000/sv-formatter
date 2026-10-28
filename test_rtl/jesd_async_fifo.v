

// This file contains multiple modules used as building blocks for fifo supporting different read and write clocks
// Starting point for the code is based on Cliff Cummings white papers on this topic . Almost full (AFULL) flag generation
// was added based on the need and this port is not used in all the instances . (Primary use is in TX path)  
// +define+BEH_ASSERTIONS will activate code to detect and report uderrun / overflow occurence at per instance level.
// Look for string "BEH_ASSERTIONS ERROR" while post processing log files to ensure the test passed without uderrun / overflow
module jesd_async_fifo
 #(parameter DSIZE = 8,
   parameter ASIZE = 4)
   (output [DSIZE-1:0] rdata,
    output            wfull,
    output [3:0]      afull, // If bit 3 == 1 --> only 3 locations available , bit [2] == 1 --> only 2 locations available and so on . All 0 and wfull=0 means more than 3 locations avail 
    output            rempty,
    input [DSIZE-1:0] wdata,
    input             winc, wclk, wrst,
    input             rinc, rclk, rrst);

   
   wire [ASIZE-1:0]   waddr, raddr;
   wire [ASIZE:0]     wptr, rptr, wq2_rptr, rq2_wptr;
   

   jesd_simple_sync #(.WIDTH (ASIZE+1),
                 .REG_IP(0))
   sync_r2w (.src_signal(rptr),
             .src_clk(1'b0),
             .dest_clk(wclk),
             .dest_signal(wq2_rptr));
   
   jesd_simple_sync #(.WIDTH (ASIZE+1),
                 .REG_IP(0))
   sync_w2r  (.src_signal(wptr),
             .src_clk(1'b0),
             .dest_clk(rclk),
             .dest_signal(rq2_wptr));
   
   fifomem #(DSIZE, ASIZE) fifomem
     (.rdata(rdata), .wdata(wdata),
      .waddr(waddr), .raddr(raddr),
      .wclken(winc), .wfull(wfull),
      .wclk(wclk));
   rptr_empty #(ASIZE) rptr_empty
     (.rempty(rempty),
      .raddr(raddr),
      .rptr(rptr), .rq2_wptr(rq2_wptr),
      .rinc(rinc), .rclk(rclk),
      .rrst(rrst));
   wptr_full #(ASIZE) wptr_full
     (.wfull(wfull), .afull(afull),
      .waddr(waddr),
      .wptr(wptr), .wq2_rptr(wq2_rptr),
      .winc(winc), .wclk(wclk),
      .wrst(wrst));
endmodule // jesd_async_fifo


module fifomem #(parameter DATASIZE = 8, // Memory data word width
                 parameter ADDRSIZE = 4) // Number of mem address bits
   (output [DATASIZE-1:0] rdata,
    input [DATASIZE-1:0] wdata,
    input [ADDRSIZE-1:0] waddr, raddr,
    input                wclken, wfull, wclk);

   localparam DEPTH = 1<<ADDRSIZE;
   reg [DATASIZE-1:0]    mem [0:DEPTH-1];
   assign rdata = mem[raddr];
   always @(posedge wclk)
     if (wclken && !wfull) mem[waddr] <= wdata;

endmodule // fifomem






//Verilog RTL code for the read pointer and empty flag logic
module rptr_empty #(parameter ADDRSIZE = 4)
(output reg rempty,
output [ADDRSIZE-1:0] raddr,
output reg [ADDRSIZE :0] rptr,
input [ADDRSIZE :0] rq2_wptr,
input rinc, rclk, rrst);
reg [ADDRSIZE:0] rbin;
wire [ADDRSIZE:0] rgraynext, rbinnext;
wire rempty_val;
//-------------------
// GRAYSTYLE2 pointer
//-------------------
always @(posedge rclk or posedge rrst)
if (rrst) {rbin, rptr} <= 0;
else {rbin, rptr} <= {rbinnext, rgraynext};
// Memory read-address pointer (okay to use binary to address memory)
assign raddr = rbin[ADDRSIZE-1:0];
assign rbinnext = rbin + {{ADDRSIZE{1'b0}},(rinc & ~rempty)};
assign rgraynext = (rbinnext>>1) ^ rbinnext;
//---------------------------------------------------------------
// FIFO empty when the next rptr == synchronized wptr or on reset
//---------------------------------------------------------------
assign rempty_val = (rgraynext == rq2_wptr);
always @(posedge rclk or posedge rrst)
if (rrst) rempty <= 1'b1;
else rempty <= rempty_val;

`ifdef BEH_ASSERTIONS
   always @(posedge rclk ) begin
      if (rempty & rinc & !rrst)
        $display("%m %0t BEH_ASSERTIONS ERROR : FIFO pop & Fifo empty = 1",$time);      
   end
`endif
endmodule // rptr_empty


//Verilog RTL code for the write pointer and full flag logic
module wptr_full #(parameter ADDRSIZE = 4)
(output reg wfull,
 output reg [3:0]         afull, // If bit 3 == 1 --> only 3 locations available , bit [2] == 1 --> only 2 location available and so on . All 0 means more than 3 locations avail 
 output [ADDRSIZE-1:0]    waddr,
 output reg [ADDRSIZE :0] wptr,
 input [ADDRSIZE :0]      wq2_rptr,
 input                    winc, wclk, wrst);
reg [ADDRSIZE:0] wbin;
wire [ADDRSIZE:0] wgraynext, wbinnext;
wire wfull_val;
// GRAYSTYLE2 pointer
always @(posedge wclk or posedge wrst)
if (wrst) {wbin, wptr} <= 0;
else {wbin, wptr} <= {wbinnext, wgraynext};
// Memory write-address pointer (okay to use binary to address memory)
assign waddr = wbin[ADDRSIZE-1:0];
assign wbinnext = wbin + {{ADDRSIZE{1'b0}},(winc & ~wfull)};
assign wgraynext = (wbinnext>>1) ^ wbinnext;
//------------------------------------------------------------------
// Simplified version of the three necessary full-tests:
// assign wfull_val=((wgnext[ADDRSIZE] !=wq2_rptr[ADDRSIZE] ) &&
// (wgnext[ADDRSIZE-1] !=wq2_rptr[ADDRSIZE-1]) &&
// (wgnext[ADDRSIZE-2:0]==wq2_rptr[ADDRSIZE-2:0]));
//------------------------------------------------------------------
assign wfull_val = (wgraynext=={~wq2_rptr[ADDRSIZE:ADDRSIZE-1],
wq2_rptr[ADDRSIZE-2:0]});
always @(posedge wclk or posedge wrst)
if (wrst) wfull <= 1'b0;
else wfull <= wfull_val;


   wire [ADDRSIZE:0] wbin_p1 = wbin + {{(ADDRSIZE-1){1'b0}},2'b01} + {{ADDRSIZE{1'b0}},(winc & ~wfull)} ;
   wire [ADDRSIZE:0] wbin_p2 = wbin + {{(ADDRSIZE-1){1'b0}},2'b10} + {{ADDRSIZE{1'b0}},(winc & ~wfull)} ;
   wire [ADDRSIZE:0] wbin_p3 = wbin + {{(ADDRSIZE-1){1'b0}},2'b11} + {{ADDRSIZE{1'b0}},(winc & ~wfull)} ;
   wire [ADDRSIZE:0] wbin_p4 = wbin + {{(ADDRSIZE-2){1'b0}},3'b100} + {{ADDRSIZE{1'b0}},(winc & ~wfull)} ;
   wire [ADDRSIZE:0] wgray_p1_next = (wbin_p1 >> 1) ^ wbin_p1;
   wire [ADDRSIZE:0] wgray_p2_next = (wbin_p2 >> 1) ^ wbin_p2;
   wire [ADDRSIZE:0] wgray_p3_next = (wbin_p3 >> 1) ^ wbin_p3;
   wire [ADDRSIZE:0] wgray_p4_next = (wbin_p4 >> 1) ^ wbin_p4;   

   wire afull_1_next = (wgray_p1_next=={~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]});
   wire afull_2_next = (wgray_p2_next=={~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]});
   wire afull_3_next = (wgray_p3_next=={~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]});
   wire afull_4_next = (wgray_p4_next=={~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]});
   
   always @(posedge wclk or posedge wrst)
     if (wrst) afull <= 4'b0000;
     else afull <= {afull_4_next,afull_3_next,afull_2_next,afull_1_next};   

`ifdef BEH_ASSERTIONS
   always @(posedge wclk ) begin
      if (wfull & winc & !wrst)
        $display("%m %0t BEH_ASSERTIONS ERROR : FIFO push & Fifo full = 1",$time);      
   end
`endif   
endmodule // wptr_full
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
