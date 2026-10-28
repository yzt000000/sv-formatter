

// This module has 4 instance of jesd_10b8b_decode module and logic to check disparity
// based on the outputs of each of the 4 instances. 
// Assumption : If previous symbol reception results in  disparity error or not_in_table_error 
// then current symbol disparity is assumed to be positive provided the lookup in positive disparity 
// table is satisfied else it is assumed negative.
// Overall latency of this module is 2 clocks. 
// A decode error on a particular symbol is represented using K28.5 symbol on rxdata(k) lines

module jesd_40b32b_decode
  (input         clk_character,               // main clock
   input         rst_clk_character,           // async reset
   input         symbol_vld,                  // Input indicating symbol_in has valid content that needs to be processed
   input [39:0]  symbol_in,                   // Input containing 4 symbols {symbol_3,symbol_2,symbol_1,symbol_0}. Numbered in increasing order of time
   output reg    rxdata_vld,                  // When high indicates receive data stream is active
   output reg [31:0] rxdata,                  // Decoded data from 4 symbols
   output reg [3:0]  rxdata_k,                // One bit per byte of rxdata. When a bit is high it indicates corresponding decoded character is control else data
   output reg [3:0]  rxdisparity_err,         // One bit per byte of rxdata. When a bit is high it indicates correspondig symbol failed the running disparity check
   output [3:0]  rxnot_in_table_err);         // One bit per byte of rxdata. When a bit is high it indicates correspondig symbol failed the decoding check.
   wire [39:0]   symbol_in_40 = symbol_in;
   wire [3:0]    flip_disparity;
//   wire [3:0]    symbol_disparity;
   wire [3:0] expected_disparity;
   wire [3:0] rxdisparity_err_next;
   wire [3:0] pos_table_hit,neg_table_hit;
   
   reg        rxdata_vld_next;
   wire [31:0] rxdata_next;
   wire [3:0]  rxdata_k_next;
   

   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         rxdata_vld_next <= 1'b0;
         rxdata_vld <= 1'b0;
         rxdata_k <= 4'h0;
         rxdata <= 32'h0;
      end
      else begin
         rxdata_vld_next  <= symbol_vld;
         rxdata_vld <= rxdata_vld_next;
         rxdata_k <= rxdata_k_next;
         rxdata <= rxdata_next;         
      end
   end

   
   reg rxnot_in_table_err_r;
   reg flip_disparity_r;
   reg expected_disparity_r;
   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         rxnot_in_table_err_r <= 1'b1;
         flip_disparity_r <= 1'b0;
         expected_disparity_r <= 1'b0;
         rxdisparity_err <= 4'h0;         
      end else if (rxdata_vld) begin
         rxnot_in_table_err_r <= rxnot_in_table_err[3];
         flip_disparity_r   <= flip_disparity[3];
         expected_disparity_r <= expected_disparity[3];   
         rxdisparity_err <= rxdisparity_err_next;               
      end
   end

   assign expected_disparity[0] = (rxdisparity_err[3] || rxnot_in_table_err_r)  ? pos_table_hit[0]
                                  : flip_disparity_r ^ expected_disparity_r;
   assign expected_disparity[1] = ( rxdisparity_err_next[0] || rxnot_in_table_err[0])  ? pos_table_hit[1]
                                  : flip_disparity[0] ^ expected_disparity[0];   
   assign expected_disparity[2] =  (rxdisparity_err_next[1] || rxnot_in_table_err[1])  ? pos_table_hit[2]
                                  : flip_disparity[1] ^ expected_disparity[1];   
   assign expected_disparity[3] =  (rxdisparity_err_next[2] || rxnot_in_table_err[2])  ? pos_table_hit[3]
                                  : flip_disparity[2] ^ expected_disparity[2];   

   assign rxdisparity_err_next[0] =  expected_disparity[0] ? ~pos_table_hit[0] : ~neg_table_hit[0];
   assign rxdisparity_err_next[1] =  expected_disparity[1] ? ~pos_table_hit[1] : ~neg_table_hit[1];
   assign rxdisparity_err_next[2] =  expected_disparity[2] ? ~pos_table_hit[2] : ~neg_table_hit[2];
   assign rxdisparity_err_next[3] =  expected_disparity[3] ? ~pos_table_hit[3] : ~neg_table_hit[3];
   
   


   
   jesd_10b8b_decode symbol_dec0
     (.clk(clk_character),
	  .rst(rst_clk_character),
      .symbol_in(symbol_in_40[9:0]), 
      .dout(rxdata_next[7:0]),
      .dout_k(rxdata_k_next[0]),
      .flip_disparity (flip_disparity[0]),
//      .symbol_disparity(symbol_disparity[0]),
      .pos_table_hit (pos_table_hit[0]),
      .neg_table_hit (neg_table_hit[0]),      
      .not_in_table_err(rxnot_in_table_err[0]));

   jesd_10b8b_decode symbol_dec1
     (.clk(clk_character),
	  .rst(rst_clk_character),	 
      .symbol_in(symbol_in_40[19:10]), 
      .dout(rxdata_next[15:8]),
      .dout_k(rxdata_k_next[1]),
      .flip_disparity (flip_disparity[1]),
//      .symbol_disparity(symbol_disparity[1]),
      .pos_table_hit (pos_table_hit[1]),
      .neg_table_hit (neg_table_hit[1]),      
      .not_in_table_err(rxnot_in_table_err[1]));


   jesd_10b8b_decode symbol_dec2
     (.clk(clk_character),
	  .rst(rst_clk_character),	 
      .symbol_in(symbol_in_40[29:20]), 
      .dout(rxdata_next[23:16]),
      .dout_k(rxdata_k_next[2]),
      .flip_disparity (flip_disparity[2]),
//      .symbol_disparity(symbol_disparity[2]),
      .pos_table_hit (pos_table_hit[2]),
      .neg_table_hit (neg_table_hit[2]),      
      .not_in_table_err(rxnot_in_table_err[2]));

   jesd_10b8b_decode symbol_dec3
     (.clk(clk_character),
	  .rst(rst_clk_character),	 
      .symbol_in(symbol_in_40[39:30]), 
      .dout(rxdata_next[31:24]),
      .dout_k(rxdata_k_next[3]),
      .flip_disparity (flip_disparity[3]),
//      .symbol_disparity(symbol_disparity[3]),
      .pos_table_hit (pos_table_hit[3]),
      .neg_table_hit (neg_table_hit[3]),            
      .not_in_table_err(rxnot_in_table_err[3]));

      
   
endmodule // jesd_40b32b_decode
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
