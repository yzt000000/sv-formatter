

// This module is primarily a shell module which instantiates the per lane encode logic , width conversion and clock crossing logic required to interface the MAC 
// with serdes.  
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
`include "jesd_jesd204b_tx_defines.v"



module jesd_lane_encode
  #(parameter NO_SERDES_WORDS=1)
   (input                             clk_serdes,
    input                             rst_clk_serdes,
    input                             clk_character,
    input                             rst_clk_character,
    input [31:0]                      txdata,
    input [03:0]                      txdata_k, 
    input                             txdata_vld,
    input                             first_symbol_disparity,
         `ifdef BYPASS_8B10B
    output [(8*NO_SERDES_WORDS)-1:0] serdes_symbol,
          `endif
     `ifndef BYPASS_8B10B
    output [(10*NO_SERDES_WORDS)-1:0] serdes_symbol,
          `endif

    output                            serdes_symbol_vld
    );

             `ifdef BYPASS_8B10B
   localparam WORD_SIZE=8;
             `endif

             `ifndef BYPASS_8B10B
   localparam WORD_SIZE=10;
             `endif

   localparam DSIZE = WORD_SIZE*4;
   localparam ASIZE = 4; // 8 deep fifo for sync logic

   wire [(4*WORD_SIZE)-1:0] data_in;   
   wire                 data_in_vld;   
   wire [DSIZE-1:0]     rdata;         
   wire                 rempty;        
   wire                 wfull;         

   


   wire                 wclk = clk_character;
   wire                 wrst = rst_clk_character;
   
   wire                 rclk = clk_serdes;
   wire                 rrst = rst_clk_serdes;

   wire                  winc;
   wire [DSIZE-1:0]      wdata;
   wire                  rinc;
   

 `ifndef BYPASS_8B10B  
   
 jesd_32b40b_encode jesd_32b40b_encode(
                                     .rst (rst_clk_character),
                                     .first_symbol_disparity (first_symbol_disparity),
                                     .din (txdata),
                                     .din_k (txdata_k),
                                     .clk (clk_character),
                                     .din_vld (txdata_vld),
                                     .dout(wdata),
                                     .dout_vld(winc)
                         );
                             `endif
  jesd_async_fifo 
     #(
       // Parameters
       .DSIZE                           (DSIZE),
       .ASIZE                           (ASIZE))
   sync
   (
    // Outputs
    .rdata                              (rdata[DSIZE-1:0]),
    .wfull                              (wfull),
    .rempty                             (rempty),
    .afull                              (),
    // Inputs
     `ifndef BYPASS_8B10B  
    .wdata                              (wdata[DSIZE-1:0]),
    .winc                               (winc),
     `endif
     `ifdef BYPASS_8B10B
     .wdata                              (txdata[DSIZE-1:0]),
    .winc                               (txdata_vld),
      `endif
      
    .wclk                               (wclk),
    .wrst                               (wrst),
    .rinc                               (rinc),
    .rclk                               (rclk),
    .rrst                               (rrst));

   
   jesd_4_to_421_gearbox 
     #(
       // Parameters
       .NO_SERDES_WORDS                 (NO_SERDES_WORDS),
       .WORD_SIZE                       (WORD_SIZE))
   width_conv 
     (
    // Outputs
    .serdes_symbol_vld                  (serdes_symbol_vld),
    .serdes_symbol                      (serdes_symbol),
    .data_in_rdy                        (rinc),
    // Inputs
    .clk_serdes                         (clk_serdes),
    .rst_clk_serdes                     (rst_clk_serdes),
    .data_in                           (rdata),
    .data_in_vld                       (!rempty));
   

 
endmodule // jesd_lane_encode

// Local Variables:
// verilog-library-directories:(".")
// End:
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
