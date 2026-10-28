  `include "jesd_jesd204b_rx_defines.v" 
  `include "jesd_jesd204b_tx_defines.v" 
  `include "jesd_jesd204b_tx_address_defines.v" 
  `include "jesd_jesd204b_rx_address_defines.v" 
  `define TESTCASE
//  `define PRBS_TEST_ENABLE
//  `define JTSPAT_TEST_ENABLE
//  `define BIT_DELAY
`ifdef BIT_DELAY
 `define BIT_DELAY 2 //Defines how many bits will be shifted inside the lane
`endif  

`ifdef AXI_BUS
  `undef AXI_BUS
`endif
`define APB_BUS
//`define TEST_LATENCY

//`define SLAVE_INTERRUPT_TEST

module jesd_tb_link_layer_1tx_2rx #(

    parameter JESD_MAST_INST=1,              //! Used in subclass2 mode to synchronize local LMFC of multiple RX instances
    parameter JESD_DESKEW_BUF_ASIZE=8,       //! Determines Depth of lane alignment buffer per lane.     
    parameter JESD_DESKEW_BUF_DSIZE=36,      //! Width of deskew buffer
    parameter JESD_CSR_SELECT_MASK=24'h000,  //! Will be used to match slave_addr[31:24]
    parameter JESD_CSR_SELECT_MASK_TX=24'h000,  //! Will be used to match slave_addr[31:24]
    parameter JESD_CSR_SELECT_MASK_RX=24'h000,  //! Will be used to match slave_addr[31:24]
    parameter CLK_RATIO=0,    
    parameter JESD_NO_LANES=2,               //! User defined parameter. Legal values 1 to 8
    parameter JESD_NO_SERDES_WORDS=4,        //! User defined parameter to indicate serdes data path width in terms of 10 bit symbols . Valid values are 1,2,4
    parameter JESD_PAR_IF=1,                 //!User defined parameter to select a shared/dedicated interface between the core and application layer 
    parameter JESD_NO_FRAMES=2,
    parameter JESD_N_REG=16,
    parameter JESD_NO_SAMPLES=1,
    parameter JESD_NO_CONVERTERS=1,
    parameter BUS_EXTENSION=0,
    parameter JESD_NTOTAL=16,
    parameter JESD_CS_REG=0,
    parameter JESD_CF_REG=0,
    parameter JESD_K_REG=16
)
    (
	// `ifndef TESTCASE

// `endif   

`ifdef TESTCASE 
    output clk_tester,
    input [32*JESD_NO_LANES-1:0]  tframe_data,
    input                         tframe_data_vld,
    output                        tframe_data_rdy,
    input [32*JESD_NO_LANES-1:0]  data_to_tl, //! Frame Sample data receieved
    output [JESD_NO_LANES-1:0]    data_to_tl_vld//!Push request for received frame data. One bit per converter. If CSC_PAR_IF=0 it will be one-hot encoded 
`endif );
     
`ifndef BYPASS_8B10B  
  localparam WORD_SIZE=10;
`endif
`ifdef BYPASS_8B10B  
  localparam WORD_SIZE=8;
  reg [(4*JESD_NO_LANES)-1:0]     rxdata_k;
  reg [(4*JESD_NO_LANES)-1:0]     rxdisparity_err;
  reg [(4*JESD_NO_LANES)-1:0]     rxnot_in_table_err;
`endif

`ifdef BYPASS_8B10B
  genvar ki;
  generate
    for (ki = 0; ki < JESD_NO_LANES; ki = ki + 1) begin: gen_rxdata_k
      always @(*) begin
        if ((lane_generate[ki].jesd_jesd204b_rx_link.lane_generate[0].jesd_lane_rxdp.jesd_lane_cgs_sm.cgs_curr_state == 4'b0100) &&
            (lane_generate[ki].jesd_jesd204b_rx_link.lane_generate[0].jesd_lane_rxdp.jesd_lane_fs_sm.fs_curr_state == 2'b10))
          rxdata_k[4*ki +: 4] = 4'b0000;
        else
          rxdata_k[4*ki +: 4] = 4'b1111;
      end
    end
  endgenerate
`endif

  
  reg                         clk_sample;   //! Clock  for sample interface signals. Maybe 1xclk_character or 2xclk_character
  reg                         clk_frame;    //! Clock for aligning samples to frame timing and sync_n processing
  reg                         clk_cpu;      //!Clock used by the CPU interface to access Control and Status Registers (CSR)
  reg                         clk_character;//! clock used for data path and control logic
  reg [JESD_NO_LANES-1:0]     clk_serdes;   //! Clock used for serdes interface. Maybe 1xclk_character or 2xclk_character or 4xclk_character 
  reg                         reset_csr;    //!Active High Reset, de-assertion is aligned to clk_cpu
  reg                         reset_core;   //! Active High Reset, de-assertion is aligned to clk_cpu

    //! Synchronization interface signals aligned to frame_clk domain
  wire [JESD_NO_LANES-1:0]    sync_b;      //! Combined sync_b signal from  all lanes connected to a single ADC device. 
  reg  [JESD_NO_LANES-1:0]    lmfc_div2_i; //! Used if CSC_MAST_INST=0
  wire [JESD_NO_LANES-1:0]    lmfc_div2_o; //! Generated if CSC_MAST_INST=1
  
    //! Synchronization interface signals aligned to ????? domain 
  reg                         sysref;      //! Signal used for aligning LMFC when operating in subclass 1 mode.
  reg [WORD_SIZE*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i;//! Encoded symbol data of all lanes
  wire [WORD_SIZE*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_o;//! Encoded symbol data of all lanes

    //! Serdes RX Interface signals aligned to clk_serdes
  wire [JESD_NO_LANES-1:0]    serdes_data_vld;
    
`ifndef TESTCASE 
  reg [32*JESD_NO_LANES-1:0] tframe_data;
  reg                        tframe_data_vld;
  wire                       tframe_data_rdy;

	wire [32*JESD_NO_LANES-1:0] data_to_tl;
	wire [JESD_NO_LANES-1:0]    data_to_tl_vld;
  
`endif 
    //! Sample interface signals aligned to clk_sample. If  CSC_PAR_IF=0 then all converters will get data via sample_data_o[0] and sample_cntrl_o[0]. Valid information is expected on these bits in clock where sample_valid_o is asserted
    wire [JESD_NO_LANES-1:0]                      rx_tvalid;//!Push request for received frame data. One bit per converter. If CSC_PAR_IF=0 it will be one-hot encoded
	
    //! The frame length (register N). Used to synthesize clk_character + clk_serdes_* It is just a copy of the CPU register N for use in attached logic
    wire [7:0]                                     sample_length_o_tx;
    wire [7:0]                                     sample_length_o_rx;

    wire [31:0] all_ones = 32'hFFFFFFFF;

`ifdef TESTCASE 	
  assign clk_tester = clk_character;
`endif

 // wire [5*JESD_NO_LANES-1:00]                    txrx_lid_reg_rx;
//  wire [5*JESD_NO_LANES-1:00]                    txrx_lid_reg_tx;



   wire [29:00]                    txrx_lid_reg_tx;


  wire [JESD_NO_LANES-1:0]                         active_lane_rx;
  wire [7:0]                                       active_lane_rx_link;
  wire [8-1:0]                                     active_lane_tx;   
  wire [JESD_NO_CONVERTERS-1:0]                                       active_conv_rx;
  wire [7:0]                                       active_conv_tx;
  wire [8:0]                                       frame_length_char_tx;
  wire [46:0]                                      tl_spec_param_rx;
  wire [35:0]                                      tl_spec_param_tx;
//   wire [20*32-1:0]                                 tl_user_param_rx;
//   wire [20*32-1:0]                                 tl_user_param_tx;   
  wire                                             txrx_enablemodule_reg_rx;
  wire                                             txrx_enablemodule_reg_tx;
  wire [JESD_NO_LANES+2:0]                         generated_resets_tx;
  wire                                             comb_cgs_sync_req_rx;   
  wire                                             comb_cgs_sync_req_tx;      


`ifdef AXI_BUS      
    reg                                           slave_write_tx;     //! Active high signal indicating valid info on slave_write_data and slave_addr. Once asserted remains high until slave_ack 
    reg                                           slave_write_rx;     //! Active high signal indicating valid info on slave_write_data and slave_addr. Once asserted remains high until slave_ack 
    reg                                           slave_read_tx;      //! Active high signal indicating valid info on  slave_addr. Once asserted remains high until slave_ack
    reg                                           slave_read_rx;      //! Active high signal indicating valid info on  slave_addr. Once asserted remains high until slave_ack
    reg [31:0]                                    slave_write_data;//! data to be written to selected dword
    reg [31:0]                                    slave_addr;      //! bits [7:0] will be used to select a dword register if slave_addr[31:23] == CSC_CSR_SELECT_MASK.
    wire                                          slave_ack_rx;       //! Active high signal to indicate completion of write and read access.
    wire                                          slave_ack_tx;       //! Active high signal to indicate completion of write and read access.
    wire [31:0]                                   slave_read_data_rx;   //! Return data valid whne slave_ack=1 
    wire [31:0]                                   slave_read_data_tx;   //! Return data valid whne slave_ack=1 
`endif
   
`ifdef APB_BUS
   reg [31:0]               paddr;
   reg                      pwrite;
   reg [JESD_NO_LANES-1:0]  psel_rx;
   reg                      psel_tx;
   reg                      penable;
   reg [31:0]               pwdata;
   wire [JESD_NO_LANES-1:0] pready_rx;
   wire                     pready_tx;
   wire [31:0]              prdata_rx [JESD_NO_LANES-1:0];
   wire [31:0]              prdata_tx;
   

`endif

`ifdef AVALON_BUS
   reg [31:0]         address;
   reg [31:0]         writedata;     
   reg                write_tx;
   reg                write_rx;
   reg                read_tx;
   reg                read_rx;   
   wire               waitrequest_tx;
   wire               waitrequest_rx;
   wire [31:0]        readdata_tx;
   wire [31:0]        readdata_rx;
 
`endif
`ifdef I2C_IF
   reg [7:0]       rf_addr_rx;
   reg             rf_wen_rx;
   reg             rf_ren_rx;
   wire [31:0]     rf_rdata_rx;
   reg  [31:0]     rf_wdata_rx; 
   reg [7:0]       rf_addr_tx;
   reg             rf_wen_tx;
   reg             rf_ren_tx;
   wire [31:0]     rf_rdata_tx;
   reg  [31:0]     rf_wdata_tx; 
`endif
   
   
   integer LID,LID2,LID3,LID4,subclass,CF,CS,F,K,L,N,M,HD,NTOTAL,S,nibble_l0_lower,nibble_l1_lower,nibble_l2_lower,nibble_l3_lower,nibble_l4_lower,nibble_l5_lower,nibble_l6_lower,nibble_l7_lower,nibble_l0_upper,nibble_l1_upper,nibble_l2_upper,nibble_l3_upper,nibble_l4_upper,nibble_l5_upper,nibble_l6_upper,nibble_l7_upper,lane_start_map_l1l0, lane_start_map_l3l2,lane_start_map_l7l6,lane_start_map_l5l4; 
   
    //! Interface  to access control and status registers. All signals are aligned to cpu_clk

//    wire                                          slave_interrupt_rx;
//    wire                                          slave_interrupt_tx;

    
    //! CSR information aligned to cpu_clk



   wire test_mode = 1'b0;
   
   



	if (JESD_NO_LANES<8)
		assign active_lane_rx_link = 8'h00 | active_lane_rx;
	else
		assign active_lane_rx_link = active_lane_rx[7:0];





  genvar ln_cnt;
  generate for (ln_cnt = 0; ln_cnt < JESD_NO_LANES; ln_cnt = ln_cnt + 1) begin : lane_generate

    //////////////////////////////////////////////
    // Replay RAM INTERFACE
    // 
    // Runs in clk_character domain
    //
    //////////////////////////////////////////////
    wire [(32*1)-1:0]                  replay_ram_rd_data;       // Valid one clk after replay_rd_en=1
    wire [6:0]                         replay_ram_write_addr;
    wire  [32*1-1:0]                   replay_ram_wr_data;
    wire                               replay_ram_write_en;
    wire                               replay_ram_read_en;
    wire  [6:0]                        replay_ram_read_addr;
    wire [29:00]                       txrx_lid_reg_rx;
    wire [1+2:0]                       generated_resets_rx;
    wire [8:0]                         frame_length_char_rx;
    wire [32-1:0]                   rx_tdata; //! Frame Sample data receieved
    wire [4-1:0]                    rx_frame_error;//!Indicates synchronization error and sample_data to be ignored
    wire [4-1:0]                    rx_start_of_frame; //! Frame Control data received
    wire [4-1:0]                    rx_end_of_frame; //! Frame Control data receive
    //////////////////////////////////////////////
    // DESKEW RAM INTERFACE
    // 
    // Runs in clk_character domain
    //
    //////////////////////////////////////////////
    wire [(1*JESD_DESKEW_BUF_DSIZE)-1:0]    deskew_rd_data;         // Valid one clk after deskev_rd_en=1
    wire [(1*JESD_DESKEW_BUF_ASIZE)-1:0]    deskew_wr_addr;
    wire [1-1:0]                            deskew_wr_en;
    wire [(1*JESD_DESKEW_BUF_DSIZE)-1:0]    deskew_wr_data;
    wire [(1*JESD_DESKEW_BUF_ASIZE)-1:0]    deskew_rd_addr;
    wire [1-1:0]                            deskew_rd_en;

    jesd_sdpr
    #(.DSIZE (JESD_DESKEW_BUF_DSIZE),
      .ASIZE (JESD_DESKEW_BUF_ASIZE-2)
    )
    ram_deskew 
    (
      .clk        (clk_character),
      //write ports
      .wr_en      (deskew_wr_en[0]),
      .wr_addr    (deskew_wr_addr[(JESD_DESKEW_BUF_ASIZE)-1:2]),
      .wr_data    (deskew_wr_data[(JESD_DESKEW_BUF_DSIZE)-1:0]),
      //Read ports
      .rd_en      (deskew_rd_en[0]),
      .rd_addr    (deskew_rd_addr[(JESD_DESKEW_BUF_ASIZE)-1:2]),
      .rd_data    (deskew_rd_data[(JESD_DESKEW_BUF_DSIZE)-1:0])
    );
    
    jesd_sdpr
    #(.DSIZE (32*1),
      .ASIZE (7)
    )
    ram_replay 
    (
      //write ports
      .clk      (clk_character),
      .wr_en    (replay_ram_write_en),
      .wr_addr   (replay_ram_write_addr),
      .wr_data  (replay_ram_wr_data),
      //Read ports
      
      .rd_en    (replay_ram_read_en),
      .rd_addr   (replay_ram_read_addr),
      .rd_data  (replay_ram_rd_data)
    );
    
    
    jesd_replay_lid_mux #(/*AUTOINSTPARAM*/
    // Parameters
      .JESD_NO_LANES    (1)) 
    jesd_replay_lid_mux  (/*AUTOINST*/
      // Outputs
      .replay_ram_wr_data     (replay_ram_wr_data[32-1:0]),
      .replay_ram_write_addr  (replay_ram_write_addr[6:0]),
      .replay_ram_read_addr   (replay_ram_read_addr[6:0]),
      .replay_ram_write_en    (replay_ram_write_en),
      .replay_ram_read_en     (replay_ram_read_en),                          
      .data_to_tl             (data_to_tl[32*(ln_cnt+1)-1:32*ln_cnt]),
      .data_to_tl_vld         (data_to_tl_vld[ln_cnt]),
      // Inputs
      .clk_character          (clk_character),
      .rst_clk_character      (generated_resets_rx[0]),
      .frame_length_char      (frame_length_char_rx[8:0]),
      .active_lane            (active_lane_rx_link[7:0]),
      .txrx_lid_reg           (txrx_lid_reg_rx[4:0]),
      .rx_tvalid              (rx_tvalid[ln_cnt]),
      .rx_frame_error         (rx_frame_error),
      .rx_end_of_frame        (rx_end_of_frame),
      .rx_start_of_frame      (rx_start_of_frame),
      .rx_tdata               (rx_tdata),
      .replay_ram_rd_data     (replay_ram_rd_data)
     );
    
     jesd_jesd204b_rx_link  

     #(
        .JESD_NO_SERDES_WORDS   (JESD_NO_SERDES_WORDS),
        .JESD_DESKEW_BUF_ASIZE  (JESD_DESKEW_BUF_ASIZE),
        .JESD_DESKEW_BUF_DSIZE  (JESD_DESKEW_BUF_DSIZE),
        .JESD_MAST_INST         (ln_cnt==0 ? 1 : 0),
        .JESD_NO_CONVERTERS     (JESD_NO_CONVERTERS),
        .JESD_CSR_SELECT_MASK   (JESD_CSR_SELECT_MASK_RX),
        .JESD_NO_LANES          (1)

        )
        
     jesd_jesd204b_rx_link    (
      
`ifdef APB_BUS
       //Inputs in the APB bus
        .paddr                  (paddr),
        .pwrite                 (pwrite),
        .psel                   (psel_rx[ln_cnt]),
        .penable                (penable),
        .pwdata                 (pwdata),

       //Outputs in the APB_bus
        .pready                 (pready_rx[ln_cnt]),
        .prdata                 (prdata_rx[ln_cnt]),
       
          
`endif
       
`ifdef AXI_BUS
       //Outputs in the AXI bus
        .slave_ack              (slave_ack_rx),
        .slave_read_data        (slave_read_data_rx[31:0]),
      
       //Inputs in the AXI bus
        .slave_write            (slave_write_rx),
        .slave_read             (slave_read_rx),
        .slave_write_data       (slave_write_data[31:0]),
        .slave_addr             (slave_addr[31:0]),
       

`endif 
      
`ifdef AVALON_BUS
        .address                (address),
        .write                  (write_rx),
        .read                   (read_rx),
        .waitrequest            (waitrequest_rx),
        .readdata               (readdata_rx),
        .writedata              (writedata),
`endif

`ifdef I2C_IF
        .rf_addr                (rf_addr_rx),
        .rf_wen                 (rf_wen_rx),
        .rf_ren                 (rf_ren_rx),
        .rf_rdata               (rf_rdata_rx),
        .rf_wdata               (rf_wdata_rx), 
`endif
      

       //outputs
        .sync_b                 (sync_b[ln_cnt]), 
        .lmfc_div2_o            (lmfc_div2_o[ln_cnt]), 
        .rx_tdata               (rx_tdata),
        .rx_tvalid              (rx_tvalid[ln_cnt]),
        .rx_frame_error         (rx_frame_error), 
        .rx_start_of_frame      (rx_start_of_frame),
        .rx_end_of_frame        (rx_end_of_frame),
        .slave_interrupt        (slave_interrupt_rx), 

        .clk_cpu                (clk_cpu), 
        .clk_character          (clk_character), 
        .clk_serdes             (clk_serdes[ln_cnt]), 
        .reset_csr              (reset_csr), 
        .reset_core             (reset_core), 
        .lmfc_div2_i            (lmfc_div2_i[ln_cnt]),
      
        .txrx_lid_reg           (txrx_lid_reg_rx[4:0]),
        .active_lane            (active_lane_rx[ln_cnt]),
        .frame_length_char      (frame_length_char_rx),
        .generated_resets       (generated_resets_rx),
     
        //////////////////////////////////////////////
        // DESKEW RAM INTERFACE
        // 
        // Runs in clk_character domain
        //
        //////////////////////////////////////////////
        .deskew_rd_data         (deskew_rd_data),
        .deskew_wr_addr         (deskew_wr_addr),
        .deskew_wr_en           (deskew_wr_en  ),
        .deskew_wr_data         (deskew_wr_data),
        .deskew_rd_addr         (deskew_rd_addr),
        .deskew_rd_en           (deskew_rd_en  ),

        //inputs

`ifdef BYPASS_8B10B  
        .rxdata_k               (rxdata_k[4*ln_cnt +: 4]),
        .rxdisparity_err        (rxdisparity_err[4*ln_cnt +: 4]),
        .rxnot_in_table_err     (rxnot_in_table_err[4*ln_cnt +: 4]),
`endif
        
        .sysref                 (sysref), 
        .test_mode              (test_mode),
`ifdef BIT_DELAY
        .serdes_data_i          (serdes_data_i[(ln_cnt+1)*WORD_SIZE*JESD_NO_SERDES_WORDS-1:ln_cnt*WORD_SIZE*JESD_NO_SERDES_WORDS])
`endif    
`ifndef BIT_DELAY
        .serdes_data_i          (serdes_data_o[(ln_cnt+1)*WORD_SIZE*JESD_NO_SERDES_WORDS-1:ln_cnt*WORD_SIZE*JESD_NO_SERDES_WORDS])
`endif
    );
  end endgenerate

jesd_jesd204b_tx_link  
#(
      .JESD_NO_SERDES_WORDS (JESD_NO_SERDES_WORDS),
      .JESD_CSR_SELECT_MASK (JESD_CSR_SELECT_MASK_TX),
      .JESD_NO_LANES        (JESD_NO_LANES)
      )
      
  jesd_jesd204b_tx_link  (      
    .clk_cpu                (clk_cpu),
    .clk_character          (clk_character),
    .clk_serdes             (clk_serdes[0]),
    .reset_csr              (reset_csr),
    .reset_core             (reset_core),
    .test_mode              (test_mode),
    .sync_b                 (&(sync_b)),
    .sysref                 (sysref),
    .serdes_data_o          (serdes_data_o),
    .serdes_data_vld        (serdes_data_vld),
`ifdef APB_BUS
   //Outputs in the APB_bus
    .paddr                  (paddr),
    .pwrite                 (pwrite),
    .psel                   (psel_tx),
    .penable                (penable),
    .pwdata                 (pwdata),

   //Inputs in the APB bus
    .pready                 (pready_tx),
    .prdata                 (prdata_tx),  
`endif
   
`ifdef AXI_BUS
   //Outputs in the AXI bus
    .slave_ack              (slave_ack_tx),
    .slave_read_data        (slave_read_data_tx[31:0]),
   //Inputs in the AXI bus
    .slave_write            (slave_write_tx),
    .slave_read             (slave_read_tx),
    .slave_write_data       (slave_write_data[31:0]),
    .slave_addr             (slave_addr[31:0]),
`endif 
  
`ifdef AVALON_BUS
    .address                (address),
    .write                  (write_tx),
    .read                   (read_tx),
    .waitrequest            (waitrequest_tx),
    .readdata               (readdata_tx),
    .writedata              (writedata),
`endif
`ifdef I2C_IF
    .rf_addr                (rf_addr_tx),
    .rf_wen                 (rf_wen_tx),
    .rf_ren                 (rf_ren_tx),
    .rf_rdata               (rf_rdata_tx),
    .rf_wdata               (rf_wdata_tx), 
`endif


    .slave_interrupt        (slave_interrupt_tx),

//    .txrx_lid_reg          (txrx_lid_reg_tx),
//    .active_lane           (active_lane_tx),
//    .tl_spec_param         (tl_spec_param_tx),
//    .tl_user_param         (tl_user_param_tx),
//    .txrx_enablemodule_reg (txrx_enablemodule_reg_tx),
//    .generated_resets      (generated_resets_tx),
//    .sample_length_o       (sample_length_o_tx),     

    .frame_length_char      (frame_length_char_tx),
    .tframe_data            (tframe_data),
    .tframe_data_vld        (tframe_data_vld),
    .tframe_data_rdy        (tframe_data_rdy)
  );
 
reg [2:0] state;
reg [2:0] next_state;
reg [31:0] data_ack;

parameter TX_CORE = 2'b00;
parameter RX_CORE_0 = 2'b01;
parameter RX_CORE_1 = 2'b10;
 
`ifdef APB_BUS
  parameter IDLE = 3'b001, SETUP = 3'b010, ACCESS = 3'b011, IDLE_2 = 3'b100, IDLE_3 = 3'b101, IDLE_4 = 3'b110;  

  task read_data (input integer addr, input [1:0] core);

    @(posedge clk_cpu) 
    begin
      wait(state==IDLE && psel_rx==0 && psel_tx==0 && penable == 'b0 && reset_csr == 'b0);
      
      if (core == RX_CORE_0)
        begin
          psel_rx[0] <= 1'b1;
          paddr      <= {22'h0,addr[9:0]};
        end
      else if (core == RX_CORE_1)
        begin
          psel_rx[1] <= 1'b1;
          paddr      <= {22'h0,addr[9:0]};
        end 
      else
        begin
          psel_tx <= 1'b1;
          paddr   <= {22'h0,addr[9:0]};
        end
      pwrite <= 1'b0;

    end
  endtask

  task write_data (input integer addr,integer data, input [1:0]  core);

    @(posedge clk_cpu) 
    begin
      wait(state==IDLE && psel_rx==0 && psel_tx==0 && penable == 'b0 && reset_csr == 'b0);
     
      if (core == RX_CORE_0)
        begin
          psel_rx[0] <= 1'b1;
          paddr      <= {22'h0,addr[9:0]};
        end 
      else if (core == RX_CORE_1)
        begin
          psel_rx[1] <= 1'b1;
          paddr      <= {22'h0,addr[9:0]};
        end 
      else
        begin
          psel_tx <= 1'b1;
          paddr   <= {22'h0,addr[9:0]};
        end 
       
      pwdata <= data;
      pwrite <= 1'b1;
    end
  endtask

  always @(posedge clk_cpu or posedge reset_csr) 
  begin
  if (reset_csr == 'b1)
    begin
      state   <=IDLE;
      paddr   <= 32'h0;
      psel_rx <= 'h0;
      psel_tx <= 'b0;
      penable <= 'b0;
      pwdata  <= 'b0;
      pwrite  <= 'b0;
    end
    else
    begin
      state <= next_state;
    end
  end
    
  always @(clk_cpu)     
    case (state)
      IDLE:
      begin
        if (psel_rx != 0 || psel_tx == 1'b1)
          next_state <= SETUP;
      end
      
      SETUP:
      begin
          penable    <= 1'b1;      
          next_state <= ACCESS;
      end
      
      ACCESS:
      begin
        if (pready_rx == 0 && pready_tx == 'b0)
          next_state <= ACCESS;
        else
        begin
          next_state <= IDLE;
          psel_rx    <= 'h0;
          psel_tx    <= 1'b0;
          penable    <= 1'b0;
        end
      end

      default: 
        next_state <= IDLE;
    endcase
  
`endif 
   
   //////////////////////////////////////////////////////////////////////////////////////////////
`ifdef I2C_IF
parameter IDLE = 3'b001, READ_RX = 3'b010, READ_TX = 3'b011, WRITE_RX = 3'b100, WRITE_TX = 3'b101, WAIT = 3'b110; 
   
task read_data (input integer addr, bit core);
    @(posedge clk_cpu) 
   begin
     wait(state==IDLE && rf_ren_tx =='b1 && rf_wen_tx == 'b1 && rf_ren_rx =='b1 && rf_wen_rx == 'b1);
     if (core == TX_CORE) begin
       rf_addr_tx <= {JESD_CSR_SELECT_MASK_TX,addr[9:0]};
       rf_ren_tx  <= 1'b0;
     end else begin
       rf_addr_rx <= {JESD_CSR_SELECT_MASK_RX,addr[9:0]};
       rf_ren_rx  <= 1'b0;
     end

  end
endtask

task write_data (input integer addr, integer data, bit core);
  @(posedge clk_cpu)//&& state== IDLE)
  begin 
    wait(state==IDLE && rf_ren_rx =='b1 && rf_wen_rx == 'b1 && rf_ren_tx =='b1 && rf_wen_tx == 'b1);

    if (core == TX_CORE) begin
      rf_addr_tx <= {2'b00, JESD_CSR_SELECT_MASK_TX,addr[9:2]};
      rf_wen_tx  <= 1'b0;
      rf_wdata_tx <= data;//32'h0040;//data;
    end else begin
      rf_addr_rx <= {2'b00, JESD_CSR_SELECT_MASK_RX,addr[9:2]};
      rf_wen_rx  <= 1'b0;
      rf_wdata_rx <= data;//32'h0040;//data;
    end
 end
    
endtask


always @(posedge clk_cpu or posedge reset_csr) 
begin
  if (reset_csr == 'b1)
  begin
    state <=IDLE;
    rf_addr_tx <= 8'h0;
    rf_addr_rx <= 8'h0;
    rf_ren_rx <= 'b1;
    rf_ren_tx <= 'b1;
    rf_wen_rx <= 'b1;
    rf_wen_tx <= 'b1;
    rf_wdata_tx <= 32'b0;
    rf_wdata_rx <= 32'b0;
  end
  else 
    case (state)
      IDLE:
      begin
      if (rf_ren_rx == 'b0)
        state <= READ_RX;
      else if (rf_wen_rx == 'b0)
          state <= WRITE_RX;
      else if (rf_ren_tx == 'b0)
          state <= READ_TX;
      else if (rf_wen_tx == 'b0)
          state <= WRITE_TX;
      else
          state <= IDLE;
      end
    
      WRITE_RX:
      begin
      //    next_state <= WAIT;
        state <= WAIT;
        rf_wen_rx <= 'b1;
      end

      READ_RX:
      begin
      //    next_state <= WAIT;
        state <= WAIT;
        rf_ren_rx <= 'b1;
      end
      
      READ_TX:
      begin
      //    next_state <= WAIT;
        state <= WAIT;
        rf_ren_tx <= 'b1;
      end
      
      WRITE_TX:
      begin
      //    next_state <= WAIT;
        state <= WAIT;
        rf_wen_tx <= 'b1;
      end
      
    
      
      WAIT:
      begin
        state <= IDLE;
      end
        
      default: 
      state <= IDLE;
    endcase   
end
   
`endif

   
`ifdef AVALON_BUS
parameter IDLE = 3'b001, READ_RX = 3'b010, READ_TX = 3'b011, WRITE_RX = 3'b100, WRITE_TX = 3'b101, WAIT = 3'b110; 
   
   
   // reg [31:0]       address;
   // reg                write;
   // reg                read;
   // wire              waitrequest;
   // wire [31:0]     readdata;
   // reg [31:0]     writedata;  
   
task read_data (input integer addr, bit core);
    @(posedge clk_cpu) 
   begin
     wait(state==IDLE && read_tx =='b0 && write_tx == 'b0 && read_rx =='b0 && write_rx == 'b0);
	  if (core == TX_CORE)
       address <= {JESD_CSR_SELECT_MASK_TX,addr[9:0]};
      else
       address <= {JESD_CSR_SELECT_MASK_RX,addr[9:0]};
    if (core == TX_CORE)
       read_tx <= 'b1;
    else
       read_rx <= 'b1;

  end
endtask

task write_data (input integer addr, integer data, bit core);
  @(posedge clk_cpu)//&& state== IDLE)
  begin 
    wait(state==IDLE && read_rx =='b0 && write_rx == 'b0 && read_tx =='b0 && write_tx == 'b0);

    begin
	  if (core == TX_CORE)
       address <= {JESD_CSR_SELECT_MASK_TX,addr[9:0]};
      else
       address <= {JESD_CSR_SELECT_MASK_RX,addr[9:0]};
      
      writedata <= data;//32'h0040;//data;
      if (core == TX_CORE)
         write_tx <= 'b1;
       else
         write_rx <= 'b1;
    end
 end

    
endtask


always @(posedge clk_cpu or posedge reset_csr) 
begin
  if (reset_csr == 'b1)
    begin
    state <=IDLE;
    address <= 32'h0;
    read_rx <= 'b0;
    read_tx <= 'b0;
    write_rx <= 'b0;
    write_tx <= 'b0;
    writedata <= 32'b0;
  end
  else
    begin
      state <= next_state;
      
  end
end
  
always @(clk_cpu)     
  case (state)
    IDLE:
    begin
    if (read_rx == 'b1)
      next_state <= READ_RX;
    else if (write_rx == 'b1)
        next_state <= WRITE_RX;
    else if (read_tx == 'b1)
        next_state <= READ_TX;
    else if (write_tx == 'b1)
        next_state <= WRITE_TX;
    else
        next_state <= IDLE;
    end

    WRITE_RX:
    begin
      if (waitrequest_rx == 'b1)
      begin
        data_ack <= readdata_tx;
        next_state <= WAIT;
        write_rx <= 'b0;

      end
        
      else
        next_state <= WRITE_RX;
    end
	
    READ_RX:
    begin
      if (waitrequest_rx == 'b1)
      begin        
        data_ack <= readdata_rx;
        next_state <= WAIT;
        read_rx <= 'b0;
      end
        
      else
        next_state <= READ_RX;
    end
    
    READ_TX:
    begin
     
      if (waitrequest_tx == 'b0)
      begin
        next_state <= WAIT;
        read_tx <= 'b0;
   //     data<=slave_read_data;
      end
        
      else
        next_state <= READ_TX;
    end
    
    WRITE_TX:
    begin
      if (waitrequest_tx == 'b0)
      begin
        next_state <= WAIT;
        write_tx <= 'b0;
      end
        
      else
        next_state <= WRITE_TX;
    end


    WAIT:
    begin
      if (waitrequest_rx =='b0 || waitrequest_tx == 'b1)
        begin
          next_state <= IDLE;
        end
      else
        next_state <= WAIT;
    end
      
    default: 
    state <= IDLE;
  endcase   
   
`endif
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////AXI BUS////////////////////////////////////////////////////////////
`ifdef AXI_BUS
parameter IDLE = 3'b001, READ_RX = 3'b010, READ_TX = 3'b011, WRITE_RX = 3'b100, WRITE_TX = 3'b101, WAIT = 3'b110; 
   
task read_data (input integer addr, bit core);
    @(posedge clk_cpu) 
   begin
     wait(state==IDLE && slave_read_tx =='b0 && slave_write_tx == 'b0 && slave_read_rx =='b0 && slave_write_rx == 'b0);
     if (core == TX_CORE)
       slave_addr <= {JESD_CSR_SELECT_MASK_TX,addr[9:0]};
     else
       slave_addr <= {JESD_CSR_SELECT_MASK_RX,addr[9:0]};
      


    if (core == TX_CORE)


       slave_read_tx <= 'b1;

    else


       slave_read_rx <= 'b1;


  end
endtask

task write_data (input integer addr, integer data, bit core);
  @(posedge clk_cpu)//&& state== IDLE)
  begin 
    wait(state==IDLE && slave_read_rx =='b0 && slave_write_rx == 'b0 && slave_read_tx =='b0 && slave_write_tx == 'b0);

    begin
      if (core == TX_CORE)
       slave_addr <= {JESD_CSR_SELECT_MASK_TX,addr[9:0]};
      else
       slave_addr <= {JESD_CSR_SELECT_MASK_RX,addr[9:0]};
      slave_write_data <= data;//32'h0040;//data;
      if (core == TX_CORE)
         slave_write_tx <= 'b1;
       else
         slave_write_rx <= 'b1;

    end
 end
endtask

always @(posedge clk_cpu or posedge reset_csr) 
begin
  if (reset_csr == 'b1)
    begin
    state <=IDLE;
    slave_addr <= 32'h0;
    slave_read_rx <= 'b0;
    slave_read_tx <= 'b0;
    slave_write_rx <= 'b0;
    slave_write_tx <= 'b0;
    slave_write_data <= 32'b0;
  end
  else
    begin
      state <= next_state;      
  end
end
  
always @(clk_cpu)     
  case (state)
    IDLE:
    begin
    if (slave_read_rx == 'b1)
      next_state <= READ_RX;
    else if (slave_write_rx == 'b1)
        next_state <= WRITE_RX;
    else if (slave_read_tx == 'b1)
        next_state <= READ_TX;
    else if (slave_write_tx == 'b1)
        next_state <= WRITE_TX;
    else
        next_state <= IDLE;
    end


    READ_RX:
    begin
      if (slave_ack_rx == 'b1)
      begin
        data_ack <= slave_read_data_rx;
        next_state <= WAIT;
        slave_read_rx <= 'b0;
      end
        
      else
        next_state <= READ_RX;
    end
    
    READ_TX:
    begin
     
      if (slave_ack_tx == 'b1)
      begin
        data_ack <= slave_read_data_tx;
        next_state <= WAIT;
        slave_read_tx <= 'b0;
   //     data<=slave_read_data;
      end
        
      else
        next_state <= READ_TX;
    end
    
    WRITE_TX:
    begin
      if (slave_ack_tx == 'b1)
      begin
        next_state <= WAIT;
        slave_write_tx <= 'b0;
      end
        
      else
        next_state <= WRITE_TX;
    end
    
    WRITE_RX:
    begin
      if (slave_ack_rx == 'b1)
      begin
        next_state <= WAIT;
        slave_write_rx <= 'b0;

      end
        
      else
        next_state <= WRITE_RX;
    end
    
    WAIT:
    begin
      if (slave_ack_rx =='b0 || slave_ack_tx == 'b0)
        begin
          next_state <= IDLE;
        end
      else
        next_state <= WAIT;
    end
      
    default: 
    state <= IDLE;
  endcase
`endif

 initial begin
    clk_frame ='h1;
    clk_cpu='h1;
    clk_character='h1;
    clk_serdes=8'b11111111;
    

    #1 reset_core = 'b1;
    #128 reset_core ='b0;
    #1 reset_csr = 'b1;
    #128 reset_csr ='b0;
 	  //#15000 reset_csr<='h1;
      //#15000 reset_core<='h1;
      //#100 reset_csr<='h0;
      //#15000 reset_core<='h0;
    lmfc_div2_i=0;
end

      /*
      R = 001111 0100    110000 1011
      A = 001111 0011    110000 1100
      Q = 001111 0010    110000 1101
      K = 001111 1010    110000 0101
      F = 001111 1000    110000 0111
      */ 
reg [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i_delayed='h0;
reg [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i_delayed_2='h0;
reg [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i_delayed_3='h0;
reg [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i_delayed_4='h0;
reg [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i_delayed_5='h0;
reg [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i_delayed_6='h0;
reg [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i_delayed_7='h0;
reg [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i_delayed_8='h0;
reg [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i_delayed_9='h0;
reg [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i_delayed_10='h0;
reg [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i_delayed_11='h0;
reg [10*JESD_NO_SERDES_WORDS*JESD_NO_LANES-1:0] serdes_data_i_delayed_12='h0;

`ifdef SLAVE_INTERRUPT_TEST
  reg [12:0] error_insertion_counter='h0;
`endif

//Test of the comma aligner function
generate for (ln_cnt = 0; ln_cnt < JESD_NO_LANES; ln_cnt = ln_cnt + 1) begin : loop_serdes_data
  always @(posedge clk_serdes[ln_cnt])
  begin
`ifdef SLAVE_INTERRUPT_TEST
    if (tframe_data_rdy)
      error_insertion_counter <= error_insertion_counter +1;
    if (error_insertion_counter == 1<<10)
    begin
      serdes_data_i <= serdes_data_o;
      error_insertion_counter <= 'h0;
    end
`endif  

    serdes_data_i_delayed <=serdes_data_o;
`ifndef BIT_DELAY
      serdes_data_i_delayed_2<=serdes_data_i_delayed;
`endif      
`ifdef BIT_DELAY
      serdes_data_i_delayed_2 [(WORD_SIZE*JESD_NO_SERDES_WORDS*(ln_cnt+1))-1:(WORD_SIZE*JESD_NO_SERDES_WORDS*ln_cnt)]<={serdes_data_o [(WORD_SIZE*JESD_NO_SERDES_WORDS*(ln_cnt))+`BIT_DELAY-1:(WORD_SIZE*JESD_NO_SERDES_WORDS*ln_cnt)],serdes_data_i_delayed[(WORD_SIZE*JESD_NO_SERDES_WORDS*(ln_cnt+1))-1:`BIT_DELAY+(WORD_SIZE*JESD_NO_SERDES_WORDS*ln_cnt)]};
`endif      
//serdes_data_i_delayed_2 <={serdes_data_o [`BIT_DELAY-1:0],serdes_data_i_delayed[(WORD_SIZE*JESD_NO_SERDES_WORDS*JESD_NO_LANES)-1:`BIT_DELAY]};    1lane
    serdes_data_i_delayed_3 <=serdes_data_i_delayed_2;	
    serdes_data_i_delayed_4 <=serdes_data_i_delayed_3;
    serdes_data_i_delayed_5 <={serdes_data_o[39:10],serdes_data_i_delayed[10-1:0]};//[JESD_NO_LANES*JESD_NO_SERDES_WORDS*10-1:JESD_NO_SERDES_WORDS*10]//[39:10] //serdes_data_o[JESD_NO_LANES*JESD_NO_SERDES_WORDS*10-1:JESD_NO_SERDES_WORDS*10],serdes_data_i_delayed_4[JESD_NO_SERDES_WORDS*10-1:0]
    //serdes_data_i[(WORD_SIZE*JESD_NO_SERDES_WORDS*(ln_cnt+1))-1:(WORD_SIZE*JESD_NO_SERDES_WORDS*ln_cnt)] <= serdes_data_i_delayed_2[(WORD_SIZE*JESD_NO_SERDES_WORDS*(ln_cnt+1))-1:(WORD_SIZE*JESD_NO_SERDES_WORDS*ln_cnt)];

`ifdef SLAVE_INTERRUPT_TEST //create an error in the incoming data
    if (tframe_data_rdy)
      error_insertion_counter <= error_insertion_counter +1;
    if (error_insertion_counter == 1<<10)
    begin
      serdes_data_i <=serdes_data_i_delayed;
      error_insertion_counter <= 'h0;
    end
    else 
        serdes_data_i <=serdes_data_i_delayed_2;

`endif 
`ifndef SLAVE_INTERRUPT_TEST  
    serdes_data_i <=serdes_data_i_delayed_2;
`endif  
  end 
end endgenerate
reg sysref_clk_frame;
reg [7:0] multiframe_counter;
reg [1:0] mf_cnt;

always @(posedge clk_frame or posedge reset_csr)
begin
  if(reset_csr)
  begin
    multiframe_counter <='h0;
    sysref_clk_frame   <='h0;
    mf_cnt             <= 2'b00;
  end
  else begin

    if (multiframe_counter == JESD_K_REG-1)
    begin
      multiframe_counter <='h0;
      if (!mf_cnt)
        sysref_clk_frame <= 1'h1;// ~sysref;
      mf_cnt <= mf_cnt + 2'b01;
    end 
    else
      multiframe_counter <=multiframe_counter+1;
  end
end

initial
begin
  sysref <='h0;
  #1000 sysref <='h1; 
end 

always @(posedge clk_character)
begin
  if (sysref_clk_frame)
  begin
    sysref<=1;
  end
  else 
    sysref<=0;
  if(sysref=='h1)
  begin
    sysref_clk_frame<='h0;
    sysref <='h0; 
  end
end


reg[11:0] sysref_counter = 'h0;
reg k28_5_started=1'h0;
always @(posedge clk_character)
begin
  if (sysref)
    sysref_counter <=1'h0;
  else 
    sysref_counter <= sysref_counter + 1;
    
  if (serdes_data_o [39:0] == 'h5f2835f283 || serdes_data_o [39:0] == 'ha0d7ca0d7c)
    k28_5_started <=1'h1;
  if (serdes_data_o [39:0] != 'h5f2835f283 && k28_5_started == 1'h1 && serdes_data_o [39:0] != 'ha0d7ca0d7c)
  begin
    $display("delay value from sysref to non k28_5 in serdes_data_o : %d", sysref_counter);
    k28_5_started <='h0;
    
  end
end
`ifndef TESTCASE
integer data_inc_1='h0,data_inc_2='h0,data_inc_3='h0,data_inc_4='h0;
always @(posedge clk_character)
begin
	if (tframe_data_rdy)
	begin
//      data1 <= {{10{data[9]}}, data};
//     tframe_data={JESD_NO_LANES{32'h11bb2200}};    
     //,32'h11bb2000+data_inc_1,32'h11bb2000+data_inc_1,32'h11bb2000+data_inc_1,32'h11bb2000+data_inc_1,32'h11bb2000+data_inc_1,32'h11bb2000+data_inc_1,32'h11bb2000+data_inc_1};
		tframe_data={32'h11bb21fc+data_inc_4,32'h11bb21fd+data_inc_3,32'h11bb21fe+data_inc_2,32'h11bb21ff+data_inc_1,32'h11bb2200*data_inc_4,32'h11bb2201*data_inc_3,32'h11bb2202*data_inc_2,32'h11bb2203*data_inc_1,32'h11bb2204*2*data_inc_4,32'h11bb2205*data_inc_1,32'h11bb2206*data_inc_2,32'h11bb2207*data_inc_3,32'h11bb2208*data_inc_1,32'h11bb2209*data_inc_2,32'h11bb220a*data_inc_4*4,32'h11bb220b*data_inc_4*6,32'h11bb220c*data_inc_4*2,32'h11bb220d*data_inc_1*2,32'h11bb220e*data_inc_4*8,32'h11bb220f*data_inc_4*7};        
		data_inc_1= data_inc_1 + 'hF00001;
		data_inc_2= data_inc_2 + 'hF10F;
		data_inc_3= data_inc_3 + 'h1cda;
		data_inc_4= data_inc_4 + 'hff00000;
		tframe_data_vld = 1'b1;
	end
	else begin
		tframe_data = 32'h00000000;
		tframe_data_vld = 1'b0;
    end
end
`endif

function integer sample_calculate ;
  input integer sample;
  input integer character_period;
  begin
    if (CLK_RATIO==3)
      sample_calculate = character_period/8;
    else if (CLK_RATIO==2)

      sample_calculate = character_period/4;
    else if (CLK_RATIO==1)

      sample_calculate = character_period/2;
    else
      sample_calculate = character_period;
  end
endfunction

function integer clk_character_calculate ;
  input integer NO_FRAMES;
  input integer NO_SAMPLES;
  integer sample_multiplier;
  begin
    if (NO_SAMPLES>=16)
    begin
      sample_multiplier =2;
    end
    else
      sample_multiplier = 1;
   
    clk_character_calculate =JESD_NO_FRAMES*4*sample_multiplier*4;
  end
endfunction

localparam CLK_CHARACTER_PERIOD = clk_character_calculate (JESD_NO_FRAMES, JESD_NTOTAL); 

localparam CLK_SAMPLE_PERIOD = sample_calculate (JESD_NTOTAL, CLK_CHARACTER_PERIOD);

//localparam CLK_SAMPLE_RX_PERIOD = sample_rx_calculate (CLK_CHARACTER_PERIOD, JESD_NO_FRAMES,JESD_NO_SAMPLES);//CLK_CHARACTER_PERIOD*(JESD_NO_FRAMES/4)/JESD_NO_SAMPLES;

localparam CLK_FRAME_PERIOD = CLK_CHARACTER_PERIOD * JESD_NO_FRAMES / 4;

localparam CLK_SERDES_PERIOD = (CLK_CHARACTER_PERIOD *JESD_NO_SERDES_WORDS / 4);
  
always
  begin
    forever #CLK_SAMPLE_PERIOD clk_sample = ~clk_sample;   //! Clock  for sample interface signals. Maybe 1xclk_character or 2xclk_character
  end
always 
  begin
    forever #CLK_FRAME_PERIOD clk_frame = ~clk_frame; //48 MHz  //! Clock for aligning samples to frame timing and sync_n processing 
 end
always
  begin
    forever #CLK_CHARACTER_PERIOD clk_character = ~clk_character; //60 MHz  //! clock used for data path and control logic 
 end
 always
  begin 
    forever #CLK_CHARACTER_PERIOD clk_cpu = ~clk_cpu;   //!Clock used by the CPU interface to access Control and Status Registers (CSR) 
 end
always
  begin
    forever #CLK_SERDES_PERIOD clk_serdes = ~clk_serdes; //! Clock used for serdes interface. Maybe 1xclk_character or 2xclk_character or 4xclk_character  
 end
 
reg [11:0] ilas_buffer;
reg [7:0] multiframes_in_ilas;


integer i;
task register_testing;
begin

  wait (reset_csr== 'b0);
  for (i=0; i<'h3FF ; i=i+1)
  begin:write_loop_rx
   #40 write_data (i,32'h0, RX_CORE_0);
  end
  for (i=0; i<'h3FF ; i=i+1)
  begin:read_loop_rx
  #40 read_data (i, RX_CORE_0);
  end
  for (i=0; i<'h3FF ; i=i+1)
  begin:write_loop_tx
   #40 write_data (i,32'h0, TX_CORE);
  end
  for (i=0; i<'h3FF ; i=i+1)
  begin:read_loop_tx
  #40 read_data (i, TX_CORE);
  end  
  for (i=0; i<'h3FF ; i=i+1)
  begin:write_loop_rx_2
   #40 write_data (i,i, RX_CORE_0);
    #40 read_data (i, RX_CORE_0);
  end
  for (i=0; i<'h3FF ; i=i+1)
  begin:read_loop_rx_2
  #40 read_data (i, RX_CORE_0);
  end
  for (i=0; i<'h3FF ; i=i+1)
  begin:write_loop_tx_2
   #40 write_data (i,32'h0, TX_CORE);
   #40 read_data (i, TX_CORE);
  end
  for (i=0; i<'h3FF ; i=i+1)
  begin:read_loop_tx_2
  #40 read_data (i, TX_CORE);
  end  
//  initial_test = 'h1;
end
endtask


initial  
 begin
   integer multiframe;
`ifdef BYPASS_8B10B
   #4 rxdata_k = 32'hFFFFFFFFFF;
   #4 rxdisparity_err = 32'h0;
   #4 rxnot_in_table_err =  32'h0;
`endif
   #4 LID = {5'h5,5'h4,5'h3,5'h2,5'h1,5'h0};
   LID2 = {5'hb,5'ha,5'h9,5'h8,5'h7,5'h6};
   LID3 = {5'h11,5'h10,5'hf,5'he,5'hd,5'hc};
   LID3 = {5'h17,5'h16,5'h15,5'h14,5'h13,5'h12};
   subclass=32'h001;
   CF=JESD_CF_REG;
   CS=JESD_CS_REG;
   F=JESD_NO_FRAMES;//32'h4;             // octets per frame (F) register value +1
   K=JESD_K_REG;             //Frames per multiframe (K)
   L=JESD_NO_LANES;             //Number of lanes per converter register value +1 (L)
   M=JESD_NO_CONVERTERS;//32'h2;             // converters per device (M)
   N=JESD_N_REG;             //converter resolution (N)JESD_NTOTAL-2;//
   NTOTAL=JESD_NTOTAL;//32'd16;       //Number of bits per sample (NTOTAL)
   S=JESD_NO_SAMPLES;             // Number of samples per converter (S)
   HD=32'h1;            // HD
   multiframe = (F*K);
   multiframes_in_ilas=8'hf-1'h1;
   
   if (subclass == 2)
    ilas_buffer = 12'h1a0;
   else if (subclass ==1)
    ilas_buffer = 12'h00;
   else //if (subclass != 2)
    ilas_buffer = 12'h80;


   
   nibble_l0_lower={8'd0,8'd0,8'd0,8'd8};//nibble_map_l0_lower {8bits, received nibbles per frame that need to be routed to converter 3, 8 bits to conv 2, 8 bits to conv 1, 8 bits to conv 0}
   nibble_l1_lower={8'd0,8'd0,8'd0,8'd0};
   nibble_l2_lower={8'd0,8'd0,8'd0,8'd0};
   nibble_l3_lower={8'd0,8'd0,8'd0,8'd0};
   nibble_l4_lower={8'd0,8'd0,8'd0,8'd0};
   nibble_l5_lower={8'd0,8'd0,8'd0,8'd0};
   nibble_l6_lower={8'd0,8'd0,8'd0,8'd0};
   nibble_l7_lower={8'd0,8'd0,8'd0,8'd0};         

   nibble_l0_upper={16'd0,8'h1,8'd0};//nibble map_l0_upper {16 bits reserved RO, 8 bits number of tail bits per frame that need to be mapped on to lane , 8 bits number of control data nibbles per frame to be skipped on lane 0 to align the start of the next frame, 8 bits }
   nibble_l1_upper={16'd0,8'h0,8'd0};
   nibble_l2_upper={16'd0,8'h0,8'd0};
   nibble_l3_upper={16'd0,8'h0,8'd0};
   nibble_l4_upper={16'd0,8'd0,8'd0};
   nibble_l5_upper={16'd0,8'd0,8'd0};
   nibble_l6_upper={16'd0,8'd0,8'd0};
   nibble_l7_upper={16'd0,8'd0,8'd0};         
   wait (reset_csr== 'b0);

`ifdef BYPASS_8B10B
  if (F <= 2) begin
    force lane_generate[0].jesd_jesd204b_rx_link.jesd_sync_gen.comb_cgs_sync_req = 1'b0;
    force lane_generate[1].jesd_jesd204b_rx_link.jesd_sync_gen.comb_cgs_sync_req = 1'b0;
  end
`endif

//   register_testing();
   

  #40 write_data (`PARAM_TXRX_LID, LID, RX_CORE_0);//Lane ID
  #40 write_data (`PARAM_TXRX_SUBCLASS, subclass, RX_CORE_0);//subclass 0
  #40 write_data (`PARAM_TXRX_CF, CF, RX_CORE_0); //control words per device (CF)
  #40 write_data (`PARAM_TXRX_CS, CS, RX_CORE_0); //control bits per sample (CS)
  #40 write_data (`PARAM_TXRX_F, F-1, RX_CORE_0); // octets per frame (F) register value +1= 3+1 =4
  #40 write_data (`PARAM_TXRX_K, K-1, RX_CORE_0); //Frames per multiframe (K)
  #40 write_data (`PARAM_TXRX_L, L-1, RX_CORE_0); //Number of lanes per converter register value +1 (L)
  #40 write_data (`PARAM_TXRX_N, N-1, RX_CORE_0); //converter resolution (N)
  #40 write_data (`PARAM_TXRX_M, M-1, RX_CORE_0); // converters per device (M)
  #40 write_data (`PARAM_TXRX_NTOTAL, NTOTAL-1, RX_CORE_0); //Number of bits per sample (NTOTAL)
  #40 write_data (`PARAM_TXRX_S, S-1, RX_CORE_0); // Number of samples per converter (S)
  #40 write_data (`PARAM_RX_ILAS_DETAILS, {multiframes_in_ilas,ilas_buffer,multiframe[11:0]}, RX_CORE_0); //Ilas register, 8 bits number of multiframes in ILAS, 12bits Read buffer frame length in octets, 12bits length of multiframe in octets.
  #40 write_data (`PARAM_TXRX_HD, HD, RX_CORE_0); // High density format (HD)

  #40 write_data (`PARAM_TXRX_LID, LID, RX_CORE_1);//Lane ID
  #40 write_data (`PARAM_TXRX_SUBCLASS, subclass, RX_CORE_1);//subclass 0
  #40 write_data (`PARAM_TXRX_CF, CF, RX_CORE_1); //control words per device (CF)
  #40 write_data (`PARAM_TXRX_CS, CS, RX_CORE_1); //control bits per sample (CS)
  #40 write_data (`PARAM_TXRX_F, F-1, RX_CORE_1); // octets per frame (F) register value +1= 3+1 =4
  #40 write_data (`PARAM_TXRX_K, K-1, RX_CORE_1); //Frames per multiframe (K)
  #40 write_data (`PARAM_TXRX_L, L-1, RX_CORE_1); //Number of lanes per converter register value +1 (L)
  #40 write_data (`PARAM_TXRX_N, N-1, RX_CORE_1); //converter resolution (N)
  #40 write_data (`PARAM_TXRX_M, M-1, RX_CORE_1); // converters per device (M)
  #40 write_data (`PARAM_TXRX_NTOTAL, NTOTAL-1, RX_CORE_1); //Number of bits per sample (NTOTAL)
  #40 write_data (`PARAM_TXRX_S, S-1, RX_CORE_1); // Number of samples per converter (S)
  #40 write_data (`PARAM_RX_ILAS_DETAILS, {multiframes_in_ilas,ilas_buffer,multiframe[11:0]}, RX_CORE_1); //Ilas register, 8 bits number of multiframes in ILAS, 12bits Read buffer frame length in octets, 12bits length of multiframe in octets.
  #40 write_data (`PARAM_TXRX_HD, HD, RX_CORE_1); // High density format (HD)

  #420 write_data (`PARAM_TXRX_LID, LID, TX_CORE);//Lane ID
  #40 write_data (`PARAM_TXRX_SUBCLASS,subclass, TX_CORE); //subclass 0
  #40 write_data (`PARAM_TXRX_CF,CF, TX_CORE); //control words per device (CF)
  #40 write_data (`PARAM_TXRX_CS,CS, TX_CORE); // control bits per sample  (CS)
  #40 write_data (`PARAM_TXRX_F,F-1, TX_CORE); // octets per frame minus 1 (F)
  #40 write_data (`PARAM_TXRX_K,K-1, TX_CORE);// Frames per multiframe (k)
  #40 write_data (`PARAM_TXRX_L,L-1, TX_CORE); // Number of lanes per converter (1 per converter minus 1)
  #40 write_data (`PARAM_TXRX_N,N-1, TX_CORE); // Converter resolution (N)
  #40 write_data (`PARAM_TXRX_M,M-1, TX_CORE);// converters per device (M) minus 1
  #40 write_data (`PARAM_TXRX_NTOTAL,NTOTAL-1, TX_CORE); // total number of bits per sample NTOTAL
  #40 write_data (`PARAM_TXRX_S,S-1, TX_CORE); // Number of samples per converter (S)
  #40 write_data (`PARAM_TXRX_HD, HD, TX_CORE); // High density format (HD)



  #40 write_data (`PARAM_TX_ILAS_DETAILS,{multiframes_in_ilas,6'h4,6'h0,multiframe[11:0]}, TX_CORE); // ilas 8 bits number of multiframes in ILAS, 6 bits number of frame clocks from sync_b rising edge to next LMFC boundary while CGS state machine
  //transitions out of CGS_INIT state is read only, 6 bits: PHADJ(1bit), ADJDIR (1bit), ADJCNT (4bits), 12 bits Multiframe length in octets


  #40 write_data (`PARAM_TXRX_SCR, 32'h0, TX_CORE); //scrambler
  #40 write_data (`PARAM_TXRX_SCR, 32'h0, RX_CORE_0); //descrambler
  #40 write_data (`PARAM_TXRX_SCR, 32'h0, RX_CORE_1); //descrambler
  #40 write_data (`PARAM_TX_TAILBITS, 32'h0, TX_CORE); //tailbits to 0
  #40 write_data (`PARAM_TXRX_ENABLELINKTEST,32'h00, TX_CORE); // disable linktest
  #40 write_data (`PARAM_TXRX_ENABLEMODULE, 32'h0001, TX_CORE); // enable module
  #40 write_data (`PARAM_TXRX_ENABLEMODULE, 32'h0001, RX_CORE_0); // enable module
  #40 write_data (`PARAM_TXRX_ENABLEMODULE, 32'h0001, RX_CORE_1); // enable module
  
 // #4 read_data(`PARAM_TXRX_LID, TX_CORE);  
 // #4 read_data(`PARAM_TXRX_SUBCLASS, TX_CORE);
 // #4 read_data(`PARAM_TXRX_CF, TX_CORE);
 // #4 read_data(`PARAM_TXRX_CS, TX_CORE);
 // #4 read_data(`PARAM_TXRX_F, TX_CORE);
 // #4 read_data(`PARAM_TXRX_K, TX_CORE);
 // #4 read_data(`PARAM_TXRX_L, TX_CORE);
 // #4 read_data(`PARAM_TXRX_N, TX_CORE);
 // #4 read_data(`PARAM_TXRX_M, TX_CORE);
 // #4 read_data(`PARAM_TXRX_NTOTAL, TX_CORE);
 // #4 read_data(`PARAM_TXRX_S, TX_CORE);
 // #4 read_data(`PARAM_TXRX_HD, TX_CORE);
 // #4 read_data(`PARAM_TXRX_ENABLEMODULE, TX_CORE); 
 // #4 read_data(`PARAM_TXRX_SCR, TX_CORE);  //ilass
    
 // #4 read_data(`PARAM_TXRX_LID, RX_CORE_0);
 // #4 read_data(`PARAM_TXRX_SUBCLASS, RX_CORE_0);
 // #4 read_data(`PARAM_TXRX_CF, RX_CORE_0);
 // #4 read_data(`PARAM_TXRX_CS, RX_CORE_0);
 // #4 read_data(`PARAM_TXRX_F, RX_CORE_0);
 // #4 read_data(`PARAM_TXRX_K, RX_CORE_0);
 // #4 read_data(`PARAM_TXRX_L, RX_CORE_0);
 // #4 read_data(`PARAM_TXRX_N, RX_CORE_0);
 // #4 read_data(`PARAM_TXRX_M, RX_CORE_0);
 // #4 read_data(`PARAM_TXRX_NTOTAL, RX_CORE_0);
 // #4 read_data(`PARAM_TXRX_S, RX_CORE_0);
 // #4 read_data(`PARAM_TXRX_HD, RX_CORE_0); // ilas
 // #4 read_data(`PARAM_TXRX_ENABLEMODULE, RX_CORE_0); // Rx feature disable
// #40 write_data (`PARAM_RX_CORE_0_INTERRUPT_MASK, {9'h1ff}, RX_CORE);
//#40 write_data (`PARAM_TX_CORE_INTERRUPT_MASK, {9'h1ff}, TX_CORE);
  
 // #4 read_data(`PARAM_TXRX_LID, RX_CORE_1);
 // #4 read_data(`PARAM_TXRX_SUBCLASS, RX_CORE_1);
 // #4 read_data(`PARAM_TXRX_CF, RX_CORE_1);
 // #4 read_data(`PARAM_TXRX_CS, RX_CORE_1);
 // #4 read_data(`PARAM_TXRX_F, RX_CORE_1);
 // #4 read_data(`PARAM_TXRX_K, RX_CORE_1);
 // #4 read_data(`PARAM_TXRX_L, RX_CORE_1);
 // #4 read_data(`PARAM_TXRX_N, RX_CORE_1);
 // #4 read_data(`PARAM_TXRX_M, RX_CORE_1);
 // #4 read_data(`PARAM_TXRX_NTOTAL, RX_CORE_1);
 // #4 read_data(`PARAM_TXRX_S, RX_CORE_1);
 // #4 read_data(`PARAM_TXRX_HD, RX_CORE_1); // ilas
 // #4 read_data(`PARAM_TXRX_ENABLEMODULE, RX_CORE_1); // Rx feature disable
// #40 write_data (`PARAM_RX_CORE_1_INTERRUPT_MASK, {9'h1ff}, RX_CORE);
//#40 write_data (`PARAM_TX_CORE_INTERRUPT_MASK, {9'h1ff}, TX_CORE);
  
  wait (rx_tvalid==all_ones[JESD_NO_LANES-1:0])
  begin
`ifdef BYPASS_8B10B
      rxdata_k = 32'h00;
`endif

`ifdef JTSPAT_TEST_ENABLE  
    #40000 write_data (`PARAM_JSPAT_TEST_ENABLE, 32'hffff, TX_CORE); // JTSPAT TEST
    #8000  write_data (`PARAM_JSPAT_TEST_ENABLE, 32'hffff, RX_CORE_0); // JTSPAT TEST
    #8000  write_data (`PARAM_JSPAT_TEST_ENABLE, 32'hffff, RX_CORE_1); // JTSPAT TEST
`endif    
`ifdef PRBS_TEST_ENABLE  
    #100000 write_data (`PARAM_PRBS_TEST_ENABLE, 32'h0001, TX_CORE); // enable module
    #40 write_data     (`PARAM_PRBS_TEST_ENABLE, 32'h0001, RX_CORE_0); // enable module
    #40 write_data     (`PARAM_PRBS_TEST_ENABLE, 32'h0001, RX_CORE_1); // enable module
`endif   
     
// Testing of error injection
//  #400000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h0,8'hf}, RX_CORE_0); // Injection of synchronization request
//  #40000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'hf,8'h0}, RX_CORE_0); // Injection of synchronization request  
//  #40000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'hf,8'h0,8'h0}, RX_CORE_0); // Injection of synchronization request
//  #40000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'hf,8'h0,8'h0,8'h0}, RX_CORE_0); // Injection of synchronization request
  end

`ifdef PRBS_TEST_ENABLE  
  #400000 read_data (`PARAM_RX_PRBS_TEST_3_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_3_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_2_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_1_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_1_ERRORCOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_2_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_0_ERRORCOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_0_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_3_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_2_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_1_RECEIVECOUNTER, RX_CORE_0 );

  #400000 read_data (`PARAM_RX_PRBS_TEST_3_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_3_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_2_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_1_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_1_ERRORCOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_2_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_0_ERRORCOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_0_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_3_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_2_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_PRBS_TEST_1_RECEIVECOUNTER, RX_CORE_1 );

`endif   
`ifdef JTSPAT_TEST_ENABLE 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_3_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_3_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_2_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_1_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_1_ERRORCOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_2_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_0_ERRORCOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_0_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_3_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_2_RECEIVECOUNTER, RX_CORE_0 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_1_RECEIVECOUNTER, RX_CORE_0 );

  #400000 read_data (`PARAM_RX_JTSPAT_TEST_3_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_3_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_2_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_1_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_1_ERRORCOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_2_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_0_ERRORCOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_0_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_3_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_2_RECEIVECOUNTER, RX_CORE_1 ); 
  #400000 read_data (`PARAM_RX_JTSPAT_TEST_1_RECEIVECOUNTER, RX_CORE_1 );

`endif   

  #40 read_data ( `PARAM_RX_CORE_INTERRUPT_STATUS, RX_CORE_0);  // reset interrupt status
  #40 read_data ( `PARAM_TX_CORE_INTERRUPT_STATUS, RX_CORE_0);  // reset interrupt status
  #40 read_data ( `PARAM_RX_CORE_INTERRUPT_STATUS, RX_CORE_1);  // reset interrupt status
  #40 read_data ( `PARAM_TX_CORE_INTERRUPT_STATUS, RX_CORE_1);  // reset interrupt status
 
  wait (rx_tvalid==all_ones[JESD_NO_LANES-1:0]);
  #40 read_data (`PARAM_RX_JTSPAT_TEST_0_RECEIVECOUNTER, RX_CORE_0 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_1_RECEIVECOUNTER, RX_CORE_0 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_2_RECEIVECOUNTER, RX_CORE_0 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_3_RECEIVECOUNTER, RX_CORE_0 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_0_ERRORCOUNTER, RX_CORE_0 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_1_ERRORCOUNTER, RX_CORE_0 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_2_ERRORCOUNTER, RX_CORE_0 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_3_ERRORCOUNTER, RX_CORE_0 ); 

  #40 read_data (`PARAM_RX_JTSPAT_TEST_0_RECEIVECOUNTER, RX_CORE_1 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_1_RECEIVECOUNTER, RX_CORE_1 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_2_RECEIVECOUNTER, RX_CORE_1 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_3_RECEIVECOUNTER, RX_CORE_1 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_0_ERRORCOUNTER, RX_CORE_1 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_1_ERRORCOUNTER, RX_CORE_1 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_2_ERRORCOUNTER, RX_CORE_1 ); 
  #40 read_data (`PARAM_RX_JTSPAT_TEST_3_ERRORCOUNTER, RX_CORE_1 ); 

`ifdef INTERRUPT_TEST_DEF
  case (test_injection)
      ('ha):  #40 write_data (`PARAM_TX_CORE_INTERRUPT_MASK, 32'b1110, TX_CORE); // PARAM_TX_CORE_INTERRUPT_MASK
      ('hb):  #40 write_data (`PARAM_TX_CORE_INTERRUPT_MASK, 32'b1101, TX_CORE); // PARAM_TX_CORE_INTERRUPT_MASK
      ('hc):  #40 write_data (`PARAM_TX_CORE_INTERRUPT_MASK, 32'b1011, TX_CORE); // PARAM_TX_CORE_INTERRUPT_MASK
      ('hd):  #40 write_data (`PARAM_TX_CORE_INTERRUPT_MASK, 32'h0111, TX_CORE); // PARAM_TX_CORE_INTERRUPT_MASK
      default: #40 write_data (`PARAM_TX_CORE_INTERRUPT_MASK, {32'hffff}, TX_CORE);
    endcase
  #40 write_data (`PARAM_TX_FEATURE_DISABLE, 32'h0, TX_CORE); //    
`endif

`ifdef INTERRUPT_TEST_DEF

   case (test_injection)// INITIAL_LANE_ALIGNMENT 0 Initial lane alignment. LANE_ALIGNMENT_MONITORING 1 Lane alignment monitoring and correction. LANE_ALIGNMENT_CHARACTER_REPLACEMENT 2 Lane alignment character replacement.LANE_ALIGNMENT_PROCESSING 3 Processing of initial lane alignment character replacement sequence.  RE_INITIALIZATION_VIA_DATA_INTERFACE  4
      (1):  #40 write_data (`PARAM_RX_FEATURE_DISABLE, 8'b00000000, RX_CORE); // PARAM_RX_FEATURE_DISABLE
      (2):  #40 write_data (`PARAM_RX_FEATURE_DISABLE, 8'b00000000, RX_CORE); // PARAM_RX_FEATURE_DISABLE
      (3):  #40 write_data (`PARAM_RX_FEATURE_DISABLE, 8'b0000000, RX_CORE); // PARAM_RX_FEATURE_DISABLE
      (4):  #40 write_data (`PARAM_RX_FEATURE_DISABLE, 8'b0000000, RX_CORE); // PARAM_RX_FEATURE_DISABLE
      (4'h0): #40 write_data (`PARAM_RX_FEATURE_DISABLE, 8'b00000000, RX_CORE);
    endcase

  case (test_injection)
    (1):  #4000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h0,8'hFF}, RX_CORE); // Write of 1 to this bit will cause 4 consecutive symbols on serdes interface to have not in table error
    (2):  #4000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h1,8'h0}, RX_CORE); //  Write of 1 to this bit will cause 1 symbol on serdes interface to have not in table error
    //(3):  #4000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h1,8'h0,8'h0}, RX_CORE); // Write of 1 to this bit will cause 2 consecutive symbol on serdes interface to be replaced with /A/
    //(4):  #4000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h1,8'h0,8'h0,8'h0}, RX_CORE); // Write of 1 to this bit will cause 2 consecutive symbol on serdes interface to be replaced with /F/
    (5):  #4000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h0,8'hFF}, RX_CORE); // Write of 1 to this bit will cause 2 consecutive symbol on serdes interface to be replaced with /F/    
    (6):  #4000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'hFF,8'h0,8'h0,8'h0}, RX_CORE); // Write of 1 to this bit will cause 2 consecutive symbol on serdes interface to be replaced with /F/    
    (7):  #4000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h0,8'hF}, RX_CORE); // Write of 1 to this bit will cause 2 consecutive symbol on serdes interface to be replaced with /F/    
    (8):  #4020 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'hFF,8'h0,8'h0}, RX_CORE); // Write of 1 to this bit will cause 2 consecutive symbol on serdes interface to be replaced with /F/    
    (9):  #4000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h0,8'hFF}, RX_CORE); // Write of 1 to this bit will cause 2 consecutive symbol on serdes interface to be replaced with /F/        
    ('ha):  #4000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h0,8'hFF}, RX_CORE); // Write of 1 to this bit will cause 4 consecutive symbols on serdes interface to have not in table error
    ('hb):  #4000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h0,8'hFF}, RX_CORE); // Write of 1 to this bit will cause 4 consecutive symbols on serdes interface to have not in table error
    
    default: #4000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h0,8'h0}, RX_CORE);    
  endcase
`endif  
`ifdef TEST_LATENCY
  #40000 reset_core <='h1;
  #1000 reset_core <='h0;
  wait (data_to_tl_vld);
  #40 read_data (`PARAM_RX_JTSPAT_TEST_3_ERRORCOUNTER, RX_CORE_1 ); 
  
  
  #100000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h0,8'hf}, RX_CORE_1); // Injection of synchronization request
  #40 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h0,8'hf}, RX_CORE_0); // Injection of synchronization request
  #100000 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h0,8'hf}, RX_CORE_1); // Injection of synchronization rquest
  #40 write_data (`PARAM_RX_ERR_INJ_REQ, {8'h0,8'h0,8'h0,8'hf}, RX_CORE_0); // Injection of synchronization request
`endif


  end



endmodule
