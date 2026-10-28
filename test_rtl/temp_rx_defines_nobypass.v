`ifndef JESD_JESD204B_RX_MACRO
  `define JESD_JESD204B_RX_MACRO
  `define MAX_CONV_CS_ADDR 384 //ToDo: If it changes, need to change parameter CONV_CS_ADDR_SIZE
  `define CONV_A     3'b000
  `define CONV_B     3'b001
  `define CONV_C     3'b010
  `define CONV_D     3'b011
  `define CONV_E     3'b100
  `define CONV_F     3'b101
  `define CONV_NONE  3'b110
`endif //  `ifndef JESD_JESD204B_RX_MACRO


// `ifndef AXI_BUS
//   `define AXI_BUS
// `endif

`ifndef APB_BUS
  `define APB_BUS
`endif

//`ifndef AVALON_BUS
//  `define AVALON_BUS
//`endif

//`ifndef BYPASS_8B10B
//  `define BYPASS_8B10B
//`endif

//`ifndef BYPASS_ALIGN
//  `define BYPASS_ALIGN
//`endif

//`ifndef RX_LINK_TOP
//  `define RX_LINK_TOP
//`endif

`ifndef LANE_LONG
  `define LANE_LONG
`endif

//`ifndef RX_LIGHT_MAPPER
//  `define RX_LIGHT_MAPPER
//`endif

// `ifndef RX_EXTERNAL_REGS
	// `define RX_EXTERNAL_REGS
// `endif

//`ifndef AUTO_COMPUTE_USER_PARAMS
//  `define AUTO_COMPUTE_USER_PARAMS
//`endif

//`ifndef I2C_IF
//  `define I2C_IF
//`endif //  `ifndef I2C_IF


`define RX_RESET_VALUES

`ifdef  RX_RESET_VALUES
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
