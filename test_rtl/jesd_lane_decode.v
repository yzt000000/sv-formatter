

// This module is primarily a shell module which instantiates the per lane decode logic , width conversion and clock crossing logic required to interface the MAC 
// with serdes.  It also supports functionality to inject various kind of errors in the receive data stream which can help test firmware and hardware interop in a
// standalone environment. All the inject_error signals assume a toggle interface so the firmware should ensure once its injected an error it should wait for sufficient time
// (at least 50 to 100 clk_characters) before injecting the next error.
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
`include "jesd_jesd204b_rx_defines.v" 



module jesd_lane_decode
  #(parameter NO_SERDES_WORDS=1)
   (input                            clk_serdes,
    input                            rst_clk_serdes,
    input                            clk_character,
    input                            rst_clk_character,
    input                            inject_cgs_err,
    input                            inject_not_in_table_err,
    input                            inject_lane_alignment_err,
    input                            inject_frame_alignment_err,  
    
  `ifdef BYPASS_8B10B  
    input [(8*NO_SERDES_WORDS)-1:0] serdes_symbol,
    `endif
    output [31:0]                    rxdata,
    
    
`ifndef BYPASS_8B10B             
     input [(10*NO_SERDES_WORDS)-1:0] serdes_symbol,             
    output [03:0]                    rxdata_k, 
    output [3:0]                     rxdisparity_err,
    output [3:0]                     rxnot_in_table_err,
`endif    

    output                           rxdata_vld 
    
    );
`ifdef BYPASS_8B10B                          
localparam WORD_SIZE=8;
`endif
`ifndef BYPASS_8B10B                          
   localparam WORD_SIZE=10;
 `endif
 
   localparam DSIZE = WORD_SIZE*4;
   localparam ASIZE = 4; // 8 deep fifo for sync logic

   // TBD MGH . Need to capture wfull as part of errors

   /*AUTOREGINPUT*/
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [(4*WORD_SIZE)-1:0] data_out;           // From width_conv of jesd_421_to_4_gearbox.v
   wire                 data_out_vld;           // From width_conv of jesd_421_to_4_gearbox.v
   wire [DSIZE-1:0]     rdata;                  // From freq_conv of jesd_async_fifo.v
   wire                 rempty;                 // From freq_conv of jesd_async_fifo.v
   wire                 wfull;                  // From freq_conv of jesd_async_fifo.v
   // End of automatics
   
   wire                 serdes_symbol_vld = 1'b1;

   wire                 rclk = clk_character;
   wire                 rrst = rst_clk_character;
   
   wire                 wclk = clk_serdes;
   wire                 wrst = rst_clk_serdes;

   wire [DSIZE-1:0]      wdata = data_out; 
   wire                  winc = data_out_vld & !wfull;
   wire                  rinc = !rempty;
   wire [39:0]           symbol_in = rdata;
   wire                  symbol_vld = !rempty;
   wire                  inject_cgs_err_sync, inject_not_in_table_err_sync, inject_lane_alignment_err_sync, inject_frame_alignment_err_sync;
   reg inject_cgs_err_r, inject_not_in_table_err_r, inject_lane_alignment_err_r, inject_frame_alignment_err_r;
   reg [39:0] symbol_in_r;
   reg        symbol_vld_r;
   

   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         symbol_vld_r <= 1'b0;
         symbol_in_r <= 'h0;
         inject_cgs_err_r <= 1'b0;
         inject_not_in_table_err_r <= 1'b0;
         inject_lane_alignment_err_r <= 1'b0;
         inject_frame_alignment_err_r <= 1'b0;         
      end
      else begin
         symbol_vld_r <= symbol_vld;         
         inject_cgs_err_r <= inject_cgs_err_sync;
         inject_not_in_table_err_r <= inject_not_in_table_err_sync;
         inject_lane_alignment_err_r <= inject_lane_alignment_err_sync;
         inject_frame_alignment_err_r <= inject_frame_alignment_err_sync;
         if (inject_cgs_err_r ^ inject_cgs_err_sync)
           symbol_in_r[39:0] <= {40{1'b1}}; // 4 consecutive decode errors
         else if (inject_not_in_table_err_r ^ inject_not_in_table_err_sync)
           symbol_in_r[39:0] <= {symbol_in[39:10],10'b1111_111111}; // single decode error
         else if (inject_lane_alignment_err_r ^ inject_lane_alignment_err_sync)
           symbol_in_r[39:0] <= {symbol_in[39:20],4'b0011,6'b001111,4'b1100,6'b110000}; // A's on 2 consecutive symbols
         else if (inject_frame_alignment_err_r ^ inject_frame_alignment_err_sync)
           symbol_in_r[39:0] <= {symbol_in[39:20],4'b1000,6'b001111,4'b0111,6'b110000}; // F's on two consecutive symbols
         else
           symbol_in_r <= symbol_in;
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)
   
   

   jesd_421_to_4_gearbox 
     #(/*AUTOINSTPARAM*/
       // Parameters
       .NO_SERDES_WORDS                 (NO_SERDES_WORDS),
       .WORD_SIZE                       (WORD_SIZE))
   width_conv 
   (/*AUTOINST*/
    // Outputs
    .data_out                           (data_out[(4*WORD_SIZE)-1:0]),
    .data_out_vld                       (data_out_vld),
    // Inputs
    .clk_serdes                         (clk_serdes),
    .rst_clk_serdes                     (rst_clk_serdes),
    .serdes_symbol_vld                  (serdes_symbol_vld),
    .serdes_symbol                      (serdes_symbol[(NO_SERDES_WORDS*WORD_SIZE)-1:0]));


   jesd_async_fifo 
     #(/*AUTOINSTPARAM*/
       // Parameters
       .DSIZE                           (DSIZE),
       .ASIZE                           (ASIZE))
   sync
   (/*AUTOINST*/
    // Outputs
      `ifndef BYPASS_8B10B   
    .rdata                              (rdata[DSIZE-1:0]),
      `endif
      `ifdef BYPASS_8B10B   
      .rdata                              (rxdata[DSIZE-1:0]),

      `endif
    .wfull                              (wfull),
    .rempty                             (rempty),
    .afull                              (),
    // Inputs
    .wdata                              (wdata[DSIZE-1:0]),
    .winc                               (winc),
    .wclk                               (wclk),
    .wrst                               (wrst),
    .rinc                               (rinc),
    .rclk                               (rclk),
    .rrst                               (rrst));

   jesd_simple_sync   #(.REG_IP (0))
   inject_err_sync_0
     (
      .src_signal (inject_cgs_err),
      .src_clk (1'b0),
      .dest_clk (clk_character), 
      .dest_signal (inject_cgs_err_sync)
      );

   jesd_simple_sync   #(.REG_IP (0))
   inject_err_sync_1
     (
      .src_signal (inject_not_in_table_err),
      .src_clk (1'b0),
      .dest_clk (clk_character), 
      .dest_signal (inject_not_in_table_err_sync)
      );

   jesd_simple_sync   #(.REG_IP (0))
   inject_err_sync_2
     (
      .src_signal (inject_lane_alignment_err),
      .src_clk (1'b0),
      .dest_clk (clk_character), 
      .dest_signal (inject_lane_alignment_err_sync)
      );

   jesd_simple_sync   #(.REG_IP (0))
   inject_err_sync_3
     (
      .src_signal (inject_frame_alignment_err),
      .src_clk (1'b0),
      .dest_clk (clk_character), 
      .dest_signal (inject_frame_alignment_err_sync)
      );
     
                          
      `ifdef BYPASS_8B10B   
      assign rxdata_vld = rinc;
      `endif
            
            
  `ifndef BYPASS_8B10B   
   jesd_40b32b_decode jesd_40b32b_decode 
     (/*AUTOINST*/
      // Outputs
      .rxdata_vld                       (rxdata_vld),
      .rxdata                           (rxdata[31:0]),
      .rxdata_k                         (rxdata_k[3:0]),
      .rxdisparity_err                  (rxdisparity_err[3:0]),
      .rxnot_in_table_err               (rxnot_in_table_err[3:0]),
      // Inputs
      .clk_character                    (clk_character),
      .rst_clk_character                (rst_clk_character),
      .symbol_vld                       (symbol_vld_r),
      .symbol_in                        (symbol_in_r[39:0]));
      
      `endif
endmodule // jesd_lane_decode

// Local Variables:
// verilog-library-directories:(".")
// End:
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
