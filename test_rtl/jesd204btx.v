// Generated using jscript version 3.00 by stevenchung at Wed Jun 17 21:02:17 2020
// Module jesd204btx: mode flat
module jesd204btx (
	jesd204b_tx_frame_length_char,
	jesd204btx_clk,
	jesd204btx_intr,
	jesd204btx_pclk,
	jesd204btx_preset,
	jesd204btx_serdes_data_o,
	jesd204btx_serdes_data_vld,
	jesd204btx_sync_b,
	jesd204btx_sysref,
	jesd204btx_tframe_data,
	jesd204btx_tframe_data_rdy,
	jesd204btx_tframe_data_vld,
	paddr,
	penable,
	prdata,
	pready,
	psel,
	pwdata,
	pwrite,
	scan_mode,
	txdata_k
);	// jesd204btx

	output	[8:0]	jesd204b_tx_frame_length_char;
	input		jesd204btx_clk;
	output		jesd204btx_intr;
	input		jesd204btx_pclk;
	input		jesd204btx_preset;
	output	[127:0]	jesd204btx_serdes_data_o;
	output	[3:0]	jesd204btx_serdes_data_vld;
	input		jesd204btx_sync_b;
	input		jesd204btx_sysref;
	input	[127:0]	jesd204btx_tframe_data;
	output		jesd204btx_tframe_data_rdy;
	input		jesd204btx_tframe_data_vld;
	input	[31:0]	paddr;
	input		penable;
	output	[31:0]	prdata;
	output		pready;
	input		psel;
	input	[31:0]	pwdata;
	input		pwrite;
	input		scan_mode;
	output	[15:0]	txdata_k;





jesd204btx_wrapper u_jesd204btx_wrapper (
	.clk_character ( jesd204btx_clk ),
	.clk_cpu ( jesd204btx_pclk ),
	.clk_sample ( jesd204btx_clk ),
	.clk_serdes ( jesd204btx_clk ),
	.frame_length_char ( jesd204b_tx_frame_length_char ),
	.paddr ( paddr ),
	.penable ( penable ),
	.prdata ( prdata ),
	.pready ( pready ),
	.psel ( psel ),
	.pwdata ( pwdata ),
	.pwrite ( pwrite ),
	.reset_core ( jesd204btx_preset ),
	.reset_csr ( jesd204btx_preset ),
	.serdes_data_o ( jesd204btx_serdes_data_o ),
	.serdes_data_vld ( jesd204btx_serdes_data_vld ),
	.slave_interrupt ( jesd204btx_intr ),
	.sync_b ( jesd204btx_sync_b ),
	.sysref ( jesd204btx_sysref ),
	.test_mode ( scan_mode ),
	.tframe_data ( jesd204btx_tframe_data ),
	.tframe_data_rdy ( jesd204btx_tframe_data_rdy ),
	.tframe_data_vld ( jesd204btx_tframe_data_vld ),
	.txdata_k ( txdata_k )
 ); 	// u_jesd204btx_wrapper





endmodule 	// jesd204btx


