


//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
`include "jesd_jesd204b_rx_defines.v" 


//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
`include "jesd_jesd204b_rx_address_defines.v" 



module jesd_rx_core_register
  #(
    parameter NO_LANES = 1,
    parameter NO_CONVERTERS = 1,
    parameter CSR_SELECT_MASK = 22'h000
   )
   (
    input                  rst_clk_character,
    input                  clk_character, 
    input                  clk_cpu,
    input                  rst,
       
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
   input  [31:0]      writedata, 
`endif

`ifdef I2C_IF
   input [7:0]       rf_addr,
   input             rf_wen,
   input             rf_ren,
   output reg [31:0] rf_rdata,
   input  [31:0]     rf_wdata, 
`endif


    input [NO_LANES-1:0]   ilas_mismatch,
    input [4*NO_LANES-1:0] jtspat_vld_count,
    input [4*NO_LANES-1:0] jtspat_err_count,
    input [4*NO_LANES-1:0] prbs_vld_count,
    input [4*NO_LANES-1:0] prbs_err_count,
    input [4*NO_LANES-1:0] incr_err_count,
    input [4*NO_LANES-1:0] incr_comma_frame_count,

    // Interrupt sources all from clk_character domain
    input [NO_LANES-1:0]   underrun_err,
    input [NO_LANES-1:0]   overrun_err,
    input [NO_LANES-1:0]   disparity_err,
    input [NO_LANES-1:0]   not_in_table_err,
    input [NO_LANES-1:0]   alignment_err,
    input [NO_LANES-1:0]   unexpected_k_err,
    input [NO_LANES-1:0]   cgs_sync_req,
    input [NO_LANES-1:0]   mframe_symbol_err, 
    input                  comb_cgs_sync_req,
    input                  captured_fw_sync_req,
    output                 fw_sync_req,
    output                 s_interrupt, 
    output reg [03:00]     txrx_bank_id_reg,
    output reg [07:00]     txrx_did_reg,
// `ifndef LANE_LONG

    // output reg [07:0]      prbs_test_enable_reg,
// `endif 
// `ifdef LANE_LONG
   //output reg [119:00]    txrx_lid_reg,
    // output reg [23:0]      prbs_test_enable_reg,
// `endif 
    output [5*NO_LANES-1:00]        txrx_lid_reg,
    output reg [NO_LANES-1:0]  prbs_test_enable_reg,
    output reg [NO_LANES-1:0]       active_lane,
    output reg [NO_CONVERTERS-1:0]  active_conv,    
    output reg [02:00]     txrx_subclass_reg,
    output reg [04:0]      txrx_cf_reg,
    output reg [01:0]      txrx_cs_reg,
    output reg [07:0]      txrx_f_reg,
    output reg [04:0]      txrx_k_reg,
    output reg [04:0]      txrx_l_reg,
    output reg [04:0]      txrx_n_reg,
    output reg [07:0]      txrx_m_reg,
    output reg [04:0]      txrx_ntotal_reg,
    output reg [04:0]      txrx_s_reg,
    output reg [00:0]      txrx_hd_reg,
    output reg [00:0]      txrx_scr_reg,
    output reg [00:0]      txrx_enablemodule_reg,
    output reg [01:0]      txrx_enablelinktest_reg,
    output reg [NO_LANES-1:0]      txrx_enable_jtspat_test_reg,
    

    output reg             txrx_ilas_disable,
    output                 txrx_lane_align_mon_disable,
    output                 txrx_lane_align_char_rep_disable,
    output                 txrx_resync_on_comma_disable, 
    output                 txrx_symbol_err_via_sync_disable,// MGH TBD doc update
    output reg [8:0]       txrx_ilas_length_mframe,// MGH TBD doc update
    output [10:0]          mframe_length_char,// MGH TBD doc update
    output [10:0]          rbd_char_cnt, // MGH TBD doc update
    output reg [8:0]       frame_length_char,
    output [NO_LANES-1:0]           inject_cgs_err,
    output [NO_LANES-1:0]           inject_not_in_table_err,
    output [NO_LANES-1:0]           inject_lane_alignment_err,
    output [NO_LANES-1:0]           inject_frame_alignment_err, 
    output reg [3:0]       min_sync_duration,
    output reg [7:0]       sum_ilas_com_param,
    output reg  [1:0]      clk_ratio,              // Ratio of clk_character to clk_sample: "00": 1:1, "01": 1:2, "10": 1:4
    output reg [47:0]      tl_spec_param
    );

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

   
   assign fw_sync_req = 1'b0; // MGH TBD logic and doc pending 

`ifndef   RX_RESET_VALUES
  `define RX_CS_RESET_VALUE 2'h0
  `define RX_F_RESET_VALUE 8'h0
  `define RX_L_RESET_VALUE 5'h3
  `define RX_N_RESET_VALUE 5'hF
  `define RX_M_RESET_VALUE 8'h3
  `define RX_NTOTAL_RESET_VALUE 5'hf
  `define RX_S_RESET_VALUE 5'h0
  `define RX_CF_RESET_VALUE 18'h0
  `define RX_LID_RESET_VALUE {5'h5,5'h4,5'h3,5'h2,5'h1,5'h0}
  `define RX_LID2_RESET_VALUE {5'hb,5'ha,5'h9,5'h8,5'h7,5'h6}
  `define RX_LID3_RESET_VALUE {5'h11,5'h10,5'hf,5'he,5'hd,5'hc}
  `define RX_LID4_RESET_VALUE {5'h17,5'h16,5'h15,5'h14,5'h13,5'h12}
  `define RX_BID_RESET_VALUE 4'h0
  `define RX_DID_RESET_VALUE 8'h0
  `define RX_SUBCLASS_RESET_VALUE 3'h1
  `define RX_K_RESET_VALUE 5'h10
  `define RX_HD_RESET_VALUE 1'h0
  `define RX_SCR_RESET_VALUE 1'h0
  `define RX_ILAS_DETAILS_RESET_VALUE 32'h03011011
  `define RX_INTMASK_RESET_VALUE {9{1'b1}}
  `define RX_FEAT_DIS_RESET_VALUE  6'h0
  `define RX_CLK_RATIO_RESET_VALUE 2'h0
`endif 




   reg  [7:0]         cf_first_nib;
   reg  [4:0]         cf_first_ln;

   reg [31:0]            reg_addr_int;
   reg                   reg_write_int;
   reg                   reg_read_int;
   reg                   reg_read_int_r;   
   reg [31:0]            reg_wdata_int;
   reg [31:0]            rd_data_mux;
   reg                   rd_ack;

   reg [NO_LANES-1:0]    ilas_mismatch_r;   
   wire [NO_LANES-1:0]    ilas_status, ilas_status_rd_ack_per_lane;
   reg ilas_status_rd_req ;
   reg ilas_status_rd_ack;
   wire txrx_ilas_comparison_disable;
      
/*    `ifdef LANE_LONG   
   wire [(32*24)-1:0] linktest_errorcounter;
   wire [(32*24)-1:0] linktest_receivecounter;
   wire [(32*24)-1:0] jtspat_test_receivecounter;
   wire [(32*24)-1:0] jtspat_test_errorcounter;
   wire [(32*24)-1:0] prbs_test_errorcounter;
   wire [(32*24)-1:0] prbs_test_receivecounter;
   wire [23:0]    rd_ack_errorcounter;   
   reg  [23:0]    rd_req_errorcounter;  
   wire [23:0]    rd_ack_jtspat_errorcounter;   
   reg  [23:0]    rd_req_jtspat_errorcounter;   
   wire [23:0]    rd_ack_jtspat_receivecounter;
   reg  [23:0]    rd_req_jtspat_receivecounter; 
   wire [23:0]    rd_ack_prbs_errorcounter;
   reg  [23:0]    rd_req_prbs_errorcounter;   
   wire [23:0]    rd_ack_prbs_receivecounter;
   reg  [23:0]    rd_req_prbs_receivecounter; 
   wire [23:0]    rd_ack_receivecounter;
   reg  [23:0]    rd_req_receivecounter;
   `endif */
//   `ifndef LANE_LONG   
   reg  [NO_LANES-1:0]    rd_req_errorcounter;   
   wire [NO_LANES-1:0]    rd_ack_errorcounter;   
   wire [NO_LANES-1:0]    rd_ack_jtspat_errorcounter;   
   reg  [NO_LANES-1:0]    rd_req_jtspat_errorcounter;   
   wire [NO_LANES-1:0]    rd_ack_jtspat_receivecounter;
   reg  [NO_LANES-1:0]    rd_req_jtspat_receivecounter; 
   wire [NO_LANES-1:0]    rd_ack_prbs_errorcounter;
   reg  [NO_LANES-1:0]    rd_req_prbs_errorcounter;  
   wire [NO_LANES-1:0]    rd_ack_prbs_receivecounter; 
   reg  [NO_LANES-1:0]    rd_req_prbs_receivecounter;   
   wire [NO_LANES-1:0]    rd_ack_receivecounter;
   reg  [NO_LANES-1:0]    rd_req_receivecounter;
   wire [(32*NO_LANES)-1:0] linktest_errorcounter;
   wire [(32*NO_LANES)-1:0] linktest_receivecounter;
   wire [(32*NO_LANES)-1:0] jtspat_test_receivecounter;
   wire [(32*NO_LANES)-1:0] jtspat_test_errorcounter;
   wire [(32*NO_LANES)-1:0] prbs_test_errorcounter;
   wire [(32*NO_LANES)-1:0] prbs_test_receivecounter;

//   `endif
   // wire [NO_LANES-1:0]    rd_ack_errorcounter;
   // reg [NO_LANES-1:0]    rd_req_errorcounter;   
   
   // wire [NO_LANES-1:0]    rd_ack_jtspat_errorcounter;
   // reg [NO_LANES-1:0]    rd_req_jtspat_errorcounter;   
   // wire [NO_LANES-1:0]    rd_ack_jtspat_receivecounter;
   // reg [NO_LANES-1:0]    rd_req_jtspat_receivecounter; 
   
   // wire [NO_LANES-1:0]    rd_ack_prbs_errorcounter;
   // reg [NO_LANES-1:0]    rd_req_prbs_errorcounter;   
   // wire [NO_LANES-1:0]    rd_ack_prbs_receivecounter;
   // reg [NO_LANES-1:0]    rd_req_prbs_receivecounter; 
   
   
   // wire [NO_LANES-1:0]    rd_ack_receivecounter;
   // reg [NO_LANES-1:0]    rd_req_receivecounter;

   reg [5:0]              rx_feature_disable;     
   reg [8:0]              rx_core_interrupt_mask;
   reg [31:0]             rx_err_inj_req;
   reg [31:0]             rx_ilas_details;

   wire [8:0]              rx_core_interrupt;
   reg                     any_underrun_err;
   reg                     any_overrun_err;
   reg                     any_disparity_err;
   reg                     any_not_in_table_err;
   reg                     any_alignment_err;
   reg                     any_unexpected_k_err;
   reg [8:0]               interrupt_rd_val;
   wire                     rd_interrupt_ack;
   
   
   wire                    rd_interrupt;
   reg                     rd_interrupt_r;
   

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
        else
          reg_addr_int <= 32'h0;  
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


 `ifdef AVALON_BUS
 
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
// generate
// begin
  // if (NO_LANES > 6)
    wire txrx_lid_cs2             = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_LID2;
//  if (NO_LANES > 12)   
    wire txrx_lid_cs3             = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_LID3;
//  if (NO_LANES > 18)   
    wire txrx_lid_cs4             = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_LID4;
//end
//endgenerate   

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


   wire txrx_enablemodule_cs          = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_ENABLEMODULE         ;
   wire txrx_enablelinktest_cs        = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_TXRX_ENABLELINKTEST       ;
   wire rx_feature_disable_cs           = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_FEATURE_DISABLE            ;
   wire tx_rx_enable_jtspat_test_cs         = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_ENABLEJTSPATTEST            ;
   

   wire rx_ilas_details_cs              = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_ILAS_DETAILS               ;
   wire rx_err_inj_req_cs               = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_ERR_INJ_REQ                ;
   wire rx_core_interrupt_mask_cs       = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_CORE_INTERRUPT_MASK        ;
   
   wire rx_linkconfigurationerror_cs  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKCONFIGURATIONERROR ;

   wire prbs_test_enable_reg_cs = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_PRBS_TEST_ENABLE  ;

   


   wire rx_core_interrupt_status_cs     = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_CORE_INTERRUPT_STATUS      ;
   wire rx_clk_ratio_cs                 = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_CLK_RATIO                  ;
   


         
	wire [NO_LANES-1:0] rx_prbs_errorcounter_cs;               
  generate
   if(NO_LANES >0) begin :  L0_BLK assign rx_prbs_errorcounter_cs [0]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_0_ERRORCOUNTER  ; end
   if(NO_LANES >1) begin :  L1_BLK assign rx_prbs_errorcounter_cs [1] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_1_ERRORCOUNTER  ; end
   if(NO_LANES >2) begin :  L2_BLK assign rx_prbs_errorcounter_cs [2] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_2_ERRORCOUNTER  ; end
   if(NO_LANES >3) begin :  L3_BLK assign rx_prbs_errorcounter_cs [3]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_3_ERRORCOUNTER  ; end
   if(NO_LANES >4) begin :  L4_BLK assign rx_prbs_errorcounter_cs [4]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_4_ERRORCOUNTER  ; end
   if(NO_LANES >5) begin :  L5_BLK assign rx_prbs_errorcounter_cs [5]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_5_ERRORCOUNTER  ; end
   if(NO_LANES >6) begin :  L6_BLK assign rx_prbs_errorcounter_cs [6]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_6_ERRORCOUNTER  ; end
   if(NO_LANES >7) begin :  L7_BLK assign rx_prbs_errorcounter_cs [7]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_7_ERRORCOUNTER  ; end
   if(NO_LANES >8) begin :  L8_BLK assign rx_prbs_errorcounter_cs [8]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_8_ERRORCOUNTER  ; end
   if(NO_LANES >9) begin :  L9_BLK assign rx_prbs_errorcounter_cs [9]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_9_ERRORCOUNTER  ; end
   if(NO_LANES >10) begin : L10_BLK assign rx_prbs_errorcounter_cs [10]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_10_ERRORCOUNTER  ; end 
   if(NO_LANES >11) begin : L11_BLK assign rx_prbs_errorcounter_cs [11]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_11_ERRORCOUNTER  ; end 
   if(NO_LANES >12) begin : L12_BLK assign rx_prbs_errorcounter_cs [12]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_12_ERRORCOUNTER  ; end 
   if(NO_LANES >13) begin : L13_BLK assign rx_prbs_errorcounter_cs [13]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_13_ERRORCOUNTER  ; end 
   if(NO_LANES >14) begin : L14_BLK assign rx_prbs_errorcounter_cs [14]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_14_ERRORCOUNTER  ; end 
   if(NO_LANES >15) begin : L15_BLK assign rx_prbs_errorcounter_cs [15]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_15_ERRORCOUNTER  ; end       
   if(NO_LANES >16) begin : L16_BLK assign rx_prbs_errorcounter_cs [16]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_16_ERRORCOUNTER  ; end 
   if(NO_LANES >17) begin : L17_BLK assign rx_prbs_errorcounter_cs [17]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_17_ERRORCOUNTER  ; end 
   if(NO_LANES >18) begin : L18_BLK assign rx_prbs_errorcounter_cs [18]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_18_ERRORCOUNTER  ; end 
   if(NO_LANES >19) begin : L19_BLK assign rx_prbs_errorcounter_cs [19]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_19_ERRORCOUNTER  ; end 
   if(NO_LANES >20) begin : L20_BLK assign rx_prbs_errorcounter_cs [20]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_20_ERRORCOUNTER  ; end 
   if(NO_LANES >21) begin : L21_BLK assign rx_prbs_errorcounter_cs [21]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_21_ERRORCOUNTER  ; end 
   if(NO_LANES >22) begin : L22_BLK assign rx_prbs_errorcounter_cs [22]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_22_ERRORCOUNTER  ; end 
   if(NO_LANES >23) begin : L23_BLK assign rx_prbs_errorcounter_cs [23]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_23_ERRORCOUNTER  ; end 
   endgenerate
   wire [NO_LANES-1:0] rx_jtspat_test_errorcounter_cs;
   
   generate
   if(NO_LANES >0) begin :  LJ0_BLK assign rx_jtspat_test_errorcounter_cs [0]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_0_ERRORCOUNTER    ; end
   if(NO_LANES >1) begin :  LJ1_BLK assign rx_jtspat_test_errorcounter_cs [1]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_1_ERRORCOUNTER    ; end
   if(NO_LANES >2) begin :  LJ2_BLK assign rx_jtspat_test_errorcounter_cs [2]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_2_ERRORCOUNTER    ; end
   if(NO_LANES >3) begin :  LJ3_BLK assign rx_jtspat_test_errorcounter_cs [3]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_3_ERRORCOUNTER    ; end
   if(NO_LANES >4) begin :  LJ4_BLK assign rx_jtspat_test_errorcounter_cs [4]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_4_ERRORCOUNTER    ; end
   if(NO_LANES >5) begin :  LJ5_BLK assign rx_jtspat_test_errorcounter_cs [5]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_5_ERRORCOUNTER    ; end
   if(NO_LANES >6) begin :  LJ6_BLK assign rx_jtspat_test_errorcounter_cs [6]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_6_ERRORCOUNTER    ; end
   if(NO_LANES >7) begin :  LJ7_BLK assign rx_jtspat_test_errorcounter_cs [7]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_7_ERRORCOUNTER    ; end
   if(NO_LANES >8) begin :  LJ8_BLK assign rx_jtspat_test_errorcounter_cs [8]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_8_ERRORCOUNTER    ; end
   if(NO_LANES >9) begin :  LJ9_BLK assign rx_jtspat_test_errorcounter_cs [9]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_9_ERRORCOUNTER    ; end
   if(NO_LANES >10) begin : LJ10_BLK assign rx_jtspat_test_errorcounter_cs [10]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_10_ERRORCOUNTER    ; end
   if(NO_LANES >11) begin : LJ11_BLK assign rx_jtspat_test_errorcounter_cs [11]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_11_ERRORCOUNTER    ; end
   if(NO_LANES >12) begin : LJ12_BLK assign rx_jtspat_test_errorcounter_cs [12]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_12_ERRORCOUNTER    ; end
   if(NO_LANES >13) begin : LJ13_BLK assign rx_jtspat_test_errorcounter_cs [13]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_13_ERRORCOUNTER    ; end
   if(NO_LANES >14) begin : LJ14_BLK assign rx_jtspat_test_errorcounter_cs [14]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_14_ERRORCOUNTER    ; end
   if(NO_LANES >15) begin : LJ15_BLK assign rx_jtspat_test_errorcounter_cs [15]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_15_ERRORCOUNTER    ; end
   if(NO_LANES >16) begin : LJ16_BLK assign rx_jtspat_test_errorcounter_cs [16]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_16_ERRORCOUNTER    ; end
   if(NO_LANES >17) begin : LJ17_BLK assign rx_jtspat_test_errorcounter_cs [17]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_17_ERRORCOUNTER    ; end
   if(NO_LANES >18) begin : LJ18_BLK assign rx_jtspat_test_errorcounter_cs [18]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_18_ERRORCOUNTER    ; end
   if(NO_LANES >19) begin : LJ19_BLK assign rx_jtspat_test_errorcounter_cs [19]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_19_ERRORCOUNTER    ; end   
   if(NO_LANES >20) begin : LJ20_BLK assign rx_jtspat_test_errorcounter_cs [20]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_20_ERRORCOUNTER    ; end
   if(NO_LANES >21) begin : LJ21_BLK assign rx_jtspat_test_errorcounter_cs [21]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_21_ERRORCOUNTER    ; end
   if(NO_LANES >22) begin : LJ22_BLK assign rx_jtspat_test_errorcounter_cs [22] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_22_ERRORCOUNTER    ; end
   if(NO_LANES >23) begin : LJ23_BLK assign rx_jtspat_test_errorcounter_cs [23]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_23_ERRORCOUNTER    ; end
   endgenerate
   
   wire [NO_LANES-1:0] rx_jtspat_test_receivecounter_cs;
   
   generate
   if(NO_LANES >0 ) begin : LJR0_BLK assign rx_jtspat_test_receivecounter_cs [0]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_0_RECEIVECOUNTER  ; end
   if(NO_LANES >1 ) begin : LJR1_BLK assign rx_jtspat_test_receivecounter_cs [1]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_1_RECEIVECOUNTER  ; end
   if(NO_LANES >2 ) begin : LJR2_BLK assign rx_jtspat_test_receivecounter_cs [2]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_2_RECEIVECOUNTER  ; end
   if(NO_LANES >3 ) begin : LJR3_BLK assign rx_jtspat_test_receivecounter_cs [3]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_3_RECEIVECOUNTER  ; end
   if(NO_LANES >4 ) begin : LJR4_BLK assign rx_jtspat_test_receivecounter_cs [4]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_4_RECEIVECOUNTER  ; end
   if(NO_LANES >5 ) begin : LJR5_BLK assign rx_jtspat_test_receivecounter_cs [5]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_5_RECEIVECOUNTER  ; end
   if(NO_LANES >6 ) begin : LJR6_BLK assign rx_jtspat_test_receivecounter_cs [6]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_6_RECEIVECOUNTER  ; end
   if(NO_LANES >7 ) begin : LJR7_BLK assign rx_jtspat_test_receivecounter_cs [7]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_7_RECEIVECOUNTER  ; end
   if(NO_LANES >8 ) begin : LJR8_BLK assign rx_jtspat_test_receivecounter_cs [8]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_8_RECEIVECOUNTER  ; end
   if(NO_LANES >9 ) begin : LJR9_BLK assign rx_jtspat_test_receivecounter_cs [9]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_9_RECEIVECOUNTER  ; end
   if(NO_LANES >10) begin : LJR10_BLK assign rx_jtspat_test_receivecounter_cs [10]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_10_RECEIVECOUNTER  ; end
   if(NO_LANES >11) begin : LJR11_BLK assign rx_jtspat_test_receivecounter_cs [11]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_11_RECEIVECOUNTER  ; end
   if(NO_LANES >12) begin : LJR12_BLK assign rx_jtspat_test_receivecounter_cs [12]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_12_RECEIVECOUNTER  ; end
   if(NO_LANES >13) begin : LJR13_BLK assign rx_jtspat_test_receivecounter_cs [13]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_13_RECEIVECOUNTER  ; end
   if(NO_LANES >14) begin : LJR14_BLK assign rx_jtspat_test_receivecounter_cs [14]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_14_RECEIVECOUNTER  ; end
   if(NO_LANES >15) begin : LJR15_BLK assign rx_jtspat_test_receivecounter_cs [15]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_15_RECEIVECOUNTER  ; end
   if(NO_LANES >16) begin : LJR16_BLK assign rx_jtspat_test_receivecounter_cs [16]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_16_RECEIVECOUNTER  ; end
   if(NO_LANES >17) begin : LJR17_BLK assign rx_jtspat_test_receivecounter_cs [17]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_17_RECEIVECOUNTER  ; end
   if(NO_LANES >18) begin : LJR18_BLK assign rx_jtspat_test_receivecounter_cs [18]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_18_RECEIVECOUNTER  ; end
   if(NO_LANES >19) begin : LJR19_BLK assign rx_jtspat_test_receivecounter_cs [19]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_19_RECEIVECOUNTER  ; end
   if(NO_LANES >20) begin : LJR20_BLK assign rx_jtspat_test_receivecounter_cs [20]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_20_RECEIVECOUNTER  ; end
   if(NO_LANES >21) begin : LJR21_BLK assign rx_jtspat_test_receivecounter_cs [21]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_21_RECEIVECOUNTER  ; end
   if(NO_LANES >22) begin : LJR22_BLK assign rx_jtspat_test_receivecounter_cs [22]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_22_RECEIVECOUNTER  ; end
   if(NO_LANES >23) begin : LJR23_BLK assign rx_jtspat_test_receivecounter_cs [23]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_JTSPAT_TEST_23_RECEIVECOUNTER  ; end
endgenerate
  
  wire [NO_LANES-1:0] rx_prbs_receivecounter_cs;
   generate
   if(NO_LANES >0 )begin  : LPR0_BLK assign rx_prbs_receivecounter_cs [0] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_0_RECEIVECOUNTER  ; end
   if(NO_LANES >1 )begin  : LPR1_BLK assign rx_prbs_receivecounter_cs [1] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_1_RECEIVECOUNTER  ; end
   if(NO_LANES >2 )begin  : LPR2_BLK assign rx_prbs_receivecounter_cs [2]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_2_RECEIVECOUNTER  ; end
   if(NO_LANES >3 )begin  : LPR3_BLK assign rx_prbs_receivecounter_cs [3]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_3_RECEIVECOUNTER  ; end
   if(NO_LANES >4 )begin  : LPR4_BLK assign rx_prbs_receivecounter_cs [4]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_4_RECEIVECOUNTER  ; end
   if(NO_LANES >5 )begin  : LPR5_BLK assign rx_prbs_receivecounter_cs [5]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_5_RECEIVECOUNTER  ; end
   if(NO_LANES >6 )begin  : LPR6_BLK assign rx_prbs_receivecounter_cs [6]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_6_RECEIVECOUNTER  ; end
   if(NO_LANES >7 )begin  : LPR7_BLK assign rx_prbs_receivecounter_cs [7]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_7_RECEIVECOUNTER  ; end
   if(NO_LANES >8 )begin  : LPR8_BLK assign rx_prbs_receivecounter_cs [8]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_8_RECEIVECOUNTER  ; end
   if(NO_LANES >9 ) begin : LPR9_BLK assign rx_prbs_receivecounter_cs [9]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_9_RECEIVECOUNTER  ; end
   if(NO_LANES >10) begin : LPR10_BLK assign rx_prbs_receivecounter_cs[10] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_10_RECEIVECOUNTER  ; end
   if(NO_LANES >11) begin : LPR11_BLK assign rx_prbs_receivecounter_cs[11] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_11_RECEIVECOUNTER  ; end
   if(NO_LANES >12) begin : LPR12_BLK assign rx_prbs_receivecounter_cs[12] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_12_RECEIVECOUNTER  ; end
   if(NO_LANES >13) begin : LPR13_BLK assign rx_prbs_receivecounter_cs[13] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_13_RECEIVECOUNTER  ; end
   if(NO_LANES >14) begin : LPR14_BLK assign rx_prbs_receivecounter_cs[14] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_14_RECEIVECOUNTER  ; end
   if(NO_LANES >15) begin : LPR15_BLK assign rx_prbs_receivecounter_cs[15]= ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_15_RECEIVECOUNTER  ; end
   if(NO_LANES >16) begin : LPR16_BLK assign rx_prbs_receivecounter_cs[16] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_16_RECEIVECOUNTER  ; end
   if(NO_LANES >17) begin : LPR17_BLK assign rx_prbs_receivecounter_cs[17] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_17_RECEIVECOUNTER  ; end
   if(NO_LANES >18) begin : LPR18_BLK assign rx_prbs_receivecounter_cs[18] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_18_RECEIVECOUNTER  ; end
   if(NO_LANES >19) begin : LPR19_BLK assign rx_prbs_receivecounter_cs[19] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_19_RECEIVECOUNTER  ; end
   if(NO_LANES >20) begin : LPR20_BLK assign rx_prbs_receivecounter_cs[20] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_20_RECEIVECOUNTER  ; end
   if(NO_LANES >21) begin : LPR21_BLK assign rx_prbs_receivecounter_cs[21] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_21_RECEIVECOUNTER  ; end
   if(NO_LANES >22) begin : LPR22_BLK assign rx_prbs_receivecounter_cs[22] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_22_RECEIVECOUNTER  ; end
   if(NO_LANES >23) begin : LPR23_BLK assign rx_prbs_receivecounter_cs[23] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_PRBS_TEST_23_RECEIVECOUNTER  ; end   
endgenerate

   wire [NO_LANES-1:0] rx_linktest_errorcounter_cs;
   generate 
   if(NO_LANES >0 ) begin : LTE0_BLK assign rx_linktest_errorcounter_cs [0]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_0_ERRORCOUNTER    ; end
   if(NO_LANES >1 ) begin : LTE1_BLK assign rx_linktest_errorcounter_cs [1]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_1_ERRORCOUNTER    ; end
   if(NO_LANES >2 ) begin : LTE2_BLK assign rx_linktest_errorcounter_cs [2]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_2_ERRORCOUNTER    ; end
   if(NO_LANES >3 ) begin : LTE3_BLK assign rx_linktest_errorcounter_cs [3]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_3_ERRORCOUNTER    ; end
   if(NO_LANES >4 ) begin : LTE4_BLK assign rx_linktest_errorcounter_cs [4]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_4_ERRORCOUNTER    ; end
   if(NO_LANES >5 ) begin : LTE5_BLK assign rx_linktest_errorcounter_cs [5]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_5_ERRORCOUNTER    ; end
   if(NO_LANES >6 ) begin : LTE6_BLK assign rx_linktest_errorcounter_cs [6]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_6_ERRORCOUNTER    ; end
   if(NO_LANES >7 ) begin : LTE7_BLK assign rx_linktest_errorcounter_cs [7]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_7_ERRORCOUNTER    ; end
   if(NO_LANES >8 ) begin : LTE8_BLK assign rx_linktest_errorcounter_cs [8]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_8_ERRORCOUNTER    ; end
   if(NO_LANES >9 ) begin : LTE9_BLK assign rx_linktest_errorcounter_cs [9]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_9_ERRORCOUNTER    ; end
   if(NO_LANES >10) begin : LTE10_BLK assign rx_linktest_errorcounter_cs [10]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_10_ERRORCOUNTER    ; end
   if(NO_LANES >11) begin : LTE11_BLK assign rx_linktest_errorcounter_cs [11]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_11_ERRORCOUNTER    ; end
   if(NO_LANES >12) begin : LTE12_BLK assign rx_linktest_errorcounter_cs [12]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_12_ERRORCOUNTER    ; end
   if(NO_LANES >13) begin : LTE13_BLK assign rx_linktest_errorcounter_cs [13]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_13_ERRORCOUNTER    ; end
   if(NO_LANES >14) begin : LTE14_BLK assign rx_linktest_errorcounter_cs [14]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_14_ERRORCOUNTER    ; end
   if(NO_LANES >15) begin : LTE15_BLK assign rx_linktest_errorcounter_cs [15]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_15_ERRORCOUNTER    ; end
   if(NO_LANES >16) begin : LTE16_BLK assign rx_linktest_errorcounter_cs [16]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_16_ERRORCOUNTER    ; end
   if(NO_LANES >17) begin : LTE17_BLK assign rx_linktest_errorcounter_cs [17]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_17_ERRORCOUNTER    ; end
   if(NO_LANES >18) begin : LTE18_BLK assign rx_linktest_errorcounter_cs [18]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_18_ERRORCOUNTER    ; end
   if(NO_LANES >19) begin : LTE19_BLK assign rx_linktest_errorcounter_cs [19]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_19_ERRORCOUNTER    ; end
   if(NO_LANES >20) begin : LTE20_BLK assign rx_linktest_errorcounter_cs [20]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_20_ERRORCOUNTER    ; end
   if(NO_LANES >21) begin : LTE21_BLK assign rx_linktest_errorcounter_cs [21]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_21_ERRORCOUNTER    ; end
   if(NO_LANES >22) begin : LTE22_BLK assign rx_linktest_errorcounter_cs [22] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_22_ERRORCOUNTER    ; end
   if(NO_LANES >23) begin : LTE23_BLK assign rx_linktest_errorcounter_cs [23]  = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_23_ERRORCOUNTER    ; end
   endgenerate

   wire [NO_LANES-1:0] rx_linktest_receivecounter_cs;
   generate
   if(NO_LANES >0)begin : LTR0_BLK assign rx_linktest_receivecounter_cs [0] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_0_RECEIVECOUNTER  ; end
   if(NO_LANES >1)begin : LTR1_BLK assign rx_linktest_receivecounter_cs[1] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_1_RECEIVECOUNTER  ; end
   if(NO_LANES >2)begin : LTR2_BLK assign rx_linktest_receivecounter_cs[2] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_2_RECEIVECOUNTER  ; end
   if(NO_LANES >3)begin : LTR3_BLK assign rx_linktest_receivecounter_cs[3] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_3_RECEIVECOUNTER  ; end
   if(NO_LANES >4)begin : LTR4_BLK assign rx_linktest_receivecounter_cs[4] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_4_RECEIVECOUNTER  ; end
   if(NO_LANES >5)begin : LTR5_BLK assign rx_linktest_receivecounter_cs[5] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_5_RECEIVECOUNTER  ; end
   if(NO_LANES >6)begin : LTR6_BLK assign rx_linktest_receivecounter_cs[6] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_6_RECEIVECOUNTER  ; end
   if(NO_LANES >7)begin : LTR7_BLK assign rx_linktest_receivecounter_cs[7] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_7_RECEIVECOUNTER  ; end
   if(NO_LANES >8)begin : LTR8_BLK assign rx_linktest_receivecounter_cs[8] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_8_RECEIVECOUNTER  ; end
   if(NO_LANES >9)begin : LTR9_BLK assign rx_linktest_receivecounter_cs[9] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_9_RECEIVECOUNTER  ; end
   if(NO_LANES >10)begin : LTR10_BLK assign rx_linktest_receivecounter_cs[10] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_10_RECEIVECOUNTER  ; end
   if(NO_LANES >11)begin : LTR11_BLK assign rx_linktest_receivecounter_cs[11] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_11_RECEIVECOUNTER  ; end
   if(NO_LANES >12)begin : LTR12_BLK assign rx_linktest_receivecounter_cs[12] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_12_RECEIVECOUNTER  ; end
   if(NO_LANES >13)begin : LTR13_BLK assign rx_linktest_receivecounter_cs[13] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_13_RECEIVECOUNTER  ; end
   if(NO_LANES >14)begin : LTR14_BLK assign rx_linktest_receivecounter_cs[14] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_14_RECEIVECOUNTER  ; end
   if(NO_LANES >15)begin : LTR15_BLK assign rx_linktest_receivecounter_cs[15] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_15_RECEIVECOUNTER  ; end
   if(NO_LANES >16)begin : LTR16_BLK assign rx_linktest_receivecounter_cs[16] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_16_RECEIVECOUNTER  ; end
   if(NO_LANES >17)begin : LTR17_BLK assign rx_linktest_receivecounter_cs[17] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_17_RECEIVECOUNTER  ; end
   if(NO_LANES >18)begin : LTR18_BLK assign rx_linktest_receivecounter_cs[18] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_18_RECEIVECOUNTER  ; end
   if(NO_LANES >19)begin : LTR19_BLK assign rx_linktest_receivecounter_cs[19] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_19_RECEIVECOUNTER  ; end
   if(NO_LANES >20)begin : LTR20_BLK assign rx_linktest_receivecounter_cs[20] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_20_RECEIVECOUNTER  ; end
   if(NO_LANES >21)begin : LTR21_BLK assign rx_linktest_receivecounter_cs[21] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_21_RECEIVECOUNTER  ; end
   if(NO_LANES >22)begin : LTR22_BLK assign rx_linktest_receivecounter_cs[22] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_22_RECEIVECOUNTER  ; end
   if(NO_LANES >23)begin : LTR23_BLK assign rx_linktest_receivecounter_cs[23] = ~up_addr_match ? 1'b0 : reg_addr_int[9:0] == `PARAM_RX_LINKTEST_23_RECEIVECOUNTER  ; end

   endgenerate

   

               
			   


               
                  
   
   `define RW_REG_W_MACRO(storage_name,rst_value,wr_enable,write_value) \
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

   `RW_REG_W_MACRO(txrx_cs_reg[1:0], `RX_CS_RESET_VALUE, txrx_cs_cs, reg_wdata_int[1:0])
   `RW_REG_W_MACRO(txrx_f_reg[7:0], `RX_F_RESET_VALUE, txrx_f_cs, reg_wdata_int[7:0])
   `RW_REG_W_MACRO(txrx_l_reg[4:0], `RX_L_RESET_VALUE, txrx_l_cs, reg_wdata_int[4:0])
   `RW_REG_W_MACRO(txrx_n_reg[4:0], `RX_N_RESET_VALUE, txrx_n_cs, reg_wdata_int[4:0])
   `RW_REG_W_MACRO(txrx_m_reg[7:0], `RX_M_RESET_VALUE, txrx_m_cs, reg_wdata_int[7:0])
   `RW_REG_W_MACRO(txrx_ntotal_reg[4:0], `RX_NTOTAL_RESET_VALUE, txrx_ntotal_cs, reg_wdata_int[4:0])
   `RW_REG_W_MACRO(txrx_s_reg[4:0], `RX_S_RESET_VALUE, txrx_s_cs, reg_wdata_int[4:0])  
   `RW_REG_W_MACRO({cf_first_nib[7:0],cf_first_ln[4:0],txrx_cf_reg[4:0]}, `RX_CF_RESET_VALUE, txrx_cf_cs, reg_wdata_int[17:0]) 
`endif   

   `RW_REG_W_MACRO(txrx_lid_reg_r[29:0], `RX_LID_RESET_VALUE, txrx_lid_cs, reg_wdata_int[31:0])
    generate
//    begin
      if(NO_LANES > 6) begin : NL6_BLK
        `RW_REG_W_MACRO(txrx_lid_reg_r[59:30], `RX_LID2_RESET_VALUE, txrx_lid_cs2, reg_wdata_int[31:0])
      end
      if (NO_LANES >12) begin : NL12_BLK
        `RW_REG_W_MACRO(txrx_lid_reg_r[89:60], `RX_LID3_RESET_VALUE, txrx_lid_cs3, reg_wdata_int[31:0])
      end
      if (NO_LANES >18) begin : NL18_BLK
        `RW_REG_W_MACRO(txrx_lid_reg_r[119:90], `RX_LID4_RESET_VALUE, txrx_lid_cs4, reg_wdata_int[31:0])
      end
//    end   
   endgenerate
   
   `RW_REG_W_MACRO(txrx_bank_id_reg[3:0],`RX_BID_RESET_VALUE, txrx_bank_id_cs, reg_wdata_int[3:0])
   `RW_REG_W_MACRO(txrx_did_reg[7:0], `RX_DID_RESET_VALUE, txrx_did_cs, reg_wdata_int[7:0])

   `RW_REG_W_MACRO(txrx_subclass_reg[2:0], `RX_SUBCLASS_RESET_VALUE, txrx_subclass_cs, reg_wdata_int[2:0])
   `RW_REG_W_MACRO(txrx_k_reg[4:0], `RX_K_RESET_VALUE, txrx_k_cs, reg_wdata_int[4:0])
   `RW_REG_W_MACRO(txrx_hd_reg[0], `RX_HD_RESET_VALUE, txrx_hd_cs, reg_wdata_int[0])
   `RW_REG_W_MACRO(txrx_scr_reg[0], `RX_SCR_RESET_VALUE, txrx_scr_cs, reg_wdata_int[0])
   `RW_REG_W_MACRO(txrx_enablemodule_reg[0], 1'h0, txrx_enablemodule_cs, reg_wdata_int[0])
   `RW_REG_W_MACRO(txrx_enablelinktest_reg[1:0], 2'h0, txrx_enablelinktest_cs, reg_wdata_int[1:0])
   `RW_REG_W_MACRO(txrx_enable_jtspat_test_reg[NO_LANES-1:0], 32'h0, tx_rx_enable_jtspat_test_cs, reg_wdata_int[7:0])
   `RW_REG_W_MACRO(prbs_test_enable_reg[NO_LANES-1:0], 8'h0, prbs_test_enable_reg_cs, reg_wdata_int[7:0])
   `RW_REG_W_MACRO(rx_feature_disable[5:0], `RX_FEAT_DIS_RESET_VALUE, rx_feature_disable_cs, reg_wdata_int[5:0])
   `RW_REG_W_MACRO(rx_ilas_details[31:0], `RX_ILAS_DETAILS_RESET_VALUE, rx_ilas_details_cs, reg_wdata_int[31:0])
   `RW_REG_W_MACRO(rx_core_interrupt_mask[8:0], `RX_INTMASK_RESET_VALUE, rx_core_interrupt_mask_cs, reg_wdata_int[8:0])   
   `RW_REG_W_MACRO(rx_err_inj_req[31:0],32'h0,rx_err_inj_req_cs,reg_wdata_int[31:0] ^ rx_err_inj_req)
   `RW_REG_W_MACRO(clk_ratio[1:0], `RX_CLK_RATIO_RESET_VALUE, rx_clk_ratio_cs, reg_wdata_int[1:0])   

   reg [31:0] counter;
   
//generate 
//begin  
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
               
              begin
                if (NO_LANES >6)
                  rd_data_mux [29:0] =       txrx_lid_reg_r[59:30];
                
                rd_ack = reg_read_int;
              end
              
           end            
           `PARAM_TXRX_LID3 : begin
              if (NO_LANES >12)
                rd_data_mux [29:0] =       txrx_lid_reg_r[89:60];
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_LID4 : begin
              if (NO_LANES >18)
                rd_data_mux [29:0] =       txrx_lid_reg_r[119:90];
              rd_ack = reg_read_int;
           end 
//`endif           
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
              rd_data_mux =    {27'h0,txrx_ntotal_reg};
              rd_ack = reg_read_int;
           end 
           `PARAM_TXRX_S : begin
              rd_data_mux =         {27'h0,txrx_s_reg};
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
           `PARAM_RX_ENABLEJTSPATTEST : begin
              rd_data_mux =          {30'h0,txrx_enable_jtspat_test_reg};
              rd_ack = reg_read_int;
           end            
           `PARAM_PRBS_TEST_ENABLE : begin
              rd_data_mux =          {30'h0,prbs_test_enable_reg};
              rd_ack = reg_read_int;
           end                   
           `PARAM_RX_FEATURE_DISABLE : begin
              rd_data_mux =           {26'h0,rx_feature_disable};
              rd_ack = reg_read_int;
           end
           `PARAM_RX_CORE_INTERRUPT_MASK : begin
              rd_data_mux =       {23'h0,rx_core_interrupt_mask};
              rd_ack = reg_read_int;
           end 
           `PARAM_RX_ILAS_DETAILS : begin
              rd_data_mux =             rx_ilas_details;
              rd_ack = reg_read_int;
           end 
           `PARAM_RX_ERR_INJ_REQ : begin
              rd_data_mux =  32'h0;// Write only reg rx_err_inj_req
              rd_ack = reg_read_int;
           end 
           `PARAM_RX_CLK_RATIO: begin
              rd_data_mux = {30'h0,clk_ratio[1:0]};
              rd_ack = reg_read_int;
           end
           `PARAM_RX_LINKCONFIGURATIONERROR : begin
              rd_data_mux =    {24'h0,ilas_status};
              rd_ack = reg_read_int_r & (ilas_status_rd_ack == ilas_status_rd_req);              
           end 

           `PARAM_RX_PRBS_TEST_0_RECEIVECOUNTER : begin
              if (NO_LANES > 0)begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*0):32*0];             
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[0] == rd_ack_prbs_receivecounter[0]) || (~txrx_enablemodule_reg & reg_read_int);
               end
              else
               rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_1_RECEIVECOUNTER : begin
              if (NO_LANES >1)
              begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*1):32*1];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[1] == rd_ack_prbs_receivecounter[1]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_2_RECEIVECOUNTER : begin
              if (NO_LANES >2) begin
                rd_data_mux = counter;//prbs_test_receivecounter[31+(32*2):32*2]
                rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[2] == rd_ack_prbs_receivecounter[2]) || (~txrx_enablemodule_reg & reg_read_int);
                end
              else  rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_3_RECEIVECOUNTER : begin
              if (NO_LANES > 3) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*3):32*3];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[3] == rd_ack_prbs_receivecounter[3]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_4_RECEIVECOUNTER : begin
              if (NO_LANES > 4) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*4):32*4];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[4] == rd_ack_prbs_receivecounter[4]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_5_RECEIVECOUNTER : begin
              if (NO_LANES > 5) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*5):32*5];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[5] == rd_ack_prbs_receivecounter[5]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_6_RECEIVECOUNTER : begin
              if (NO_LANES > 6) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*6):32*6];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[6] == rd_ack_prbs_receivecounter[6]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_7_RECEIVECOUNTER : begin
              if (NO_LANES > 7) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*7):32*7];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[7] == rd_ack_prbs_receivecounter[7]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
//`ifdef LANE_LONG
           `PARAM_RX_PRBS_TEST_8_RECEIVECOUNTER : begin
              if (NO_LANES > 8) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*8):32*8];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[8] == rd_ack_prbs_receivecounter[8]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end		   
           `PARAM_RX_PRBS_TEST_9_RECEIVECOUNTER : begin
              if (NO_LANES > 9) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*9):32*9];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[9] == rd_ack_prbs_receivecounter[9]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end		   
           `PARAM_RX_PRBS_TEST_10_RECEIVECOUNTER : begin
              if (NO_LANES > 10) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*10):32*10];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[10] == rd_ack_prbs_receivecounter[10]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_11_RECEIVECOUNTER : begin
              if (NO_LANES > 11) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*11):32*11];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[11] == rd_ack_prbs_receivecounter[11]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_12_RECEIVECOUNTER : begin
              if (NO_LANES > 12) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*12):32*12];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[12] == rd_ack_prbs_receivecounter[12]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_13_RECEIVECOUNTER : begin
              if (NO_LANES > 13) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*13):32*13];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[13] == rd_ack_prbs_receivecounter[13]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end		   
           `PARAM_RX_PRBS_TEST_14_RECEIVECOUNTER : begin
              if (NO_LANES > 14) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*14):32*14];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[14] == rd_ack_prbs_receivecounter[14]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_15_RECEIVECOUNTER : begin
              if (NO_LANES > 15) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*15):32*15];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[15] == rd_ack_prbs_receivecounter[15]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_16_RECEIVECOUNTER : begin
              if (NO_LANES > 16) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*16):32*16];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[16] == rd_ack_prbs_receivecounter[16]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_17_RECEIVECOUNTER : begin
              if (NO_LANES > 17) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*17):32*17];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[17] == rd_ack_prbs_receivecounter[17]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_18_RECEIVECOUNTER : begin
              if (NO_LANES > 18) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*18):32*18];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[18] == rd_ack_prbs_receivecounter[18]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_19_RECEIVECOUNTER : begin
              if (NO_LANES > 19) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*19):32*19];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[19] == rd_ack_prbs_receivecounter[19]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_20_RECEIVECOUNTER : begin
              if (NO_LANES > 20) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*20):32*20];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[20] == rd_ack_prbs_receivecounter[20]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_21_RECEIVECOUNTER : begin
              if (NO_LANES > 21) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*21):32*21];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[21] == rd_ack_prbs_receivecounter[21]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_PRBS_TEST_22_RECEIVECOUNTER : begin
              if (NO_LANES > 22) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*22):32*22];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[22] == rd_ack_prbs_receivecounter[22]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end		   
           `PARAM_RX_PRBS_TEST_23_RECEIVECOUNTER : begin
              if (NO_LANES > 23) begin
                 rd_data_mux = counter;//prbs_test_receivecounter[31+(32*23):32*23];
                 rd_ack = reg_read_int_r & (rd_req_prbs_receivecounter[23] == rd_ack_prbs_receivecounter[23]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end		   		   
//`endif
		   
           `PARAM_RX_JTSPAT_TEST_0_RECEIVECOUNTER : begin
              if (NO_LANES > 0) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*0):32*0];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[0] == rd_ack_jtspat_receivecounter[0]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_JTSPAT_TEST_1_RECEIVECOUNTER : begin
              if (NO_LANES > 1) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*1):32*1];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[1] == rd_ack_jtspat_receivecounter[1]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end           
           `PARAM_RX_JTSPAT_TEST_2_RECEIVECOUNTER : begin
              if (NO_LANES > 2) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*2):32*2];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[2] == rd_ack_jtspat_receivecounter[2]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end  
           
           `PARAM_RX_JTSPAT_TEST_3_RECEIVECOUNTER : begin
              if (NO_LANES > 3) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*3):32*3];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[3] == rd_ack_jtspat_receivecounter[3]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end                        
           `PARAM_RX_JTSPAT_TEST_4_RECEIVECOUNTER : begin
              if (NO_LANES > 4) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*4):32*4];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[4] == rd_ack_jtspat_receivecounter[4]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end             
           `PARAM_RX_JTSPAT_TEST_5_RECEIVECOUNTER : begin
              if (NO_LANES > 5) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*5):32*5];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[5] == rd_ack_jtspat_receivecounter[5]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end  
           `PARAM_RX_JTSPAT_TEST_6_RECEIVECOUNTER : begin
              if (NO_LANES > 6) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*6):32*6];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[6] == rd_ack_jtspat_receivecounter[6]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end                        
           `PARAM_RX_JTSPAT_TEST_7_RECEIVECOUNTER : begin
              if (NO_LANES > 7) begin
                 rd_data_mux = counter;//[31+(32*7):32*7];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[7] == rd_ack_jtspat_receivecounter[7]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
//`ifdef LANE_LONG
           `PARAM_RX_JTSPAT_TEST_8_RECEIVECOUNTER : begin
              if (NO_LANES > 8) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*8):32*8];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[8] == rd_ack_jtspat_receivecounter[8]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_9_RECEIVECOUNTER : begin
              if (NO_LANES > 9) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*9):32*9];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[9] == rd_ack_jtspat_receivecounter[9]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_10_RECEIVECOUNTER : begin
              if (NO_LANES > 10) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*10):32*10];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[10] == rd_ack_jtspat_receivecounter[10]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_11_RECEIVECOUNTER : begin
              if (NO_LANES > 11) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*11):32*11];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[11] == rd_ack_jtspat_receivecounter[11]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_12_RECEIVECOUNTER : begin
              if (NO_LANES > 12) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*12):32*12];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[12] == rd_ack_jtspat_receivecounter[12]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_13_RECEIVECOUNTER : begin
              if (NO_LANES > 13) begin
                 rd_data_mux = counter;//[31+(32*13):32*13];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[13] == rd_ack_jtspat_receivecounter[13]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_14_RECEIVECOUNTER : begin
              if (NO_LANES > 14) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*14):32*14];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[14] == rd_ack_jtspat_receivecounter[14]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_15_RECEIVECOUNTER : begin
              if (NO_LANES > 15) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*15):32*15];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[15] == rd_ack_jtspat_receivecounter[15]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_16_RECEIVECOUNTER : begin
              if (NO_LANES > 16) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*16):32*16];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[16] == rd_ack_jtspat_receivecounter[16]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_17_RECEIVECOUNTER : begin
              if (NO_LANES > 17) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*17):32*17];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[17] == rd_ack_jtspat_receivecounter[17]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_18_RECEIVECOUNTER : begin
              if (NO_LANES > 18) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*18):32*18];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[18] == rd_ack_jtspat_receivecounter[18]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_19_RECEIVECOUNTER : begin
              if (NO_LANES > 19) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*19):32*19];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[19] == rd_ack_jtspat_receivecounter[19]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_20_RECEIVECOUNTER : begin
              if (NO_LANES > 20) begin
                 rd_data_mux = counter;//[31+(32*20):32*20];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[20] == rd_ack_jtspat_receivecounter[20]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_JTSPAT_TEST_21_RECEIVECOUNTER : begin
              if (NO_LANES > 21) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*21):32*21];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[21] == rd_ack_jtspat_receivecounter[21]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 		   
           `PARAM_RX_JTSPAT_TEST_22_RECEIVECOUNTER : begin
              if (NO_LANES > 22) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*22):32*22];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[22] == rd_ack_jtspat_receivecounter[22]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 		
           `PARAM_RX_JTSPAT_TEST_23_RECEIVECOUNTER : begin
              if (NO_LANES > 23) begin
                 rd_data_mux = counter;//jtspat_test_receivecounter[31+(32*23):32*23];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_receivecounter[23] == rd_ack_jtspat_receivecounter[23]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 		
		   
//`endif
		   
           `PARAM_RX_LINKTEST_0_RECEIVECOUNTER : begin
              if (NO_LANES > 0) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*0):32*0];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[0] == rd_ack_receivecounter[0])  || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end
           `PARAM_RX_LINKTEST_1_RECEIVECOUNTER : begin
              if (NO_LANES > 1) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*1):32*1];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[1] == rd_ack_receivecounter[1]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_2_RECEIVECOUNTER : begin
              if (NO_LANES > 2) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*2):32*2];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[2] == rd_ack_receivecounter[2]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_3_RECEIVECOUNTER : begin
              if (NO_LANES > 3) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*3):32*3];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[3] == rd_ack_receivecounter[3]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_4_RECEIVECOUNTER : begin
              if (NO_LANES > 4) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*4):32*4];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[4] == rd_ack_receivecounter[4]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_5_RECEIVECOUNTER : begin
              if (NO_LANES > 5) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*5):32*5];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[5] == rd_ack_receivecounter[5]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_6_RECEIVECOUNTER : begin
              if (NO_LANES > 6) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*6):32*6];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[6] == rd_ack_receivecounter[6]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_7_RECEIVECOUNTER : begin
              if (NO_LANES > 7) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*7):32*7];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[7] == rd_ack_receivecounter[7]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           
//`ifdef LANE_LONG
           `PARAM_RX_LINKTEST_8_RECEIVECOUNTER : begin
              if (NO_LANES > 8) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*8):32*8];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[8] == rd_ack_receivecounter[8]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
            `PARAM_RX_LINKTEST_9_RECEIVECOUNTER : begin
              if (NO_LANES > 9) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*9):32*9];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[9] == rd_ack_receivecounter[9]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
            `PARAM_RX_LINKTEST_10_RECEIVECOUNTER : begin
              if (NO_LANES > 10) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*10):32*10];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[10] == rd_ack_receivecounter[10]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
            `PARAM_RX_LINKTEST_11_RECEIVECOUNTER : begin
              if (NO_LANES > 11) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*11):32*11];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[11] == rd_ack_receivecounter[11]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
            `PARAM_RX_LINKTEST_12_RECEIVECOUNTER : begin
              if (NO_LANES > 12) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*12):32*12];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[12] == rd_ack_receivecounter[12]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
            `PARAM_RX_LINKTEST_13_RECEIVECOUNTER : begin
              if (NO_LANES > 13) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*13):32*13];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[13] == rd_ack_receivecounter[13]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_14_RECEIVECOUNTER : begin
              if (NO_LANES > 14) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*14):32*14];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[14] == rd_ack_receivecounter[14]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_15_RECEIVECOUNTER : begin
              if (NO_LANES > 15) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*15):32*15];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[15] == rd_ack_receivecounter[15]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end            
           `PARAM_RX_LINKTEST_16_RECEIVECOUNTER : begin
              if (NO_LANES > 16) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*16):32*16];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[16] == rd_ack_receivecounter[16]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end                  
           `PARAM_RX_LINKTEST_17_RECEIVECOUNTER : begin
              if (NO_LANES > 17) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*17):32*17];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[17] == rd_ack_receivecounter[17]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end                 
           `PARAM_RX_LINKTEST_18_RECEIVECOUNTER : begin
              if (NO_LANES > 18) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*18):32*18];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[18] == rd_ack_receivecounter[18]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end            
           `PARAM_RX_LINKTEST_19_RECEIVECOUNTER : begin
              if (NO_LANES > 19) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*19):32*19];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[19] == rd_ack_receivecounter[19]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end            
           `PARAM_RX_LINKTEST_20_RECEIVECOUNTER : begin
              if (NO_LANES > 20) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*20):32*20];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[20] == rd_ack_receivecounter[20]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_21_RECEIVECOUNTER : begin
              if (NO_LANES > 21) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*21):32*21];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[21] == rd_ack_receivecounter[21]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_22_RECEIVECOUNTER : begin
              if (NO_LANES > 22) begin
                 rd_data_mux = counter;//linktest_receivecounter[31+(32*22):32*22];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[22] == rd_ack_receivecounter[22]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_23_RECEIVECOUNTER : begin
              if (NO_LANES > 23) begin
                 rd_data_mux = counter;// linktest_receivecounter[31+(32*23):32*23];
                 rd_ack = reg_read_int_r & (rd_req_receivecounter[23] == rd_ack_receivecounter[23]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end              
            
//`endif

           `PARAM_RX_PRBS_TEST_0_ERRORCOUNTER : begin
              if (NO_LANES > 0) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*0):32*0];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[0] == rd_ack_prbs_errorcounter[0]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_1_ERRORCOUNTER : begin
              if (NO_LANES > 1) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*1):32*1];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[1] == rd_ack_prbs_errorcounter[1]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_2_ERRORCOUNTER : begin
              if (NO_LANES > 2) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*2):32*2];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[2] == rd_ack_prbs_errorcounter[2]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_3_ERRORCOUNTER : begin
              if (NO_LANES > 3) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*3):32*3];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[3] == rd_ack_prbs_errorcounter[3]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_4_ERRORCOUNTER : begin
              if (NO_LANES > 4) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*4):32*4];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[4] == rd_ack_prbs_errorcounter[4]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_5_ERRORCOUNTER : begin
              if (NO_LANES > 5) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*5):32*5];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[5] == rd_ack_prbs_errorcounter[5]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_6_ERRORCOUNTER : begin
              if (NO_LANES > 6) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*6):32*6];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[6] == rd_ack_prbs_errorcounter[6]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_7_ERRORCOUNTER : begin
              if (NO_LANES > 7) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*7):32*7];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[7] == rd_ack_prbs_errorcounter[7]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
		   
//`ifdef LANE_LONG
           `PARAM_RX_PRBS_TEST_8_ERRORCOUNTER : begin
              if (NO_LANES > 8) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*8):32*8];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[8] == rd_ack_prbs_errorcounter[8]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_9_ERRORCOUNTER : begin
              if (NO_LANES > 9) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*9):32*9];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[9] == rd_ack_prbs_errorcounter[9]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_10_ERRORCOUNTER : begin
              if (NO_LANES > 10) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*10):32*10];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[10] == rd_ack_prbs_errorcounter[10]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_11_ERRORCOUNTER : begin
              if (NO_LANES > 11) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*11):32*11];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[11] == rd_ack_prbs_errorcounter[11]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_12_ERRORCOUNTER : begin
              if (NO_LANES > 12) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*12):32*12];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[12] == rd_ack_prbs_errorcounter[12]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_13_ERRORCOUNTER : begin
              if (NO_LANES > 13) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*13):32*13];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[13] == rd_ack_prbs_errorcounter[13]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_14_ERRORCOUNTER : begin
              if (NO_LANES > 14) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*14):32*14];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[14] == rd_ack_prbs_errorcounter[14]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_15_ERRORCOUNTER : begin
              if (NO_LANES > 15) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*15):32*15];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[15] == rd_ack_prbs_errorcounter[15]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_16_ERRORCOUNTER : begin
              if (NO_LANES > 16) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*16):32*16];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[16] == rd_ack_prbs_errorcounter[16]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_17_ERRORCOUNTER : begin
              if (NO_LANES > 17) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*17):32*17];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[17] == rd_ack_prbs_errorcounter[17]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_18_ERRORCOUNTER : begin
              if (NO_LANES > 18) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*18):32*18];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[18] == rd_ack_prbs_errorcounter[18]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_19_ERRORCOUNTER : begin
              if (NO_LANES > 19) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*19):32*19];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[19] == rd_ack_prbs_errorcounter[19]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_20_ERRORCOUNTER : begin
              if (NO_LANES > 20) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*20):32*20];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[20] == rd_ack_prbs_errorcounter[20]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_21_ERRORCOUNTER : begin
              if (NO_LANES > 21) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*21):32*21];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[21] == rd_ack_prbs_errorcounter[21]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_22_ERRORCOUNTER : begin
              if (NO_LANES > 22) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*22):32*22];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[22] == rd_ack_prbs_errorcounter[22]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_PRBS_TEST_23_ERRORCOUNTER : begin
              if (NO_LANES > 23) begin
                 rd_data_mux = counter;//prbs_test_errorcounter[31+(32*23):32*23];
                 rd_ack = reg_read_int_r & (rd_req_prbs_errorcounter[23] == rd_ack_prbs_errorcounter[23]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
		   
//`endif
           `PARAM_RX_JTSPAT_TEST_0_ERRORCOUNTER : begin
              if (NO_LANES > 0) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*0):32*0];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[0] == rd_ack_jtspat_errorcounter[0]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end           
           `PARAM_RX_JTSPAT_TEST_1_ERRORCOUNTER : begin
              if (NO_LANES > 1) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*1):32*1];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[1] == rd_ack_jtspat_errorcounter[1]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end           
           `PARAM_RX_JTSPAT_TEST_2_ERRORCOUNTER : begin
              if (NO_LANES > 2) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*2):32*2];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[2] == rd_ack_jtspat_errorcounter[2]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end           
           `PARAM_RX_JTSPAT_TEST_3_ERRORCOUNTER : begin
              if (NO_LANES > 3) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*3):32*3];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[3] == rd_ack_jtspat_errorcounter[3]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end           
           
           `PARAM_RX_JTSPAT_TEST_4_ERRORCOUNTER : begin
              if (NO_LANES > 4) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*4):32*4];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[4] == rd_ack_jtspat_errorcounter[4]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end           
           `PARAM_RX_JTSPAT_TEST_5_ERRORCOUNTER : begin
              if (NO_LANES > 5) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*5):32*5];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[5] == rd_ack_jtspat_errorcounter[5]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end           
           `PARAM_RX_JTSPAT_TEST_6_ERRORCOUNTER : begin
              if (NO_LANES > 6) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*6):32*6];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[6] == rd_ack_jtspat_errorcounter[6]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end           
           `PARAM_RX_JTSPAT_TEST_7_ERRORCOUNTER : begin
              if (NO_LANES > 7) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*7):32*7];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[7] == rd_ack_jtspat_errorcounter[7]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end           
//`ifdef LANE_LONG                      
           `PARAM_RX_JTSPAT_TEST_8_ERRORCOUNTER : begin
              if (NO_LANES > 8) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*8):32*8];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[8] == rd_ack_jtspat_errorcounter[8]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_9_ERRORCOUNTER : begin
              if (NO_LANES > 9) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*9):32*9];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[9] == rd_ack_jtspat_errorcounter[9]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_10_ERRORCOUNTER : begin
              if (NO_LANES > 10) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*10):32*10];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[10] == rd_ack_jtspat_errorcounter[10]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_11_ERRORCOUNTER : begin
              if (NO_LANES > 11) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*11):32*11];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[11] == rd_ack_jtspat_errorcounter[11]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_12_ERRORCOUNTER : begin
              if (NO_LANES > 12) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*12):32*12];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[12] == rd_ack_jtspat_errorcounter[12]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_13_ERRORCOUNTER : begin
              if (NO_LANES > 13) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*13):32*13];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[13] == rd_ack_jtspat_errorcounter[13]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_14_ERRORCOUNTER : begin
              if (NO_LANES > 14) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*14):32*14];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[14] == rd_ack_jtspat_errorcounter[14]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_15_ERRORCOUNTER : begin
              if (NO_LANES > 15) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*15):32*15];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[15] == rd_ack_jtspat_errorcounter[15]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_16_ERRORCOUNTER : begin
              if (NO_LANES > 16) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*16):32*16];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[16] == rd_ack_jtspat_errorcounter[16]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_17_ERRORCOUNTER : begin
              if (NO_LANES > 17) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*17):32*17];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[17] == rd_ack_jtspat_errorcounter[17]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_18_ERRORCOUNTER : begin
              if (NO_LANES > 18) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*18):32*18];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[18] == rd_ack_jtspat_errorcounter[18]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_19_ERRORCOUNTER : begin
              if (NO_LANES > 19) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*19):32*19];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[19] == rd_ack_jtspat_errorcounter[19]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_20_ERRORCOUNTER : begin
              if (NO_LANES > 20) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*20):32*20];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[20] == rd_ack_jtspat_errorcounter[20]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_21_ERRORCOUNTER : begin
              if (NO_LANES > 21) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*21):32*21];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[21] == rd_ack_jtspat_errorcounter[21]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_22_ERRORCOUNTER : begin
              if (NO_LANES > 22) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*22):32*22];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[22] == rd_ack_jtspat_errorcounter[22]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   
           `PARAM_RX_JTSPAT_TEST_23_ERRORCOUNTER : begin
              if (NO_LANES > 23) begin
                 rd_data_mux = counter;//jtspat_test_errorcounter[31+(32*23):32*23];
                 rd_ack = reg_read_int_r & (rd_req_jtspat_errorcounter[23] == rd_ack_jtspat_errorcounter[23]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end   

//`endif


              
           `PARAM_RX_LINKTEST_0_ERRORCOUNTER : begin
              if (NO_LANES > 0) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*0):32*0];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[0] == rd_ack_errorcounter[0]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end           
           `PARAM_RX_LINKTEST_1_ERRORCOUNTER : begin
              if (NO_LANES > 1) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*1):32*1];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[1] == rd_ack_errorcounter[1]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_2_ERRORCOUNTER : begin
              if (NO_LANES > 2) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*2):32*2];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[2] == rd_ack_errorcounter[2]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_3_ERRORCOUNTER : begin
              if (NO_LANES > 3) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*3):32*3];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[3] == rd_ack_errorcounter[3]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_4_ERRORCOUNTER : begin
              if (NO_LANES > 4) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*4):32*4];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[4] == rd_ack_errorcounter[4]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_5_ERRORCOUNTER : begin
              if (NO_LANES > 5) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*5):32*5];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[5] == rd_ack_errorcounter[5]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_6_ERRORCOUNTER : begin
              if (NO_LANES > 6) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*6):32*6];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[6] == rd_ack_errorcounter[6]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_7_ERRORCOUNTER : begin
              if (NO_LANES > 7) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*7):32*7];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[7] == rd_ack_errorcounter[7]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
//`ifdef LANE_LONG
           `PARAM_RX_LINKTEST_8_ERRORCOUNTER : begin
              if (NO_LANES > 8) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*8):32*8];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[8] == rd_ack_errorcounter[8]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_9_ERRORCOUNTER : begin
              if (NO_LANES > 9) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*9):32*9];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[9] == rd_ack_errorcounter[9]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end        
           `PARAM_RX_LINKTEST_10_ERRORCOUNTER : begin
              if (NO_LANES > 10) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*10):32*10];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[10] == rd_ack_errorcounter[10]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end    
           `PARAM_RX_LINKTEST_11_ERRORCOUNTER : begin
              if (NO_LANES > 11) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*11):32*11];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[11] == rd_ack_errorcounter[11]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_12_ERRORCOUNTER : begin
              if (NO_LANES > 12) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*12):32*12];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[12] == rd_ack_errorcounter[12]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_13_ERRORCOUNTER : begin
              if (NO_LANES > 13) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*13):32*13];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[13] == rd_ack_errorcounter[13]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_14_ERRORCOUNTER : begin
              if (NO_LANES > 14) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*14):32*14];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[14] == rd_ack_errorcounter[14]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_15_ERRORCOUNTER : begin
              if (NO_LANES > 15) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*15):32*15];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[15] == rd_ack_errorcounter[15]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_16_ERRORCOUNTER : begin
              if (NO_LANES > 16) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*16):32*16];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[16] == rd_ack_errorcounter[16]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_17_ERRORCOUNTER : begin
              if (NO_LANES > 17) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*17):32*17];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[17] == rd_ack_errorcounter[17]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_18_ERRORCOUNTER : begin
              if (NO_LANES > 18) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*18):32*18];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[18] == rd_ack_errorcounter[18]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_19_ERRORCOUNTER : begin
              if (NO_LANES > 19) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*19):32*19];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[19] == rd_ack_errorcounter[19]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_20_ERRORCOUNTER : begin
              if (NO_LANES > 20) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*20):32*20];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[20] == rd_ack_errorcounter[20]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_21_ERRORCOUNTER : begin
              if (NO_LANES > 21) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*21):32*21];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[21] == rd_ack_errorcounter[21]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_22_ERRORCOUNTER : begin
              if (NO_LANES > 22) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*22):32*22];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[22] == rd_ack_errorcounter[22]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
           `PARAM_RX_LINKTEST_23_ERRORCOUNTER : begin
              if (NO_LANES > 23) begin
                 rd_data_mux = counter;//linktest_errorcounter[31+(32*23):32*23];
                 rd_ack = reg_read_int_r & (rd_req_errorcounter[23] == rd_ack_errorcounter[23]) || (~txrx_enablemodule_reg & reg_read_int);
              end
              else rd_ack = reg_read_int;
           end 
//`endif
           `PARAM_RX_CORE_INTERRUPT_STATUS : begin
              rd_data_mux = {23'h0,interrupt_rd_val};
              rd_ack = (rd_interrupt_ack & reg_read_int) || (~txrx_enablemodule_reg & reg_read_int);
           end 
           default:begin
              rd_data_mux = 32'b0;
              rd_ack = reg_read_int;
           end 
         endcase // case (reg_addr_int)
      end
   end
//end   
//endgenerate

reg [7:0] test_address_mux ;
wire [31:0] counter_w [NO_LANES-1:0]; 
generate for (ln_cnt = 0; ln_cnt < NO_LANES; ln_cnt= ln_cnt +1) begin : wire_assign
  assign counter_w [ln_cnt] [31:0]= (test_address_mux [7:5] == 0)? prbs_test_receivecounter [31+(32*ln_cnt):32*ln_cnt]:(test_address_mux [7:5] == 1)? prbs_test_errorcounter [31+(32*ln_cnt):32*ln_cnt]:(test_address_mux [7:5] == 2)? jtspat_test_receivecounter [31+(32*ln_cnt):32*ln_cnt]:(test_address_mux [7:5] == 3)? jtspat_test_errorcounter [31+(32*ln_cnt):32*ln_cnt]:(test_address_mux [7:5] == 4)? linktest_receivecounter [31+(32*ln_cnt):32*ln_cnt]:(test_address_mux [7:5] == 5)? linktest_errorcounter [31+(32*ln_cnt):32*ln_cnt]:'h0; 
end
endgenerate

always@(posedge clk_cpu or posedge rst) begin
  if (rst)  
  begin
    counter = 32'h0;
  end
  else 
  begin
    if (test_address_mux[4:0] > NO_LANES-1)
      counter = 32'h0;
    else
    begin
      counter = counter_w [(test_address_mux[4:0])];
    end
  end
end
  
//generate
//begin
  always@(posedge clk_cpu or posedge rst) begin
    if (rst) begin
       test_address_mux [7:5] = 3'h0;
       test_address_mux [4:0] = 5'h0;
    end
    else 
    begin
      case(reg_addr_int[9:0])
          `PARAM_RX_PRBS_TEST_0_RECEIVECOUNTER: begin
          if (NO_LANES >0)begin   
            test_address_mux [7:5] = 3'h0;
            test_address_mux [4:0] = 5'h0;
          end      
        end
      
         `PARAM_RX_PRBS_TEST_1_RECEIVECOUNTER: begin 
          if (NO_LANES >1)begin   
            test_address_mux [7:5] = 3'h0;
            test_address_mux [4:0] = 5'h1;
          end
        end
      
          `PARAM_RX_PRBS_TEST_2_RECEIVECOUNTER : begin
            if (NO_LANES >2) begin
              test_address_mux [7:5] = 3'h0;
              test_address_mux [4:0] = 5'h2;
            end
          end
      
          `PARAM_RX_PRBS_TEST_3_RECEIVECOUNTER : begin 
            if (NO_LANES > 3)begin
              test_address_mux [7:5] = 3'h0;
              test_address_mux [4:0] = 5'h3;
            end
          end            
       
          `PARAM_RX_PRBS_TEST_4_RECEIVECOUNTER : begin
            if (NO_LANES > 4) begin 
              test_address_mux [7:5] = 3'h0;
              test_address_mux [4:0] = 5'h4;
            end           
          end

           `PARAM_RX_PRBS_TEST_5_RECEIVECOUNTER : begin
              if (NO_LANES > 5) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'h5;
              end
           end
           `PARAM_RX_PRBS_TEST_6_RECEIVECOUNTER : begin
              if (NO_LANES > 6) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'h6;
              end
           end
           `PARAM_RX_PRBS_TEST_7_RECEIVECOUNTER : begin
              if (NO_LANES > 7) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'h7;
              end
           end
//`ifdef LANE_LONG
           `PARAM_RX_PRBS_TEST_8_RECEIVECOUNTER : begin
              if (NO_LANES > 8) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'h8;
              end
           end		   
           `PARAM_RX_PRBS_TEST_9_RECEIVECOUNTER : begin
              if (NO_LANES > 9) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'h9;
              end
           end		   
           `PARAM_RX_PRBS_TEST_10_RECEIVECOUNTER : begin
              if (NO_LANES > 10) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd10;
              end
           end
           `PARAM_RX_PRBS_TEST_11_RECEIVECOUNTER : begin
              if (NO_LANES > 11) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd11;
              end
           end
           `PARAM_RX_PRBS_TEST_12_RECEIVECOUNTER : begin
              if (NO_LANES > 12) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd12;
              end
           end
           `PARAM_RX_PRBS_TEST_13_RECEIVECOUNTER : begin
              if (NO_LANES > 13) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd13;
              end
           end		   
           `PARAM_RX_PRBS_TEST_14_RECEIVECOUNTER : begin
              if (NO_LANES > 14) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd14;
              end
           end
           `PARAM_RX_PRBS_TEST_15_RECEIVECOUNTER : begin
              if (NO_LANES > 15) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd15;
              end
           end
           `PARAM_RX_PRBS_TEST_16_RECEIVECOUNTER : begin
              if (NO_LANES > 16) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd16;
              end
           end
           `PARAM_RX_PRBS_TEST_17_RECEIVECOUNTER : begin
              if (NO_LANES > 17) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd17;
              end
           end
           `PARAM_RX_PRBS_TEST_18_RECEIVECOUNTER : begin
              if (NO_LANES > 18) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd18;
              end
           end
           `PARAM_RX_PRBS_TEST_19_RECEIVECOUNTER : begin
              if (NO_LANES > 19) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd19;
              end
           end
           `PARAM_RX_PRBS_TEST_20_RECEIVECOUNTER : begin
              if (NO_LANES > 20) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd20;
              end
           end
           `PARAM_RX_PRBS_TEST_21_RECEIVECOUNTER : begin
              if (NO_LANES > 21) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd21;
              end
           end
           `PARAM_RX_PRBS_TEST_22_RECEIVECOUNTER : begin
              if (NO_LANES > 22) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd22;
              end
           end		   
           `PARAM_RX_PRBS_TEST_23_RECEIVECOUNTER : begin
              if (NO_LANES > 23) 
              begin
                test_address_mux [7:5] = 3'h0;
                test_address_mux [4:0] = 5'd23;
              end
           end		   		   
//`endif
		   
           `PARAM_RX_JTSPAT_TEST_0_RECEIVECOUNTER : begin
              if (NO_LANES > 0) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'h0;
              end          
            end
           `PARAM_RX_JTSPAT_TEST_1_RECEIVECOUNTER : begin
              if (NO_LANES > 1) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'h1;
              end     
           end           
           `PARAM_RX_JTSPAT_TEST_2_RECEIVECOUNTER : begin
              if (NO_LANES > 2) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'h2;
              end     
           end  
           
           `PARAM_RX_JTSPAT_TEST_3_RECEIVECOUNTER : begin
              if (NO_LANES > 3) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'h3;
              end     
           end                        
           `PARAM_RX_JTSPAT_TEST_4_RECEIVECOUNTER : begin
              if (NO_LANES > 4) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'h4;
              end    
           end             
           `PARAM_RX_JTSPAT_TEST_5_RECEIVECOUNTER : begin
              if (NO_LANES > 5) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'h5;
              end    
           end  
           `PARAM_RX_JTSPAT_TEST_6_RECEIVECOUNTER : begin
              if (NO_LANES > 6) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'h6;
              end    
           end                        
           `PARAM_RX_JTSPAT_TEST_7_RECEIVECOUNTER : begin
              if (NO_LANES > 7) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'h7;
              end    
           end 
//`ifdef LANE_LONG
           `PARAM_RX_JTSPAT_TEST_8_RECEIVECOUNTER : begin
              if (NO_LANES > 8) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'h8;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_9_RECEIVECOUNTER : begin
              if (NO_LANES > 9) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'h9;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_10_RECEIVECOUNTER : begin
              if (NO_LANES > 10) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd10;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_11_RECEIVECOUNTER : begin
              if (NO_LANES > 11) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd11;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_12_RECEIVECOUNTER : begin
              if (NO_LANES > 12) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd12;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_13_RECEIVECOUNTER : begin
              if (NO_LANES > 13) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd13;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_14_RECEIVECOUNTER : begin
              if (NO_LANES > 14) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd14;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_15_RECEIVECOUNTER : begin
              if (NO_LANES > 15) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd15;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_16_RECEIVECOUNTER : begin
              if (NO_LANES > 16) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd16;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_17_RECEIVECOUNTER : begin
              if (NO_LANES > 17) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd17;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_18_RECEIVECOUNTER : begin
              if (NO_LANES > 18) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd18;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_19_RECEIVECOUNTER : begin
              if (NO_LANES > 19) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd19;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_20_RECEIVECOUNTER : begin
              if (NO_LANES > 20) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd20;
              end    
           end 
           `PARAM_RX_JTSPAT_TEST_21_RECEIVECOUNTER : begin
              if (NO_LANES > 21) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd21;
              end    
           end 		   
           `PARAM_RX_JTSPAT_TEST_22_RECEIVECOUNTER : begin
              if (NO_LANES > 22) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd22;
              end    
           end 		
           `PARAM_RX_JTSPAT_TEST_23_RECEIVECOUNTER : begin
              if (NO_LANES > 23) 
              begin
                test_address_mux [7:5] = 3'h2;
                test_address_mux [4:0] = 5'd23;
              end    
           end 				   
           `PARAM_RX_LINKTEST_0_RECEIVECOUNTER : begin
              if (NO_LANES > 0) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h0;
              end    
           end
           `PARAM_RX_LINKTEST_1_RECEIVECOUNTER : begin
              if (NO_LANES > 1) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h1;
              end    
           end 
           `PARAM_RX_LINKTEST_2_RECEIVECOUNTER : begin
              if (NO_LANES > 2) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h2;
              end    
           end 
           `PARAM_RX_LINKTEST_3_RECEIVECOUNTER : begin
              if (NO_LANES > 3) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h3;
              end    
           end 
           `PARAM_RX_LINKTEST_4_RECEIVECOUNTER : begin
              if (NO_LANES > 4) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h4;
              end    
           end 
           `PARAM_RX_LINKTEST_5_RECEIVECOUNTER : begin
              if (NO_LANES > 5) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h5;
              end    
           end 
           `PARAM_RX_LINKTEST_6_RECEIVECOUNTER : begin
              if (NO_LANES > 6) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h6;
              end    
           end 
           `PARAM_RX_LINKTEST_7_RECEIVECOUNTER : begin
              if (NO_LANES > 7) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h7;
            end    
           end 
           
//`ifdef LANE_LONG
           `PARAM_RX_LINKTEST_8_RECEIVECOUNTER : begin
              if (NO_LANES > 8) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h8;
              end    
           end 
            `PARAM_RX_LINKTEST_9_RECEIVECOUNTER : begin
              if (NO_LANES > 9) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h9;
              end    
           end 
            `PARAM_RX_LINKTEST_10_RECEIVECOUNTER : begin
              if (NO_LANES > 10) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'ha;
              end    
           end 
            `PARAM_RX_LINKTEST_11_RECEIVECOUNTER : begin
              if (NO_LANES > 11) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'hb;
              end    
           end 
            `PARAM_RX_LINKTEST_12_RECEIVECOUNTER : begin
              if (NO_LANES > 12) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'hc;
              end    
           end 
            `PARAM_RX_LINKTEST_13_RECEIVECOUNTER : begin
              if (NO_LANES > 13) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'hd;
              end    
           end 
           `PARAM_RX_LINKTEST_14_RECEIVECOUNTER : begin
              if (NO_LANES > 14) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'he;
              end    
           end 
           `PARAM_RX_LINKTEST_15_RECEIVECOUNTER : begin
              if (NO_LANES > 15) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'hf;
              end    
           end            
           `PARAM_RX_LINKTEST_16_RECEIVECOUNTER : begin
              if (NO_LANES > 16) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h10;
              end    
           end                  
           `PARAM_RX_LINKTEST_17_RECEIVECOUNTER : begin
              if (NO_LANES > 17) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h11;
              end    
           end                 
           `PARAM_RX_LINKTEST_18_RECEIVECOUNTER : begin
              if (NO_LANES > 18) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h12;
              end    
           end            
           `PARAM_RX_LINKTEST_19_RECEIVECOUNTER : begin
              if (NO_LANES > 19) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h13;
              end    
           end            
           `PARAM_RX_LINKTEST_20_RECEIVECOUNTER : begin
              if (NO_LANES > 20) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h14;
              end    
           end 
           `PARAM_RX_LINKTEST_21_RECEIVECOUNTER : begin
              if (NO_LANES > 21) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h15;
              end    
           end 
           `PARAM_RX_LINKTEST_22_RECEIVECOUNTER : begin
              if (NO_LANES > 22) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h16;
              end    
           end 
           `PARAM_RX_LINKTEST_23_RECEIVECOUNTER : begin
              if (NO_LANES > 23) 
              begin
                test_address_mux [7:5] = 3'h4;
                test_address_mux [4:0] = 5'h17;
              end    
           end              
           `PARAM_RX_PRBS_TEST_0_ERRORCOUNTER : begin
              if (NO_LANES > 0) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h0;
              end    
           end 
           `PARAM_RX_PRBS_TEST_1_ERRORCOUNTER : begin
              if (NO_LANES > 1) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h1;
              end    
           end 
           `PARAM_RX_PRBS_TEST_2_ERRORCOUNTER : begin
              if (NO_LANES > 2) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h2;
              end    
           end 
           `PARAM_RX_PRBS_TEST_3_ERRORCOUNTER : begin
              if (NO_LANES > 3) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h3;
              end    
           end 
           `PARAM_RX_PRBS_TEST_4_ERRORCOUNTER : begin
              if (NO_LANES > 4) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h4;
              end    
           end 
           `PARAM_RX_PRBS_TEST_5_ERRORCOUNTER : begin
              if (NO_LANES > 5) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h5;
              end    
           end 
           `PARAM_RX_PRBS_TEST_6_ERRORCOUNTER : begin
              if (NO_LANES > 6) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h6;
              end    
           end 
           `PARAM_RX_PRBS_TEST_7_ERRORCOUNTER : begin
              if (NO_LANES > 7) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h7;
              end    
           end 
		   
//`ifdef LANE_LONG
           `PARAM_RX_PRBS_TEST_8_ERRORCOUNTER : begin
              if (NO_LANES > 8) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h8;
              end    
           end 
           `PARAM_RX_PRBS_TEST_9_ERRORCOUNTER : begin
              if (NO_LANES > 9) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h9;
              end    
           end 
           `PARAM_RX_PRBS_TEST_10_ERRORCOUNTER : begin
              if (NO_LANES > 10) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'ha;
              end    
           end 
           `PARAM_RX_PRBS_TEST_11_ERRORCOUNTER : begin
              if (NO_LANES > 11) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'hb;
              end    
           end 
           `PARAM_RX_PRBS_TEST_12_ERRORCOUNTER : begin
              if (NO_LANES > 12) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'hc;
              end    
           end 
           `PARAM_RX_PRBS_TEST_13_ERRORCOUNTER : begin
              if (NO_LANES > 13) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'hd;
              end    
           end 
           `PARAM_RX_PRBS_TEST_14_ERRORCOUNTER : begin
              if (NO_LANES > 14) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'he;
              end    
           end 
           `PARAM_RX_PRBS_TEST_15_ERRORCOUNTER : begin
              if (NO_LANES > 15) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'hf;
              end    
           end 
           `PARAM_RX_PRBS_TEST_16_ERRORCOUNTER : begin
              if (NO_LANES > 16) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h10;
              end    
           end 
           `PARAM_RX_PRBS_TEST_17_ERRORCOUNTER : begin
              if (NO_LANES > 17) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h11;
              end    
           end 
           `PARAM_RX_PRBS_TEST_18_ERRORCOUNTER : begin
              if (NO_LANES > 18) 
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h12;
              end    
           end 
           `PARAM_RX_PRBS_TEST_19_ERRORCOUNTER : begin
              if (NO_LANES > 19)
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h13;
              end    
           end 
           `PARAM_RX_PRBS_TEST_20_ERRORCOUNTER : begin
              if (NO_LANES > 20)
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h14;
              end    
           end 
           `PARAM_RX_PRBS_TEST_21_ERRORCOUNTER : begin
              if (NO_LANES > 21)
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h15;
              end    
           end 
           `PARAM_RX_PRBS_TEST_22_ERRORCOUNTER : begin
              if (NO_LANES > 22)
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h16;
              end    
           end 
           `PARAM_RX_PRBS_TEST_23_ERRORCOUNTER : begin
              if (NO_LANES > 23)
              begin
                test_address_mux [7:5] = 3'h1;
                test_address_mux [4:0] = 5'h17;
              end    
           end 		   
           `PARAM_RX_JTSPAT_TEST_0_ERRORCOUNTER : begin
              if (NO_LANES > 0)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h0;
              end    
           end           
           `PARAM_RX_JTSPAT_TEST_1_ERRORCOUNTER : begin
              if (NO_LANES > 1)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h1;
              end    
           end           
           `PARAM_RX_JTSPAT_TEST_2_ERRORCOUNTER : begin
              if (NO_LANES > 2)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h2;
              end    
           end           
           `PARAM_RX_JTSPAT_TEST_3_ERRORCOUNTER : begin
              if (NO_LANES > 3)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h3;
              end    
           end           
           
           `PARAM_RX_JTSPAT_TEST_4_ERRORCOUNTER : begin
              if (NO_LANES > 4)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h4;
              end    
           end           
           `PARAM_RX_JTSPAT_TEST_5_ERRORCOUNTER : begin
              if (NO_LANES > 5)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h5;
              end    
           end           
           `PARAM_RX_JTSPAT_TEST_6_ERRORCOUNTER : begin
              if (NO_LANES > 6)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h6;
              end    
           end           
           `PARAM_RX_JTSPAT_TEST_7_ERRORCOUNTER : begin
              if (NO_LANES > 7)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h7;
              end    
           end           
//`ifdef LANE_LONG                      
           `PARAM_RX_JTSPAT_TEST_8_ERRORCOUNTER : begin
              if (NO_LANES > 8)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h8;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_9_ERRORCOUNTER : begin
              if (NO_LANES > 9)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h9;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_10_ERRORCOUNTER : begin
              if (NO_LANES > 10)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'ha;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_11_ERRORCOUNTER : begin
              if (NO_LANES > 11)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'hb;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_12_ERRORCOUNTER : begin
              if (NO_LANES > 12)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'hc;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_13_ERRORCOUNTER : begin
              if (NO_LANES > 13)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'hd;
              end     
           end   
           `PARAM_RX_JTSPAT_TEST_14_ERRORCOUNTER : begin
              if (NO_LANES > 14)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'he;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_15_ERRORCOUNTER : begin
              if (NO_LANES > 15)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'hf;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_16_ERRORCOUNTER : begin
              if (NO_LANES > 16)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h10;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_17_ERRORCOUNTER : begin
              if (NO_LANES > 17)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h11;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_18_ERRORCOUNTER : begin
              if (NO_LANES > 18)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h12;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_19_ERRORCOUNTER : begin
              if (NO_LANES > 19)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h13;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_20_ERRORCOUNTER : begin
              if (NO_LANES > 20)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h14;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_21_ERRORCOUNTER : begin
              if (NO_LANES > 21)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h15;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_22_ERRORCOUNTER : begin
              if (NO_LANES > 22)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h16;
              end    
           end   
           `PARAM_RX_JTSPAT_TEST_23_ERRORCOUNTER : begin
              if (NO_LANES > 23)
              begin
                test_address_mux [7:5] = 3'h3;
                test_address_mux [4:0] = 5'h17;
              end    
           end   
           `PARAM_RX_LINKTEST_0_ERRORCOUNTER : begin
              if (NO_LANES > 0)
              begin
                test_address_mux [7:5] = 3'h5;
                test_address_mux [4:0] = 5'h0;
              end    
           end           
           `PARAM_RX_LINKTEST_1_ERRORCOUNTER : begin
              if (NO_LANES > 1)
              begin
                test_address_mux [7:5] = 3'h5;
                test_address_mux [4:0] = 5'h1;
              end    
           end 
           `PARAM_RX_LINKTEST_2_ERRORCOUNTER : begin
              if (NO_LANES > 2)
              begin
                test_address_mux [7:5] = 3'h5;
                test_address_mux [4:0] = 5'h2;
              end    
           end 
           `PARAM_RX_LINKTEST_3_ERRORCOUNTER : begin
              if (NO_LANES > 3)
              begin
                test_address_mux [7:5] = 3'h5;
                test_address_mux [4:0] = 5'h3;
              end    
           end 
           `PARAM_RX_LINKTEST_4_ERRORCOUNTER : begin
              if (NO_LANES > 4)
              begin
                test_address_mux [7:5] = 3'h5;
                test_address_mux [4:0] = 5'h4;
              end    
           end 
           `PARAM_RX_LINKTEST_5_ERRORCOUNTER : begin
              if (NO_LANES > 5)
            begin
              test_address_mux [7:5] = 3'h5;
              test_address_mux [4:0] = 5'h5;
            end    
           end 
           `PARAM_RX_LINKTEST_6_ERRORCOUNTER : begin
              if (NO_LANES > 6)
            begin
              test_address_mux [7:5] = 3'h5;
              test_address_mux [4:0] = 5'h6;
            end    
           end 
           `PARAM_RX_LINKTEST_7_ERRORCOUNTER : begin
              if (NO_LANES > 7)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'h7;
                end    
           end 
//`ifdef LANE_LONG
           `PARAM_RX_LINKTEST_8_ERRORCOUNTER : begin
              if (NO_LANES > 8)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'h8;
                end    

           end 
           `PARAM_RX_LINKTEST_9_ERRORCOUNTER : begin
              if (NO_LANES > 9)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'h9;
                end    

           end        
           `PARAM_RX_LINKTEST_10_ERRORCOUNTER : begin
              if (NO_LANES > 10)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'ha;
                end    

           end    
           `PARAM_RX_LINKTEST_11_ERRORCOUNTER : begin
              if (NO_LANES > 11)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'hb;
                end    

           end 
           `PARAM_RX_LINKTEST_12_ERRORCOUNTER : begin
              if (NO_LANES > 12)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'hc;
                end    

           end 
           `PARAM_RX_LINKTEST_13_ERRORCOUNTER : begin
              if (NO_LANES > 13)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'hd;
                end    

           end 
           `PARAM_RX_LINKTEST_14_ERRORCOUNTER : begin
              if (NO_LANES > 14)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'he;
                end    

           end 
           `PARAM_RX_LINKTEST_15_ERRORCOUNTER : begin
              if (NO_LANES > 15)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'hf;
                end    

           end 
           `PARAM_RX_LINKTEST_16_ERRORCOUNTER : begin
              if (NO_LANES > 16)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'h10;
                end    

           end 
           `PARAM_RX_LINKTEST_17_ERRORCOUNTER : begin
              if (NO_LANES > 17)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'h11;
                end    

           end 
           `PARAM_RX_LINKTEST_18_ERRORCOUNTER : begin
              if (NO_LANES > 18)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'h12;
                end    

           end 
           `PARAM_RX_LINKTEST_19_ERRORCOUNTER : begin
              if (NO_LANES > 19)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'h13;
                end    

           end 
           `PARAM_RX_LINKTEST_20_ERRORCOUNTER : begin
              if (NO_LANES > 20)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'h14;
                end    

           end 
           `PARAM_RX_LINKTEST_21_ERRORCOUNTER : begin
              if (NO_LANES > 21)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'h15;
                end    

           end 
           `PARAM_RX_LINKTEST_22_ERRORCOUNTER : begin
              if (NO_LANES > 22)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'h16;
                end    

           end 
           `PARAM_RX_LINKTEST_23_ERRORCOUNTER : begin
              if (NO_LANES > 23)
                begin
                  test_address_mux [7:5] = 3'h5;
                  test_address_mux [4:0] = 5'h17;
                end    

           end 
           default:
                begin
                  test_address_mux [7:5] = 3'h0;
                  test_address_mux [4:0] = 5'h0;
                end    
      endcase
    end
  end
//end  
//endgenerate
   
   always @(posedge clk_cpu or posedge rst) begin
      if (rst) begin
         ilas_status_rd_req <= 1'b0;
         ilas_status_rd_ack <= 1'b0;
      end
      else begin
         if (ilas_status_rd_req ^ ilas_status_rd_ack) 
           ilas_status_rd_ack <= ilas_status_rd_req ? txrx_enablemodule_reg ? &(ilas_status_rd_ack_per_lane) : 'h1 : |(ilas_status_rd_ack_per_lane);         
         else if (reg_read_int & ~reg_read_int_r)
           ilas_status_rd_req <= rx_linkconfigurationerror_cs ? ~ilas_status_rd_req : ilas_status_rd_req;
      end // else: !if(rst)
   end // always @ (posedge clk_cpu or posedge rst)
   
   
//   genvar ln_cnt;
   generate for (ln_cnt = 0; ln_cnt < NO_LANES; ln_cnt = ln_cnt + 1) begin : lane_generate

      always @ (posedge clk_cpu or posedge rst) begin
         if (rst) begin
            rd_req_errorcounter[ln_cnt] <= 1'b0;
            rd_req_receivecounter[ln_cnt] <= 1'b0;
            rd_req_jtspat_errorcounter[ln_cnt] <=1'b0;
            rd_req_jtspat_receivecounter[ln_cnt] <=1'b0;
            rd_req_prbs_errorcounter[ln_cnt] <=1'b0;
            rd_req_prbs_receivecounter[ln_cnt] <=1'b0;            
            
         end
         else if (reg_read_int & ~reg_read_int_r) begin
              rd_req_prbs_errorcounter[ln_cnt]   <=   rx_prbs_errorcounter_cs[ln_cnt] ^ rd_req_prbs_errorcounter[ln_cnt];
              rd_req_prbs_receivecounter[ln_cnt] <=   rx_prbs_receivecounter_cs[ln_cnt] ^ rd_req_prbs_receivecounter[ln_cnt];
              rd_req_errorcounter[ln_cnt]   <=   rx_linktest_errorcounter_cs[ln_cnt] ^ rd_req_errorcounter[ln_cnt];
              rd_req_receivecounter[ln_cnt] <=   rx_linktest_receivecounter_cs[ln_cnt] ^ rd_req_receivecounter[ln_cnt];
              rd_req_jtspat_errorcounter[ln_cnt]   <=   rx_jtspat_test_errorcounter_cs[ln_cnt] ^ rd_req_jtspat_errorcounter[ln_cnt];
              rd_req_jtspat_receivecounter[ln_cnt]   <=   rx_jtspat_test_receivecounter_cs[ln_cnt] ^ rd_req_jtspat_receivecounter[ln_cnt];
         end
      end // always @ (posedge clk_cpu or posedge rst)
      
      
   
   jesd_rc_counter prbs_receivecounter  (
                                          // Outputs
                                          .counter              (prbs_test_receivecounter[31+32*ln_cnt:32*ln_cnt]),
                                          .rd_ack               (rd_ack_prbs_receivecounter[ln_cnt]),
                                          // Inputs
                                          .clk_character        (clk_character),
                                          .rst_clk_character    (rst_clk_character),
                                          .incr_count           (prbs_vld_count[3+4*ln_cnt:4*ln_cnt]),
                                          .clk_cpu              (clk_cpu),
                                          .rd_req               (rd_req_prbs_receivecounter[ln_cnt]));                                    

    jesd_rc_counter prbs_errorcounter  (
                                    // Outputs
                                    .counter              (prbs_test_errorcounter[31+32*ln_cnt:32*ln_cnt]),
                                    .rd_ack               (rd_ack_prbs_errorcounter[ln_cnt]),
                                    // Inputs
                                    .clk_character        (clk_character),
                                    .rst_clk_character    (rst_clk_character),
                                    .incr_count           (prbs_err_count[3+4*ln_cnt:4*ln_cnt]),
                                    .clk_cpu              (clk_cpu),
                                    .rd_req               (rd_req_prbs_errorcounter[ln_cnt]));
      
      jesd_rc_counter jtspat_errorcounter  (
                                    // Outputs
                                    .counter              (jtspat_test_errorcounter[31+32*ln_cnt:32*ln_cnt]),
                                    .rd_ack               (rd_ack_jtspat_errorcounter[ln_cnt]),
                                    // Inputs
                                    .clk_character        (clk_character),
                                    .rst_clk_character    (rst_clk_character),
                                    .incr_count           (jtspat_err_count[3+4*ln_cnt:4*ln_cnt]),
                                    .clk_cpu              (clk_cpu),
                                    .rd_req               (rd_req_jtspat_errorcounter[ln_cnt]));

   
   jesd_rc_counter jtspat_receivecounter  (
                                          // Outputs
                                          .counter              (jtspat_test_receivecounter[31+32*ln_cnt:32*ln_cnt]),
                                          .rd_ack               (rd_ack_jtspat_receivecounter[ln_cnt]),
                                          // Inputs
                                          .clk_character        (clk_character),
                                          .rst_clk_character    (rst_clk_character),
                                          .incr_count           (jtspat_vld_count[3+4*ln_cnt:4*ln_cnt]),
                                          .clk_cpu              (clk_cpu),
                                          .rd_req               (rd_req_jtspat_receivecounter[ln_cnt]));                                    

      jesd_rc_counter errorcounter  (
                                    // Outputs
                                    .counter              (linktest_errorcounter[31+32*ln_cnt:32*ln_cnt]),
                                    .rd_ack               (rd_ack_errorcounter[ln_cnt]),
                                    // Inputs
                                    .clk_character        (clk_character),
                                    .rst_clk_character    (rst_clk_character),
                                    .incr_count           (incr_err_count[3+4*ln_cnt:4*ln_cnt]),
                                    .clk_cpu              (clk_cpu),
                                    .rd_req               (rd_req_errorcounter[ln_cnt]));

   
   
   jesd_rc_counter comma_framecounter  (
                                          // Outputs
                                          .counter              (linktest_receivecounter[31+32*ln_cnt:32*ln_cnt]),
                                          .rd_ack               (rd_ack_receivecounter[ln_cnt]),
                                          // Inputs
                                          .clk_character        (clk_character),
                                          .rst_clk_character    (rst_clk_character),
                                          .incr_count           (incr_comma_frame_count[3+4*ln_cnt:4*ln_cnt]),
                                          .clk_cpu              (clk_cpu),
                                          .rd_req               (rd_req_receivecounter[ln_cnt]));


      
   jesd_rc_counter #(.COUNTER_WIDTH(1)) 
   u_ilas_status  (
                                          // Outputs
                                .counter              (ilas_status[ln_cnt]),
                                .rd_ack               (ilas_status_rd_ack_per_lane[ln_cnt]),
                                // Inputs
                                .clk_character        (clk_character),
                                .rst_clk_character    (rst_clk_character),
                                .incr_count           ({3'b0,ilas_mismatch_r[ln_cnt]}),
                                .clk_cpu              (clk_cpu),
                                .rd_req               (ilas_status_rd_req));

   end endgenerate // block: lane_generate



// Use testmode setting to derive ilas disable because if ilas is enabled and we need to count the frames the eof generation logic will skip first few frames
   always @(posedge clk_cpu or posedge rst) begin
     if (rst) begin
       txrx_ilas_disable <= 1'b0;
     end
     else begin
       txrx_ilas_disable <= rx_feature_disable[0] | (txrx_enablelinktest_reg == 2'b10);
     end        
   end

   // Multicycle path global variables
   wire [7:0] sum_ilas_com_param_next;
   reg [NO_LANES-1:0]  active_lane_next;
   reg [NO_CONVERTERS-1:0]  active_conv_next;

   always @ (posedge clk_cpu or posedge rst) begin
      if (rst) begin
         active_lane <= 'h1;
         active_conv <= 'h4;
         txrx_ilas_length_mframe <= 9'h4;
         frame_length_char <= 9'h1;
         sum_ilas_com_param <= 8'h0;
      end
      else begin
         active_lane <= active_lane_next;         
         active_conv <= active_conv_next;         
         txrx_ilas_length_mframe <= rx_ilas_details[31:24]  + 1'b1;
         frame_length_char <= txrx_f_reg + 1'b1;
         sum_ilas_com_param <= sum_ilas_com_param_next;
      end
   end

   always @(*) begin
      case (txrx_l_reg[4:0])
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

   assign sum_ilas_com_param_next = txrx_m_reg
                     + {4'h0,txrx_bank_id_reg }
                     + {3'h0,txrx_l_reg }
                     + {7'h0,txrx_scr_reg  }
                     + txrx_f_reg
                     + {3'h0,txrx_k_reg }
                     + txrx_did_reg
                     + {6'h0,txrx_cs_reg }
                     + {3'h0,txrx_n_reg }
                     + {5'h0,txrx_subclass_reg}
                     + {3'h0,txrx_ntotal_reg}
                     + {8'h1}
                     + {3'h0,txrx_s_reg}
                     + {7'h0,txrx_hd_reg}
                     + {3'h0,txrx_cf_reg};

   
   assign txrx_lane_align_mon_disable      = rx_feature_disable[1];
   assign txrx_lane_align_char_rep_disable = rx_feature_disable[2];
   assign txrx_ilas_comparison_disable     = rx_feature_disable[3] ;
   assign txrx_resync_on_comma_disable     = rx_feature_disable[4] ;
   assign txrx_symbol_err_via_sync_disable = rx_feature_disable[5];   
   assign rbd_char_cnt                     = rx_ilas_details[22:12];
   assign mframe_length_char               = rx_ilas_details[10:0];

   always @(posedge clk_character or posedge rst_clk_character) begin // ensure input to the rc_counter is flopped
     if (rst_clk_character) begin
        ilas_mismatch_r <= {NO_LANES{1'b0}};
     end
     else begin
        ilas_mismatch_r <= (txrx_ilas_comparison_disable | txrx_ilas_disable) ? {NO_LANES{1'b0}} : ilas_mismatch;
     end // else: !if(rst)
   end
   
   reg [8:0] interrupt_reg;
   reg       interrupt_pin_value;
   
   wire      rd_interrupt_req = rd_interrupt & ~rd_interrupt_r;
   
   always @(posedge clk_character or posedge rst_clk_character) begin
     if (rst_clk_character) begin
        interrupt_reg <= 9'h0;
        interrupt_rd_val <= 9'h0;
        rd_interrupt_r <= 1'b0; 
        interrupt_pin_value <= 1'b0;        
     end
     else begin
        rd_interrupt_r <= rd_interrupt;                
        if (rd_interrupt_req) begin
           interrupt_rd_val <= interrupt_reg;
        end
        interrupt_pin_value <= |(interrupt_reg & ~rx_core_interrupt_mask);
        interrupt_reg[0] <= (interrupt_reg[0] & ~rd_interrupt_req)  || 
                            ((mframe_symbol_err != 8'h00) & ~txrx_symbol_err_via_sync_disable);
        interrupt_reg[1] <= (interrupt_reg[1]  & ~rd_interrupt_req) || comb_cgs_sync_req;
        interrupt_reg[2] <= (interrupt_reg[2]  & ~rd_interrupt_req) || (|(underrun_err));
        interrupt_reg[3] <= (interrupt_reg[3]  & ~rd_interrupt_req) || (|(overrun_err));
        interrupt_reg[4] <= (interrupt_reg[4]  & ~rd_interrupt_req) || (|(disparity_err));        
        interrupt_reg[5] <= (interrupt_reg[5]  & ~rd_interrupt_req) || (|(unexpected_k_err));
        interrupt_reg[6] <= (interrupt_reg[6]  & ~rd_interrupt_req) || (|(not_in_table_err));
        interrupt_reg[7] <= (interrupt_reg[7]  & ~rd_interrupt_req) || (|(alignment_err));
        interrupt_reg[8] <= (interrupt_reg[8]  & ~rd_interrupt_req) || (|(cgs_sync_req));
     end // else: !if(rst)
   end // always @ (posedge clk_character or posedge rst_clk_character)

   jesd_simple_sync
     intr_rd_req_sync 
       (
        .src_signal (rx_core_interrupt_status_cs & reg_read_int),
        .src_clk (clk_cpu),
        .dest_clk (clk_character), 
        .dest_signal (rd_interrupt)                     
        );
   
jesd_simple_sync  #(.REG_IP (0))
     intr_rd_ack_sync
       (
        .src_signal (rd_interrupt_r),
        .src_clk (1'b0),
        .dest_clk (clk_cpu), 
        .dest_signal (rd_interrupt_ack)                     
        );
   

   jesd_simple_sync #(.REG_IP (0))
   intr_sync (
     .src_signal (interrupt_pin_value),
     .src_clk (1'b0),
     .dest_clk (clk_cpu), 
     .dest_signal (s_interrupt)
       );
   

always @(*) begin
   case (txrx_f_reg)
     0:min_sync_duration = 5 + 9; // 9 octets = 9 frames
     1:min_sync_duration = 5 + 4 + 1; // 9 octets = 4.xxx frames
     2:min_sync_duration = 5 + 3; // 9 octets = 3 frames
     3:min_sync_duration = 5 + 2 + 1; // 9 octets = 2.xxx frames
     4,5,6,7:min_sync_duration = 5 + 1 + 1; // 9 octets = 1.xxx frames
     default:min_sync_duration = 5 + 1; // 9 octets = 1 frames
   endcase // case (txrx_f_reg)
end // always @ begin
  
  reg [NO_LANES-1:0] inject_cgs_err_r, inject_not_in_table_err_r, inject_lane_alignment_err_r,inject_frame_alignment_err_r;
   assign inject_cgs_err = rx_err_inj_req[7:0];
   assign inject_not_in_table_err = rx_err_inj_req[15:8];
   assign inject_lane_alignment_err = rx_err_inj_req[23:16];
   assign inject_frame_alignment_err = rx_err_inj_req[31:24];

  reg [NO_LANES-1:0] lane_pointer;
  always @(posedge clk_character or posedge rst_clk_character)
  begin
    if (rst_clk_character)
      begin
        inject_cgs_err_r <= 'h0;
        inject_not_in_table_err_r <= 'h0;
        inject_lane_alignment_err_r <= 'h0;
        inject_frame_alignment_err_r <= 'h0;
        lane_pointer = 'h0;
      end
    else
    begin
        lane_pointer = 1<<rx_err_inj_req[4:0];
        case (rx_err_inj_req [7:5])
        3'h0: begin
          inject_cgs_err_r  <= lane_pointer;
        end
        3'h1: begin
          inject_not_in_table_err_r <= lane_pointer;
        end
        3'h2: begin
          inject_lane_alignment_err_r <= lane_pointer;
        end
        3'h3: begin
          inject_frame_alignment_err_r <= lane_pointer;
        end
        endcase
        
//      case (rx_err_inj_req [4:0])
//        5'h1:lane_pointer <= 'h1;
//      default:lane_pointer = 'h0;
//      endcase
    end
   
   end

               
   always @(posedge clk_cpu or posedge rst) begin
      if (rst) 
         tl_spec_param <= 48'h0;
      else
      begin
         tl_spec_param[1:0] <= {txrx_cs_reg[1:0]};
         tl_spec_param[5:2] <= {txrx_cf_reg[0]};
         tl_spec_param[9:6] <= txrx_s_reg[3:0];
         tl_spec_param[17:10] <= txrx_n_reg[4:0];
         tl_spec_param[25:18]  <= txrx_ntotal_reg[4:0];
         tl_spec_param[33:26]  <= txrx_f_reg[7:0];
         tl_spec_param[41:34]  <= cf_first_nib[7:0];
         tl_spec_param[46:42]  <= cf_first_ln[4:0];
         tl_spec_param[47   ]  <= txrx_hd_reg;
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
   
   
endmodule // jesd_rx_core_register

//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
