
`define INTERRUPT_TEST_DEF
`define TESTCASE
  `include "jesd_jesd204b_tx_defines.v" 
module TC_INT_RX_OVERRUN #(
    
    parameter JESD_MAST_INST=1,              //! Used in subclass2 mode to synchronize local LMFC of multiple RX instances
    parameter JESD_DESKEW_BUF_ASIZE=8,       //! Determines Depth of lane alignment buffer per lane.     
    parameter JESD_DESKEW_BUF_DSIZE=36,      //! Width of deskew buffer
    parameter JESD_CSR_SELECT_MASK=24'h000,  //! Will be used to match slave_addr[31:24]
    parameter JESD_CSR_SELECT_MASK_TX=24'h001,  //! Will be used to match slave_addr[31:24]
    parameter JESD_CSR_SELECT_MASK_RX=24'h002,  //! Will be used to match slave_addr[31:24]
    parameter JESD_NO_LANES=4,               //! User defined parameter. Legal values 1 to 8
    parameter JESD_NO_SERDES_WORDS=4,        //! User defined parameter to indicate serdes data path width in terms of 10 bit symbols . Valid values are 1,2,4
    parameter JESD_PAR_IF=1,                 //!User defined parameter to select a shared/dedicated interface between the core and application layer 
    parameter JESD_NO_FRAMES=4,
	  parameter JESD_N_REG=16,
    parameter JESD_NO_SAMPLES=1,
    parameter JESD_NO_CONVERTERS=2,
    parameter BUS_EXTENSION=0,
    parameter JESD_NTOTAL=16,
    parameter JESD_CS_REG=0,
    parameter JESD_CF_REG=0,
    parameter JESD_K_REG=32

//    parameter JESD_NO_TX_LANES=2,               //! User defined parameter. Legal values 1 to 8
//    parameter JESD_NO_RX_LANES=1,               //! User defined parameter. Legal values 1 to 8
)
(

    );

 
localparam ADDRESS_NUM = 128;

reg [31:0] test_injection;
reg [32*JESD_NO_LANES-1:0] data_input [ADDRESS_NUM-1:0];
//reg [(4*JESD_NO_LANES*6)-1:0] cntrl_input [ADDRESS_NUM-1:0];
wire clk_test;

reg [32*JESD_NO_LANES-1:0] tframe_data='h2;
reg                        tframe_data_vld='h0;
wire                       tframe_data_rdy;
wire [32*JESD_NO_LANES-1:0] data_to_tl;
wire                        data_to_tl_vld;

wire                                          slave_interrupt_rx;
wire                                          slave_interrupt_tx;
integer slave_interrupt_value_rx, slave_interrupt_value_tx; 

jesd_tb_link_layer

   #(
      .JESD_NO_SERDES_WORDS (JESD_NO_SERDES_WORDS),
      .JESD_DESKEW_BUF_ASIZE (JESD_DESKEW_BUF_ASIZE),
      .JESD_DESKEW_BUF_DSIZE (JESD_DESKEW_BUF_DSIZE),
      .JESD_MAST_INST (JESD_MAST_INST),

      .JESD_CSR_SELECT_MASK_RX (JESD_CSR_SELECT_MASK_RX),
      .JESD_CSR_SELECT_MASK_TX (JESD_CSR_SELECT_MASK_TX),
      .JESD_NO_LANES (JESD_NO_LANES),
      .JESD_NO_FRAMES (JESD_NO_FRAMES),
      .JESD_NO_SAMPLES(JESD_NO_SAMPLES),
      .JESD_NO_CONVERTERS(JESD_NO_CONVERTERS),
      .BUS_EXTENSION(BUS_EXTENSION),
      .JESD_N_REG(JESD_N_REG),	  
      .JESD_CS_REG(JESD_CS_REG),
      .JESD_CF_REG(JESD_CF_REG),
      .JESD_K_REG(JESD_K_REG),
      .JESD_NTOTAL(JESD_NTOTAL)	  
      )
      
jesd_tb    (
          .test_injection (test_injection),
          .slave_interrupt_rx (slave_interrupt_rx),
          .slave_interrupt_tx (slave_interrupt_tx),
          .slave_interrupt_value_rx (slave_interrupt_value_rx),
          .slave_interrupt_value_tx (slave_interrupt_value_tx),
          .clk_tester (clk_test),
          .tframe_data (tframe_data),
          .tframe_data_vld (tframe_data_vld),
          .tframe_data_rdy (tframe_data_rdy),
          .data_to_tl (data_to_tl),
          .data_to_tl_vld (data_to_tl_vld)
);
wire[31:0] data_inc_2;
reg [31:0] data_inc_1 = 'h0;

reg 						data_to_tl_vld_r;
reg 						data_to_tl_vld_r_r;
reg tframe_data_rdy_r, tframe_data_rdy_r_r;
always@(posedge clk_test)
begin
	tframe_data_rdy_r<=tframe_data_rdy; // 1 clock cycle of latency
	tframe_data_rdy_r_r<=tframe_data_rdy_r;
	data_to_tl_vld_r <= data_to_tl_vld;
	data_to_tl_vld_r_r <= data_to_tl_vld_r;
end

reg [JESD_NO_LANES-1:0]  [31:0] data_increment ={JESD_NO_LANES{32'habcdabcd}};
reg [32*JESD_NO_LANES-1:0] prbs_data;
reg [4*JESD_NO_LANES-1:0] prbs_k;
reg [JESD_NO_LANES-1:0] prbs_vld;

genvar i;
generate for (i=0; i <JESD_NO_LANES; i=i+1)
begin

      jesd_prbs15_generator generator( 
                  .rst_clk_character    (1'h0),
                  .prbs_test_enable_reg (tframe_data_rdy),
                  .clk_character        (clk_test),
 
                  .prbs_data            (prbs_data[(32*(i+1))-1:32*i]),
                  .prbs_k               (prbs_k[(4*(i+1))-1:4*i]),
                  .prbs_vld             (prbs_vld[i])
);

	always @(posedge clk_test)
	begin
		
		if (tframe_data_rdy)
		begin
      tframe_data_vld<=1'h1;
			data_input[data_inc_1] <=tframe_data;  
			data_inc_1 <= data_inc_1 + 'h1;
			tframe_data [32*(i+1):32*i] <={32'h0+data_increment[i]};  
//						tframe_data<={JESD_NO_LANES{32'h11bb2200+data_increment[i]}};  
			data_increment[0]<= prbs_data[31:0];//data_increment[0] + 'h00110012;
			data_increment[1]<= data_increment[1] + 'hFFFFFFFF;
			data_increment[2]<= data_increment[2] + 'h100;
			data_increment[3]<= data_increment[3] + 'h1000;
			data_increment[4]<= data_increment[4] + 'h10000;
			data_increment[5]<= data_increment[5] + 'h100000;
			data_increment[6]<= data_increment[6] + 'hff4;
			data_increment[7]<= data_increment[7] + 'hff4421;
		end
		else begin
			tframe_data = 32'h00000000;
      data_inc_1 <='h0;

		end
		if (data_inc_1 == ADDRESS_NUM-1)
			data_inc_1<='h0;
	end
end
endgenerate

wire data_pass;
reg [31:0] data_inc_2_r = 'h0;
reg [20:0] counter = 'h0;
reg [20:0] error_counter = 'h0;

wire [32*JESD_NO_LANES-1:0] check_data;
wire [32*JESD_NO_LANES-1:0] check_data_2;//,check_data_3,check_data_4;
assign check_data [32*JESD_NO_LANES-1:0]= data_to_tl[32*JESD_NO_LANES-1:0];
assign check_data_2 [32*JESD_NO_LANES-1:0] = data_input[data_inc_2-1] [32*JESD_NO_LANES-1:0];
assign data_inc_2 = data_to_tl_vld_r? (data_inc_2_r +1): data_inc_2_r;
assign data_pass = (check_data == check_data_2)? 1'h1:1'h0;


always @(posedge clk_test)
begin
 if (data_to_tl_vld) // 1 cycle data latency
 begin
	data_inc_2_r <= data_inc_2_r + 'h1;
 	if (~data_pass)
	begin
		error_counter ++;	
	end
	else 
		counter ++;
	if (data_inc_2_r==ADDRESS_NUM-1)
		data_inc_2_r<='h0;
	end
  if(!tframe_data_rdy)
    data_inc_2_r<='h0;
end

always @(*)
begin        
if (counter>= 1024)
  begin
   $display("Test Passed");
   $stop();
   counter<='h0;
  end
  else if (error_counter>=1)
  begin
	$display("Test failed");
	$stop();
	//break;
  end
end
`ifdef INTERRUPT_TEST_DEF
// 1st test: One not_in_table errors is injected and sync_b goes low for a short time. The interrupt is tested.
// 2nd test: Four not_in_table errors are injected and sync_b goes low. The interrupt is tested.
// 3rd test: Four not_in_table errors are injected and sync_b is deasserted. Detected under run in RX data path
// 4th test: Detected over run in RX data path
// 5th test: Disparity error
// 6th test: Unexpected k error (Not possible to inject from the core)
// 7th test: Not in table error
// 8th test: alignment error
// 9th test: Comb_cgs_request

// 10th test: TX sync_b
//11th test: TX request signal



initial
  test_injection = 'h4;

reg                                          slave_interrupt_rx_r;
reg                                          slave_interrupt_tx_r;
always @(posedge clk_test) slave_interrupt_rx_r<=slave_interrupt_rx;
always @(posedge clk_test) slave_interrupt_tx_r<=slave_interrupt_tx;  
                                               
always@(posedge clk_test)
begin
  
  if (slave_interrupt_rx && !(slave_interrupt_rx_r))
  begin
   case (test_injection)
   ('h1): $display("Slave_interrupt detected: Signaled error on sync_b");
   ('h2): $display("Signaled resynchronization request on sync_b");
   ('h3): $display("Detected under run in RX data path");
   ('h4): $display("Detected over run in RX data path");
   ('h5): $display("Detected rx_disparity_errror");
   ('h6): $display("Unexpected control character");
   ('h7): $display("Not-in-table error");
   ('h8): $display("A control character is received that is not expected at the given character position");
   ('h9): $display("Code group synchronization error");
   endcase
   
  /*  
    $display("Slave_interrupt detected: %d", slave_interrupt_value_rx);
    //test_injection <=8'hf;
    if (slave_interrupt_value_rx[0])
      $display("Signaled error on sync_b in RX");
    if (slave_interrupt_value_rx[1])
      $display  ("Signaled resynchronization request on sync_b");
    if (slave_interrupt_value_rx[2])
      $display  ("Detected under run in RX data path");
    if (slave_interrupt_value_rx[3])
    $display  ("Detected over run in RX data path");
    if (slave_interrupt_value_rx[4])
    $display  ("Detected rx_disparity_error");
    if (slave_interrupt_value_rx[5])
    $display  ("Unexpected control character");
    if (slave_interrupt_value_rx[6])
    $display  ("Not-in-table error");
    if (slave_interrupt_value_rx[7])
    $display  ("A control character is received that is not expected at the given character position");
 */
  end
  if (slave_interrupt_tx)
  begin
     case (test_injection)
   ('ha): $display("Signaled error on sync_b");
   ('hb): $display("Signaled resynchronization request on sync_b");
//   ('hc): $display("Detected under run in TX datapath");
//   ('hd): $display("Detected over run in TX data path");
   endcase
   
    //$display("slave_interrupt TX: %d", slave_interrupt_value_tx);
  end
end

`endif  
             
endmodule
