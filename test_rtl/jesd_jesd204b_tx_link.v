

// This file contatins the definition of module 'jesd_jesd204b_tx_link' . This module serves as stand alone link layer implementation of JESD204B spec
// depending on the presence of define TX_LINK_TOP one can choose the content of the port list. In case of standalone operation the latency from
// tframe_data_rdy to tframe_data is 1 clock but in case when it is used in combination with transport layer this latency is assumed to be 2 clocks
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
  `include "jesd_jesd204b_tx_defines.v" 


  
module jesd_jesd204b_tx_link
  #(
    //! Will be used to match slave_addr[31:24]    
   parameter JESD_CSR_SELECT_MASK=24'h001,
   //! User defined parameter. Legal values 1 to 8
    parameter JESD_NO_LANES=6,              
   //! User defined parameter. Legal values 1 to 8
    parameter JESD_NO_CONVERTERS=4,              
   //! User defined parameter to indicate serdes data path width in terms of 10 bit symbols . Valid values are 1,2,4
    parameter JESD_NO_SERDES_WORDS=4       
   )
  (
    //!Clock used by the CPU interface to access Control and Status Registers (CSR)
   input                                              clk_cpu, 
    //! clock used for data path and control logic
   input                                              clk_character,
    //! Clock used for serdes interface. Maybe 1xclk_character or 2xclk_character or 4xclk_character 
   input                                              clk_serdes, 
    //!Active High Reset, de-assertion is aligned to clk_cpu
   input                                              reset_csr, 
    //! Active High Reset, de-assertion is aligned to clk_cpu
   input                                              reset_core, 

   // test mode pin for bypassing generated resets in scan mode
   input                                              test_mode,

    //! Frame Synchronization interface signals aligned to frame_clk domain

    //! Combined sync_b signal from  all lanes connected to a single DAC device. 
   input                                              sync_b, 

    //! Synchronization interface signal aligned to clk_character domain.sysref is used for aligning LMFC when operating in subclass 1 mode.
   input                                              sysref, 

    `ifdef BYPASS_8B10B  
   output [8*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0]  serdes_data_o, 
   output [4*JESD_NO_LANES-1:0]                       txdata_k,
     `endif
     `ifndef BYPASS_8B10B  
   output [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_o, 
    `endif
   output [JESD_NO_LANES-1:0]                         serdes_data_vld,
    
`ifdef AXI_BUS  
    input                                             slave_write, 
   input                                              slave_read, 
   input [31:0]                                       slave_write_data,
   input [31:0]                                       slave_addr, 
   output                                             slave_ack, 
   output [31:0]                                      slave_read_data, 
      
   `endif
   
`ifdef APB_BUS
   input [31:0]         paddr,
   input                pwrite,
   input                psel,
   input                penable,
   input [31:0]         pwdata,
   output               pready,
   output [31:0]        prdata,
`endif

`ifdef AVALON_BUS
   input [31:0]       address,
   input              write,
   input              read,
   output             waitrequest,
   output [31:0]     readdata,
   input  [31:0]     writedata, 
`endif

`ifdef I2C_IF
   input [7:0]       rf_addr,
   input             rf_wen,
   input             rf_ren,
   output [31:0]     rf_rdata,
   input  [31:0]     rf_wdata, 
`endif


`ifdef TX_EXTERNAL_REGS
  output [3:0]              txrx_adjcnt_reg,        // From jesd_tx_core_register of jesd_tx_core_register.v
  output                    txrx_adjdir_reg,        // From jesd_tx_core_register of jesd_tx_core_register.v
  output [3:0]              txrx_bank_id_reg,       // From jesd_tx_core_register of jesd_tx_core_register.v
  output [4:0]              txrx_cf_reg,            // From jesd_tx_core_register of jesd_tx_core_register.v
  output [1:0]              txrx_cs_reg,            // From jesd_tx_core_register of jesd_tx_core_register.v
  output [7:0]              txrx_did_reg,           // From jesd_tx_core_register of jesd_tx_core_register.v
  output [1:0]              txrx_enablelinktest_reg,// From jesd_tx_core_register of jesd_tx_core_register.v
  output [7:0]              txrx_f_reg,             // From jesd_tx_core_register of jesd_tx_core_register.v
  output [0:0]              txrx_hd_reg,            // From jesd_tx_core_register of jesd_tx_core_register.v
  output [4:0]              txrx_k_reg,             // From jesd_tx_core_register of jesd_tx_core_register.v
  output [4:0]              txrx_l_reg,             // From jesd_tx_core_register of jesd_tx_core_register.v
  output [7:0]              txrx_m_reg,             // From jesd_tx_core_register of jesd_tx_core_register.v
  output [4:0]              txrx_n_reg,             // From jesd_tx_core_register of jesd_tx_core_register.v
  output [4:0]              txrx_ntotal_reg,        // From jesd_tx_core_register of jesd_tx_core_register.v
  output                    txrx_phadj_reg,         // From jesd_tx_core_register of jesd_tx_core_register.v
  output [4:0]              txrx_s_reg,             // From jesd_tx_core_register of jesd_tx_core_register.v
  output [0:0]              txrx_scr_reg,           // From jesd_tx_core_register of jesd_tx_core_register.v
  output [2:0]              txrx_subclass_reg,      // From jesd_tx_core_register of jesd_tx_core_register.v
`endif    

   output                                            slave_interrupt,
   output [8:0]                                      frame_length_char,   
   


   input [32*JESD_NO_LANES-1:0]                      tframe_data,
   input                                             tframe_data_vld,   
   output                                            tframe_data_rdy

   
   
`ifndef TX_LINK_TOP
   // Transport layer parameters from csr
  // `ifndef LANE_LONG
     // ,output [29:00]     txrx_lid_reg,// Information to transport layer to help it remap a physical lane on to a differnt logical lane before reassembly of the frame.
  // `endif 

  // `ifdef LANE_LONG
     // ,output [119:00]     txrx_lid_reg,
  // `endif 
   ,output [5*JESD_NO_LANES-1:00]                   txrx_lid_reg,
   output                                           start_sample_if,
   output [JESD_NO_LANES-1:0]                       active_lane,
   output [JESD_NO_CONVERTERS-1:0]                  active_conv,
   output [42:0]                                    tl_spec_param,
   output  [1:0]                                    clk_ratio,              // Ratio of clk_character to clk_sample: "00": 1:1, "01": 1:2, "10": 1:4
   output                                           txrx_enablemodule_reg,
   input                                            clk_sample,
   output [2:0]                                     generated_resets
`endif
   );

`ifdef TX_LINK_TOP
    // Transport layer parameters from csr
  // `ifndef LANE_LONG
    // wire [29:00]                           txrx_lid_reg;
  // `endif 
  // `ifdef LANE_LONG
    // wire [119:00]                          txrx_lid_reg;
  // `endif 
  wire [5*JESD_NO_LANES-1:00]                      txrx_lid_reg;
  wire                                             start_sample_if;
  wire [JESD_NO_LANES-1:0]                         active_lane;
  wire [JESD_NO_CONVERTERS-1:0]                    active_conv;
  wire [42:0]                                      tl_spec_param;
  wire  [1:0]                                      clk_ratio;              // Ratio of clk_character to clk_sample: "00": 1:1, "01": 1:2, "10": 1:4
  wire                                             txrx_enablemodule_reg;
  wire [2:0]                                       generated_resets;
  wire                                             clk_sample;
`endif

  wire [JESD_NO_LANES-1:0]                          unscr_data_rdy,jspat_or_custom_data_rdy;
  wire unscr_data_vld_int;
  wire [32*JESD_NO_LANES-1:0]                      tframe_data_int;
  assign tframe_data_int = tframe_data_vld ? tframe_data : 'h0;
  assign unscr_data_vld_int = tframe_data_vld ? tframe_data_vld : unscr_data_rdy[0];
  assign tframe_data_rdy = unscr_data_rdy[0];

   
`ifdef BYPASS_8B10B  
   localparam temp_width=8*JESD_NO_SERDES_WORDS;
`endif
    
`ifndef BYPASS_8B10B  
   localparam temp_width=10*JESD_NO_SERDES_WORDS;
`endif
   
   localparam temp_width_m1=temp_width-1; 

   localparam RDY_TO_DATA_LATENCY = 1;

   localparam NO_SERDES_WORDS=JESD_NO_SERDES_WORDS;
   localparam NO_LANES=JESD_NO_LANES;
   localparam CTP_BUF_ASIZE=5;
   localparam CTP_BUF_DSIZE=36;
   localparam CSR_SELECT_MASK=JESD_CSR_SELECT_MASK;


// `ifndef LANE_LONG
    // wire [7:0]                             prbs_test_enable_reg;   
// `endif
// `ifdef LANE_LONG
    // wire [23:0]                            prbs_test_enable_reg;
// `endif
    wire [JESD_NO_LANES-1:0]                            prbs_test_enable_reg;
/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire                 disable_eomf_char_rep;
  wire                 disable_ilas_tx;
  wire [CTP_BUF_DSIZE-1:0]                          jspat_data;             // To jesd_ctp_gen of jesd_ctp_gen.v
  wire              start_cgs_tx_sync_dec_clk_char,start_cgs_tx_fw_req_clk_char;
  wire [7:0]              sum_ilas_com_param;   
  wire                    captured_sync_lh_ph_info;// From jesd_sync_decode of jesd_sync_decode.v
  wire                    error_decoded_on_sync;  // From jesd_sync_decode of jesd_sync_decode.v
  wire [5:0]              frame_clks_sync_lh_to_next_lmfc_boundary;// From jesd_sync_decode of jesd_sync_decode.v
  //wire                    random_error_detected;  // From jesd_sync_decode of jesd_sync_decode.v
  wire [8:0]              ilas_length_mframe;     // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [6:0]               sample_to_frame_delay;     // Variable delay between start_sample_if and first frame to be transmitted. Value depends on F, S, and clk_ratio
  wire [CTP_BUF_ASIZE-1:0] jspat_addr_offset;     // From jesd_ctp_gen of jesd_ctp_gen.v
  wire [31:0]              jspat_or_custom_data;   // From jesd_ctp_gen of jesd_ctp_gen.v
  wire [1:0]               jspat_or_custom_data_bc;// From jesd_ctp_gen of jesd_ctp_gen.v
  wire [3:0]               jspat_or_custom_data_k; // From jesd_ctp_gen of jesd_ctp_gen.v
  wire                     jspat_or_custom_data_vld;// From jesd_ctp_gen of jesd_ctp_gen.v
  wire                     jspat_test_enable_reg;  // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [15:0]              linktest_custom_data_reg;// From jesd_tx_core_register of jesd_tx_core_register.v
  wire                     linktest_custom_enable_reg;// From jesd_tx_core_register of jesd_tx_core_register.v
  wire [10:0]              mframe_length_char;     // From jesd_tx_core_register of jesd_tx_core_register.v
  wire                     rst_clk_character;      // From jesd_jesd204b_rst_gen of jesd_jesd204b_rst_gen.v
  wire                     rst_clk_sample;         // From jesd_jesd204b_rst_gen of jesd_jesd204b_rst_gen.v
  wire                     rst_clk_serdes;         // From jesd_jesd204b_rst_gen of jesd_jesd204b_rst_gen.v
  wire                     start_cgs_tx_fw_req;    // From jesd_tx_core_register of jesd_tx_core_register.v
  wire                     start_cgs_tx_sync_dec;  // From jesd_sync_decode of jesd_sync_decode.v
  wire                     first_symbol_disparity;
  wire [JESD_NO_LANES-1:0] start_sample_if_ln;
  wire                     lmfc_boundary;

`ifndef TX_EXTERNAL_REGS
  wire [3:0]              txrx_adjcnt_reg;        // From jesd_tx_core_register of jesd_tx_core_register.v
  wire                    txrx_adjdir_reg;        // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [3:0]              txrx_bank_id_reg;       // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [4:0]              txrx_cf_reg;            // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [1:0]              txrx_cs_reg;            // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [7:0]              txrx_did_reg;           // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [1:0]              txrx_enablelinktest_reg;// From jesd_tx_core_register of jesd_tx_core_register.v
  wire [7:0]              txrx_f_reg;             // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [0:0]              txrx_hd_reg;            // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [4:0]              txrx_k_reg;             // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [4:0]              txrx_l_reg;             // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [7:0]              txrx_m_reg;             // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [4:0]              txrx_n_reg;             // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [4:0]              txrx_ntotal_reg;        // From jesd_tx_core_register of jesd_tx_core_register.v
  wire                    txrx_phadj_reg;         // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [4:0]              txrx_s_reg;             // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [0:0]              txrx_scr_reg;           // From jesd_tx_core_register of jesd_tx_core_register.v
  wire [2:0]              txrx_subclass_reg;      // From jesd_tx_core_register of jesd_tx_core_register.v
`endif 
// End of automatics

   
   jesd_ctp_rom  #(
                  // Parameters
                  .DSIZE                (CTP_BUF_DSIZE),
                  .ASIZE                (CTP_BUF_ASIZE))
   jesd_ctp_rom  (
                  // Outputs
                  .rd_data              (jspat_data),
                  // Inputs
                  .clk                  (clk_character),
                  .rst                  (rst_clk_character),
                  .rd_addr              (jspat_addr_offset),
                  .rd_en                (1'b1));
   
                  
   jesd_ctp_gen #(
                 // Parameters
                 .CTP_BUF_ASIZE         (CTP_BUF_ASIZE),
                 .CTP_BUF_DSIZE         (CTP_BUF_DSIZE))
   jesd_ctp_gen (
                // Outputs
                .jspat_addr_offset      (jspat_addr_offset[CTP_BUF_ASIZE-1:0]),
                .jspat_or_custom_data   (jspat_or_custom_data[31:0]),
                .jspat_or_custom_data_k (jspat_or_custom_data_k[3:0]),
                .jspat_or_custom_data_bc(jspat_or_custom_data_bc[1:0]),
                .jspat_or_custom_data_vld(jspat_or_custom_data_vld),
                // Inputs
                .clk_character          (clk_character),
                .rst_clk_character      (rst_clk_character),
                .custom_test_enable     (linktest_custom_enable_reg),
                .custom_test_data       (linktest_custom_data_reg),
                .prbs_test_enable_reg   (prbs_test_enable_reg[0]),
                .jspat_data             (jspat_data),
                .jspat_length_char      (7'd120),
                .jspat_enable           (jspat_test_enable_reg),
                .jspat_or_custom_data_rdy(jspat_or_custom_data_rdy[0]));//this block can be implemented for each lane if required

   jesd_jesd204b_rst_gen jesd_jesd204b_rst_gen(
                        // Outputs
                        .rst_clk_character(rst_clk_character),
                        .rst_clk_serdes (rst_clk_serdes),
                        .rst_clk_sample (rst_clk_sample),
                        // Inputs
                        .clk_serdes     (clk_serdes),
                        .clk_character  (clk_character),
`ifdef TX_LINK_TOP
                        .clk_sample     (1'b0),
`endif          
`ifndef TX_LINK_TOP
                        .clk_sample     (clk_sample),
`endif          
                        .clk_cpu        (clk_cpu),
                        .reset_core     (reset_core),
                        .test_mode      (test_mode),
                        .enable_module  (txrx_enablemodule_reg));


   jesd_tx_core_register #(/*AUTOINSTPARAM*/
                          // Parameters
                          .NO_LANES             (NO_LANES),
                          .NO_CONVERTERS        (JESD_NO_CONVERTERS),
                          .CSR_SELECT_MASK      (CSR_SELECT_MASK))
   jesd_tx_core_register  (
    `ifdef APB_BUS
   //Outputs in the APB_bus
                          .paddr(paddr),
                          .pwrite (pwrite),
                          .psel (psel),
                          .penable (penable),
                          .pwdata(pwdata),

   //Inputs in the APB bus
                          .pready(pready),
                          .prdata (prdata),
   
      
   `endif
`ifdef AVALON_BUS
                        .address     (address),
                        .write       (write),
                        .read        (read),
                        .waitrequest (waitrequest),
                        .readdata    (readdata),
                        .writedata   (writedata),
`endif
`ifdef I2C_IF
                        .rf_addr     (rf_addr),
                        .rf_wen      (rf_wen),
                        .rf_ren      (rf_ren),
                        .rf_rdata    (rf_rdata),
                        .rf_wdata    (rf_wdata), 
`endif

   
`ifdef AXI_BUS
                          //Outputs in the AXI bus
                          .s_read_dbus          (slave_read_data[31:0]),
                          .s_ack                (slave_ack),

                          //Inputs in the AXI bus
                          .s_abus               (slave_addr[31:0]),
                          .s_write              (slave_write),
                          .s_read               (slave_read),
                          .s_write_dbus         (slave_write_data[31:0]),
   
`endif
                          // Outputs

                          .s_interrupt          (slave_interrupt),
                          .mframe_length_char   (mframe_length_char[10:0]),
                          .frame_length_char    (frame_length_char[8:0]),
                          .txrx_bank_id_reg     (txrx_bank_id_reg[03:00]),
                          .txrx_did_reg         (txrx_did_reg[07:00]),
// `ifdef LANE_LONG
                          // .txrx_lid_reg         (txrx_lid_reg[119:00]),
// `endif
// `ifndef LANE_LONG
                          // .txrx_lid_reg         (txrx_lid_reg[29:00]),
// `endif 
                          .txrx_lid_reg         (txrx_lid_reg),
                          .active_lane          (active_lane),
                          .active_conv          (active_conv),
                          .txrx_subclass_reg    (txrx_subclass_reg[02:00]),
                          .txrx_cf_reg          (txrx_cf_reg[04:0]),
                          .txrx_cs_reg          (txrx_cs_reg[01:0]),
                          .txrx_f_reg           (txrx_f_reg[07:0]),
                          .txrx_k_reg           (txrx_k_reg[04:0]),
                          .txrx_l_reg           (txrx_l_reg[04:0]),
                          .txrx_n_reg           (txrx_n_reg[04:0]),
                          .txrx_m_reg           (txrx_m_reg[07:0]),
                          .txrx_ntotal_reg      (txrx_ntotal_reg[04:0]),
                          .txrx_s_reg           (txrx_s_reg[04:0]),
                          .txrx_hd_reg          (txrx_hd_reg[00:0]),
                          .txrx_scr_reg         (txrx_scr_reg[00:0]),
                          .txrx_enablemodule_reg(txrx_enablemodule_reg),
                          .txrx_enablelinktest_reg(txrx_enablelinktest_reg[01:0]),
                          .txrx_adjcnt_reg      (txrx_adjcnt_reg[3:0]),
                          .txrx_adjdir_reg      (txrx_adjdir_reg),
                          .txrx_phadj_reg       (txrx_phadj_reg),
                          .start_cgs_tx_fw_req  (start_cgs_tx_fw_req),
                          .ilas_length_mframe   (ilas_length_mframe[8:0]),
                          .sample_to_frame_delay(sample_to_frame_delay),
                          .linktest_custom_data_reg(linktest_custom_data_reg[15:0]),
                          .linktest_custom_enable_reg(linktest_custom_enable_reg),
                          .jspat_test_enable_reg(jspat_test_enable_reg),
                          .prbs_test_enable_reg (prbs_test_enable_reg),
                          .disable_eomf_char_rep(disable_eomf_char_rep),
                          .disable_ilas_tx      (disable_ilas_tx),
                          .first_symbol_disparity (first_symbol_disparity),                                               
                          .sum_ilas_com_param   (sum_ilas_com_param),
                          .tl_spec_param        (tl_spec_param),
                          .clk_ratio            (clk_ratio),
                          // Inputs
                          .clk_cpu              (clk_cpu),
                          .rst                  (reset_csr),

                          .frame_clks_sync_lh_to_next_lmfc_boundary(frame_clks_sync_lh_to_next_lmfc_boundary[5:0]),
                          .captured_sync_lh_ph_info(captured_sync_lh_ph_info),
                          .error_decoded_on_sync(error_decoded_on_sync),
                          .start_cgs_tx_sync_dec(start_cgs_tx_sync_dec),
//                        .random_error_detected(random_error_detected),
                          .underrun_err         (1'b0),
                          .overrun_err          (1'b0));
   


   jesd_sync_decode  #(/*AUTOINSTPARAM*/
                      // Parameters
                      .NO_LANES         (NO_LANES))
   jesd_sync_decode (/*AUTOINST*/
                    // Outputs
                    .frame_clks_sync_lh_to_next_lmfc_boundary(frame_clks_sync_lh_to_next_lmfc_boundary[5:0]),
                    .captured_sync_lh_ph_info (captured_sync_lh_ph_info),
                    .start_cgs_tx_sync_dec    (start_cgs_tx_sync_dec),
                    .error_decoded_on_sync    (error_decoded_on_sync),
                    .lmfc_boundary            (lmfc_boundary),

                    // Inputs
                    .num_k              (txrx_k_reg[4:0]),
                    .txrx_f_reg         (txrx_f_reg),
                    .mf_len             (mframe_length_char[10:0]),
                    .sync_b             (sync_b),
                    .txrx_subclass_reg  (txrx_subclass_reg[1:0]),
                    .clk_character      (clk_character),
                    .rst_clk_character  (rst_clk_character),
                    .sysref             (sysref));

    
   wire [JESD_NO_LANES-1:0] comma_data_vld;
   
   assign start_sample_if = (start_sample_if_ln != 0);

   genvar ln_cnt;
   generate for (ln_cnt = 0; ln_cnt < JESD_NO_LANES; ln_cnt = ln_cnt + 1) begin : lane_generate
      
      jesd_lane_txdp #(
                      // Parameters
                      .RDY_TO_DATA_LATENCY(RDY_TO_DATA_LATENCY),
                      .NO_SERDES_WORDS  (NO_SERDES_WORDS),
                      .CTP_BUF_DSIZE    (CTP_BUF_DSIZE))                      
      jesd_lane_txdp (
                     // Outputs
                     .start_sample_if   (start_sample_if_ln[ln_cnt]),
                     .serdes_symbol     (serdes_data_o[(ln_cnt*temp_width)+temp_width_m1:ln_cnt*temp_width]),
                     .serdes_symbol_vld (serdes_data_vld[ln_cnt]),
                     .jspat_or_custom_data_rdy(jspat_or_custom_data_rdy[ln_cnt]),
                     .unscr_data_rdy    (unscr_data_rdy[ln_cnt]),  
                     .comma_data_vld    (comma_data_vld[ln_cnt]),
`ifdef BYPASS_8B10B                
                     .txdata_k          (txdata_k[ln_cnt*4+3:ln_cnt*4]),
`endif                         
                     // Inputs
                     .clk_character              (clk_character),
                     .clk_serdes                 (clk_serdes),
                     .rst_clk_character          (rst_clk_character),
                     .rst_clk_serdes             (rst_clk_serdes),
                     .test_mode                  (test_mode),
                     .start_cgs_tx_sync_dec      (start_cgs_tx_sync_dec_clk_char),
                     .unscr_data                 (tframe_data_int[31+(32*ln_cnt):32*ln_cnt]),
                     .unscr_data_vld             (unscr_data_vld_int),
                     .jspat_or_custom_data       (jspat_or_custom_data[31:0]),
                     .jspat_or_custom_data_k     (jspat_or_custom_data_k[3:0]),
                     .jspat_or_custom_data_vld   (jspat_or_custom_data_vld),                     
                     .disable_eof_char_rep       (1'b0),
                     .disable_eomf_char_rep      (disable_eomf_char_rep),
                     .disable_ilas_tx            (disable_ilas_tx),
                     .active_lane                (active_lane[ln_cnt]),
                     .sum_ilas_com_param         (sum_ilas_com_param),
                     .first_symbol_disparity     (first_symbol_disparity),                     
                     .txrx_bank_id_reg           (txrx_bank_id_reg[3:0]),
                     .txrx_cf_reg                (txrx_cf_reg[4:0]),
                     .txrx_cs_reg                (txrx_cs_reg[1:0]),
                     .txrx_did_reg               (txrx_did_reg[7:0]),
                     .txrx_enablelinktest_reg    (txrx_enablelinktest_reg[1:0]),
                     .txrx_f_reg                 (txrx_f_reg[7:0]),
                     .txrx_hd_reg                (txrx_hd_reg[0:0]),
                     .txrx_k_reg                 (txrx_k_reg[4:0]),
                     .txrx_l_reg                 (txrx_l_reg[4:0]),
                     .txrx_lid_reg               (txrx_lid_reg[4+ln_cnt*5:ln_cnt*5]),
                     .txrx_m_reg                 (txrx_m_reg[7:0]),
                     .txrx_n_reg                 (txrx_n_reg[4:0]),
                     .txrx_ntotal_reg            (txrx_ntotal_reg[4:0]),
                     .txrx_s_reg                 (txrx_s_reg[4:0]),
                     .txrx_scr_reg               (txrx_scr_reg[0:0]),
                     .txrx_subclass_reg          (txrx_subclass_reg[2:0]),
                     .txrx_adjcnt_reg            (txrx_adjcnt_reg[3:0]),
                     .txrx_adjdir_reg            (txrx_adjdir_reg),
                     .txrx_phadj_reg             (txrx_phadj_reg),
                     .start_cgs_tx_fw_req        (start_cgs_tx_fw_req_clk_char),
                     .ilas_length_mframe         (ilas_length_mframe[8:0]),
                     .sample_to_frame_delay      (sample_to_frame_delay),
                     .frame_length_char          (frame_length_char[8:0]),
                     .lmfc_boundary              (lmfc_boundary),
                     .mframe_length_char         (mframe_length_char[10:0]));
   end endgenerate

// Use single synchronizer per source of sync request to feed the logic of all lanes and thus avoid possibility of skew insertion in internal TX path  
   jesd_simple_sync #(.REG_IP(0))
   sync_decode_sync (
    .src_signal  (start_cgs_tx_sync_dec),
    .src_clk    (1'b0),
    .dest_clk   (clk_character), 
    .dest_signal (start_cgs_tx_sync_dec_clk_char)
   );


   jesd_simple_sync #(.REG_IP(0))
   fw_req_sync(
    .src_signal  (start_cgs_tx_fw_req),
    .src_clk    (1'b0),
    .dest_clk   (clk_character), 
    .dest_signal (start_cgs_tx_fw_req_clk_char)
   );

   
   assign generated_resets = {rst_clk_character,rst_clk_serdes,rst_clk_sample};        
   
endmodule // jesd_jesd204b_tx_link

// Local Variables:
// verilog-library-directories:("." "../rx")
// End:
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
