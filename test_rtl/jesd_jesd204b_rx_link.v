

// This file contatins the definition of module 'jesd_jesd204b_rx_link' . This module serves as stand alone link layer implementation of JESD204B spec
// depending on the presence of define RX_LINK_TOP one can choose the content of the port list.
// Pending modification RAMS used to buffer data for lane deskew logic need to be pulled up to top level.

//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
`include "jesd_jesd204b_rx_defines.v" 



module jesd_jesd204b_rx_link
  #(parameter JESD_MAST_INST=1,              //! Used in subclass2 mode to synchronize local LMFC of multiple RX instances
    parameter JESD_DESKEW_BUF_ASIZE=8,       //! Address size of lane alignment buffer. DEPTH is calculated using ASIZE
    parameter JESD_DESKEW_BUF_DSIZE=36,      //! Data width of lane alignment buffer.
    parameter JESD_CSR_SELECT_MASK=22'h000,  //! Will be used to match slave_addr[31:10]
    parameter JESD_NO_LANES=8,               //! User defined parameter. Legal values 1 to 8
    parameter JESD_NO_CONVERTERS=8,          //! User defined parameter. Legal values 1 to 8
    parameter JESD_NO_SERDES_WORDS=4         //! User defined parameter to indicate serdes data path width in terms of 10 bit symbols . Valid values are 1,2,4
    )
   (
    input                                           clk_cpu, //!Clock used by the CPU interface to access Control and Status Registers (CSR)
    input                                           clk_character,//! clock used for data path and control logic
    input [JESD_NO_LANES-1:0]                       clk_serdes, //! Clock used for serdes interface. Maybe 1xclk_character or 2xclk_character or 4xclk_character 
    input                                           reset_csr, //!Active High Reset, de-assertion is aligned to clk_cpu
    input                                           reset_core, //! Active High Reset, de-assertion is aligned to clk_cpu

    // test mode pin for bypassing generated resets in scan mode
    input                                            test_mode,

    //! Synchronization interface signals aligned to frame_clk domain
    output                                          sync_b, //! Combined sync_b signal from  all lanes connected to a single ADC device. 
    input                                           lmfc_div2_i, //! Used if JESD_MAST_INST=0
    output                                          lmfc_div2_o, //! Generated if JESD_MAST_INST=1
    
    //! Synchronization interface signals aligned to clk_character 
    input                                           sysref, //! Signal used for aligning LMFC when operating in subclass 1 mode.

    
`ifndef BYPASS_8B10B  
    //! Serdes RX Interface signals aligned to clk_serdes
    input [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i,//! Encoded symbol data of all lanes
`endif
  
    //Decode bypass signals. Decoder control signals  
`ifdef BYPASS_8B10B  
    input [8*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0]  serdes_data_i,//! Encoded symbol data of all lanes
    input [(4*JESD_NO_LANES)-1:0]                     rxdata_k,
    input [(4*JESD_NO_LANES)-1:0]                     rxdisparity_err,
    input [(4*JESD_NO_LANES)-1:0]                     rxnot_in_table_err,
`endif

`ifdef AXI_BUS      
//! Active high signal indicating valid info on slave_write_data and slave_addr. Once asserted remains high until slave_ack 
    input                                            slave_write, 
    //! Active high signal indicating valid info on  slave_addr. Once asserted remains high until slave_ack
    input                                            slave_read, 
    //! data to be written to selected dword
    input [31:0]                                     slave_write_data,
    //! bits [7:0] will be used to select a dword register if slave_addr[31:23] == JESD_CSR_SELECT_MASK.
    input [31:0]                                     slave_addr, 
    //! Active high signal to indicate completion of write and read access.
    output                                           slave_ack, 
    //! Return data valid when slave_ack=1 
    output [31:0]                                    slave_read_data, 
`endif
   
`ifdef APB_BUS
   input [31:0]       paddr,
   input                pwrite,
   input                psel,
   input                penable,
   input [31:0]       pwdata,
   output              pready,
   output [31:0]     prdata,

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

   output                                           slave_interrupt,
   
   //! Unscrambled Receive Data Interface
   output [(32*JESD_NO_LANES)-1:0]                  rx_tdata, // Receive user data stream after deskewing . First octet of user data stream will be placed on rx_tdata[7:0]
   output                                           rx_tvalid, // When high indicates successful linkup and valid user data information on remaining rx_* output signals
   output [3:0]                                     rx_start_of_frame, // 1 bit per octet of rx_tdata of lane 0 to indicate the octet where a new frame begins. Leads rx_tdata by one clk. Since data is already deskewed across all lanes the sof marker for lane 0 is applicable for other lanes as well
   output [3:0]                                     rx_end_of_frame,// 1 bit per octet of rx_tdata of lane0 to indicate the octet where current frame ends. Leads rx_tdata by one clk. Since data is already deskewed across all lanes the sof marker for lane 0 is applicable for other lanes as well
   output [(4*JESD_NO_LANES)-1:0]                   rx_frame_error,//1 bit per octet of rx_tdata to indicate if there was any error while processing the corresponding octet on rx_tdata

`ifdef RX_EXTERNAL_REGS
   output [03:00]      txrx_bank_id_reg,
   output [07:00]      txrx_did_reg,
   output [02:00]      txrx_subclass_reg,
   output [04:0]       txrx_cf_reg,
   output [01:0]       txrx_cs_reg,
   output [07:0]       txrx_f_reg,
   output [04:0]       txrx_k_reg,
   output [04:0]       txrx_l_reg,
   output [04:0]       txrx_n_reg,
   output [07:0]       txrx_m_reg,
   output [04:0]       txrx_ntotal_reg,
   output [04:0]       txrx_s_reg,
   output [00:0]       txrx_hd_reg,
   output [00:0]       txrx_scr_reg,
   output [01:0]       txrx_enablelinktest_reg,
   output [8:0]        txrx_ilas_length_mframe,
`endif 	
   output [JESD_NO_LANES+2:0]                      generated_resets, // Bunch of derived resets as per clock domain needs 
   output [JESD_NO_LANES-1:0]                      active_lane,// 1 bit per lane . When high indicates that lane content is part of the framing and should be used by transport layer
   output [5*JESD_NO_LANES-1:00]                   txrx_lid_reg,

   output [8:0]                                    frame_length_char, //actual F


    //////////////////////////////////////////////
    // DESKEW RAM INTERFACE
    //
    // Runs in clk_character domain
    //
    //////////////////////////////////////////////
   input  [(JESD_NO_LANES*JESD_DESKEW_BUF_DSIZE)-1:0]    deskew_rd_data,         // Valid one clk after deskew_rd_en=1
   output [(JESD_NO_LANES*JESD_DESKEW_BUF_ASIZE)-1:0]    deskew_wr_addr,
   output [JESD_NO_LANES-1:0]                            deskew_wr_en,
   output [(JESD_NO_LANES*JESD_DESKEW_BUF_DSIZE)-1:0]    deskew_wr_data,
   output [(JESD_NO_LANES*JESD_DESKEW_BUF_ASIZE)-1:0]    deskew_rd_addr,
   output [JESD_NO_LANES-1:0]                            deskew_rd_en




// Following ports are disabled if the link layer is used as top ."RX_LINK_TOP" can be added to compile for backward compatibility
`ifndef RX_LINK_TOP
    // Transport layer parameters from csr

    ,
    output [47:0]                                   tl_spec_param,// Standard JESD204B run time variables  packed into a single bus for use by transport layer.
    output  [1:0]                                   clk_ratio,              // Ratio of clk_character to clk_sample: "00": 1:1, "01": 1:2, "10": 1:4
    output                                          txrx_enablemodule_reg,//Indication to transport layer that information coming from registers is valid
    output [JESD_NO_CONVERTERS-1:0]                 active_conv,// 1 bit per converter . When high indicates that converter content is part of the framing and should be used by transport layer
    output                                          comb_cgs_sync_req // Net to indicate link down event which requres transport layer to be rest without resetting the link layer
`endif
   );

`ifdef RX_LINK_TOP
    // Transport layer parameters from csr
   wire [47:0]                                      tl_spec_param;
   wire    [1:0]                                    clk_ratio;              // Ratio of clk_character to clk_sample: "00": 1:1, "01": 1:2, "10": 1:4
   wire                                             txrx_enablemodule_reg;
   wire                                             comb_cgs_sync_req;   
   wire [JESD_NO_CONVERTERS-1:0]                    active_conv;            // 1 bit per converter . When high indicates that converter content is part of the framing and should be used by transport layer   
`endif
   
   reg                                              tl_rst;
   
   
   wire [JESD_NO_LANES-1:0]                            cgs_sync_req;
   wire [JESD_NO_LANES-1:0]                            dskew_err;
   wire [JESD_NO_LANES-1:0]                            overrun_err;
   wire [JESD_NO_LANES-1:0]                            underrun_err;   
   wire [JESD_NO_LANES-1:0]                            lane_disparity_err;
   wire [JESD_NO_LANES-1:0]                            lane_not_in_table_err;
   wire [JESD_NO_LANES-1:0]                            mframe_symbol_err;
   wire [JESD_NO_LANES-1:0]                            mframe_alignment_err;
   wire [JESD_NO_LANES-1:0]                            frame_alignment_err;
   wire [(4*JESD_NO_LANES-1):0]                        incr_err_count;
   wire [(4*JESD_NO_LANES-1):0]                        incr_comma_frame_count;
   wire [JESD_NO_LANES-1:0]                            ilas_mismatch; 
   wire [JESD_NO_LANES-1:0]                            unexpected_k_err; 
   wire [JESD_NO_LANES-1:0]                            tport_data_vld;
   wire [(4*JESD_NO_LANES-1):0]                        tport_byte_en;
   wire [(4*JESD_NO_LANES-1):0]                        tport_data_eof;
   wire [(4*JESD_NO_LANES-1):0]                        tport_data_eomf;
   wire [(4*JESD_NO_LANES-1):0]                        tport_data_sof;
   wire [(4*JESD_NO_LANES-1):0]                        tport_data_somf;
   wire [(32*JESD_NO_LANES-1):0]                       tport_data;
   wire [JESD_NO_LANES-1:0]                            frame_data_vld_grp;

   wire [10:0]                                        mframe_length_char;
   wire [10:0]                                        rbd_char_cnt;
   wire [7:0]                                         sum_ilas_com_param;   
   
   wire [3:0]                                         min_sync_duration; // Min No of frames sync should be asserted 


`ifndef RX_EXTERNAL_REGS
   wire [03:00]      txrx_bank_id_reg;
   wire [07:00]      txrx_did_reg;
   wire [02:00]      txrx_subclass_reg;
   wire [04:0]       txrx_cf_reg;
   wire [01:0]       txrx_cs_reg;
   wire [07:0]       txrx_f_reg;
   wire [04:0]       txrx_k_reg;
   wire [04:0]       txrx_l_reg;
   wire [04:0]       txrx_n_reg;
   wire [07:0]       txrx_m_reg;
   wire [04:0]       txrx_ntotal_reg;
   wire [04:0]       txrx_s_reg;
   wire [00:0]       txrx_hd_reg;
   wire [00:0]       txrx_scr_reg;
   wire [01:0]       txrx_enablelinktest_reg;
   wire [8:0]        txrx_ilas_length_mframe;
`endif 

   wire              txrx_ilas_disable, txrx_lane_align_mon_disable, txrx_lane_align_char_rep_disable, txrx_resync_on_comma_disable;
   wire [(4*JESD_NO_LANES-1):0]jtspat_err_count;
   wire [JESD_NO_LANES-1:0] txrx_enable_jtspat_test_reg;
   wire [(4*JESD_NO_LANES-1):0]jtspat_vld_count;
   wire[(4*JESD_NO_LANES-1):0] prbs_vld_count;
   wire[(4*JESD_NO_LANES-1):0] prbs_err_count;
   wire txrx_symbol_err_via_sync_disable;
   wire fw_sync_req, captured_fw_sync_req;
    wire[JESD_NO_LANES-1:0] prbs_test_enable_reg;

`ifdef BYPASS_8B10B  
      localparam temp_width=8*JESD_NO_SERDES_WORDS;
`endif
    
`ifndef BYPASS_8B10B  
   localparam temp_width=10*JESD_NO_SERDES_WORDS;
`endif
   localparam temp_width_m1=temp_width-1;   
   
   wire                      rst_clk_character,rst_clk_sample;
   wire [JESD_NO_LANES-1:0]  rst_clk_serdes;
   wire [JESD_NO_LANES-1:0]  inject_cgs_err,inject_not_in_table_err,inject_lane_alignment_err,inject_frame_alignment_err;
   wire                      comb_frame_data_vld_r;
   wire                      lmfc_boundary;
   wire                      mf_is_long;

   
   assign generated_resets = {tl_rst,rst_clk_character,rst_clk_serdes,rst_clk_sample};
   
   genvar ln_cnt;
   generate for (ln_cnt = 0; ln_cnt < JESD_NO_LANES; ln_cnt = ln_cnt + 1) begin : lane_generate
      
      jesd_lane_rxdp
                          #(.NO_SERDES_WORDS (JESD_NO_SERDES_WORDS),
                            .DESKEW_BUF_ASIZE (JESD_DESKEW_BUF_ASIZE),
                            .DESKEW_BUF_DSIZE (JESD_DESKEW_BUF_DSIZE)
                            )
      jesd_lane_rxdp (
                     // Outputs
                     .cgs_sync_req      (cgs_sync_req[ln_cnt]),
                     .dskew_err         (dskew_err[ln_cnt]),
                     .underrun_err      (underrun_err[ln_cnt]),
                     .overrun_err       (overrun_err[ln_cnt]),
                     .lane_disparity_err (lane_disparity_err[ln_cnt]),
                     .lane_not_in_table_err (lane_not_in_table_err[ln_cnt]),
                     .mframe_symbol_err (mframe_symbol_err[ln_cnt]),
                     .mframe_alignment_err (mframe_alignment_err[ln_cnt]),
                     .frame_alignment_err (frame_alignment_err[ln_cnt]), 
                     .ilas_mismatch (ilas_mismatch[ln_cnt]),
                     .unexpected_k_err (unexpected_k_err[ln_cnt]),
                     .jtspat_err_count (jtspat_err_count[3+4*ln_cnt:4*ln_cnt]),
                     .jtspat_vld_count (jtspat_vld_count[3+4*ln_cnt:4*ln_cnt]),
                     .incr_err_count (incr_err_count[3+4*ln_cnt:4*ln_cnt]),
                     .incr_comma_frame_count (incr_comma_frame_count[3+4*ln_cnt:4*ln_cnt]),
                     .tport_byte_en     (tport_byte_en[3+4*ln_cnt:4*ln_cnt]),
                     .tport_data_eof    (tport_data_eof[3+4*ln_cnt:4*ln_cnt]),
                     .tport_data_eomf   (tport_data_eomf[3+4*ln_cnt:4*ln_cnt]),
                     .tport_data_sof    (tport_data_sof[3+4*ln_cnt:4*ln_cnt]),
                     .tport_data_somf   (tport_data_somf[3+4*ln_cnt:4*ln_cnt]),
                     .tport_data        (tport_data[31+32*ln_cnt:32*ln_cnt]),                     
                     .tport_data_vld    (tport_data_vld[ln_cnt]),
                     .deskew_wr_addr    (deskew_wr_addr[(JESD_DESKEW_BUF_ASIZE*(ln_cnt+1))-1:JESD_DESKEW_BUF_ASIZE*ln_cnt]),
                     .deskew_wr_en      (deskew_wr_en[ln_cnt]),
                     .deskew_wr_data    (deskew_wr_data[(JESD_DESKEW_BUF_DSIZE*(ln_cnt+1))-1:JESD_DESKEW_BUF_DSIZE*ln_cnt]),
                     .deskew_rd_addr    (deskew_rd_addr[(JESD_DESKEW_BUF_ASIZE*(ln_cnt+1))-1:JESD_DESKEW_BUF_ASIZE*ln_cnt]),
                     .deskew_rd_en      (deskew_rd_en[ln_cnt]),
                     .frame_data_vld    (frame_data_vld_grp[ln_cnt]),
                     .prbs_vld_count  (prbs_vld_count[3+4*ln_cnt:4*ln_cnt]),
                     .prbs_err_count  (prbs_err_count[3+4*ln_cnt:4*ln_cnt]),
                     // Inputs
                     .lmfc_boundary        (lmfc_boundary),
                     .mf_is_long           (mf_is_long),
                     .prbs_test_enable_reg (prbs_test_enable_reg[ln_cnt]),
                     .comb_frame_data_vld(comb_frame_data_vld_r),
                     .sum_ilas_com_param (sum_ilas_com_param),                     
                     .txrx_bank_id_reg(txrx_bank_id_reg[03:00]),
                     .txrx_did_reg    (txrx_did_reg[07:00]),
                     .txrx_lid_reg    (txrx_lid_reg[4+5*ln_cnt:5*ln_cnt]),
                     .txrx_subclass_reg(txrx_subclass_reg[02:00]),
                     .txrx_cf_reg     (txrx_cf_reg[04:0]),
                     .txrx_cs_reg     (txrx_cs_reg[01:0]),
                     .txrx_f_reg      (txrx_f_reg[07:0]),
                     .txrx_k_reg      (txrx_k_reg[04:0]),
                     .txrx_l_reg      (txrx_l_reg[04:0]),
                     .txrx_n_reg      (txrx_n_reg[04:0]),
                     .txrx_m_reg      (txrx_m_reg[07:0]),
                     .txrx_ntotal_reg (txrx_ntotal_reg[04:0]),
                     .txrx_s_reg      (txrx_s_reg[04:0]),
                     .txrx_hd_reg     (txrx_hd_reg[00:0]),
                     .txrx_scr_reg    (txrx_scr_reg[00:0]),
                     .txrx_enablemodule_reg(1'b1), // This input is redundant as of now because the reset generation logic takes care of ensuring reset is active if enable_module is de-asserted
                     .txrx_enablelinktest_reg(txrx_enablelinktest_reg[01:0]),
                     .txrx_enable_jtspat_test_reg (txrx_enable_jtspat_test_reg[ln_cnt]),
                     .txrx_ilas_length_mframe(txrx_ilas_length_mframe),
                     .txrx_ilas_disable(txrx_ilas_disable),
                     .txrx_lane_align_mon_disable (txrx_lane_align_mon_disable),
                     .txrx_lane_align_char_rep_disable (txrx_lane_align_char_rep_disable),
                     .txrx_resync_on_comma_disable (txrx_resync_on_comma_disable),
                     .inject_cgs_err (inject_cgs_err[ln_cnt]),
                     .inject_not_in_table_err (inject_not_in_table_err[ln_cnt]),
                     .inject_lane_alignment_err (inject_lane_alignment_err[ln_cnt]),
                     .inject_frame_alignment_err (inject_frame_alignment_err[ln_cnt]),

`ifdef BYPASS_8B10B  
                      .rxdata_k (rxdata_k[3+4*ln_cnt:4*ln_cnt]),
                      .rxdisparity_err (rxdisparity_err[3+4*ln_cnt:4*ln_cnt]),
                      .rxnot_in_table_err (rxnot_in_table_err[3+4*ln_cnt:4*ln_cnt]),
`else 
   `ifndef BYPASS_ALIGN
                      .sync_b (sync_b),
   `endif
`endif
      
                     .deskew_rd_data    (deskew_rd_data[(JESD_DESKEW_BUF_DSIZE*(ln_cnt+1))-1:JESD_DESKEW_BUF_DSIZE*ln_cnt]),
                     .clk_character     (clk_character),
                     .clk_serdes        (clk_serdes[ln_cnt]),
                     .comb_cgs_sync_req (comb_cgs_sync_req),
                     .mframe_length_char(mframe_length_char[10:0]),
                     .frame_length_char (frame_length_char),
                     .rbd_char_cnt      (rbd_char_cnt[10:0]),
                     .rst_clk_character (rst_clk_character),
                     .rst_clk_serdes    (rst_clk_serdes[ln_cnt]),
                     .serdes_symbol     (serdes_data_i[temp_width_m1+(temp_width*ln_cnt):temp_width*ln_cnt]));
   end endgenerate

   assign rx_tdata = tport_data;
   assign rx_tvalid = tport_data_vld[0];
   assign rx_start_of_frame = tport_data_sof[3:0];
   assign rx_end_of_frame = tport_data_eof[3:0];
   assign rx_frame_error = ~tport_byte_en;


   
   wire clk_sample = clk_character;   
   jesd_jesd204b_rst_gen  #(
                             .NO_LANES            (JESD_NO_LANES)
                           )
   jesd_jesd204b_rst_gen(
                            // Outputs
                            .rst_clk_character (rst_clk_character),
                            .rst_clk_serdes    (rst_clk_serdes),
                            .rst_clk_sample    (rst_clk_sample),
                            // Inputs
                            .clk_serdes        (clk_serdes),
                            .clk_character     (clk_character),
                            .clk_sample        (clk_sample),
                            .clk_cpu           (clk_cpu),
                            .reset_core        (reset_core),
                            .test_mode         (test_mode),
                            .enable_module     (txrx_enablemodule_reg)
                        );
   
     
   jesd_sync_gen  #(
                   // Parameters
                   .NO_LANES            (JESD_NO_LANES),
                   .MAST_INST           (JESD_MAST_INST)) 
   jesd_sync_gen (
                 // Outputs
                 .lmfc_div2_o           (lmfc_div2_o),
                 .sync_b                (sync_b),
                 .comb_cgs_sync_req     (comb_cgs_sync_req),
                 .lmfc_boundary         (lmfc_boundary),
                 .mf_is_long            (mf_is_long),
                 .captured_fw_sync_req  (captured_fw_sync_req),
                 // Inputs
                 .txrx_f_reg            (txrx_f_reg[07:0]),                 
                 .mf_len                (mframe_length_char[10:0]),
                 .active_lane           (active_lane),
                 .ignore_symbol_err     (txrx_symbol_err_via_sync_disable),
                 .ignore_dskew_err      (1'b0),
                 .ignore_frame_alignment_err(1'b0),
                 .ignore_mframe_alignment_err(1'b0),
                 .fw_sync_req           (fw_sync_req),
                 .cgs_sync_req          (cgs_sync_req),
                 .dskew_err             (dskew_err),
                 .frame_alignment_err   (frame_alignment_err),
                 .mframe_alignment_err  (mframe_alignment_err),
                 .mframe_symbol_err     (mframe_symbol_err),
                 .min_sync_duration     (min_sync_duration[3:0]),
                 .num_k                 (txrx_k_reg),
                 .subclass              (txrx_subclass_reg[1:0]),
                 .clk_character         (clk_character),
                 .clk_cpu               (clk_cpu),
                 .rst_clk_character     (rst_clk_character),
                 .sysref                (sysref),
                 .lmfc_div2_i           (lmfc_div2_i));
   

   jesd_rx_core_register #(
                          // Parameters
                          .NO_LANES          (JESD_NO_LANES),
                          .NO_CONVERTERS     (JESD_NO_CONVERTERS),
                          .CSR_SELECT_MASK (JESD_CSR_SELECT_MASK))
   jesd_rx_core_register  (
   
      
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

                          // Outputs

                          .s_interrupt     (slave_interrupt),
                          .txrx_bank_id_reg(txrx_bank_id_reg[03:00]),
                          .txrx_did_reg    (txrx_did_reg[07:00]),
                          .txrx_lid_reg    (txrx_lid_reg),
                          .txrx_subclass_reg(txrx_subclass_reg[02:00]),
                          .txrx_cf_reg     (txrx_cf_reg[04:0]),
                          .txrx_cs_reg     (txrx_cs_reg[01:0]),
                          .txrx_f_reg      (txrx_f_reg[07:0]),
                          .txrx_k_reg      (txrx_k_reg[04:0]),
                          .txrx_l_reg      (txrx_l_reg[04:0]),
                          .txrx_n_reg      (txrx_n_reg[04:0]),
                          .txrx_m_reg      (txrx_m_reg[07:0]),
                          .txrx_ntotal_reg (txrx_ntotal_reg[04:0]),
                          .txrx_s_reg      (txrx_s_reg[04:0]),
                          .txrx_hd_reg     (txrx_hd_reg[00:0]),
                          .txrx_scr_reg    (txrx_scr_reg[00:0]),
                          .txrx_enablemodule_reg(txrx_enablemodule_reg),
                          .txrx_enablelinktest_reg(txrx_enablelinktest_reg[01:0]),
                          .txrx_enable_jtspat_test_reg (txrx_enable_jtspat_test_reg[JESD_NO_LANES-1:0]),
                          .prbs_vld_count  (prbs_vld_count),
                          .prbs_err_count  (prbs_err_count),
                          .prbs_test_enable_reg (prbs_test_enable_reg),
                          .txrx_ilas_length_mframe(txrx_ilas_length_mframe),
                          .txrx_ilas_disable(txrx_ilas_disable),
                          .txrx_lane_align_mon_disable (txrx_lane_align_mon_disable),
                          .txrx_lane_align_char_rep_disable (txrx_lane_align_char_rep_disable),
                          .txrx_resync_on_comma_disable (txrx_resync_on_comma_disable),
                          .txrx_symbol_err_via_sync_disable(txrx_symbol_err_via_sync_disable),
                          .mframe_length_char (mframe_length_char),
                          .frame_length_char (frame_length_char),
                          .rbd_char_cnt (rbd_char_cnt),
                          .fw_sync_req           (fw_sync_req),
                          .min_sync_duration     (min_sync_duration[3:0]),
                          .inject_cgs_err (inject_cgs_err),
                          .inject_not_in_table_err (inject_not_in_table_err),
                          .inject_lane_alignment_err (inject_lane_alignment_err),
                          .inject_frame_alignment_err (inject_frame_alignment_err),
                          .active_lane           (active_lane),
                          .active_conv           (active_conv),
                          .sum_ilas_com_param (sum_ilas_com_param),
                          .tl_spec_param (tl_spec_param),
                          .clk_ratio            (clk_ratio),
                          // Inputs
                          .rst_clk_character (rst_clk_character),
                          .clk_character   (clk_character),
                          .clk_cpu         (clk_cpu),
                          .rst             (reset_csr),
                          .captured_fw_sync_req  (captured_fw_sync_req),
                          .ilas_mismatch   (ilas_mismatch),
                          .underrun_err      (underrun_err),
                          .overrun_err       (overrun_err),
                          .disparity_err (lane_disparity_err),
                          .not_in_table_err (lane_not_in_table_err),
                          .alignment_err (mframe_alignment_err | frame_alignment_err),
                          .unexpected_k_err (unexpected_k_err),
                          .cgs_sync_req (cgs_sync_req),
                          .comb_cgs_sync_req (comb_cgs_sync_req),
                          .mframe_symbol_err (mframe_symbol_err),  
                          .jtspat_err_count (jtspat_err_count),
                          .jtspat_vld_count(jtspat_vld_count),
                          .incr_err_count(incr_err_count),
                          .incr_comma_frame_count(incr_comma_frame_count));

   
   reg [2:0] link_down_reset_duration; // 8 clock of reset should be sufficient to flush tl pipe line
   reg       comb_cgs_sync_req_r;
   reg comb_frame_data_vld;

   always @(posedge clk_character or posedge rst_clk_character)begin
     if (rst_clk_character) begin
       comb_cgs_sync_req_r <= 1'b0;
       comb_frame_data_vld <= 1'b0;
     end else begin
       comb_cgs_sync_req_r <= comb_cgs_sync_req;
       comb_frame_data_vld <=|(frame_data_vld_grp);
     end
   end
   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         link_down_reset_duration <= 3'h0;
         tl_rst <= 1'b1;
      end
      else if (comb_cgs_sync_req & !comb_cgs_sync_req_r) begin
         tl_rst <= 1'b1;
         link_down_reset_duration <= link_down_reset_duration + 1'b1;
      end
      else begin
         if (link_down_reset_duration == 'h7)
           tl_rst <= 1'b0;
         else
           link_down_reset_duration <= link_down_reset_duration + 1'b1;
      end
   end // always @ (posedge clk_character or rst_clk_character)
   
assign comb_frame_data_vld_r=comb_frame_data_vld;   
endmodule // jesd_jesd204b_rx_link

// Local Variables:
// verilog-library-directories:(".")
// End:

//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
