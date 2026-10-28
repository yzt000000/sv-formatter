

// This module is used to meet the needs of TX and RX IP cores . It has an almost full signal as one of its outputs which is asserted when 
// the amount of data stored in fifo is equal to Fifo Depth - THRESHOLD (parameter) . The almost full signal is generally not used excpet 
// in the case of TX data path instance within the the jesd_tx_arb module.
module jesd_sync_fifo_ext_mem
 #(parameter ASIZE = 3,
   parameter AFULL_TH=2'h2
   )
   (
    output reg         wfull,
    output reg         rempty,
    output reg         afull, // early full indication pulse
    output             wen,
    output [ASIZE-1:0] waddr,
    output [ASIZE-1:0] raddr,
    input              winc,
    input              rinc,
    input              clk, rst
    );

   wire [ASIZE:0]     wptr_next, rptr_next,wptr_th_next;
   reg [ASIZE:0]      wptr, rptr;   

   assign wptr_th_next = wptr + AFULL_TH;   
   assign wptr_next = wptr + (winc & ~wfull);
   assign rptr_next = rptr + (rinc & ~rempty);   

   wire               wfull_next = (wptr_next[ASIZE-1:0] == rptr_next[ASIZE-1:0]) && 
                                   (wptr_next[ASIZE] ^ rptr_next[ASIZE]);
   wire               rempty_next = (wptr_next[ASIZE:0] == rptr_next[ASIZE:0]);

   wire               afull_next = (wptr_th_next[ASIZE-1:0] == rptr_next[ASIZE-1:0]) && 
                                   (wptr_th_next[ASIZE] ^ rptr_next[ASIZE]);
                     
   assign waddr = wptr[ASIZE-1:0];
   assign raddr = rptr_next [ASIZE-1:0];
   assign wen   = (winc & ~wfull);
   
   always @(posedge clk or posedge rst) begin
      if (rst) begin
         wfull <= 1'b0;
         rempty <= 1'b1;
         rptr  <= 'h0;
         wptr <= 'h0;
         afull <= 1'b0;
      end
      else begin
         afull <= afull_next;         
         wfull <= wfull_next;
         rempty <= rempty_next;
         wptr <= wptr_next;
         rptr <= rptr_next;      
      end // else: !if(rst)
   end // always @ (posedge clk or posedge rst)

   
`ifdef BEH_ASSERTIONS
   always @(posedge clk ) begin
      if (rempty & rinc & !rst)
        $display("%m %0t BEH_ASSERTIONS ERROR : FIFO pop & Fifo empty = 1",$time);
      if (wfull & winc & !rst)
        $display("%m %0t BEH_ASSERTIONS ERROR : FIFO push & Fifo full = 1",$time);      
      
   end
`endif   
endmodule // jesd_sync_fifo

   
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
