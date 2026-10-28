   
   // list of register with respective address
`ifndef TX_DEFINED 
  `ifndef RX_DEFINED 
    `define PARAM_TXRX_BANK_ID    10'h0
    `define PARAM_TXRX_DID        10'h4
    `define PARAM_TXRX_LID        10'h8
    `define PARAM_TXRX_LID2        10'hC //added feature
    `define PARAM_TXRX_LID3        10'h10 //added feature
    `define PARAM_TXRX_LID4        10'h14 //added feature
    `define PARAM_TXRX_SUBCLASS   10'h1C
    `define PARAM_TXRX_CF         10'h20
    `define PARAM_TXRX_CS         10'h24
    `define PARAM_TXRX_F          10'h28
    `define PARAM_TXRX_K          10'h2C
    `define PARAM_TXRX_L          10'h30
    `define PARAM_TXRX_N          10'h34
    `define PARAM_TXRX_M          10'h38
    `define PARAM_TXRX_NTOTAL     10'h3C
    `define PARAM_TXRX_S          10'h40
    `define PARAM_TXRX_HD         10'h44
    `define PARAM_TXRX_SCR        10'h48
    `define PARAM_TXRX_ENABLEMODULE             10'h50
    `define PARAM_TXRX_ENABLELINKTEST           10'h54
    `define PARAM_PRBS_TEST_ENABLE  10'h134
  `endif
  `define PARAM_TX_TAILBITS              10'h58
  `define PARAM_LINKTEST_CUSTOM_DATA     10'h5C
  `define PARAM_LINKTEST_CUSTOM_ENABLE   10'h60
  `define PARAM_TX_FEATURE_DISABLE       10'h120
  `define PARAM_TX_CORE_INTERRUPT_MASK   10'h124
  `define PARAM_TX_CORE_INTERRUPT_STATUS  10'h128
  `define PARAM_TX_ILAS_DETAILS  10'h12C
  `define PARAM_TX_ILAS_DELAY    10'h2C0
  `define PARAM_JSPAT_TEST_ENABLE  10'h138
  `define PARAM_CLK_RATIO          10'h13C
`endif

`define TX_DEFINED
