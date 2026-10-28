// This file contatins the definition of module 'jesd_jesd204b_rx_link' . This module serves as stand alone link layer implementation of JESD204B spec
// depending on the presence of define RX_LINK_TOP one can choose the content of the port list.
// Pending modification RAMS used to buffer data for lane deskew logic need to be pulled up to top level.

`include "jesd_jesd204b_rx_defines.v" 

module jesd_jesd204b_rx_link_top
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
   jesd_jesd204b_rx_link #(/*AUTOINSTPARAM*/
                         // Parameters
                         .JESD_MAST_INST         (JESD_MAST_INST),
                         .JESD_DESKEW_BUF_ASIZE  (JESD_DESKEW_BUF_ASIZE),
                         .JESD_DESKEW_BUF_DSIZE  (JESD_DESKEW_BUF_DSIZE),
                         .JESD_CSR_SELECT_MASK   (JESD_CSR_SELECT_MASK),
                         .JESD_NO_LANES          (JESD_NO_LANES),
                         .JESD_NO_CONVERTERS     (JESD_NO_CONVERTERS),
                         .JESD_NO_SERDES_WORDS   (JESD_NO_SERDES_WORDS))
     jesd_jesd204b_rx_link (/*AUTOINST*/
     
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
                        .slave_ack             (slave_ack),
                        .slave_read_data       (slave_read_data[31:0]),
  
                         //Inputs in the AXI bus
                        .slave_write           (slave_write),
                        .slave_read            (slave_read),
                        .slave_write_data      (slave_write_data[31:0]),
                        .slave_addr            (slave_addr[31:0]),
   
`endif

`ifdef AVALON_BUS
                        .address     (address),
                        .write       (write),
                        .read        (read),
                        .waitrequest (waitrequest),
                        .readdata    (readdata),
                        .writedata   (writedata),
`endif   
`ifdef RX_EXTERNAL_REGS
                        .txrx_did_reg (txrx_did_reg),
                        .txrx_bank_id_reg (txrx_bank_id_reg),
                        .txrx_subclass_reg (txrx_subclass_reg),
                        .txrx_cf_reg (txrx_cf_reg),
                        .txrx_cs_reg (txrx_cs_reg),
                        .txrx_f_reg (txrx_f_reg),
                        .txrx_k_reg (txrx_k_reg),
                        .txrx_l_reg (txrx_l_reg),
                        .txrx_n_reg (txrx_n_reg),
                        .txrx_m_reg (txrx_m_reg),
                        .txrx_ntotal_reg (txrx_ntotal_reg),
                        .txrx_s_reg (txrx_s_reg),
                        .txrx_hd_reg (txrx_hd_reg),
                        .txrx_scr_reg (txrx_scr_reg),
                        .txrx_enablelinktest_reg (txrx_enablelinktest_reg),
                        .txrx_ilas_length_mframe (txrx_ilas_length_mframe),
`endif 
`ifdef I2C_IF
                        .rf_addr     (rf_addr),
                        .rf_wen      (rf_wen),
                        .rf_ren      (rf_ren),
                        .rf_rdata    (rf_rdata),
                        .rf_wdata    (rf_wdata), 
`endif

                        // Outputs
                        .sync_b              (sync_b),
                        .lmfc_div2_o         (lmfc_div2_o),
                        .slave_interrupt     (slave_interrupt),
                        .rx_tdata            (rx_tdata[(32*JESD_NO_LANES)-1:0]),
                        .rx_tvalid           (rx_tvalid),
                        .rx_start_of_frame   (rx_start_of_frame[3:0]),
                        .rx_end_of_frame     (rx_end_of_frame[3:0]),
                        .rx_frame_error      (rx_frame_error[(4*JESD_NO_LANES)-1:0]),
                        .txrx_lid_reg        (txrx_lid_reg),
                        .active_lane         (active_lane),
                        .frame_length_char   (frame_length_char[8:0]),
`ifndef RX_LINK_TOP	
                        .clk_ratio           (clk_ratio),													
                        .tl_spec_param       (tl_spec_param[47:0]),
                        .active_conv         (active_conv),
                        .txrx_enablemodule_reg(txrx_enablemodule_reg),
                        .comb_cgs_sync_req   (comb_cgs_sync_req),
`endif								
                        .generated_resets    (generated_resets),
                        .deskew_wr_addr      (deskew_wr_addr),
                        .deskew_wr_en        (deskew_wr_en  ),
                        .deskew_wr_data      (deskew_wr_data),
                        .deskew_rd_addr      (deskew_rd_addr),
                        .deskew_rd_en        (deskew_rd_en  ),

                        // Inputs
                        .clk_cpu             (clk_cpu),
                        .clk_character       (clk_character),
                        .clk_serdes          (clk_serdes),
                           
`ifdef BYPASS_8B10B  
                        .rxdata_k (rxdata_k),
                        .rxdisparity_err (rxdisparity_err),
                        .rxnot_in_table_err (rxnot_in_table_err),
`endif
                     
                        .reset_csr           (reset_csr),
                        .reset_core          (reset_core),
                        .test_mode           (test_mode),
                        .deskew_rd_data      (deskew_rd_data),
                        .lmfc_div2_i         (lmfc_div2_i),
                        .sysref              (sysref),
                        .serdes_data_i       (serdes_data_i)
                      );
endmodule // jesd_jesd204b_rx_link
