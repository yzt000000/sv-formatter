// Generated using jscript version 3.00 by stevenchung at Wed Jun 17 21:02:17 2020
// Module jesd204brx: mode flat
module jesd204brx (
	bist_cen,
	bist_mode,
	bist_oen,
	frame_length_char,
	jesd204brx_active_lane,
	jesd204brx_bist_addr,
	jesd204brx_bist_d,
	jesd204brx_bist_wen,
	jesd204brx_clk,
	jesd204brx_end_of_frame,
	jesd204brx_frame_error,
	jesd204brx_intr,
	jesd204brx_pclk,
	jesd204brx_preset,
	jesd204brx_serdes_data_i,
	jesd204brx_start_of_frame,
	jesd204brx_sync_b,
	jesd204brx_sysref,
	jesd204brx_tdata,
	jesd204brx_tvalid,
	jesd204brx_txrx_lid_reg,
	jesd_pma_rx0_clk,
	jesd_pma_rx1_clk,
	jesd_pma_rx2_clk,
	jesd_pma_rx3_clk,
	paddr,
	penable,
	prdata,
	pready,
	psel,
	pwdata,
	pwrite,
	rxdata_k,
	rxdisparity_err,
	rxnot_in_table_err,
	scan_mode
);	// jesd204brx

	input		bist_cen;
	input		bist_mode;
	input		bist_oen;
	output	[8:0]	frame_length_char;
	output	[7:0]	jesd204brx_active_lane;
	input	[7:0]	jesd204brx_bist_addr;
	input	[35:0]	jesd204brx_bist_d;
	input	[0:0]	jesd204brx_bist_wen;
	input		jesd204brx_clk;
	output	[3:0]	jesd204brx_end_of_frame;
	output	[31:0]	jesd204brx_frame_error;
	output		jesd204brx_intr;
	input		jesd204brx_pclk;
	input		jesd204brx_preset;
	input	[255:0]	jesd204brx_serdes_data_i;
	output	[3:0]	jesd204brx_start_of_frame;
	output		jesd204brx_sync_b;
	input		jesd204brx_sysref;
	output	[255:0]	jesd204brx_tdata;
	output		jesd204brx_tvalid;
	output	[39:0]	jesd204brx_txrx_lid_reg;
	input		jesd_pma_rx0_clk;
	input		jesd_pma_rx1_clk;
	input		jesd_pma_rx2_clk;
	input		jesd_pma_rx3_clk;
	input	[31:0]	paddr;
	input		penable;
	output	[31:0]	prdata;
	output		pready;
	input		psel;
	input	[31:0]	pwdata;
	input		pwrite;
	input	[31:0]	rxdata_k;
	input	[31:0]	rxdisparity_err;
	input	[31:0]	rxnot_in_table_err;
	input		scan_mode;

	wire	[63:0]	deskew_rd_addr;
	wire	[7:0]	deskew_rd_en;
	wire	[63:0]	deskew_wr_addr;
	wire	[287:0]	deskew_wr_data;
	wire	[7:0]	deskew_wr_en;
	wire	[35:0]	q0;
	wire	[35:0]	q1;
	wire	[35:0]	q2;
	wire	[35:0]	q3;




jesd204brx_wrapper u_jesd204brx_wrapper (
	.active_lane ( jesd204brx_active_lane ),
	.clk_character ( jesd204brx_clk ),
	.clk_cpu ( jesd204brx_pclk ),
	.clk_serdes ( {jesd_pma_rx3_clk, jesd_pma_rx2_clk, jesd_pma_rx1_clk, jesd_pma_rx0_clk} ),
	.deskew_rd_addr ( deskew_rd_addr ),
	.deskew_rd_data ( {q3[35:0], q2[35:0], q1[35:0], q0[35:0]} ),
	.deskew_rd_en ( deskew_rd_en ),
	.deskew_wr_addr ( deskew_wr_addr ),
	.deskew_wr_data ( deskew_wr_data ),
	.deskew_wr_en ( deskew_wr_en ),
	.frame_length_char ( frame_length_char ),
	.lmfc_div2_i ( 1'b0 ),
	.paddr ( paddr ),
	.penable ( penable ),
	.prdata ( prdata ),
	.pready ( pready ),
	.psel ( psel ),
	.pwdata ( pwdata ),
	.pwrite ( pwrite ),
	.reset_core ( jesd204brx_preset ),
	.reset_csr ( jesd204brx_preset ),
	.rx_end_of_frame ( jesd204brx_end_of_frame ),
	.rx_frame_error ( jesd204brx_frame_error ),
	.rx_start_of_frame ( jesd204brx_start_of_frame ),
	.rx_tdata ( jesd204brx_tdata ),
	.rx_tvalid ( jesd204brx_tvalid ),
	.rxdata_k ( rxdata_k ),
	.rxdisparity_err ( rxdisparity_err ),
	.rxnot_in_table_err ( rxnot_in_table_err ),
	.serdes_data_i ( jesd204brx_serdes_data_i ),
	.slave_interrupt ( jesd204brx_intr ),
	.sync_b ( jesd204brx_sync_b ),
	.sysref ( jesd204brx_sysref ),
	.test_mode ( scan_mode ),
	.txrx_lid_reg ( jesd204brx_txrx_lid_reg )
 ); 	// u_jesd204brx_wrapper

jesd204brx_ram u_jesd204brx_ram2 (
	.addr ( deskew_rd_addr[23:16] ),
	.addr_b ( deskew_wr_addr[23:16] ),
	.bist_addr ( jesd204brx_bist_addr ),
	.bist_cen ( bist_cen ),
	.bist_d ( jesd204brx_bist_d ),
	.bist_mode ( bist_mode ),
	.bist_oen ( bist_oen ),
	.bist_wen ( jesd204brx_bist_wen ),
	.cen ( deskew_rd_en[2] ),
	.cen_b ( deskew_wr_en[2] ),
	.clk ( jesd204brx_clk ),
	.clk_b ( jesd_pma_rx2_clk ),
	.d ( 36'h0 ),
	.d_b ( deskew_wr_data[107:72] ),
	.oen ( 1'b1 ),
	.oen_b ( 1'b0 ),
	.q ( q2 ),
	.scan_mode ( scan_mode ),
	.wen ( 1'b0 ),
	.wen_b ( deskew_wr_en[2] )
 ); 	// u_jesd204brx_ram2

jesd204brx_ram u_jesd204brx_ram3 (
	.addr ( deskew_rd_addr[31:24] ),
	.addr_b ( deskew_wr_addr[31:24] ),
	.bist_addr ( jesd204brx_bist_addr ),
	.bist_cen ( bist_cen ),
	.bist_d ( jesd204brx_bist_d ),
	.bist_mode ( bist_mode ),
	.bist_oen ( bist_oen ),
	.bist_wen ( jesd204brx_bist_wen ),
	.cen ( deskew_rd_en[3] ),
	.cen_b ( deskew_wr_en[3] ),
	.clk ( jesd204brx_clk ),
	.clk_b ( jesd_pma_rx3_clk ),
	.d ( 36'h0 ),
	.d_b ( deskew_wr_data[143:108] ),
	.oen ( 1'b1 ),
	.oen_b ( 1'b0 ),
	.q ( q3 ),
	.scan_mode ( scan_mode ),
	.wen ( 1'b0 ),
	.wen_b ( deskew_wr_en[3] )
 ); 	// u_jesd204brx_ram3

jesd204brx_ram u_jesd204brx_ram0 (
	.addr ( deskew_rd_addr[7:0] ),
	.addr_b ( deskew_wr_addr[7:0] ),
	.bist_addr ( jesd204brx_bist_addr ),
	.bist_cen ( bist_cen ),
	.bist_d ( jesd204brx_bist_d ),
	.bist_mode ( bist_mode ),
	.bist_oen ( bist_oen ),
	.bist_wen ( jesd204brx_bist_wen ),
	.cen ( deskew_rd_en[0] ),
	.cen_b ( deskew_wr_en[0] ),
	.clk ( jesd204brx_clk ),
	.clk_b ( jesd_pma_rx0_clk ),
	.d ( 36'h0 ),
	.d_b ( deskew_wr_data[35:0] ),
	.oen ( 1'b1 ),
	.oen_b ( 1'b0 ),
	.q ( q0 ),
	.scan_mode ( scan_mode ),
	.wen ( 1'b0 ),
	.wen_b ( deskew_wr_en[0] )
 ); 	// u_jesd204brx_ram0

jesd204brx_ram u_jesd204brx_ram1 (
	.addr ( deskew_rd_addr[15:8] ),
	.addr_b ( deskew_wr_addr[15:8] ),
	.bist_addr ( jesd204brx_bist_addr ),
	.bist_cen ( bist_cen ),
	.bist_d ( jesd204brx_bist_d ),
	.bist_mode ( bist_mode ),
	.bist_oen ( bist_oen ),
	.bist_wen ( jesd204brx_bist_wen ),
	.cen ( deskew_rd_en[1] ),
	.cen_b ( deskew_wr_en[1] ),
	.clk ( jesd204brx_clk ),
	.clk_b ( jesd_pma_rx1_clk ),
	.d ( 36'h0 ),
	.d_b ( deskew_wr_data[71:36] ),
	.oen ( 1'b1 ),
	.oen_b ( 1'b0 ),
	.q ( q1 ),
	.scan_mode ( scan_mode ),
	.wen ( 1'b0 ),
	.wen_b ( deskew_wr_en[1] )
 ); 	// u_jesd204brx_ram1





endmodule 	// jesd204brx


