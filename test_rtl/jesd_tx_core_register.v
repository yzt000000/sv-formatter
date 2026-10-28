

//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
  `include "jesd_jesd204b_tx_defines.v" 


//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
  `include "jesd_jesd204b_tx_address_defines.v" 


module jesd_tx_core_register
  #(
   //! Valid values 1 to 8
    parameter NO_LANES = 1,
    parameter NO_CONVERTERS = 4,
    parameter CSR_SELECT_MASK = 22'h000
   )
   (
   input              clk_cpu,
   input              rst,

    // Inputs for phase alignment statemachine  
   input [5:0]        frame_clks_sync_lh_to_next_lmfc_boundary,
   input              captured_sync_lh_ph_info,
    // Inputs to interrupt logic
   input              error_decoded_on_sync,
//   input              random_error_detected,
   input              start_cgs_tx_sync_dec,
   input              underrun_err,
   input              overrun_err,
    
`ifdef AXI_BUS
   input [31:0]       s_abus,
   input              s_write,
   input              s_read,
   input [31:0]       s_write_dbus,
   output reg [31:0]  s_read_dbus,
   output reg         s_ack,
`endif
   
`ifdef APB_BUS
   input [31:0]       paddr,
   input              pwrite,
   input              psel,
   input              penable,
   input [31:0]       pwdata,
   output reg         pready,
   output reg [31:0]      prdata,
`endif

`ifdef AVALON_BUS
   input [31:0]       address,
   input              write,
   input              read,
   output reg         waitrequest,
   output reg [31:0]  readdata,
   input  [31:0]     writedata, 
`endif

`ifdef I2C_IF
   input [7:0]       rf_addr,
   input             rf_wen,
   input             rf_ren,
   output reg [31:0] rf_rdata,
   input  [31:0]     rf_wdata, 
`endif


   output reg         s_interrupt, 
   
   output reg [7:0]   sum_ilas_com_param,
   output reg [10:0]  mframe_length_char,
   output reg [8:0]   frame_length_char, 
   output reg [03:00] txrx_bank_id_reg,
   output reg [07:00] txrx_did_reg,

// `ifndef LANE_LONG
    // output reg [29:00]     txrx_lid_reg,
    // output reg [7:0]   prbs_test_enable_reg,
// `endif 
// `ifdef LANE_LONG
    // output reg [119:00]     txrx_lid_reg,
    // output reg [23:0]    prbs_test_enable_reg,
// `endif 
   output [5*NO_LANES-1:00]     txrx_lid_reg,
   output reg [NO_LANES-1:0]       prbs_test_enable_reg,
   output reg [NO_LANES-1:0] active_lane,
   output reg [NO_CONVERTERS-1:0] active_conv,
   output reg [02:00] txrx_subclass_reg,
   output reg [04:0]  txrx_cf_reg,
   output reg [01:0]  txrx_cs_reg,
   output reg [07:0]  txrx_f_reg,
   output reg [04:0]  txrx_k_reg,
   output reg [04:0]  txrx_l_reg,
   output reg [04:0]  txrx_n_reg,
   output reg [07:0]  txrx_m_reg,
   output reg [04:0]  txrx_ntotal_reg,
   output reg [04:0]  txrx_s_reg,
   output reg [00:0]  txrx_hd_reg,
   output reg [00:0]  txrx_scr_reg,
   output reg [00:0]  txrx_enablemodule_reg,
   output reg [01:0]  txrx_enablelinktest_reg, // Doc update : Clarify requirement on transition to 2'b00
   output reg [3:0]   txrx_adjcnt_reg, 
   output reg         txrx_adjdir_reg, 
   output reg         txrx_phadj_reg,
   output reg         start_cgs_tx_fw_req, // Doc update : Add bit 11 details to  `PARAM_TX_ILAS_AND_MISC_DETAILS as WO bit
   output reg [8:0]   ilas_length_mframe,
   output reg [6:0]   sample_to_frame_delay,     // Variable delay between start_sample_if and first frame to be transmitted. Value depends on F, S, and clk_ratio
   output reg [15:0]  linktest_custom_data_reg,
   output reg         linktest_custom_enable_reg,
   output reg         jspat_test_enable_reg,
   
   output             disable_eomf_char_rep,
   output             disable_ilas_tx,

   output reg         first_symbol_disparity, // DOC update
   output reg  [1:0]  clk_ratio,              // Ratio of clk_character to clk_sample: "00": 1:1, "01": 1:2, "10": 1:4
   output reg [42:0]  tl_spec_param
    );
      

`ifndef    TX_RESET_VALUES
  `define TX_CS_RESET_VALUE 2'h0
  `define TX_F_RESET_VALUE 8'h0
  `define TX_L_RESET_VALUE 5'h3
  `define TX_N_RESET_VALUE 5'hF
  `define TX_M_RESET_VALUE 8'h3
  `define TX_NTOTAL_RESET_VALUE 5'hf
  `define TX_S_RESET_VALUE 5'h0
  `define TX_CF_RESET_VALUE 18'h0
  `define TX_LID_RESET_VALUE {5'h5,5'h4,5'h3,5'h2,5'h1,5'h0}
  `define TX_LID2_RESET_VALUE {5'hb,5'ha,5'h9,5'h8,5'h7,5'h6}
  `define TX_LID3_RESET_VALUE {5'h11,5'h10,5'hf,5'he,5'hd,5'hc}
  `define TX_LID4_RESET_VALUE {5'h17,5'h16,5'h15,5'h14,5'h13,5'h12}
  `define TX_BID_RESET_VALUE 4'h0
  `define TX_DID_RESET_VALUE 8'h0
  `define TX_SUBCLASS_RESET_VALUE 3'h1
  `define TX_K_RESET_VALUE 5'h10
  `define TX_HD_RESET_VALUE 1'h0
  `define TX_SCR_RESET_VALUE 1'h0
  `define TX_ILAS_NUM_MFRAME_RESET_VALUE 8'h3
  `define TX_ILAS_DELAY_RESET_VALUE 7'h04
  `define TX_ILAS_MFRAME_RESET_VALUE 11'h11
  `define TX_INTMASK_RESET_VALUE {4{1'b1}}
  `define TX_RX_ADJCNT_RESET_VALUE 4'h0
  `define TX_RX_ADJDIR_RESET_VALUE 1'h0
  `define TX_RX_PHADJ_RESET_VALUE 1'h0
`endif   


  function integer lid_calculate (input integer LANE_NUMBER);

    if (LANE_NUMBER >18)
      lid_calculate = 4;
    else if (LANE_NUMBER >12)
      lid_calculate = 3;
    else if (LANE_NUMBER > 6)
      lid_calculate = 2;
    else 
      lid_calculate = 1;
  endfunction
    
  localparam LID_REG_SIZE = lid_calculate (NO_LANES);
  reg  [(30*LID_REG_SIZE)-1:00] txrx_lid_reg_r;
  reg  [5*NO_LANES-1:00] txrx_lid_reg_r_r;
  assign txrx_lid_reg = txrx_lid_reg_r_r;
  genvar ln_cnt;
  
  always @(posedge clk_cpu or posedge rst)
  begin
    if (rst)
      txrx_lid_reg_r_r [NO_LANES*5-1:0] <= 'h0;
    else
    begin
      txrx_lid_reg_r_r [NO_LANES*5-1:0] <= txrx_lid_reg_r [NO_LANES*5-1:0];
    end
  end



   reg [31:0]            reg_addr_int;
   reg                   reg_write_int;
   reg                   reg_read_int;
   reg [31:0]            reg_wdata_int;
   reg [31:0]            rd_data_mux;
   reg                   rd_ack;
   reg [5:0]             ph_status;   

                         
   wire    rd_ack_sync_b_random_errorcounter;
   reg     rd_req_sync_b_random_errorcounter;  
   reg                   reg_read_int_r;  
   
`ifdef APB_BUS
   always @(posedge clk_cpu or posedge rst) begin
      if (rst) begin
         // reset interface and internal signals
         prdata          <= 32'h0;
         pready           <= 1'b1;
         reg_addr_int    <= 32'h0;
         reg_write_int   <= 1'b0;
         reg_read_int    <= 1'b0;
         reg_wdata_int   <= 32'h0;
         reg_read_int_r <= 1'b0; 
      end else begin
         reg_read_int_r <= ~pready & reg_read_int;
         pready <=  psel ? (rd_ack | reg_write_int) & ~pready : 1'b1;
         // latch interface level signal to internal register
         if (penable & psel) begin
           reg_addr_int <= paddr;
         end
         if (pwrite & penable & psel) begin
           reg_write_int <= ~pready;
           reg_wdata_int <= pwdata;
         end else begin
           reg_write_int <= 1'b0;
           reg_wdata_int <= 32'h0;
         end
         if (!pwrite & penable & psel) begin
           reg_read_int <= ~pready;            
         end else begin
           reg_read_int <= 1'b0;
         end         
         if (reg_read_int) begin
           prdata <= rd_data_mux;
         end else begin
           prdata <= 32'h0;
         end
      end
   end
`endif

`ifdef AXI_BUS
   always @(posedge clk_cpu or posedge rst) begin
      if (rst) begin
         // reset interface and internal signals
         s_read_dbus     <= 32'h0;
         s_ack           <= 1'b0;
         reg_addr_int    <= 32'h0;
         reg_write_int   <= 1'b0;
         reg_read_int    <= 1'b0;
         reg_wdata_int   <= 32'h0;
         reg_read_int_r <= 1'b0;  
      end else begin
         reg_read_int_r <= ~s_ack & reg_read_int;
         s_ack <=  (rd_ack | reg_write_int) & ~s_ack;
         // latch interface level signal to internal register
         if (s_write | s_read) begin
            reg_addr_int <= s_abus;
         end
         if (s_write) begin
            reg_write_int <= ~s_ack;
            reg_wdata_int <= s_write_dbus;
         end else begin
            reg_write_int <= 1'b0;
            reg_wdata_int <= 32'h0;
         end

         if (s_read) begin
            reg_read_int <= ~s_ack;            
         end else begin
            reg_read_int <= 1'b0;
         end
         
         if (reg_read_int) begin
            s_read_dbus <= rd_data_mux;
         end else begin
            s_read_dbus <= 32'h0;
         end
         
      end
   end
 `endif
 
 `ifdef AVALON_BUS
    // input [31:0]       address,
   // input              write,
   // input              read,
   // output             waitrequest,
   // output [31:0]     readdata,
   // input  [31:0]     writedata, 
   always @(posedge clk_cpu or posedge rst) begin
      if (rst) begin
         // reset interface and internal signals
         readdata     <= 32'h0;
         waitrequest           <= 1'b1;
         reg_addr_int    <= 32'h0;
         reg_write_int   <= 1'b0;
         reg_read_int    <= 1'b0;
         reg_wdata_int   <= 32'h0;
         reg_read_int_r <= 1'b0;  
      end else begin
         reg_read_int_r <= waitrequest & reg_read_int;
         waitrequest <= !( (rd_ack | reg_write_int) & waitrequest);
         // latch interface level signal to internal register
         if (write | read) begin
            reg_addr_int <= address;
         end
         if (write) begin
            reg_write_int <= waitrequest;
            reg_wdata_int <= writedata;
         end else begin
            reg_write_int <= 1'b0;
            reg_wdata_int <= 32'h0;
         end

         if (read) begin
            reg_read_int <= waitrequest;            
         end else begin
            reg_read_int <= 1'b0;
         end
         
         if (reg_read_int) begin
            readdata <= rd_data_mux;
         end else begin
            readdata <= 32'h0;
         end
         
      end
   end
 `endif
 
`ifdef I2C_IF

   always @(posedge clk_cpu or posedge rst) begin
      if (rst) begin
         // reset interface and internal signals
         rf_rdata        <= 32'h0;
         reg_addr_int    <= 32'h0;
         reg_write_int   <= 1'b0;
         reg_read_int    <= 1'b0;
         reg_wdata_int   <= 32'h0;
         reg_read_int_r  <= 1'b0;         
      end else begin
         reg_read_int_r <= reg_read_int;
         // latch interface level signal to internal register
         if (!rf_wen | !rf_ren) begin
            reg_addr_int[31:0] <= {22'h0, rf_addr[7:0], 2'b00};
         end

         reg_write_int <= !rf_wen;            
         if (!rf_wen)
            reg_wdata_int <= rf_wdata;
         else
            reg_wdata_int <= 32'h0;

         reg_read_int <= !rf_ren;

         if (reg_read_int)
            rf_rdata    <= rd_data_mux;
         else 
            rf_rdata    <= 32'h0;
         
      end
   end
`endif

`ifdef I2C_IF
   wire up_addr_match = 1'b1;
`endif
`ifdef APB_BUS
   wire up_addr_match = 1'b1;
`endif
`ifndef I2C_IF
  `ifndef APB_BUS
   wire up_addr_match = CSR_SELECT_MASK == reg_addr_int[31:10];   
   `endif
`endif 
   wire txrx_bank_id_cs         = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_BANK_ID;
   wire txrx_did_cs             = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_DID;
   wire txrx_lid_cs             = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_LID;
 
   wire txrx_lid_cs2             = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_LID2;
   wire txrx_lid_cs3             = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_LID3;
   wire txrx_lid_cs4             = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_LID4;

   wire txrx_subclass_cs        = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_SUBCLASS;
   wire txrx_cf_cs              = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_CF      ;
   wire txrx_cs_cs              = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_CS      ;
   wire txrx_f_cs               = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_F       ;
   wire txrx_k_cs               = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_K       ;
   wire txrx_l_cs               = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_L       ;
   wire txrx_n_cs               = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_N       ;
   wire txrx_m_cs               = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_M       ;
   wire txrx_ntotal_cs          = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_NTOTAL  ;
   wire txrx_s_cs               = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_S       ;
   wire txrx_hd_cs              = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_HD      ;
   wire txrx_scr_cs             = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_SCR     ;


   wire txrx_enablemodule_cs          = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_ENABLEMODULE;
   wire txrx_enablelinktest_cs        = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_ENABLELINKTEST;
   wire tx_feature_disable_cs         = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TX_FEATURE_DISABLE;
   wire tx_tailbits_cs               = ~up_addr_match  ? 1'b0 : reg_addr_int[9:0] == `PARAM_TX_TAILBITS;
   wire linktest_custom_data_cs    = ~up_addr_match  ? 1'b0 : reg_addr_int[9:0] == `PARAM_LINKTEST_CUSTOM_DATA;
   wire linktest_custom_enable_cs  = ~up_addr_match  ? 1'b0 : reg_addr_int[9:0] == `PARAM_LINKTEST_CUSTOM_ENABLE;
   wire jspat_test_enable_cs       = ~up_addr_match  ? 1'b0 : reg_addr_int[9:0] == `PARAM_JSPAT_TEST_ENABLE;


   wire tx_core_interrupt_mask_cs       = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TX_CORE_INTERRUPT_MASK        ;
   wire tx_clk_ratio_cs                 = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_CLK_RATIO                     ;
   wire tx_core_interrupt_status_cs     = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TX_CORE_INTERRUPT_STATUS      ;
   wire tx_ilas_details_cs              = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TX_ILAS_DETAILS               ;   
   wire tx_ilas_delay_cs                = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TX_ILAS_DELAY                 ;   
   wire prbs_test_enable_cs             = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_PRBS_TEST_ENABLE              ;
//   wire random_error_detected_cs        = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TX_RANDOM_ERROR_DETECTED      ;

   reg [1:0] tx_feature_disable;
   reg [1:0] tx_tailbits;
   reg [3:0]  tx_core_interrupt_mask;
   reg [3:0] interrupt_status;   
   reg [7:0] ilas_length_mframe_int;
   reg  [7:0]         cf_first_nib;
   reg  [4:0]         cf_first_ln;
   
wire [31:0] sync_b_random_errorcounter;

 `define LRW_REG_W_MACRO(storage_name,rst_value,wr_enable,write_value) \
   always @(posedge clk_cpu or posedge rst) begin \
      if (rst) \
        storage_name <= rst_value; \
      else if (reg_write_int & wr_enable) \
        storage_name <= write_value; \
   end \


`ifdef HARDCODED_FPGA_CONFIG
   always@(*) begin
      txrx_l_reg = 0;
      txrx_f_reg = 0;
      txrx_n_reg = 0;
      txrx_ntotal_reg = 0;
      txrx_s_reg = 0;
      txrx_cs_reg = 0;
      txrx_m_reg = 0;
      txrx_cf_reg = 0;

      if (txrx_enablemodule_reg) begin
         if (NO_LANES == 1) begin // L=1, F=32, N=12, N’=16, S=4,  M=4,CS=3 , CF=0
            txrx_l_reg = 0;
            txrx_f_reg = 31;
            txrx_n_reg = 11;
            txrx_ntotal_reg = 15;
            txrx_s_reg = 3;
            txrx_cs_reg = 3;
            txrx_m_reg = 3;
            txrx_cf_reg = 0;
         end // if (NO_LANES == 1)
         else if (NO_LANES == 4) begin // L=4, F=8, N=12, N’=16, S=4,  M=4,CS=3 , CF=0
            txrx_l_reg = 3;
            txrx_f_reg = 3;
            txrx_n_reg = 11;
            txrx_ntotal_reg = 15;
            txrx_s_reg = 3;
            txrx_cs_reg = 3;
            txrx_m_reg = 3;
            txrx_cf_reg = 0;
         end // if (NO_LANES==4)
      end // if (txrx_enablemodule_reg)
   end // always@ begin      
`else


   `LRW_REG_W_MACRO(txrx_cs_reg[1:0],`TX_CS_RESET_VALUE, txrx_cs_cs, reg_wdata_int[1:0])
   `LRW_REG_W_MACRO(txrx_f_reg[7:0], `TX_F_RESET_VALUE, txrx_f_cs, reg_wdata_int[7:0])
   `LRW_REG_W_MACRO(txrx_l_reg[4:0], `TX_L_RESET_VALUE, txrx_l_cs, reg_wdata_int[4:0])
   `LRW_REG_W_MACRO(txrx_n_reg[4:0], `TX_N_RESET_VALUE, txrx_n_cs, reg_wdata_int[4:0])
   `LRW_REG_W_MACRO(txrx_m_reg[7:0], `TX_M_RESET_VALUE, txrx_m_cs, reg_wdata_int[7:0])
   `LRW_REG_W_MACRO(txrx_ntotal_reg[4:0], `TX_NTOTAL_RESET_VALUE, txrx_ntotal_cs, reg_wdata_int[4:0])
   `LRW_REG_W_MACRO(txrx_s_reg[4:0], `TX_S_RESET_VALUE, txrx_s_cs, reg_wdata_int[4:0])
   `LRW_REG_W_MACRO({cf_first_nib[7:0],cf_first_ln[4:0],txrx_cf_reg[4:0]}, `TX_CF_RESET_VALUE, txrx_cf_cs, reg_wdata_int[17:0]) 

`endif   
   
   `LRW_REG_W_MACRO(txrx_bank_id_reg[3:0], `TX_BID_RESET_VALUE, txrx_bank_id_cs, reg_wdata_int[3:0])
   `LRW_REG_W_MACRO(txrx_did_reg[7:0], `TX_DID_RESET_VALUE, txrx_did_cs, reg_wdata_int[7:0])
   `LRW_REG_W_MACRO(txrx_lid_reg_r[29:0], `TX_LID_RESET_VALUE, txrx_lid_cs, reg_wdata_int[31:0])
    generate
//    begin
      if(NO_LANES > 6) begin: L6_BLK
        `LRW_REG_W_MACRO(txrx_lid_reg_r[59:30], `TX_LID2_RESET_VALUE, txrx_lid_cs2, reg_wdata_int[31:0])
      end
      if (NO_LANES >12) begin: L12_BLK
        `LRW_REG_W_MACRO(txrx_lid_reg_r[89:60], `TX_LID3_RESET_VALUE, txrx_lid_cs3, reg_wdata_int[31:0])
      end
      if (NO_LANES >18) begin: L18_BLK
        `LRW_REG_W_MACRO(txrx_lid_reg_r[119:90], `TX_LID4_RESET_VALUE, txrx_lid_cs4, reg_wdata_int[31:0])
      end
//    end   
   endgenerate
// `ifdef LANE_LONG   
   

   `LRW_REG_W_MACRO(prbs_test_enable_reg,'h0, prbs_test_enable_cs,reg_wdata_int[23:0])
// `else
   // `LRW_REG_W_MACRO(prbs_test_enable_reg,8'h0, prbs_test_enable_cs,reg_wdata_int[7:0])
// `endif
   
   `LRW_REG_W_MACRO(txrx_subclass_reg[2:0], `TX_SUBCLASS_RESET_VALUE, txrx_subclass_cs, reg_wdata_int[2:0])
   `LRW_REG_W_MACRO(txrx_k_reg[4:0], `TX_K_RESET_VALUE, txrx_k_cs, reg_wdata_int[4:0])
   `LRW_REG_W_MACRO(txrx_hd_reg[0], `TX_HD_RESET_VALUE, txrx_hd_cs, reg_wdata_int[0])
   `LRW_REG_W_MACRO(txrx_scr_reg[0], `TX_SCR_RESET_VALUE, txrx_scr_cs, reg_wdata_int[0])
   `LRW_REG_W_MACRO(txrx_enablemodule_reg[0], 1'h0, txrx_enablemodule_cs, reg_wdata_int[0])
   `LRW_REG_W_MACRO(txrx_enablelinktest_reg[1:0], 2'h0, txrx_enablelinktest_cs, reg_wdata_int[1:0])
   `LRW_REG_W_MACRO(tx_feature_disable[1:0], 2'h0, tx_feature_disable_cs, reg_wdata_int[1:0])
   `LRW_REG_W_MACRO(tx_tailbits[1:0], 2'h0, tx_tailbits_cs, reg_wdata_int[1:0])   
   `LRW_REG_W_MACRO(linktest_custom_data_reg,16'h0, linktest_custom_data_cs,reg_wdata_int[15:0])
   `LRW_REG_W_MACRO(linktest_custom_enable_reg,1'h0, linktest_custom_enable_cs,reg_wdata_int[0])
   `LRW_REG_W_MACRO(jspat_test_enable_reg,1'h0, jspat_test_enable_cs,reg_wdata_int[0])
   `LRW_REG_W_MACRO(first_symbol_disparity,1'h0, jspat_test_enable_cs,reg_wdata_int[1])     
   
 
   `LRW_REG_W_MACRO(mframe_length_char, `TX_ILAS_MFRAME_RESET_VALUE, tx_ilas_details_cs, reg_wdata_int[10:0])
   `LRW_REG_W_MACRO(start_cgs_tx_fw_req, 1'h0, tx_ilas_details_cs, reg_wdata_int[11] ^ start_cgs_tx_fw_req)   
   `LRW_REG_W_MACRO(txrx_adjcnt_reg, `TX_RX_ADJCNT_RESET_VALUE, tx_ilas_details_cs, reg_wdata_int[15:12])
   `LRW_REG_W_MACRO(txrx_adjdir_reg, `TX_RX_ADJDIR_RESET_VALUE, tx_ilas_details_cs, reg_wdata_int[16])
   `LRW_REG_W_MACRO(txrx_phadj_reg, `TX_RX_PHADJ_RESET_VALUE, tx_ilas_details_cs, reg_wdata_int[17])
   `LRW_REG_W_MACRO(ilas_length_mframe_int, `TX_ILAS_NUM_MFRAME_RESET_VALUE, tx_ilas_details_cs, reg_wdata_int[31:24])
   `LRW_REG_W_MACRO(sample_to_frame_delay, `TX_ILAS_DELAY_RESET_VALUE, tx_ilas_delay_cs, reg_wdata_int[6:0])
   `LRW_REG_W_MACRO(tx_core_interrupt_mask[3:0], `TX_INTMASK_RESET_VALUE, tx_core_interrupt_mask_cs, reg_wdata_int[3:0])   
   `LRW_REG_W_MACRO(clk_ratio[1:0], `TX_CLK_RATIO_RESET_VALUE, tx_clk_ratio_cs, reg_wdata_int[1:0])   


   
   
   
   // Read from Register
   always @(*) begin
      rd_data_mux = 32'b0;
      rd_ack = 1'b0;
      if (up_addr_match) begin
         case (reg_addr_int[9:0])
           `PARAM_TXRX_BANK_ID : begin
              rd_data_mux =  {28'h0, txrx_bank_id_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_DID     : begin
              rd_data_mux =  {24'h0, txrx_did_reg};
              rd_ack = reg_read_int;
           end 
            `PARAM_TXRX_LID : begin
              rd_data_mux[29:0] =       txrx_lid_reg_r[29:0];
              rd_ack = reg_read_int;
           end 
//`ifdef LANE_LONG 
           `PARAM_TXRX_LID2 : begin
              if(NO_LANES > 6) begin : L6_BLK_2
                rd_data_mux [29:0] =       txrx_lid_reg_r[59:30];  
              end                
              rd_ack = reg_read_int;              
           end            
           `PARAM_TXRX_LID3 : begin
              if (NO_LANES >12) begin : L12_BLK_2
                rd_data_mux [29:0] =       txrx_lid_reg_r[89:60];
              end                
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_LID4 : begin
              if (NO_LANES >18) begin : L18_BLK_2
                rd_data_mux [29:0] =       txrx_lid_reg_r[119:90];
              end
              rd_ack = reg_read_int;
           end            
/*            `PARAM_TXRX_LID : begin
              rd_data_mux[29:0] =       txrx_lid_reg[29:0];
              rd_ack = reg_read_int;
           end 
`ifdef LANE_LONG      		   
           `PARAM_TXRX_LID2 : begin
              rd_data_mux [29:0] =       txrx_lid_reg[59:30];
              rd_ack = reg_read_int;
           end            
           `PARAM_TXRX_LID3 : begin
              rd_data_mux [29:0] =       txrx_lid_reg[89:60];
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_LID4 : begin
              rd_data_mux [29:0] =       txrx_lid_reg[119:90];
              rd_ack = reg_read_int;
           end 
`endif     */       
           

           `PARAM_TXRX_SUBCLASS : begin
              rd_data_mux =  {30'h0,txrx_subclass_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_CF : begin
              rd_data_mux =        {14'h0,cf_first_nib,cf_first_ln,txrx_cf_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_CS : begin
              rd_data_mux =        {30'h0,txrx_cs_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_F : begin
              rd_data_mux =         {24'h0,txrx_f_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_K : begin
              rd_data_mux =         {27'h0,txrx_k_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_L : begin
              rd_data_mux =         {27'h0,txrx_l_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_N : begin
              rd_data_mux =         {27'h0,txrx_n_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_M : begin
              rd_data_mux =         {24'h0,txrx_m_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_NTOTAL : begin
              rd_data_mux =    {5'h0,txrx_ntotal_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_S : begin
              rd_data_mux =         {5'h0,txrx_s_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_HD : begin
              rd_data_mux =        {31'h0,txrx_hd_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_SCR : begin
              rd_data_mux =       {31'h0,txrx_scr_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_ENABLEMODULE : begin
              rd_data_mux =            {31'h0,txrx_enablemodule_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_ENABLELINKTEST : begin
              rd_data_mux =          {30'h0,txrx_enablelinktest_reg};
              rd_ack = reg_read_int;
           end
           `PARAM_TX_FEATURE_DISABLE : begin
              rd_data_mux =           {30'h0,tx_feature_disable};
              rd_ack = reg_read_int;
           end 
           `PARAM_TX_TAILBITS:begin
              rd_data_mux =           {30'h0,tx_tailbits};
              rd_ack = reg_read_int;
           end
           `PARAM_LINKTEST_CUSTOM_DATA:begin
              rd_data_mux = {16'h0,linktest_custom_data_reg};
              rd_ack = reg_read_int;              
           end
           `PARAM_LINKTEST_CUSTOM_ENABLE:begin
              rd_data_mux = {31'h0,linktest_custom_enable_reg};
              rd_ack = reg_read_int;
           end
           `PARAM_JSPAT_TEST_ENABLE:begin
              rd_data_mux = {31'h0,jspat_test_enable_reg};
              rd_ack = reg_read_int;
           end
           `PARAM_TX_CORE_INTERRUPT_MASK : begin
              rd_data_mux =       {28'h0,tx_core_interrupt_mask};
              rd_ack = reg_read_int;
           end 
           `PARAM_TX_ILAS_DETAILS : begin
              rd_data_mux = {ilas_length_mframe_int,ph_status,
                             txrx_phadj_reg,txrx_adjdir_reg,txrx_adjcnt_reg,1'b0,mframe_length_char[10:0]};

              rd_ack = reg_read_int;
           end 
           `PARAM_TX_CORE_INTERRUPT_STATUS : begin
              rd_data_mux = {28'h0,interrupt_status};
              rd_ack = reg_read_int;              
           end
           `PARAM_PRBS_TEST_ENABLE:begin
              rd_data_mux = {31'h0,prbs_test_enable_reg};
              rd_ack = reg_read_int;
           end
           `PARAM_CLK_RATIO: begin
              rd_data_mux = {30'h0,clk_ratio[1:0]};
              rd_ack = reg_read_int;
           end
           `PARAM_TX_ILAS_DELAY: begin
              rd_data_mux = {25'h0,sample_to_frame_delay[6:0]};
              rd_ack = reg_read_int;
           end
/*            `PARAM_TX_RANDOM_ERROR_DETECTED:begin
              rd_data_mux = {31'h0,sync_b_random_errorcounter};
              rd_ack = reg_read_int & (rd_req_sync_b_random_errorcounter == rd_ack_sync_b_random_errorcounter);
           end   */         
           
           default:begin
              rd_data_mux = 32'b0;
              rd_ack = reg_read_int;
           end 
         endcase // case (reg_addr_int)
      end // if (up_addr_match)
   end // always @ (*)

/*    
   always @ (posedge clk_cpu or posedge rst) begin
     if (rst) begin
       rd_req_sync_b_random_errorcounter <=1'b0;
     end
     else if (reg_read_int & ~reg_read_int_r) begin
       rd_req_sync_b_random_errorcounter <= random_error_detected_cs ^ rd_req_sync_b_random_errorcounter;
     end
   end

       jesd_rc_counter sync_b_random_error  (
                                    // Outputs
                                    .counter              (sync_b_random_errorcounter[31:00]),
                                    .rd_ack               (rd_ack_sync_b_random_errorcounter),
                                    // Inputs
                                    .clk_character        (clk_character),
                                    .rst_clk_character    (rst_clk_character),
                                    .incr_count           ({3'b0,random_error_detected}),
                                    .clk_cpu              (clk_cpu),
                                    .rd_req               (rd_req_sync_b_random_errorcounter));
                                   */  
   
   wire                  captured_sync_lh_ph_info_cpu;
   reg                   captured_sync_lh_ph_info_cpu_r;
   
jesd_simple_sync  #(.REG_IP (0))
     ph_status_sync
       (
        .src_signal (captured_sync_lh_ph_info),
        .src_clk (1'b0),
        .dest_clk (clk_cpu), 
        .dest_signal (captured_sync_lh_ph_info_cpu)                     
        );

   always @ (posedge clk_cpu or posedge rst) begin
      if (rst) begin
         ph_status <= 'h0;
         captured_sync_lh_ph_info_cpu_r <= 1'b0;
      end
      else begin
         captured_sync_lh_ph_info_cpu_r <= captured_sync_lh_ph_info_cpu;
         ph_status <=  !captured_sync_lh_ph_info_cpu_r & captured_sync_lh_ph_info_cpu ? frame_clks_sync_lh_to_next_lmfc_boundary 
                       : ph_status;
      end
   end // always @ (posedge clk_cpu or posedge rst)


   wire                  error_decoded_on_sync_cpu,cgs_req_decoded_on_sync_cpu,overrun_err_cpu,underrun_err_cpu;
   reg                   error_decoded_on_sync_cpu_r,cgs_req_decoded_on_sync_cpu_r,overrun_err_cpu_r,underrun_err_cpu_r;


   
jesd_simple_sync  #(.REG_IP (0))
     error_status_sync
       (
        .src_signal (error_decoded_on_sync),
        .src_clk (1'b0),
        .dest_clk (clk_cpu), 
        .dest_signal (error_decoded_on_sync_cpu)                     
        );

   jesd_simple_sync  #(.REG_IP (0))
     cgs_status_sync
       (
        .src_signal (start_cgs_tx_sync_dec),
        .src_clk (1'b0),
        .dest_clk (clk_cpu), 
        .dest_signal (cgs_req_decoded_on_sync_cpu)                     
        );


      jesd_simple_sync  #(.REG_IP (0))
     underrun_status_sync
       (
        .src_signal (underrun_err),
        .src_clk (1'b0),
        .dest_clk (clk_cpu), 
        .dest_signal (underrun_err_cpu)                     
        );

   
   jesd_simple_sync  #(.REG_IP (0))
     overrun_status_sync
       (
        .src_signal (overrun_err),
        .src_clk (1'b0),
        .dest_clk (clk_cpu), 
        .dest_signal (overrun_err_cpu)                     
        );

   always @ (posedge clk_cpu or posedge rst) begin
      if (rst) begin         
         error_decoded_on_sync_cpu_r <= 1'b0;
         cgs_req_decoded_on_sync_cpu_r <= 1'b0;
         underrun_err_cpu_r <= 1'b0;         
         overrun_err_cpu_r <= 1'b0;         
      end
      else begin
         error_decoded_on_sync_cpu_r <= error_decoded_on_sync_cpu;
         cgs_req_decoded_on_sync_cpu_r <= cgs_req_decoded_on_sync_cpu; 
         underrun_err_cpu_r <= underrun_err_cpu;
         overrun_err_cpu_r <= overrun_err_cpu;         
      end
   end // always @ (posedge clk_cpu or posedge rst)




   wire      clear_interrupt_bits = tx_core_interrupt_status_cs & rd_ack;
   
 always @(posedge clk_cpu or posedge rst) begin
    if (rst) begin
       interrupt_status <= 4'h0;
       s_interrupt <= 1'b0;
    end
    else begin
       s_interrupt <=     |(interrupt_status  & ~tx_core_interrupt_mask);

       interrupt_status[0] <= (!clear_interrupt_bits & interrupt_status[0]) || 
                              (error_decoded_on_sync_cpu & !error_decoded_on_sync_cpu_r);
       interrupt_status[1] <= (!clear_interrupt_bits & interrupt_status[1]) || 
                              (cgs_req_decoded_on_sync_cpu & !cgs_req_decoded_on_sync_cpu_r);

       interrupt_status[2] <= (!clear_interrupt_bits & interrupt_status[2]) || 
                              (underrun_err_cpu & !underrun_err_cpu_r);
       interrupt_status[3] <= (!clear_interrupt_bits & interrupt_status[3]) || 
                              (overrun_err_cpu & !overrun_err_cpu_r);
       
    end // else: !if(rst)
 end // always @ (posedge clk_cpu or posedge rst)
   assign disable_ilas_tx = tx_feature_disable[0];
   assign disable_eomf_char_rep = tx_feature_disable[1];

   // Multicycle path global variables   
   wire [7:0] sum_ilas_com_param_next;
   reg [NO_LANES-1:0]  active_lane_next;
   reg [NO_CONVERTERS-1:0]  active_conv_next;

   always @ (posedge clk_cpu or posedge rst) begin
      if (rst) begin
         active_lane <= 'h1;
         active_conv <= 'h4;
         ilas_length_mframe <= 9'h4;
         frame_length_char <= 9'h1;
         sum_ilas_com_param <= 8'h0;
      end
      else begin
         active_lane <= active_lane_next;         
         active_conv <= active_conv_next;         
         ilas_length_mframe <= ilas_length_mframe_int + 1'b1;
         frame_length_char <= txrx_f_reg + 1'b1;
         sum_ilas_com_param <= sum_ilas_com_param_next;
      end
   end

   always @(*) begin
      case (txrx_l_reg)
        5'h1 : active_lane_next = 'h03;
        5'h2 : active_lane_next = 'h07;
        5'h3 : active_lane_next = 'h0F;        
        5'h4 : active_lane_next = 'h1F;
        5'h5 : active_lane_next = 'h3F;         
        5'h6 : active_lane_next = 'h7F;         
        5'h7 : active_lane_next = 'hFF;
        5'h8 : active_lane_next = 'h1FF;          
        5'h9 : active_lane_next = 'h3FF;          
        5'ha : active_lane_next = 'h7FF;          
        5'hb : active_lane_next = 'hFFF;                                  
        5'hc : active_lane_next = 'h1FFF;          
        5'hd : active_lane_next = 'h3FFF;          
        5'he : active_lane_next = 'h7FFF;          
        5'hf : active_lane_next = 'hFFFF;          
        5'h10 : active_lane_next = 'h1FFFF;                  
        5'h11 : active_lane_next = 'h3FFFF;                                                  
        5'h12 : active_lane_next = 'h7FFFF;          
        5'h13 : active_lane_next = 'hFFFFF;          
        5'h14 : active_lane_next = 'h1FFFFF;
        5'h15 : active_lane_next = 'h3FFFFF;                                    
        5'h16 : active_lane_next = 'h7FFFFF;                  
        5'h17 : active_lane_next = 'hFFFFFF;                  
                          
        default:active_lane_next = 'h01;      
      endcase
   end

   always @(*) begin
      case (txrx_m_reg[4:0])
        5'h1 : active_conv_next = 'h03;
        5'h2 : active_conv_next = 'h07;
        5'h3 : active_conv_next = 'h0F;        
        5'h4 : active_conv_next = 'h1F;
        5'h5 : active_conv_next = 'h3F;         
        5'h6 : active_conv_next = 'h7F;         
        5'h7 : active_conv_next = 'hFF;
        5'h8 : active_conv_next = 'h1FF;          
        5'h9 : active_conv_next = 'h3FF;          
        5'ha : active_conv_next = 'h7FF;          
        5'hb : active_conv_next = 'hFFF;                                  
        5'hc : active_conv_next = 'h1FFF;          
        5'hd : active_conv_next = 'h3FFF;          
        5'he : active_conv_next = 'h7FFF;          
        5'hf : active_conv_next = 'hFFFF;          
        5'h10 : active_conv_next = 'h1FFFF;                  
        5'h11 : active_conv_next = 'h3FFFF;                                                  
        5'h12 : active_conv_next = 'h7FFFF;          
        5'h13 : active_conv_next = 'hFFFFF;          
        5'h14 : active_conv_next = 'h1FFFFF;
        5'h15 : active_conv_next = 'h3FFFFF;                                    
        5'h16 : active_conv_next = 'h7FFFFF;                  
        5'h17 : active_conv_next = 'hFFFFFF;                  
                          
        default:active_conv_next = 'h01;      
      endcase
   end

   assign sum_ilas_com_param_next = {7'h0,txrx_adjdir_reg }
                     + {4'h0,txrx_adjcnt_reg }
                     + {7'h0,txrx_phadj_reg }
                     + txrx_did_reg
                     + {4'h0,txrx_bank_id_reg }
                     + {3'h0,txrx_l_reg }
                     + {7'h0,txrx_scr_reg  }
                     + txrx_f_reg
                     + {3'h0,txrx_k_reg }
                     + txrx_m_reg
                     + {6'h0,txrx_cs_reg }
                     + {3'h0,txrx_n_reg }
                     + {5'h0,txrx_subclass_reg}
                     + {3'h0,txrx_ntotal_reg}
                     + {8'h1}
                     + {3'h0,txrx_s_reg}
                     + {7'h0,txrx_hd_reg}
                     + {3'h0,txrx_cf_reg};


               
   always @(posedge clk_cpu or posedge rst) begin
      if (rst) tl_spec_param <= 42'h0;
      else begin
         tl_spec_param[1:0] <= {txrx_cs_reg[1:0]};
         tl_spec_param[3:2] <= {txrx_cf_reg[1:0]};
         tl_spec_param[8:4] <= txrx_s_reg[4:0];
         tl_spec_param[13:9] <= txrx_n_reg[4:0];
         tl_spec_param[18:14]  <= txrx_ntotal_reg[4:0];
         tl_spec_param[20:19] <= tx_tailbits;
         tl_spec_param[28:21]  <= txrx_f_reg[7:0];
         tl_spec_param[36:29]  <= cf_first_nib[7:0];
         tl_spec_param[41:37]  <= cf_first_ln[4:0];
         tl_spec_param[42   ]  <= txrx_hd_reg;
      end
   end // always @ (posedge clk_cpu)

`ifndef HARDCODED_FPGA_CONFIG
`ifdef AUTO_COMPUTE_USER_PARAMS

   function  void compute_user_params(int num_data_conv,num_f,num_lanes,num_n,num_s,num_ntotal,num_cs,num_cf,num_hd);
      int num_nib_pl; // number of nibbles that fit on per lane in a single frame
      int num_nib_pc; // number of nibbles that are used by a single convertor in a single frame
      int num_nib_ps; // number of nibbles consumed in one sample
      int num_nprime; // internal variable locally generated instead of using num_ntotal input

      // Variables used in internal alogrithm
      int curr_conv;  
      int curr_lane;
      int consumed_nc; // indicates number of nibbles from curr conv already mapped on to some lane
      int curr_conv_balance_nc; // indicates number of nibbles from curr conv yet to be mapped on to some lane
      int avail_nc; // indicates number of nibbles avail on current lane
      bit print_info;
      bit [7:0] lane_nib_cnt[8][6];
      bit [11:0] start_pos[8];
      

      
      $display("Input Debug num_data_conv=0x%0h",num_data_conv);
      $display("Input Debug num_f=0x%0h",num_f);
      $display("Input Debug num_lanes=0x%0h",num_lanes);
      $display("Input Debug num_n=0x%0h",num_n);
      $display("Input Debug num_s=0x%0h",num_s);
      $display("Input Debug num_ntotal=0x%0h",num_ntotal);
      $display("Input Debug num_cs=0x%0h",num_cs);
      $display("Input Debug num_cf=0x%0h",num_cf);      
      $display("Input Debug num_hd=0x%0h",num_hd);      
      
      num_nib_pl = num_f*2;
      curr_conv=0;
      curr_lane=0;
      consumed_nc = 0;
      avail_nc = num_nib_pl;
      print_info = 1'b1;

      
      for (int i = 0; i < 8 ; i++)begin
         start_pos[i] = 12'h0;
         for (int j = 0; j < 6 ; j++)   begin
            lane_nib_cnt[i][j]=8'h00;
         end
      end  
      
      if (num_cf == 0) num_nprime = num_n + num_cs;
      else num_nprime = num_n;
      while (num_nprime%4) num_nprime++;
      num_nprime = num_ntotal;
      num_nib_ps = num_nprime/4;
      num_nib_pc = num_nib_ps*num_s;

      while (1) begin
         // $display("Debug 1 curr_conv_balance_nc = 0x%0h, num_nib_pl = %0h, num_nib_pc = %0h, num_nib_ps = %0h, curr_conv = %0h, curr_lane = %0h, consumed_nc = %0h, avail_nc = %0h, num_nprime = %0h",curr_conv_balance_nc,num_nib_pl,num_nib_pc,num_nib_ps,curr_conv,curr_lane,consumed_nc,avail_nc,num_nprime);

         
         if (print_info) begin
            bit [3:0] temp1;
            bit [7:0] temp2;

            temp1 = curr_conv;
            temp2 = consumed_nc;
            

            
            if (curr_conv < num_data_conv) begin
              $display("LANE 0x%0h Nibble 0 Occupied by CONV 0x%0h Sample Nibble 0x%0h",curr_lane,curr_conv,consumed_nc);
               start_pos[curr_lane] = {temp1,temp2};               
            end
            else begin
              $display("LANE 0x%0h Nibble 0 Occupied by Tail Bits from Conv 5 Nibble 0 ",curr_lane);
               start_pos[curr_lane] = {4'h5,8'h00};               
            end
            print_info = 1'b0;                 
         end
         
         curr_conv_balance_nc = num_nib_pc-consumed_nc;                         
         if (curr_conv_balance_nc <= avail_nc) begin // required space is available on single lane
            lane_nib_cnt[curr_lane][curr_conv] = lane_nib_cnt[curr_lane][curr_conv] + curr_conv_balance_nc;
            //               $display("Debug 2 Lane 0x%0h Conv 0x%0h Nib Count = 0x%2h",curr_lane,curr_conv,lane_nib_cnt[curr_lane][curr_conv]);                 
            avail_nc = avail_nc - curr_conv_balance_nc;                 
            if (curr_conv < num_data_conv) begin 
               consumed_nc = 0;
               curr_conv++;      
            end
            
            if (curr_conv == num_data_conv) begin // Since we have exhausted all active conv we need to use CS bits or Tail bits
               if ((num_cf == 0) || (num_cs == 0)) begin
                  curr_conv = 5;
                  consumed_nc = 0 ;
               end
               else begin
                  curr_conv = 4;
                  consumed_nc = 0 ;                  
                  num_nib_pc = num_cs*num_s*num_data_conv;
                  while (num_nib_pc%4) num_nib_pc++;
                  num_nib_pc = num_nib_pc/4;                                    
               end
            end // if (curr_conv == num_data_conv)
            else if (curr_conv == 4) begin
               curr_conv = 5;
               consumed_nc = 0 ;
               num_nib_pc = num_nib_ps*num_s;               
            end
         end // if (curr_conv_balance_nc <= avail_nc)         
         else begin  // required space is not available on single lane so jump to subsequent lane after consuming curent lane
            if (num_hd == 1) begin
               consumed_nc = consumed_nc + avail_nc;                  
               lane_nib_cnt[curr_lane][curr_conv] = lane_nib_cnt[curr_lane][curr_conv] + avail_nc;
            end
            else begin
               while (num_nib_ps <= avail_nc) begin
                  avail_nc = avail_nc - num_nib_ps;
                  lane_nib_cnt[curr_lane][curr_conv] = lane_nib_cnt[curr_lane][curr_conv] + num_nib_ps;
                  consumed_nc = consumed_nc + num_nib_ps;
               end
               lane_nib_cnt[curr_lane][5] = lane_nib_cnt[curr_lane][5] + avail_nc; // Add Tail data bits to curr_lane as sample cannot be split across to lanes
            end // else: !if(num_hd == 1)
//            $display("Debug 3 Lane 0x%0h Conv 0x%0h Nib Count = 0x%2h",curr_lane,curr_conv,lane_nib_cnt[curr_lane][curr_conv]);                 
            avail_nc = num_nib_pl;
            print_info = 1'b1;
            if (curr_lane < num_lanes) 
              curr_lane++; 
         end // else: !if((num_nib_pc-consumed_nc) <= avail_nc)
         
         

         
         if (curr_lane == num_lanes) begin
            if (curr_conv < num_data_conv) begin
               $display ("%m @%0t ERROR: Increase num_lanes or num_f OR decrease num_nprime or num_s or num_data_conv",$time);
               $finish();
            end
            break;
         end
      end // while (1)
      
      for (int i = 0; i < 8 ; i++)begin
         for (int j = 0; j < 6 ; j++)   begin
//            if (lane_nib_cnt[i][j] != 'h0)
              $display("Lane 0x%0h Conv 0x%0h Nib Count = 0x%2h",i,j,lane_nib_cnt[i][j]);
         end
      end  

   endfunction // compute_user_params

   wire loc_enable_module = txrx_enablemodule_reg[0];
   
   always @ (posedge loc_enable_module) begin
     compute_user_params(
                       txrx_m_reg+1,
                       txrx_f_reg+1,
                       txrx_l_reg+1,
                       txrx_n_reg+1,
                       txrx_s_reg+1,
                       txrx_ntotal_reg+1,                       
                       txrx_cs_reg,
                       txrx_cf_reg,                       
                       txrx_hd_reg
                       );
   end

   
`endif //  `ifdef AUTO_COMPUTE_USER_PARAMS
`endif
   
endmodule // jesd_tx_core_register

//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
