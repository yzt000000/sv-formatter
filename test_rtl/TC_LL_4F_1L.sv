
`ifndef PASS_THRESHOLD
  `define PASS_THRESHOLD 1024
`endif
`ifndef FAIL_THRESHOLD
  `define FAIL_THRESHOLD 100
`endif
`define TESTCASE
  `include "jesd_jesd204b_tx_defines.v" 
module TC_LL_4F_1L #(
    
    parameter JESD_MAST_INST=1,              //! Used in subclass2 mode to synchronize local LMFC of multiple RX instances
    parameter JESD_DESKEW_BUF_ASIZE=8,       //! Determines Depth of lane alignment buffer per lane.     
    parameter JESD_DESKEW_BUF_DSIZE=36,      //! Width of deskew buffer
    parameter JESD_CSR_SELECT_MASK=24'h000,  //! Will be used to match slave_addr[31:24]
    parameter JESD_CSR_SELECT_MASK_TX=24'h001,  //! Will be used to match slave_addr[31:24]
    parameter JESD_CSR_SELECT_MASK_RX=24'h002,  //! Will be used to match slave_addr[31:24]
    parameter JESD_NO_LANES=1,               //! User defined parameter. Legal values 1 to 8
    parameter JESD_NO_SERDES_WORDS=4,        //! User defined parameter to indicate serdes data path width in terms of 10 bit symbols . Valid values are 1,2,4
    parameter JESD_PAR_IF=1,                 //!User defined parameter to select a shared/dedicated interface between the core and application layer 
    parameter JESD_NO_FRAMES=4,
	parameter JESD_N_REG=8,
    parameter JESD_NO_SAMPLES=1,
    parameter JESD_NO_CONVERTERS=1,
    parameter BUS_EXTENSION=0,
    parameter JESD_NTOTAL=8,
	parameter JESD_CS_REG=1,
	parameter JESD_CF_REG=0,
	parameter JESD_K_REG=16
        
)
(

    );

 
localparam ADDRESS_NUM = 128;


reg [32*JESD_NO_LANES-1:0] data_input [ADDRESS_NUM-1:0];
//reg [(4*JESD_NO_LANES*6)-1:0] cntrl_input [ADDRESS_NUM-1:0];
wire clk_test;

reg [32*JESD_NO_LANES-1:0] tframe_data='h2;
reg                        tframe_data_vld='h1;
wire                       tframe_data_rdy;
wire [32*JESD_NO_LANES-1:0] data_to_tl;
wire                        data_to_tl_vld;
  
 

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
reg tframe_data_rdy_r;
always@(posedge clk_test)
begin
	tframe_data_rdy_r<=tframe_data_rdy; // 1 clock cycle of latency
	data_to_tl_vld_r <= data_to_tl_vld;
end

reg [JESD_NO_LANES-1:0]  [31:0] data_increment ={JESD_NO_LANES{32'h11110000}};

genvar i;
generate for (i=0; i <JESD_NO_LANES; i=i+1)
begin

	always @(posedge clk_test)
	begin
		
		if (tframe_data_rdy_r)
		begin
			data_input[data_inc_1] <=tframe_data;  
			data_inc_1 <= data_inc_1 + 'h1;
			tframe_data [32*(i+1):32*i] <={32'h11bb2200+data_increment[i]};  
//						tframe_data<={JESD_NO_LANES{32'h11bb2200+data_increment[i]}};  
			data_increment[0]<= data_increment[0] + 'h0001131;
			data_increment[1]<= data_increment[1] + 'hFB2221;
			data_increment[2]<= data_increment[2] + 'hF10F;
			data_increment[3]<= data_increment[3] + 'h1cda;
			data_increment[4]<= data_increment[4] + 'hff00022;
			data_increment[5]<= data_increment[5] + 'hf00100;
			data_increment[6]<= data_increment[6] + 'hff4;
			data_increment[7]<= data_increment[7] + 'hff4421;
		end
		else begin
			tframe_data = 32'h00000000;

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


wire is_cr_frame = (check_data[31:24]==8'hFC || check_data[31:24]==8'h7C);

always @(posedge clk_test)
begin
 
 if (data_to_tl_vld_r)
 begin
	data_inc_2_r <= data_inc_2_r + 'h1;
	if (check_data != 0 && ~is_cr_frame) begin
		if (~data_pass)
		begin
			error_counter ++;
		end
		else
			counter ++;
	end
	if (data_inc_2_r==ADDRESS_NUM-1)
		data_inc_2_r<='h0;
	end
	if (counter >= `PASS_THRESHOLD) begin
		$display("Test Passed: %0d passes, %0d errors", counter, error_counter);
		$finish();
	end
	else if (error_counter >= `FAIL_THRESHOLD) begin
		$display("Test failed: %0d errors, %0d passes", error_counter, counter);
		$finish();
	end
end

always @(*)
begin        
end
             
endmodule
