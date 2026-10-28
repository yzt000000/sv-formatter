`ifndef JESD_JESD204B_TX_MACRO
  `define JESD_JESD204B_TX_MACRO
  `define MAX_CONV_CS_ADDR 384 //ToDo: If it changes, need to change parameter CONV_CS_ADDR_SIZE
  `define CONV_A     3'b000
  `define CONV_B     3'b001
  `define CONV_C     3'b010
  `define CONV_D     3'b011
  `define CONV_E     3'b100
  `define CONV_F     3'b101
  `define CONV_NONE  3'b110
`endif //  `ifndef JESD_JESD204B_TX_MACRO

// `ifndef AXI_BUS
//   `define AXI_BUS
// `endif
`ifndef APB_BUS
  `define APB_BUS
`endif

// `ifndef AVALON_BUS
//   `define AVALON_BUS
// `endif

//`ifndef AUTO_COMPUTE_USER_PARAMS
//  `define AUTO_COMPUTE_USER_PARAMS
//`endif

`ifndef BYPASS_8B10B
  `define BYPASS_8B10B
`endif

//`ifndef TX_LINK_TOP
//  `define TX_LINK_TOP
//`endif

`ifndef LANE_LONG
  `define LANE_LONG
`endif

//`ifndef TX_LIGHT_MAPPER
//  `define TX_LIGHT_MAPPER
//`endif

// `ifndef TX_EXTERNAL_REGS
//   `define TX_EXTERNAL_REGS
// `endif

//`ifndef I2C_IF
//  `define I2C_IF
//`endif //  `ifndef I2C_IF

`define TX_RESET_VALUES

`ifdef    TX_RESET_VALUES
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
  `define TX_ILAS_DELAY_RESET_VALUE 7'h04
  `define TX_ILAS_NUM_MFRAME_RESET_VALUE 8'h3
  `define TX_ILAS_MFRAME_RESET_VALUE 11'h11
  `define TX_INTMASK_RESET_VALUE {4{1'b1}}
  `define TX_RX_ADJCNT_RESET_VALUE 4'h0
  `define TX_RX_ADJDIR_RESET_VALUE 1'h0
  `define TX_RX_PHADJ_RESET_VALUE 1'h0
  `define TX_CLK_RATIO_RESET_VALUE 2'h0
`endif
