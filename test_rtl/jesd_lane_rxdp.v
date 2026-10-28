

// This is a wrapper module used to instantiated the per lane logic for processing receive data stream.
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
`include "jesd_jesd204b_rx_defines.v" 



module jesd_lane_rxdp
  #(parameter NO_SERDES_WORDS=1,
   parameter DESKEW_BUF_ASIZE=8,
   parameter DESKEW_BUF_DSIZE=36
   )
  (

   // Beginning of automatic inputs (from unused autoinst inputs)
   input                            clk_character, // To jesd_lane_decode of jesd_lane_decode.v, ...
   input                            clk_serdes, // To jesd_lane_decode of jesd_lane_decode.v
   input                            comb_cgs_sync_req, // To jesd_lane_fs_sm of jesd_lane_fs_sm.v, ...
   input [10:0]                     mframe_length_char, // To jesd_rx_align_mon_char_rep of jesd_rx_align_mon_char_rep.v
   input [8:0]                      frame_length_char, 
   input [10:0]                     rbd_char_cnt, // To jesd_lane_deskew of jesd_lane_deskew.v
   input                            rst_clk_character, // To jesd_lane_decode of jesd_lane_decode.v, ...
   input                            rst_clk_serdes, // To jesd_lane_decode of jesd_lane_decode.v
`ifndef BYPASS_8B10B  
   input [(10*NO_SERDES_WORDS)-1:0] serdes_symbol,// To jesd_lane_decode of jesd_lane_decode.v
`endif
   
   input [DESKEW_BUF_DSIZE-1:0]     deskew_rd_data, // Valid one clk after deskew_rd_en=1
   // End of automatics
   input [8:0]                      txrx_ilas_length_mframe, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input                            txrx_enablemodule_reg, // To jesd_lane_cgs_sm of jesd_lane_cgs_sm.v
   input [3:0]                      txrx_bank_id_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [4:0]                      txrx_cf_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [1:0]                      txrx_cs_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [7:0]                      txrx_did_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [1:0]                      txrx_enablelinktest_reg,// To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [7:0]                      txrx_f_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [0:0]                      txrx_hd_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [4:0]                      txrx_k_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [4:0]                      txrx_l_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v

   input [4:0]                      txrx_lid_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v

   input [7:0]                      txrx_m_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [4:0]                      txrx_n_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [4:0]                      txrx_ntotal_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [4:0]                      txrx_s_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [0:0]                      txrx_scr_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input [2:0]                      txrx_subclass_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
   input                            txrx_ilas_disable,
   input                            txrx_lane_align_mon_disable,
   input                            txrx_lane_align_char_rep_disable, 
   input                            txrx_resync_on_comma_disable,
   input                            inject_cgs_err,
   input                            inject_not_in_table_err,
   input                            inject_lane_alignment_err,
   input                            inject_frame_alignment_err,
   input [7:0]                      sum_ilas_com_param,
   input                            comb_frame_data_vld,
   input                            lmfc_boundary,
   input                            mf_is_long,
   input                            txrx_enable_jtspat_test_reg,
   input                            prbs_test_enable_reg,
    
`ifdef BYPASS_8B10B  
   input [(8*NO_SERDES_WORDS)-1:0]  serdes_symbol,// To jesd_lane_decode of jesd_lane_decode.v
   input [3:0]                      rxdata_k,
   input [3:0]                      rxdisparity_err,
   input [3:0]                      rxnot_in_table_err,
`else 
   `ifndef BYPASS_ALIGN
   input                            sync_b,
   `endif
`endif

   // Beginning of automatic outputs (from unused autoinst outputs)
   output                           cgs_sync_req, // From jesd_lane_cgs_sm of jesd_lane_cgs_sm.v
   output                           underrun_err,
   output                           overrun_err,
   output                           dskew_err, // From jesd_lane_deskew of jesd_lane_deskew.v
   output                           mframe_alignment_err,
   output                           frame_alignment_err, 
   output                           lane_disparity_err,
   output                           lane_not_in_table_err,
   output                           mframe_symbol_err, // From jesd_lane_fs_sm of jesd_lane_fs_sm.v
   output                           frame_data_vld,
   output reg                       unexpected_k_err,
   output [DESKEW_BUF_ASIZE-1:0]    deskew_wr_addr,
   output                           deskew_wr_en,
   output [DESKEW_BUF_DSIZE-1:0]    deskew_wr_data,
   output [DESKEW_BUF_ASIZE-1:0]    deskew_rd_addr,
   output                           deskew_rd_en,
  
   // End of automatics
   output [3:0]                     tport_byte_en, // From jesd_rx_align_mon_char_rep of jesd_rx_align_mon_char_rep.v
   output [3:0]                     tport_data_eof, // From jesd_rx_align_mon_char_rep of jesd_rx_align_mon_char_rep.v
   output [3:0]                     tport_data_eomf, // From jesd_rx_align_mon_char_rep of jesd_rx_align_mon_char_rep.v
   output [3:0]                     tport_data_sof, // From jesd_rx_align_mon_char_rep of jesd_rx_align_mon_char_rep.v
   output [3:0]                     tport_data_somf, // From jesd_rx_align_mon_char_rep of jesd_rx_align_mon_char_rep.v
   output [31:0]                    tport_data, // From jesd_dscrambler32 of jesd_dscrambler32.v
   output                           tport_data_vld, // From jesd_dscrambler32 of jesd_dscrambler32.v

   output                           ilas_mismatch, // Fro jesd_ilas_monitor of jesd_ilas_monitor.v

   output [3:0]                     jtspat_vld_count,
   output [3:0]                     jtspat_err_count,
   output[3:0]                      prbs_vld_count,
   output[3:0]                      prbs_err_count,
   
   output [3:0]                     incr_comma_frame_count,
   output [3:0]                     incr_err_count
);
   wire [3:0]                       scr_byte_en;
   wire [3:0]                       scr_data_eof;
   wire [3:0]                       scr_data_eomf;
   wire [3:0]                       scr_data_sof;
   wire [3:0]                       scr_data_somf;
   wire [3:0]                       ilas_data_valid;
   wire [3:0]                       ilas_data_valid_out;


   wire [3:0]                       decode_err;
   wire [3:0]                       unexpected_k_err_local;
   wire [3:0]                       user_data_valid_n;
   
   wire                             ilas_restart;

   
   
/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
wire [31:0]             dskew_frame_data;       // From jesd_lane_deskew of jesd_lane_deskew.v
wire [3:0]              dskew_frame_data_k;     // From jesd_lane_deskew of jesd_lane_deskew.v
wire                    dskew_frame_data_vld;   // From jesd_lane_deskew of jesd_lane_deskew.v
wire [31:0]             frame_data;             // From jesd_lane_fs_sm of jesd_lane_fs_sm.v
wire [3:0]              frame_data_k;           // From jesd_lane_fs_sm of jesd_lane_fs_sm.v
//wire                    frame_data_vld;         // From jesd_lane_fs_sm of jesd_lane_fs_sm.v


`ifndef BYPASS_8B10B  

wire [3:0]              rxdata_k;               // From jesd_lane_decode of jesd_lane_decode.v
wire [3:0]              rxdisparity_err;        // From jesd_lane_decode of jesd_lane_decode.v
wire [3:0]              rxnot_in_table_err;     // From jesd_lane_decode of jesd_lane_decode.v

`endif
wire                    rxdata_vld;             // From jesd_lane_decode of jesd_lane_decode.v
wire [31:0]             rxdata;                 // From jesd_lane_decode of jesd_lane_decode.v

wire [31:0]             scr_data;               // From jesd_rx_align_mon_char_rep of jesd_rx_align_mon_char_rep.v
wire                    scr_data_vld;           // From jesd_rx_align_mon_char_rep of jesd_rx_align_mon_char_rep.v
// End of automatics

   reg [3:0]            unscr_byte_en;
   reg [3:0]            unscr_data_eof;
   reg [3:0]            unscr_data_eomf;
   reg [3:0]            unscr_data_sof;
   reg [3:0]            unscr_data_somf;
   reg [3:0]            unscr_user_data;
   
   wire [31:0]          unscr_data; // From jesd_dscrambler32 of jesd_dscrambler32.v
   wire                 unscr_data_vld; // From jesd_dscrambler32 of jesd_dscrambler32.v

   reg                  dskew_frame_data_vld_r;
   always @(posedge clk_character or posedge rst_clk_character) 
      if (rst_clk_character)
         dskew_frame_data_vld_r <= 'h0;
      else
         dskew_frame_data_vld_r <= dskew_frame_data_vld;       
   assign ilas_restart = ~dskew_frame_data_vld & dskew_frame_data_vld_r;


`ifdef BYPASS_8B10B
   wire [(8*NO_SERDES_WORDS)-1:0] serdes_symbol_aligned;
   assign serdes_symbol_aligned = serdes_symbol;
`else      
   wire [(10*NO_SERDES_WORDS)-1:0] serdes_symbol_aligned;
   
   `ifdef BYPASS_ALIGN
      assign serdes_symbol_aligned = serdes_symbol;
   `else

   wire                            sync_b_clk_serdes;
      
   // Sysnchronise the sync_b signal with clk_serdes
   jesd_simple_sync #(.REG_IP(0)) 
   sysref_sync(
               .src_signal  ( sync_b ),
               .src_clk     ( 1'b0 ),
               .dest_clk    ( clk_serdes ), 
               .dest_signal ( sync_b_clk_serdes ));
   
  
   jesd_comma_searcher #(.DATA_WIDTH (NO_SERDES_WORDS))
   u_jesd_comma_searcher
     (  
        .rst_i        ( rst_clk_serdes ),
        .clk_i        ( clk_serdes ),
        .data_i       ( serdes_symbol ),
        .disable_i    ( sync_b_clk_serdes ),
        .data_o       ( serdes_symbol_aligned ), 
        .stat_delay_o ( ) 
        );
   
   `endif   
`endif

   
jesd_lane_decode #(/*AUTOINSTPARAM*/
                 // Parameters
                 .NO_SERDES_WORDS       (NO_SERDES_WORDS)) 
  jesd_lane_decode (/*AUTOINST*/
  
  `ifndef BYPASS_8B10B  
                   .rxdata_k            (rxdata_k[03:0]),
                   .rxdisparity_err     (rxdisparity_err[3:0]),
                   .rxnot_in_table_err  (rxnot_in_table_err[3:0]),
  `endif
                   // Outputs
                   .rxdata              (rxdata[31:0]),
                   
                   .rxdata_vld          (rxdata_vld),
                   // Inputs
                   .clk_serdes          (clk_serdes),
                   .rst_clk_serdes      (rst_clk_serdes),
                   .clk_character       (clk_character),
                   .rst_clk_character   (rst_clk_character),
                   .inject_cgs_err (inject_cgs_err),
                   .inject_not_in_table_err (inject_not_in_table_err),
                   .inject_lane_alignment_err (inject_lane_alignment_err),
                   .inject_frame_alignment_err (inject_frame_alignment_err),                  
                   .serdes_symbol       (serdes_symbol_aligned));

jesd_lane_cgs_sm jesd_lane_cgs_sm (/*AUTOINST*/
                                 // Outputs
                                 .cgs_sync_req          (cgs_sync_req),
                                 // Inputs
                                 .comb_cgs_sync_req     (comb_cgs_sync_req),
                                 .clk_character         (clk_character),
                                 .rst_clk_character     (rst_clk_character),
                                 .rxdata                (rxdata[31:0]),
                                 .rxdata_k              (rxdata_k[03:0]),
                                 .rxdata_vld            (rxdata_vld),
                                 .rxdisparity_err       (rxdisparity_err[3:0]),
                                 .rxnot_in_table_err    (rxnot_in_table_err[3:0]),
                                 .enable_module         (txrx_enablemodule_reg));

jesd_lane_fs_sm jesd_lane_fs_sm (/*AUTOINST*/
                               // Outputs
                               .frame_data      (frame_data[31:0]),
                               .frame_data_k    (frame_data_k[03:0]),
                               .frame_data_vld  (frame_data_vld),
                               .lane_disparity_err (lane_disparity_err),
                               .lane_not_in_table_err (lane_not_in_table_err),
                               .mframe_symbol_err (mframe_symbol_err),
                               // Inputs                               
                               .clk_character   (clk_character),
                               .rst_clk_character(rst_clk_character),
                               .rxdata          (rxdata[31:0]),
                               .rxdata_k        (rxdata_k[03:0]),
                               .rxdata_vld      (rxdata_vld),
                               .rxdisparity_err (rxdisparity_err[3:0]),
                               .rxnot_in_table_err(rxnot_in_table_err[3:0]),
                               .mframe_length_char(mframe_length_char[10:0]),
                               .cgs_sync_req          (cgs_sync_req), 
                               .txrx_resync_on_comma_disable (txrx_resync_on_comma_disable),
                               .comb_cgs_sync_req(comb_cgs_sync_req)
                               );

jesd_lane_deskew #(/*AUTOINSTPARAM*/
                 // Parameters
                 .ASIZE                 (DESKEW_BUF_ASIZE),
                 .DSIZE                 (DESKEW_BUF_DSIZE))    
  jesd_lane_deskew (/*AUTOINST*/
                   // Outputs
                   .dskew_err           (dskew_err),
                   .underrun_err (underrun_err),
                   .overrun_err (overrun_err),

                   .dskew_frame_data    (dskew_frame_data[31:0]),
                   .dskew_frame_data_k  (dskew_frame_data_k[03:0]),
                   .dskew_frame_data_vld(dskew_frame_data_vld),
                   .sdpr_wr_addr        (deskew_wr_addr),
                   .sdpr_wr_en          (deskew_wr_en  ),
                   .sdpr_wr_data        (deskew_wr_data),
                   .sdpr_rd_addr        (deskew_rd_addr),
                   .sdpr_rd_en          (deskew_rd_en  ),
                   // Inputs
                   .clk_character       (clk_character),
                   .rst_clk_character   (rst_clk_character),
                   .frame_data          (frame_data[31:0]),
                   .frame_data_k        (frame_data_k[03:0]),
                   .frame_data_vld      (frame_data_vld),
                   .comb_cgs_sync_req   (comb_cgs_sync_req),
                   .subclass            (txrx_subclass_reg[2:0]),
                   .rbd_char_cnt        (rbd_char_cnt[10:0]),
                   .mf_len              (mframe_length_char[10:0]),
                   .comb_frame_data_vld (comb_frame_data_vld),
                   .lmfc_boundary       (lmfc_boundary),
                   .mf_is_long          (mf_is_long),
                   .sdpr_rd_data        (deskew_rd_data));

   wire [08:0]     txrx_ilas_length_mframe_int = txrx_ilas_length_mframe;
   
   jesd_rx_align_mon_char_rep jesd_rx_align_mon_char_rep(/*AUTOINST*/
                                                       // Outputs
                                                       .scr_data        (scr_data[31:0]),
                                                       .scr_data_eof    (scr_data_eof[03:0]),
                                                       .scr_data_eomf   (scr_data_eomf[03:0]),
                                                       .scr_data_sof    (scr_data_sof[03:0]),
                                                       .scr_data_somf   (scr_data_somf[03:0]),
                                                       .scr_byte_en     (scr_byte_en[03:0]),
                                                       .scr_data_vld    (scr_data_vld),
                                                       .user_data_valid_n    (user_data_valid_n[3:0]),
                                                       .decode_err           (decode_err[3:0]),
                                                       .unexpected_k_err     (unexpected_k_err_local[3:0]),
                                                       .mframe_alignment_err (mframe_alignment_err),
                                                       .frame_alignment_err  (frame_alignment_err), 
                                                       .ilas_restart         (), 
                                                       // Inputs
                                                       .clk_character   (clk_character),
                                                       .rst_clk_character(rst_clk_character),
                                                       .align_a_char_replace_en         (~txrx_lane_align_char_rep_disable),
                                                       .align_a_char_error_reporting_en (~txrx_lane_align_mon_disable),  
                                                       .ilas_en                         (~txrx_ilas_disable),
                                                       .scr_dis                         (~txrx_scr_reg),
                                                       .dskew_frame_data(dskew_frame_data[31:0]),
                                                       .dskew_frame_data_k(dskew_frame_data_k[03:0]),
                                                       .dskew_frame_data_vld(dskew_frame_data_vld),
                                                       .ilas_data_valid(ilas_data_valid[3:0]),
                                                       .ilas_length_mframe(txrx_ilas_length_mframe_int[1:0]),
                                                       .frame_length_char(frame_length_char[8:0]),
                                                       .mframe_length_char(mframe_length_char[10:0]));   
                                                       
 
                                                       
 jesd_jtspat_analyzer  jesd_jtspat_analyzer
 (
 //Inputs
                   .tx_rx_enable_jtspat_test       (txrx_enable_jtspat_test_reg),
                   .clk_character                  (clk_character),
                   .rst_clk_character              (rst_clk_character),
                   .jtspat_data                    (scr_data),
                   .jtspat_vld                     (scr_data_vld),
 //Outputs
                   .jtspat_err_count               (jtspat_err_count),
                   .jtspat_vld_count               (jtspat_vld_count)
 );
 

 
 jesd_prbs_15_analyzer jesd_prbs_15_analyzer(
 //inputs
                 .prbs_test_enable_reg            (prbs_test_enable_reg),
                 .clk_character                   (clk_character),
                 .rst_clk_character               (rst_clk_character),              
                 .prbs_data                       (scr_data),
                 .prbs_vld                        (scr_data_vld),
 //outputs
                 .prbs_vld_count                  (prbs_vld_count),
                 .prbs_err_count                  (prbs_err_count)
 );
 
   wire                 clk = clk_character;
   wire                 reset = rst_clk_character;
   wire [14:0]          seed = 15'h0;
   wire                 seed_vld =1'b0;
   
   
   jesd_dscrambler32 jesd_dscrambler32(/*AUTOINST*/
                                     // Outputs
                                     .unscr_data_vld    (unscr_data_vld),
                                     .unscr_data        (unscr_data[31:0]),
                                     .curr_lfsr         (),
                                     // Inputs
                                     .clk               (clk),
                                     .reset             (reset),
                                     .seed              (seed[14:0]),
                                     .seed_vld          (seed_vld),
                                     .scr_data_vld      (scr_data_vld),
                                     .scr_data          (scr_data[31:0]),
                                     .bypass_dscr       (~txrx_scr_reg));





jesd_ilas_monitor jesd_ilas_monitor
  (/*AUTOINST*/
   // Outputs
   .ilas_mismatch                       (ilas_mismatch),
   .ilas_data_valid                     (ilas_data_valid[03:00]),
   // Inputs
   .clk_character                       (clk_character),
   .rst_clk_character                   (rst_clk_character),
   .dskew_frame_data                    (dskew_frame_data[31:0]),
   .dskew_frame_data_k                  (dskew_frame_data_k[03:0]),
   .dskew_frame_data_vld                (dskew_frame_data_vld),
//   .frame_length_char                   (frame_length_char[7:0]),
   .mframe_length_char                  (mframe_length_char[10:0]),
   .ilas_length_mframe                  (txrx_ilas_length_mframe_int[8:0]),
   .ilas_en                             (~txrx_ilas_disable),
   .ilas_restart                        (ilas_restart),
   .ilas_error_reporting_en             (1'b1), // ilas_mismatch is gated with the disable signal in CSR module so locally tying the input
   .txrx_bank_id_reg                    (txrx_bank_id_reg[03:00]),
   .txrx_did_reg                        (txrx_did_reg[07:00]),

   .txrx_lid_reg                        (txrx_lid_reg[04:00]),

   .txrx_subclass_reg                   (txrx_subclass_reg[02:00]),
   .txrx_cf_reg                         (txrx_cf_reg[04:0]),
   .txrx_cs_reg                         (txrx_cs_reg[01:0]),
   .txrx_f_reg                          (txrx_f_reg[07:0]),
   .txrx_k_reg                          (txrx_k_reg[04:0]),
   .txrx_l_reg                          (txrx_l_reg[04:0]),
   .txrx_n_reg                          (txrx_n_reg[04:0]),
   .txrx_m_reg                          (txrx_m_reg[07:0]),
   .txrx_ntotal_reg                     (txrx_ntotal_reg[04:0]),
   .txrx_s_reg                          (txrx_s_reg[04:0]),
   .txrx_hd_reg                         (txrx_hd_reg[00:0]),
   .txrx_scr_reg                        (txrx_scr_reg[00:0]),
   .sum_ilas_com_param (sum_ilas_com_param),   
   .txrx_enablelinktest_reg             (txrx_enablelinktest_reg[01:0]));

   // adjust the latency of markers to align with that of the data which is passed through de-scrambling block
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         unscr_byte_en   <= 'h0;
         unscr_data_eof  <= 'h0;
         unscr_data_eomf <= 'h0;
         unscr_data_sof  <= 'h0;
         unscr_data_somf <= 'h0;
         unscr_user_data <= 'h0;
         unexpected_k_err  <= 1'b0;
      end
      else begin
         unscr_byte_en   <= scr_byte_en;
         unscr_data_eof  <= scr_data_eof;
         unscr_data_eomf <= scr_data_eomf;
         unscr_data_sof  <= scr_data_sof;
         unscr_data_somf <= scr_data_somf;
         unscr_user_data <= ~user_data_valid_n;     
         unexpected_k_err  <= | unexpected_k_err_local[3:0];      
      end
   end

   jesd_lane_ilas_filter #(
                          // Parameters
                          .LEADING_MARKERS      (1'b1))
   jesd_lane_ilas_filter(
                          // Outputs
                          .tport_byte_en        (tport_byte_en[3:0]),
                          .tport_data_eof       (tport_data_eof[3:0]),
                          .tport_data_eomf      (tport_data_eomf[3:0]),
                          .tport_data_sof       (tport_data_sof[3:0]),
                          .tport_data_somf      (tport_data_somf[3:0]),
                          .tport_data           (tport_data[31:0]),
                          .tport_data_vld       (tport_data_vld),
                          // Inputs
                          .clk_character        (clk_character),
                          .rst_clk_character    (rst_clk_character),
                          .unscr_byte_en        (unscr_byte_en[3:0]),
                          .unscr_data_eof       (unscr_data_eof[3:0]),
                          .unscr_data_eomf      (unscr_data_eomf[3:0]),
                          .unscr_data_sof       (unscr_data_sof[3:0]),
                          .unscr_data_somf      (unscr_data_somf[3:0]),
                          .unscr_data           (unscr_data[31:0]),
                          .unscr_data_vld       (unscr_data_vld),
                          .unscr_user_data      (unscr_user_data),
                          .bypass_dscr          (~txrx_scr_reg));


   jesd_test_pattern_monitor 
     jesd_test_pattern_monitor (
                               // Outputs
                               .incr_comma_frame_count (incr_comma_frame_count),
                               .incr_err_count    (incr_err_count),
                               // Inputs
                               .clk_character    (clk_character),
                               .rst_clk_character(rst_clk_character),
                               .rxdata           (rxdata[31:0]),
                               .rxdata_k         (rxdata_k[03:0]),
                               .rxdata_vld       (rxdata_vld),
                               .rxdisparity_err  (rxdisparity_err[3:0]),
                               .rxnot_in_table_err(rxnot_in_table_err[3:0]),
                               .scr_data_eof     (scr_data_eof[3:0]),
                               .test_mode        (txrx_enablelinktest_reg[01:0]));


     
   
endmodule // jesd_lane_rxdp

// Local Variables:
// verilog-library-directories:(".")
// End:
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
