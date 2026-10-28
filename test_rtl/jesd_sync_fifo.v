

// This module is used to meet the needs of TX and RX IP cores . It has an almost full signal as one of its outputs which is asserted when 
// the amount of data stored in fifo is equal to Fifo Depth - THRESHOLD (parameter) . The almost full signal is generally not used excpet 
// in the case of TX data path instance within the the jesd_tx_arb module.
module jesd_sync_fifo
 #(parameter DSIZE = 48,
   parameter ASIZE = 3,
   parameter AFULL_TH=2'h2
   )
   (output [DSIZE-1:0] rdata,
    output reg        wfull,
    output reg        rempty,
    output reg        afull, // early full indication pulse
    input [DSIZE-1:0] wdata,
    input             flush,
    input             winc,
    input             rinc,
    input             clk, rst
    );
   localparam DEPTH =  (1<<ASIZE);

//   reg ram_wr_en, ram_rd_en;
   wire [ASIZE-1:0]   waddr, raddr;
   wire [ASIZE:0]     wptr_next, rptr_next,wptr_th_next;
   reg [ASIZE:0]      wptr, rptr;   
  // reg [DSIZE-1:0] mem [0:DEPTH-1];

   assign wptr_th_next = wptr + {{(ASIZE-1){1'b0}},AFULL_TH};   
   assign wptr_next = wptr + {{(ASIZE){1'b0}},(winc & ~wfull)};
   assign rptr_next = rptr + {{(ASIZE){1'b0}},(rinc & ~rempty)};   

   wire               wfull_next = (wptr_next[ASIZE-1:0] == rptr_next[ASIZE-1:0]) && 
                                   (wptr_next[ASIZE] ^ rptr_next[ASIZE]);
   wire               rempty_next = (wptr_next[ASIZE:0] == rptr_next[ASIZE:0]);

   wire               afull_next = (wptr_th_next[ASIZE-1:0] == rptr_next[ASIZE-1:0]) && 
                                   (wptr_th_next[ASIZE] ^ rptr_next[ASIZE]);
                     
   assign waddr = wptr[ASIZE-1:0];
   assign raddr = rptr [ASIZE-1:0];
//initial
//begin
//  ram_wr_en <= 1'b0;
//end
wire [DSIZE-1:0] wdata_prev, rdata_prev;
   
   assign wdata_prev =(winc & ~wfull)?  wdata :  'h0;

//   //assign rdata = mem[raddr];   
//   always @(posedge clk)
//   begin
////     ram_rd_en <= 1'b1;
//     if (winc & ~wfull)
//       begin
//        	 wdata_prev = wdata;
//     end
//       
// //    else
// //      begin
// //        wdata_prev<='h0;
////       ram_rd_en <= 1'b1;
////      ram_wr_en <= 1'b0;
////     end
//   end

   
   always @(posedge clk or posedge rst) begin
      if (rst) begin
         wfull <= 1'b0;
         rempty <= 1'b1;
         rptr  <= 'h0;
         wptr <= 'h0;
         afull <= 1'b0;
//         ram_rd_en <= 1'b0;
//         ram_wr_en <= 1'b0;         
      end
      else if (flush) begin
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

   ram_2_clk_1wr1r #(
   .DWID (DSIZE),
   .DEP (DEPTH),
   .AWID (ASIZE)) 
   
   ram_2_clk_1wr1r(
   //write ports
   .clk_a (clk),
   .wen_a_i  (1'b1),
   .addr_a_i  (waddr),
   .wdata_a_i (wdata_prev),
   //read ports
   .clk_b (clk),
   .ren_b_i (1'b1),
   .addr_b_i (raddr),
   .rdata_b_o (rdata)
   );
   
   
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
