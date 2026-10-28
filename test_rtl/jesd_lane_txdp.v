

// This is a wrapper module used to instantiated the per lane logic for processing transmit data stream.
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
`include "jesd_jesd204b_tx_defines.v"



module jesd_lane_txdp
  #(
   parameter RDY_TO_DATA_LATENCY=1, 
   parameter NO_SERDES_WORDS=1,
   parameter CTP_BUF_DSIZE=36   
   )
  (
                     
 input                             clk_character, // To jesd_char_rep of jesd_char_rep.v, ...
 input                             clk_serdes, // To jesd_lane_encode of jesd_lane_encode.v
 input                             rst_clk_character, // To jesd_char_rep of jesd_char_rep.v, ...
 input                             rst_clk_serdes, // To jesd_lane_encode of jesd_lane_encode.v
 input                             test_mode,         // test mode pin for bypassing generated resets in scan mode

 input                             active_lane, // To jesd_comma_gen of jesd_comma_gen.v
 input                             disable_eof_char_rep, // To jesd_char_rep of jesd_char_rep.v
 input                             disable_eomf_char_rep, // To jesd_char_rep of jesd_char_rep.v
 input                             disable_ilas_tx, // To jesd_ilas_gen of jesd_ilas_gen.v
 input [31:0]                      unscr_data, // To jesd_scrambler32 of jesd_scrambler32.v
 input                             unscr_data_vld, // To jesd_scrambler32 of jesd_scrambler32.v
 input [31:0]                      jspat_or_custom_data, // To jesd_lane_txarb of jesd_lane_txarb.v
 input [3:0]                       jspat_or_custom_data_k, // To jesd_lane_txarb of jesd_lane_txarb.v
 input                             jspat_or_custom_data_vld,
 input                             first_symbol_disparity,
 input                             start_cgs_tx_fw_req, // To jesd_comma_gen of jesd_comma_gen.v
 input                             start_cgs_tx_sync_dec, // To jesd_comma_gen of jesd_comma_gen.v   
 input                             lmfc_boundary,     // LMFC pulse
 
 input [3:0]                       txrx_bank_id_reg,
 input [4:0]                       txrx_cf_reg,
 input [1:0]                       txrx_cs_reg,
 input [7:0]                       txrx_did_reg,
 input [1:0]                       txrx_enablelinktest_reg,
 input [7:0]                       txrx_f_reg,
 input [0:0]                       txrx_hd_reg,
 input [4:0]                       txrx_k_reg,
 input [4:0]                       txrx_l_reg,
 input [4:0]                       txrx_lid_reg, // To jesd_ilas_monitor of jesd_ilas_monitor.v
 input [7:0]                       txrx_m_reg,
 input [4:0]                       txrx_n_reg,
 input [4:0]                       txrx_ntotal_reg,
 input [4:0]                       txrx_s_reg,
 input [0:0]                       txrx_scr_reg,
 input [2:0]                       txrx_subclass_reg,
 input [3:0]                       txrx_adjcnt_reg, // To jesd_ilas_gen of jesd_ilas_gen.v
 input                             txrx_adjdir_reg, // To jesd_ilas_gen of jesd_ilas_gen.v
 input                             txrx_phadj_reg, // To jesd_ilas_gen of jesd_ilas_gen.v
 input [7:0]                       sum_ilas_com_param,
 input [8:0]                       ilas_length_mframe, // To jesd_ilas_gen of jesd_ilas_gen.v
 input [6:0]                       sample_to_frame_delay,     // Variable delay between start_sample_if and first frame to be transmitted. Value depends on F, S, and clk_ratio
 input [8:0]                       frame_length_char, // To jesd_char_rep of jesd_char_rep.v, ...
 input [10:0]                      mframe_length_char, // To jesd_char_rep of jesd_char_rep.v, ...
 output                            start_sample_if,      // Signal to sample interface to start requesting samples
 output                            comma_data_vld,         // From jesd_comma_gen of jesd_comma_gen.v
 output                            jspat_or_custom_data_rdy,// From jesd_lane_txarb of jesd_lane_txarb.v   
 output                            unscr_data_rdy, // From jesd_tx_arb to hold off the popping of user data stream till CGS & ILAS transmission is almost over
`ifdef BYPASS_8B10B
 output [(8*NO_SERDES_WORDS)-1:0] serdes_symbol, // From jesd_lane_encode of jesd_lane_encode.v
 output [3:0]                     txdata_k,
`endif
`ifndef BYPASS_8B10B
 output [(10*NO_SERDES_WORDS)-1:0] serdes_symbol, // From jesd_lane_encode of jesd_lane_encode.v
`endif
 
 output                            serdes_symbol_vld      // From jesd_lane_encode of jesd_lane_encode.v
   );
   wire                            clk = clk_character;
   wire [1:0]                      subclass = txrx_subclass_reg[1:0];
   

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
wire [31:0]             comma_data;             // From jesd_comma_gen of jesd_comma_gen.v
wire [1:0]              comma_data_bc;          // From jesd_comma_gen of jesd_comma_gen.v
   wire [3:0]           comma_data_k;           // From jesd_comma_gen of jesd_comma_gen.v
wire                    comma_data_rdy;         // From jesd_lane_txarb of jesd_lane_txarb.v
wire [14:0]             curr_lfsr;              // From jesd_scrambler32 of jesd_scrambler32.v
wire [31:0]             ilas_data;              // From jesd_ilas_gen of jesd_ilas_gen.v
wire [1:0]              ilas_data_bc;           // From jesd_ilas_gen of jesd_ilas_gen.v
wire [3:0]              ilas_data_k;            // From jesd_ilas_gen of jesd_ilas_gen.v
wire                    ilas_data_rdy;          // From jesd_lane_txarb of jesd_lane_txarb.v
wire                    ilas_data_vld;          // From jesd_ilas_gen of jesd_ilas_gen.v
wire [15:0]             ilas_trail_bits;        // From jesd_ilas_gen of jesd_ilas_gen.v
wire [31:0]             process_data;           // From jesd_char_rep of jesd_char_rep.v
wire [3:0]              process_data_k;         // From jesd_char_rep of jesd_char_rep.v
wire                    process_data_vld;       // From jesd_char_rep of jesd_char_rep.v
wire [31:0]             scr_data;               // From jesd_scrambler32 of jesd_scrambler32.v
wire                    scr_data_vld;           // From jesd_scrambler32 of jesd_scrambler32.v
wire [31:0]             txdata;                 // From jesd_arb of jesd_lane_txarb.v
`ifndef BYPASS_8B10B
wire [3:0]              txdata_k;               // From jesd_lane_txarb of jesd_lane_txarb.v
`endif
wire                    txdata_vld;             // From jesd_lane_txarb of jesd_lane_txarb.v
// End of automatics

   reg                  unscr_data_rdy_r;

   
   always @(posedge clk_character or posedge rst_clk_character)
     if (rst_clk_character)
       unscr_data_rdy_r <= 1'b0;   
     else
       unscr_data_rdy_r <= unscr_data_rdy;
   
//   wire seed_vld = unscr_data_vld & unscr_data_rdy & !unscr_data_rdy_r; //Hooks are in place but may need tweeking
   wire                 seed_vld = 1'b0;
   
   wire                 valid_data_to_scr = (RDY_TO_DATA_LATENCY == 2) ? (unscr_data_vld & unscr_data_rdy_r)
                                             : unscr_data_vld & unscr_data_rdy;
   


   jesd_scrambler32    jesd_scrambler32 (
                    // Outputs
                    .scr_data_vld       (scr_data_vld),
                    .scr_data           (scr_data[31:0]),
                    .curr_lfsr          (curr_lfsr[14:0]),
                    // Inputs
                    .dis_scr            (!txrx_scr_reg),                   
                    .clk_character      (clk_character),
                    .rst_clk_character  (rst_clk_character),
                    .seed               (ilas_trail_bits[15:1]),
                    .seed_vld           (seed_vld),
                    .unscr_data_vld     (valid_data_to_scr),
                    .unscr_data         (unscr_data[31:0]));

   jesd_char_rep    jesd_char_rep (
                 // Outputs
                 .process_data          (process_data[31:0]),
                 .process_data_k        (process_data_k[3:0]),
                 .process_data_vld      (process_data_vld),
                 // Inputs
                 .clk_character         (clk_character),
                 .rst_clk_character     (rst_clk_character),
                 .unscr_data_rdy        (unscr_data_rdy),
                 .frame_length_char     (frame_length_char[8:0]),
                 .mframe_length_char    (mframe_length_char[10:0]),
                 .disable_eof_char_rep  (disable_eof_char_rep),
                 .disable_eomf_char_rep (disable_eomf_char_rep),
                 .dis_scr               (~txrx_scr_reg),
                 .scr_data              (scr_data[31:0]),
                 .scr_data_vld          (scr_data_vld));

   
   jesd_comma_gen jesd_comma_gen (
                  // Outputs
                  .comma_data           (comma_data[31:0]),
                  .comma_data_k         (comma_data_k[3:0]),
                  .comma_data_bc        (comma_data_bc[1:0]),
                  .comma_data_vld       (comma_data_vld),
                  // Inputs
                  .clk_character        (clk_character),
                  .rst_clk_character    (rst_clk_character),
                  .start_cgs_tx_sync_dec(start_cgs_tx_sync_dec),
                  .start_cgs_tx_fw_req  (start_cgs_tx_fw_req),
                  .subclass             (subclass[1:0]),
                  .active_lane          (active_lane),
                  .lmfc_boundary        (lmfc_boundary));

   jesd_ilas_gen    jesd_ilas_gen (
                 // Outputs
                 .start_sample_if       (start_sample_if),
                 .ilas_data             (ilas_data[31:0]),
                 .ilas_data_k           (ilas_data_k[3:0]),
                 .ilas_data_bc          (ilas_data_bc[1:0]),
                 .ilas_data_vld         (ilas_data_vld),
                 .ilas_trail_bits       (ilas_trail_bits[15:0]),
                 // Inputs
                 .clk_character         (clk_character),
                 .rst_clk_character     (rst_clk_character),
                 .mframe_length_char    (mframe_length_char[10:0]),
                 .ilas_length_mframe    (ilas_length_mframe),
                 .sample_to_frame_delay (sample_to_frame_delay),
                 .txrx_bank_id_reg      (txrx_bank_id_reg[3:0]),
                 .txrx_cf_reg           (txrx_cf_reg[4:0]),
                 .txrx_cs_reg           (txrx_cs_reg[1:0]),
                 .txrx_did_reg          (txrx_did_reg[7:0]),
                 .txrx_enablelinktest_reg(txrx_enablelinktest_reg[1:0]),
                 .txrx_f_reg            (txrx_f_reg[7:0]),
                 .txrx_hd_reg           (txrx_hd_reg[0:0]),
                 .txrx_k_reg            (txrx_k_reg[4:0]),
                 .txrx_l_reg            (txrx_l_reg[4:0]),
                 .txrx_lid_reg          (txrx_lid_reg[4:0]),               
                 .txrx_m_reg            (txrx_m_reg[7:0]),
                 .txrx_n_reg            (txrx_n_reg[4:0]),
                 .txrx_ntotal_reg       (txrx_ntotal_reg[4:0]),
                 .txrx_s_reg            (txrx_s_reg[4:0]),
                 .txrx_scr_reg          (txrx_scr_reg[0:0]),
                 .txrx_subclass_reg     (txrx_subclass_reg[2:0]),
                 .txrx_adjcnt_reg       (txrx_adjcnt_reg[3:0]),
                 .txrx_adjdir_reg       (txrx_adjdir_reg),
                 .txrx_phadj_reg        (txrx_phadj_reg),
                 .sum_ilas_com_param (sum_ilas_com_param),                                 
                 .disable_ilas_tx       (disable_ilas_tx),
                 .halt_or_reset_non_cgs_stream(comma_data_vld),
                 .ilas_data_rdy         (ilas_data_rdy));


   jesd_lane_txarb    jesd_lane_txarb (
                   // Outputs
                   .txdata              (txdata[31:0]),
                   .txdata_k            (txdata_k[3:0]),
                   .txdata_vld          (txdata_vld),
                   .jspat_or_custom_data_rdy(jspat_or_custom_data_rdy),
                   .comma_data_rdy      (comma_data_rdy),
                   .ilas_data_rdy       (ilas_data_rdy),
                   .unscr_data_rdy      (unscr_data_rdy),
                   // Inputs
                   .clk_character       (clk_character),
                   .rst_clk_character   (rst_clk_character),
                   .test_mode           (test_mode),
                   .jspat_or_custom_data(jspat_or_custom_data[31:0]),
                   .jspat_or_custom_data_k(jspat_or_custom_data_k[3:0]),
                   .jspat_or_custom_data_vld(jspat_or_custom_data_vld),
                   .comma_data          (comma_data[31:0]),
                   .comma_data_k        (comma_data_k[3:0]),
                   .comma_data_bc       (comma_data_bc[1:0]),
                   .comma_data_vld      (comma_data_vld),
                   .ilas_data           (ilas_data[31:0]),
                   .ilas_data_k         (ilas_data_k[3:0]),
                   .ilas_data_bc        (ilas_data_bc[1:0]),
                   .ilas_data_vld       (ilas_data_vld),
                   .process_data        (process_data[31:0]),
                   .process_data_k      (process_data_k[3:0]),
                   .process_data_vld    (process_data_vld));
   
   jesd_lane_encode #(
                     // Parameters
                     .NO_SERDES_WORDS   (NO_SERDES_WORDS))
   jesd_lane_encode (
   
                    
   
                   // Outputs
                    .serdes_symbol      (serdes_symbol),
                    .serdes_symbol_vld  (serdes_symbol_vld),
                    // Inputs
                    .clk_serdes         (clk_serdes),
                    .rst_clk_serdes     (rst_clk_serdes),
                    .clk_character      (clk_character),
                    .rst_clk_character  (rst_clk_character),
                    .first_symbol_disparity (first_symbol_disparity),                    
                    .txdata             (txdata[31:0]),
                    .txdata_k           (txdata_k[03:0]),
                    .txdata_vld         (1'b1));

   
endmodule // jesd_lane_txdp


// Local Variables:
// verilog-library-directories:("." "../rx")
// End:
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
