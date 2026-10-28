// Generated using jscript version 3.00 by stevenchung at Wed Jun 17 21:02:17 2020
// Module jesd204b: mode flat
module jesd204b (
	JESDRX_ATB_F_P,
	JESDRX_ATB_S_M,
	JESDRX_ATB_S_P,
	JESDRX_GND,
	JESDRX_REF_CLK_M,
	JESDRX_REF_CLK_P,
	JESDRX_RESREF_F,
	JESDRX_RESREF_S,
	JESDRX_VP,
	JESDRX_VPDIG,
	JESDRX_VPH,
	JESDRX_VPTX0,
	JESDRX_VPTX1,
	JESDRX_VPTX2,
	JESDRX_VPTX3,
	JESDRX_VSSCORE_0,
	JESDRX_VSSCORE_1,
	JESDRX_VSSCORE_2,
	JESDTX_ATB_F_P,
	JESDTX_ATB_S_M,
	JESDTX_ATB_S_P,
	JESDTX_GND,
	JESDTX_REF_CLK_M,
	JESDTX_REF_CLK_P,
	JESDTX_RESREF_F,
	JESDTX_RESREF_S,
	JESDTX_VP,
	JESDTX_VPDIG,
	JESDTX_VPH,
	JESDTX_VPTX0,
	JESDTX_VPTX1,
	JESDTX_VPTX2,
	JESDTX_VPTX3,
	JESDTX_VSSCORE_0,
	JESDTX_VSSCORE_1,
	JESDTX_VSSCORE_2,
	JESD_RX0_M,
	JESD_RX0_P,
	JESD_RX1_M,
	JESD_RX1_P,
	JESD_RX2_M,
	JESD_RX2_P,
	JESD_RX3_M,
	JESD_RX3_P,
	JESD_TX0_M,
	JESD_TX0_P,
	JESD_TX1_M,
	JESD_TX1_P,
	JESD_TX2_M,
	JESD_TX2_P,
	JESD_TX3_M,
	JESD_TX3_P,
	bist_cen,
	bist_mode,
	bist_oen,
	frame_length_char,
	jesd204b_tx_frame_length_char,
	jesd204brx_active_lane,
	jesd204brx_bist_addr,
	jesd204brx_bist_d,
	jesd204brx_bist_wen,
	jesd204brx_clk,
	jesd204brx_end_of_frame,
	jesd204brx_frame_error,
	jesd204brx_intr,
	jesd204brx_pclk,
	jesd204brx_prdata,
	jesd204brx_pready,
	jesd204brx_preset,
	jesd204brx_psel,
	jesd204brx_reset,
	jesd204brx_start_of_frame,
	jesd204brx_sync_b,
	jesd204brx_sysref,
	jesd204brx_tdata,
	jesd204brx_tvalid,
	jesd204brx_txrx_lid_reg,
	jesd204btx_clk,
	jesd204btx_intr,
	jesd204btx_pclk,
	jesd204btx_prdata,
	jesd204btx_pready,
	jesd204btx_preset,
	jesd204btx_psel,
	jesd204btx_reset,
	jesd204btx_serdes_data_vld,
	jesd204btx_sync_b,
	jesd204btx_sysref,
	jesd204btx_tframe_data,
	jesd204btx_tframe_data_rdy,
	jesd204btx_tframe_data_vld,
	jesd2sysc_pma_dtb_out,
	jesd2sysc_pma_mplla_state,
	jesd2sysc_pma_mpllb_state,
	jesd2sysc_pma_rx0_ack,
	jesd2sysc_pma_rx0_adapt_sts,
	jesd2sysc_pma_rx0_los,
	jesd2sysc_pma_rx1_ack,
	jesd2sysc_pma_rx1_adapt_sts,
	jesd2sysc_pma_rx1_los,
	jesd2sysc_pma_rx2_ack,
	jesd2sysc_pma_rx2_adapt_sts,
	jesd2sysc_pma_rx2_los,
	jesd2sysc_pma_rx3_ack,
	jesd2sysc_pma_rx3_adapt_sts,
	jesd2sysc_pma_rx3_los,
	jesd2sysc_pma_tx0_ack,
	jesd2sysc_pma_tx0_detrx_result,
	jesd2sysc_pma_tx1_ack,
	jesd2sysc_pma_tx1_detrx_result,
	jesd2sysc_pma_tx2_ack,
	jesd2sysc_pma_tx2_detrx_result,
	jesd2sysc_pma_tx3_ack,
	jesd2sysc_pma_tx3_detrx_result,
	jesd2sysc_rtune_ack,
	jesd_pma_bs_acmode,
	jesd_pma_bs_actest,
	jesd_pma_bs_cdr,
	jesd_pma_bs_ce,
	jesd_pma_bs_rx_init,
	jesd_pma_bs_sdr,
	jesd_pma_bs_tdi,
	jesd_pma_bs_tdo,
	jesd_pma_bs_udr,
	jesdrx02sysc_pma_dtb_out,
	jesdrx02sysc_pma_mplla_state,
	jesdrx02sysc_pma_mpllb_state,
	jesdrx02sysc_pma_rx0_valid,
	jesdrx02sysc_pma_rx1_valid,
	jesdrx02sysc_pma_rx2_valid,
	jesdrx02sysc_pma_rx3_valid,
	jesdrx02sysc_rtune_ack,
	jesdrx0_pma_bs_acmode,
	jesdrx0_pma_bs_actest,
	jesdrx0_pma_bs_cdr,
	jesdrx0_pma_bs_ce,
	jesdrx0_pma_bs_rx_init,
	jesdrx0_pma_bs_sdr,
	jesdrx0_pma_bs_tdi,
	jesdrx0_pma_bs_tdo,
	jesdrx0_pma_bs_udr,
	jesdrxphy_scan_cr_para_in,
	jesdrxphy_scan_cr_para_out,
	jesdrxphy_scan_mplla_div16p5_clk,
	jesdrxphy_scan_mplla_div16p5_in,
	jesdrxphy_scan_mplla_div16p5_out,
	jesdrxphy_scan_mplla_div33_clk,
	jesdrxphy_scan_mplla_div66_clk,
	jesdrxphy_scan_mplla_div_clk,
	jesdrxphy_scan_mplla_div_in,
	jesdrxphy_scan_mplla_div_out,
	jesdrxphy_scan_mplla_dword_clk,
	jesdrxphy_scan_mplla_dword_in,
	jesdrxphy_scan_mplla_dword_out,
	jesdrxphy_scan_mplla_fb_clk,
	jesdrxphy_scan_mplla_fb_in,
	jesdrxphy_scan_mplla_fb_out,
	jesdrxphy_scan_mplla_oword_clk,
	jesdrxphy_scan_mplla_qword_clk,
	jesdrxphy_scan_mplla_qword_in,
	jesdrxphy_scan_mplla_qword_out,
	jesdrxphy_scan_mplla_ref_clk,
	jesdrxphy_scan_mplla_ref_in,
	jesdrxphy_scan_mplla_ref_out,
	jesdrxphy_scan_mplla_ssc_clk,
	jesdrxphy_scan_mplla_ssc_in,
	jesdrxphy_scan_mplla_ssc_out,
	jesdrxphy_scan_mplla_word_clk,
	jesdrxphy_scan_mplla_word_in,
	jesdrxphy_scan_mplla_word_out,
	jesdrxphy_scan_mpllb_div_clk,
	jesdrxphy_scan_mpllb_div_in,
	jesdrxphy_scan_mpllb_div_out,
	jesdrxphy_scan_mpllb_dword_clk,
	jesdrxphy_scan_mpllb_dword_in,
	jesdrxphy_scan_mpllb_dword_out,
	jesdrxphy_scan_mpllb_fb_clk,
	jesdrxphy_scan_mpllb_fb_in,
	jesdrxphy_scan_mpllb_fb_out,
	jesdrxphy_scan_mpllb_oword_clk,
	jesdrxphy_scan_mpllb_qword_clk,
	jesdrxphy_scan_mpllb_qword_in,
	jesdrxphy_scan_mpllb_qword_out,
	jesdrxphy_scan_mpllb_ref_clk,
	jesdrxphy_scan_mpllb_ref_in,
	jesdrxphy_scan_mpllb_ref_out,
	jesdrxphy_scan_mpllb_ssc_clk,
	jesdrxphy_scan_mpllb_ssc_in,
	jesdrxphy_scan_mpllb_ssc_out,
	jesdrxphy_scan_mpllb_word_clk,
	jesdrxphy_scan_mpllb_word_in,
	jesdrxphy_scan_mpllb_word_out,
	jesdrxphy_scan_ref_clk,
	jesdrxphy_scan_ref_dig_clk,
	jesdrxphy_scan_ref_dig_in,
	jesdrxphy_scan_ref_dig_out,
	jesdrxphy_scan_ref_in,
	jesdrxphy_scan_ref_out,
	jesdrxphy_scan_ref_range_clk,
	jesdrxphy_scan_ref_range_in,
	jesdrxphy_scan_ref_range_out,
	jesdrxphy_scan_rx0_adpt_clk,
	jesdrxphy_scan_rx0_adpt_in,
	jesdrxphy_scan_rx0_adpt_out,
	jesdrxphy_scan_rx0_asic_clk,
	jesdrxphy_scan_rx0_asic_in,
	jesdrxphy_scan_rx0_asic_out,
	jesdrxphy_scan_rx0_div16p5_clk,
	jesdrxphy_scan_rx0_div16p5_in,
	jesdrxphy_scan_rx0_div16p5_out,
	jesdrxphy_scan_rx0_dpll_clk,
	jesdrxphy_scan_rx0_dpll_in,
	jesdrxphy_scan_rx0_dpll_out,
	jesdrxphy_scan_rx0_dword_clk,
	jesdrxphy_scan_rx0_dword_in,
	jesdrxphy_scan_rx0_dword_out,
	jesdrxphy_scan_rx0_scope_clk,
	jesdrxphy_scan_rx0_scope_in,
	jesdrxphy_scan_rx0_scope_out,
	jesdrxphy_scan_rx0_stat_clk,
	jesdrxphy_scan_rx0_stat_in,
	jesdrxphy_scan_rx0_stat_out,
	jesdrxphy_scan_rx0_word_clk,
	jesdrxphy_scan_rx0_word_in,
	jesdrxphy_scan_rx0_word_out,
	jesdrxphy_scan_rx1_adpt_clk,
	jesdrxphy_scan_rx1_adpt_in,
	jesdrxphy_scan_rx1_adpt_out,
	jesdrxphy_scan_rx1_asic_clk,
	jesdrxphy_scan_rx1_asic_in,
	jesdrxphy_scan_rx1_asic_out,
	jesdrxphy_scan_rx1_div16p5_clk,
	jesdrxphy_scan_rx1_div16p5_in,
	jesdrxphy_scan_rx1_div16p5_out,
	jesdrxphy_scan_rx1_dpll_clk,
	jesdrxphy_scan_rx1_dpll_in,
	jesdrxphy_scan_rx1_dpll_out,
	jesdrxphy_scan_rx1_dword_clk,
	jesdrxphy_scan_rx1_dword_in,
	jesdrxphy_scan_rx1_dword_out,
	jesdrxphy_scan_rx1_scope_clk,
	jesdrxphy_scan_rx1_scope_in,
	jesdrxphy_scan_rx1_scope_out,
	jesdrxphy_scan_rx1_stat_clk,
	jesdrxphy_scan_rx1_stat_in,
	jesdrxphy_scan_rx1_stat_out,
	jesdrxphy_scan_rx1_word_clk,
	jesdrxphy_scan_rx1_word_in,
	jesdrxphy_scan_rx1_word_out,
	jesdrxphy_scan_rx2_adpt_clk,
	jesdrxphy_scan_rx2_adpt_in,
	jesdrxphy_scan_rx2_adpt_out,
	jesdrxphy_scan_rx2_asic_clk,
	jesdrxphy_scan_rx2_asic_in,
	jesdrxphy_scan_rx2_asic_out,
	jesdrxphy_scan_rx2_div16p5_clk,
	jesdrxphy_scan_rx2_div16p5_in,
	jesdrxphy_scan_rx2_div16p5_out,
	jesdrxphy_scan_rx2_dpll_clk,
	jesdrxphy_scan_rx2_dpll_in,
	jesdrxphy_scan_rx2_dpll_out,
	jesdrxphy_scan_rx2_dword_clk,
	jesdrxphy_scan_rx2_dword_in,
	jesdrxphy_scan_rx2_dword_out,
	jesdrxphy_scan_rx2_scope_clk,
	jesdrxphy_scan_rx2_scope_in,
	jesdrxphy_scan_rx2_scope_out,
	jesdrxphy_scan_rx2_stat_clk,
	jesdrxphy_scan_rx2_stat_in,
	jesdrxphy_scan_rx2_stat_out,
	jesdrxphy_scan_rx2_word_clk,
	jesdrxphy_scan_rx2_word_in,
	jesdrxphy_scan_rx2_word_out,
	jesdrxphy_scan_rx3_adpt_clk,
	jesdrxphy_scan_rx3_adpt_in,
	jesdrxphy_scan_rx3_adpt_out,
	jesdrxphy_scan_rx3_asic_clk,
	jesdrxphy_scan_rx3_asic_in,
	jesdrxphy_scan_rx3_asic_out,
	jesdrxphy_scan_rx3_div16p5_clk,
	jesdrxphy_scan_rx3_div16p5_in,
	jesdrxphy_scan_rx3_div16p5_out,
	jesdrxphy_scan_rx3_dpll_clk,
	jesdrxphy_scan_rx3_dpll_in,
	jesdrxphy_scan_rx3_dpll_out,
	jesdrxphy_scan_rx3_dword_clk,
	jesdrxphy_scan_rx3_dword_in,
	jesdrxphy_scan_rx3_dword_out,
	jesdrxphy_scan_rx3_scope_clk,
	jesdrxphy_scan_rx3_scope_in,
	jesdrxphy_scan_rx3_scope_out,
	jesdrxphy_scan_rx3_stat_clk,
	jesdrxphy_scan_rx3_stat_in,
	jesdrxphy_scan_rx3_stat_out,
	jesdrxphy_scan_rx3_word_clk,
	jesdrxphy_scan_rx3_word_in,
	jesdrxphy_scan_rx3_word_out,
	jesdrxphy_scan_sel,
	jesdrxphy_scan_set_rst,
	jesdrxphy_scan_shift,
	jesdrxphy_scan_tx0_ana_dword_clk,
	jesdrxphy_scan_tx0_ana_dword_in,
	jesdrxphy_scan_tx0_ana_dword_out,
	jesdrxphy_scan_tx0_ana_word_clk,
	jesdrxphy_scan_tx0_ana_word_in,
	jesdrxphy_scan_tx0_ana_word_out,
	jesdrxphy_scan_tx0_asic_dword_clk,
	jesdrxphy_scan_tx0_asic_dword_in,
	jesdrxphy_scan_tx0_asic_dword_out,
	jesdrxphy_scan_tx0_in,
	jesdrxphy_scan_tx0_out,
	jesdrxphy_scan_tx1_ana_dword_clk,
	jesdrxphy_scan_tx1_ana_dword_in,
	jesdrxphy_scan_tx1_ana_dword_out,
	jesdrxphy_scan_tx1_ana_word_clk,
	jesdrxphy_scan_tx1_ana_word_in,
	jesdrxphy_scan_tx1_ana_word_out,
	jesdrxphy_scan_tx1_asic_dword_clk,
	jesdrxphy_scan_tx1_asic_dword_in,
	jesdrxphy_scan_tx1_asic_dword_out,
	jesdrxphy_scan_tx1_in,
	jesdrxphy_scan_tx1_out,
	jesdrxphy_scan_tx2_ana_dword_clk,
	jesdrxphy_scan_tx2_ana_dword_in,
	jesdrxphy_scan_tx2_ana_dword_out,
	jesdrxphy_scan_tx2_ana_word_clk,
	jesdrxphy_scan_tx2_ana_word_in,
	jesdrxphy_scan_tx2_ana_word_out,
	jesdrxphy_scan_tx2_asic_dword_clk,
	jesdrxphy_scan_tx2_asic_dword_in,
	jesdrxphy_scan_tx2_asic_dword_out,
	jesdrxphy_scan_tx2_in,
	jesdrxphy_scan_tx2_out,
	jesdrxphy_scan_tx3_ana_dword_clk,
	jesdrxphy_scan_tx3_ana_dword_in,
	jesdrxphy_scan_tx3_ana_dword_out,
	jesdrxphy_scan_tx3_ana_word_clk,
	jesdrxphy_scan_tx3_ana_word_in,
	jesdrxphy_scan_tx3_ana_word_out,
	jesdrxphy_scan_tx3_asic_dword_clk,
	jesdrxphy_scan_tx3_asic_dword_in,
	jesdrxphy_scan_tx3_asic_dword_out,
	jesdrxphy_scan_tx3_in,
	jesdrxphy_scan_tx3_out,
	jesdtxphy_scan_cr_para_in,
	jesdtxphy_scan_cr_para_out,
	jesdtxphy_scan_mplla_div16p5_clk,
	jesdtxphy_scan_mplla_div16p5_in,
	jesdtxphy_scan_mplla_div16p5_out,
	jesdtxphy_scan_mplla_div33_clk,
	jesdtxphy_scan_mplla_div66_clk,
	jesdtxphy_scan_mplla_div_clk,
	jesdtxphy_scan_mplla_div_in,
	jesdtxphy_scan_mplla_div_out,
	jesdtxphy_scan_mplla_dword_clk,
	jesdtxphy_scan_mplla_dword_in,
	jesdtxphy_scan_mplla_dword_out,
	jesdtxphy_scan_mplla_fb_clk,
	jesdtxphy_scan_mplla_fb_in,
	jesdtxphy_scan_mplla_fb_out,
	jesdtxphy_scan_mplla_oword_clk,
	jesdtxphy_scan_mplla_qword_clk,
	jesdtxphy_scan_mplla_qword_in,
	jesdtxphy_scan_mplla_qword_out,
	jesdtxphy_scan_mplla_ref_clk,
	jesdtxphy_scan_mplla_ref_in,
	jesdtxphy_scan_mplla_ref_out,
	jesdtxphy_scan_mplla_ssc_clk,
	jesdtxphy_scan_mplla_ssc_in,
	jesdtxphy_scan_mplla_ssc_out,
	jesdtxphy_scan_mplla_word_clk,
	jesdtxphy_scan_mplla_word_in,
	jesdtxphy_scan_mplla_word_out,
	jesdtxphy_scan_mpllb_div_clk,
	jesdtxphy_scan_mpllb_div_in,
	jesdtxphy_scan_mpllb_div_out,
	jesdtxphy_scan_mpllb_dword_clk,
	jesdtxphy_scan_mpllb_dword_in,
	jesdtxphy_scan_mpllb_dword_out,
	jesdtxphy_scan_mpllb_fb_clk,
	jesdtxphy_scan_mpllb_fb_in,
	jesdtxphy_scan_mpllb_fb_out,
	jesdtxphy_scan_mpllb_oword_clk,
	jesdtxphy_scan_mpllb_qword_clk,
	jesdtxphy_scan_mpllb_qword_in,
	jesdtxphy_scan_mpllb_qword_out,
	jesdtxphy_scan_mpllb_ref_clk,
	jesdtxphy_scan_mpllb_ref_in,
	jesdtxphy_scan_mpllb_ref_out,
	jesdtxphy_scan_mpllb_ssc_clk,
	jesdtxphy_scan_mpllb_ssc_in,
	jesdtxphy_scan_mpllb_ssc_out,
	jesdtxphy_scan_mpllb_word_clk,
	jesdtxphy_scan_mpllb_word_in,
	jesdtxphy_scan_mpllb_word_out,
	jesdtxphy_scan_ref_clk,
	jesdtxphy_scan_ref_dig_clk,
	jesdtxphy_scan_ref_dig_in,
	jesdtxphy_scan_ref_dig_out,
	jesdtxphy_scan_ref_in,
	jesdtxphy_scan_ref_out,
	jesdtxphy_scan_ref_range_clk,
	jesdtxphy_scan_ref_range_in,
	jesdtxphy_scan_ref_range_out,
	jesdtxphy_scan_rx0_adpt_clk,
	jesdtxphy_scan_rx0_adpt_in,
	jesdtxphy_scan_rx0_adpt_out,
	jesdtxphy_scan_rx0_asic_clk,
	jesdtxphy_scan_rx0_asic_in,
	jesdtxphy_scan_rx0_asic_out,
	jesdtxphy_scan_rx0_div16p5_clk,
	jesdtxphy_scan_rx0_div16p5_in,
	jesdtxphy_scan_rx0_div16p5_out,
	jesdtxphy_scan_rx0_dpll_clk,
	jesdtxphy_scan_rx0_dpll_in,
	jesdtxphy_scan_rx0_dpll_out,
	jesdtxphy_scan_rx0_dword_clk,
	jesdtxphy_scan_rx0_dword_in,
	jesdtxphy_scan_rx0_dword_out,
	jesdtxphy_scan_rx0_scope_clk,
	jesdtxphy_scan_rx0_scope_in,
	jesdtxphy_scan_rx0_scope_out,
	jesdtxphy_scan_rx0_stat_clk,
	jesdtxphy_scan_rx0_stat_in,
	jesdtxphy_scan_rx0_stat_out,
	jesdtxphy_scan_rx0_word_clk,
	jesdtxphy_scan_rx0_word_in,
	jesdtxphy_scan_rx0_word_out,
	jesdtxphy_scan_rx1_adpt_clk,
	jesdtxphy_scan_rx1_adpt_in,
	jesdtxphy_scan_rx1_adpt_out,
	jesdtxphy_scan_rx1_asic_clk,
	jesdtxphy_scan_rx1_asic_in,
	jesdtxphy_scan_rx1_asic_out,
	jesdtxphy_scan_rx1_div16p5_clk,
	jesdtxphy_scan_rx1_div16p5_in,
	jesdtxphy_scan_rx1_div16p5_out,
	jesdtxphy_scan_rx1_dpll_clk,
	jesdtxphy_scan_rx1_dpll_in,
	jesdtxphy_scan_rx1_dpll_out,
	jesdtxphy_scan_rx1_dword_clk,
	jesdtxphy_scan_rx1_dword_in,
	jesdtxphy_scan_rx1_dword_out,
	jesdtxphy_scan_rx1_scope_clk,
	jesdtxphy_scan_rx1_scope_in,
	jesdtxphy_scan_rx1_scope_out,
	jesdtxphy_scan_rx1_stat_clk,
	jesdtxphy_scan_rx1_stat_in,
	jesdtxphy_scan_rx1_stat_out,
	jesdtxphy_scan_rx1_word_clk,
	jesdtxphy_scan_rx1_word_in,
	jesdtxphy_scan_rx1_word_out,
	jesdtxphy_scan_rx2_adpt_clk,
	jesdtxphy_scan_rx2_adpt_in,
	jesdtxphy_scan_rx2_adpt_out,
	jesdtxphy_scan_rx2_asic_clk,
	jesdtxphy_scan_rx2_asic_in,
	jesdtxphy_scan_rx2_asic_out,
	jesdtxphy_scan_rx2_div16p5_clk,
	jesdtxphy_scan_rx2_div16p5_in,
	jesdtxphy_scan_rx2_div16p5_out,
	jesdtxphy_scan_rx2_dpll_clk,
	jesdtxphy_scan_rx2_dpll_in,
	jesdtxphy_scan_rx2_dpll_out,
	jesdtxphy_scan_rx2_dword_clk,
	jesdtxphy_scan_rx2_dword_in,
	jesdtxphy_scan_rx2_dword_out,
	jesdtxphy_scan_rx2_scope_clk,
	jesdtxphy_scan_rx2_scope_in,
	jesdtxphy_scan_rx2_scope_out,
	jesdtxphy_scan_rx2_stat_clk,
	jesdtxphy_scan_rx2_stat_in,
	jesdtxphy_scan_rx2_stat_out,
	jesdtxphy_scan_rx2_word_clk,
	jesdtxphy_scan_rx2_word_in,
	jesdtxphy_scan_rx2_word_out,
	jesdtxphy_scan_rx3_adpt_clk,
	jesdtxphy_scan_rx3_adpt_in,
	jesdtxphy_scan_rx3_adpt_out,
	jesdtxphy_scan_rx3_asic_clk,
	jesdtxphy_scan_rx3_asic_in,
	jesdtxphy_scan_rx3_asic_out,
	jesdtxphy_scan_rx3_div16p5_clk,
	jesdtxphy_scan_rx3_div16p5_in,
	jesdtxphy_scan_rx3_div16p5_out,
	jesdtxphy_scan_rx3_dpll_clk,
	jesdtxphy_scan_rx3_dpll_in,
	jesdtxphy_scan_rx3_dpll_out,
	jesdtxphy_scan_rx3_dword_clk,
	jesdtxphy_scan_rx3_dword_in,
	jesdtxphy_scan_rx3_dword_out,
	jesdtxphy_scan_rx3_scope_clk,
	jesdtxphy_scan_rx3_scope_in,
	jesdtxphy_scan_rx3_scope_out,
	jesdtxphy_scan_rx3_stat_clk,
	jesdtxphy_scan_rx3_stat_in,
	jesdtxphy_scan_rx3_stat_out,
	jesdtxphy_scan_rx3_word_clk,
	jesdtxphy_scan_rx3_word_in,
	jesdtxphy_scan_rx3_word_out,
	jesdtxphy_scan_sel,
	jesdtxphy_scan_set_rst,
	jesdtxphy_scan_shift,
	jesdtxphy_scan_tx0_ana_dword_clk,
	jesdtxphy_scan_tx0_ana_dword_in,
	jesdtxphy_scan_tx0_ana_dword_out,
	jesdtxphy_scan_tx0_ana_word_clk,
	jesdtxphy_scan_tx0_ana_word_in,
	jesdtxphy_scan_tx0_ana_word_out,
	jesdtxphy_scan_tx0_asic_dword_clk,
	jesdtxphy_scan_tx0_asic_dword_in,
	jesdtxphy_scan_tx0_asic_dword_out,
	jesdtxphy_scan_tx0_in,
	jesdtxphy_scan_tx0_out,
	jesdtxphy_scan_tx1_ana_dword_clk,
	jesdtxphy_scan_tx1_ana_dword_in,
	jesdtxphy_scan_tx1_ana_dword_out,
	jesdtxphy_scan_tx1_ana_word_clk,
	jesdtxphy_scan_tx1_ana_word_in,
	jesdtxphy_scan_tx1_ana_word_out,
	jesdtxphy_scan_tx1_asic_dword_clk,
	jesdtxphy_scan_tx1_asic_dword_in,
	jesdtxphy_scan_tx1_asic_dword_out,
	jesdtxphy_scan_tx1_in,
	jesdtxphy_scan_tx1_out,
	jesdtxphy_scan_tx2_ana_dword_clk,
	jesdtxphy_scan_tx2_ana_dword_in,
	jesdtxphy_scan_tx2_ana_dword_out,
	jesdtxphy_scan_tx2_ana_word_clk,
	jesdtxphy_scan_tx2_ana_word_in,
	jesdtxphy_scan_tx2_ana_word_out,
	jesdtxphy_scan_tx2_asic_dword_clk,
	jesdtxphy_scan_tx2_asic_dword_in,
	jesdtxphy_scan_tx2_asic_dword_out,
	jesdtxphy_scan_tx2_in,
	jesdtxphy_scan_tx2_out,
	jesdtxphy_scan_tx3_ana_dword_clk,
	jesdtxphy_scan_tx3_ana_dword_in,
	jesdtxphy_scan_tx3_ana_dword_out,
	jesdtxphy_scan_tx3_ana_word_clk,
	jesdtxphy_scan_tx3_ana_word_in,
	jesdtxphy_scan_tx3_ana_word_out,
	jesdtxphy_scan_tx3_asic_dword_clk,
	jesdtxphy_scan_tx3_asic_dword_in,
	jesdtxphy_scan_tx3_asic_dword_out,
	jesdtxphy_scan_tx3_in,
	jesdtxphy_scan_tx3_out,
	paddr,
	penable,
	pwdata,
	pwrite,
	rxdata_k,
	rxdisparity_err,
	rxnot_in_table_err,
	scan_mode,
	sysc2jesd_pma_bg_en,
	sysc2jesd_pma_bs_rx_bigswing,
	sysc2jesd_pma_bs_rx_level,
	sysc2jesd_pma_bs_tx_lowswing,
	sysc2jesd_pma_lane0_rx2tx_par_lb_en,
	sysc2jesd_pma_lane0_tx2rx_ser_lb_en,
	sysc2jesd_pma_lane1_rx2tx_par_lb_en,
	sysc2jesd_pma_lane1_tx2rx_ser_lb_en,
	sysc2jesd_pma_lane2_rx2tx_par_lb_en,
	sysc2jesd_pma_lane2_tx2rx_ser_lb_en,
	sysc2jesd_pma_lane3_rx2tx_par_lb_en,
	sysc2jesd_pma_lane3_tx2rx_ser_lb_en,
	sysc2jesd_pma_mplla_bandwidth,
	sysc2jesd_pma_mplla_div_multiplier,
	sysc2jesd_pma_mplla_en,
	sysc2jesd_pma_mplla_fracn_ctrl,
	sysc2jesd_pma_mplla_multiplier,
	sysc2jesd_pma_mplla_ssc_clk_sel,
	sysc2jesd_pma_mplla_ssc_en,
	sysc2jesd_pma_mplla_ssc_range,
	sysc2jesd_pma_mpllb_bandwidth,
	sysc2jesd_pma_mpllb_div_multiplier,
	sysc2jesd_pma_mpllb_en,
	sysc2jesd_pma_mpllb_fracn_ctrl,
	sysc2jesd_pma_mpllb_multiplier,
	sysc2jesd_pma_mpllb_ssc_clk_sel,
	sysc2jesd_pma_mpllb_ssc_en,
	sysc2jesd_pma_mpllb_ssc_range,
	sysc2jesd_pma_ref_clk_div2_en,
	sysc2jesd_pma_ref_clk_en,
	sysc2jesd_pma_ref_clk_mplla_div2_en,
	sysc2jesd_pma_ref_clk_mpllb_div2_en,
	sysc2jesd_pma_ref_range,
	sysc2jesd_pma_rx_adapt_afe_en,
	sysc2jesd_pma_rx_adapt_dfe_en,
	sysc2jesd_pma_rx_align_en,
	sysc2jesd_pma_rx_cdr_ssc_en,
	sysc2jesd_pma_rx_cdr_track_en,
	sysc2jesd_pma_rx_cdr_vco_lowfreq,
	sysc2jesd_pma_rx_clk_shift,
	sysc2jesd_pma_rx_data_en,
	sysc2jesd_pma_rx_disable,
	sysc2jesd_pma_rx_eq_att_lvl,
	sysc2jesd_pma_rx_eq_ctle_boost,
	sysc2jesd_pma_rx_eq_ctle_pole,
	sysc2jesd_pma_rx_eq_dfe_tap1,
	sysc2jesd_pma_rx_eq_dfe_tap2,
	sysc2jesd_pma_rx_eq_dfe_tap3,
	sysc2jesd_pma_rx_eq_dfe_tap4,
	sysc2jesd_pma_rx_eq_dfe_tap5,
	sysc2jesd_pma_rx_eq_vga1_gain,
	sysc2jesd_pma_rx_eq_vga2_gain,
	sysc2jesd_pma_rx_invert,
	sysc2jesd_pma_rx_los_lfps_en,
	sysc2jesd_pma_rx_los_threshold,
	sysc2jesd_pma_rx_lpd,
	sysc2jesd_pma_rx_pstate,
	sysc2jesd_pma_rx_rate,
	sysc2jesd_pma_rx_ref_ld_val,
	sysc2jesd_pma_rx_req,
	sysc2jesd_pma_rx_term_acdc,
	sysc2jesd_pma_rx_term_en,
	sysc2jesd_pma_rx_vco_ld_val,
	sysc2jesd_pma_rx_vref_ctrl,
	sysc2jesd_pma_rx_width,
	sysc2jesd_pma_test_burnin,
	sysc2jesd_pma_test_powerdown,
	sysc2jesd_pma_tx_beacon_en,
	sysc2jesd_pma_tx_clk_rdy,
	sysc2jesd_pma_tx_data_en,
	sysc2jesd_pma_tx_detrx_req,
	sysc2jesd_pma_tx_disable,
	sysc2jesd_pma_tx_eq_main,
	sysc2jesd_pma_tx_eq_post,
	sysc2jesd_pma_tx_eq_pre,
	sysc2jesd_pma_tx_iboost_lvl,
	sysc2jesd_pma_tx_invert,
	sysc2jesd_pma_tx_lpd,
	sysc2jesd_pma_tx_mpllb_sel,
	sysc2jesd_pma_tx_pstate,
	sysc2jesd_pma_tx_rate,
	sysc2jesd_pma_tx_req,
	sysc2jesd_pma_tx_vboost_en,
	sysc2jesd_pma_tx_vboost_lvl,
	sysc2jesd_pma_tx_width,
	sysc2jesd_rtune_req,
	sysc2jesdrx0_pma_bg_en,
	sysc2jesdrx0_pma_bs_rx_bigswing,
	sysc2jesdrx0_pma_bs_rx_level,
	sysc2jesdrx0_pma_bs_tx_lowswing,
	sysc2jesdrx0_pma_lane0_rx2tx_par_lb_en,
	sysc2jesdrx0_pma_lane0_tx2rx_ser_lb_en,
	sysc2jesdrx0_pma_lane1_rx2tx_par_lb_en,
	sysc2jesdrx0_pma_lane1_tx2rx_ser_lb_en,
	sysc2jesdrx0_pma_lane2_rx2tx_par_lb_en,
	sysc2jesdrx0_pma_lane2_tx2rx_ser_lb_en,
	sysc2jesdrx0_pma_lane3_rx2tx_par_lb_en,
	sysc2jesdrx0_pma_lane3_tx2rx_ser_lb_en,
	sysc2jesdrx0_pma_mplla_bandwidth,
	sysc2jesdrx0_pma_mplla_div_multiplier,
	sysc2jesdrx0_pma_mplla_en,
	sysc2jesdrx0_pma_mplla_fracn_ctrl,
	sysc2jesdrx0_pma_mplla_multiplier,
	sysc2jesdrx0_pma_mplla_ssc_clk_sel,
	sysc2jesdrx0_pma_mplla_ssc_en,
	sysc2jesdrx0_pma_mplla_ssc_range,
	sysc2jesdrx0_pma_mpllb_bandwidth,
	sysc2jesdrx0_pma_mpllb_div_multiplier,
	sysc2jesdrx0_pma_mpllb_en,
	sysc2jesdrx0_pma_mpllb_fracn_ctrl,
	sysc2jesdrx0_pma_mpllb_multiplier,
	sysc2jesdrx0_pma_mpllb_ssc_clk_sel,
	sysc2jesdrx0_pma_mpllb_ssc_en,
	sysc2jesdrx0_pma_mpllb_ssc_range,
	sysc2jesdrx0_pma_ref_clk_div2_en,
	sysc2jesdrx0_pma_ref_clk_en,
	sysc2jesdrx0_pma_ref_clk_mplla_div2_en,
	sysc2jesdrx0_pma_ref_clk_mpllb_div2_en,
	sysc2jesdrx0_pma_ref_range,
	sysc2jesdrx0_pma_test_burnin,
	sysc2jesdrx0_pma_test_powerdown,
	sysc2jesdrx0_ref_use_pad,
	sysc2jesdtx_ref_use_pad,
	sysc2xaui2_cr_cap_addr,
	sysc2xaui2_cr_data_in,
	sysc2xaui2_cr_read,
	sysc2xaui2_cr_write,
	sysc2xaui3_cr_cap_addr,
	sysc2xaui3_cr_data_in,
	sysc2xaui3_cr_read,
	sysc2xaui3_cr_write,
	txdata_k,
	xaui22sysc_cr_data_out,
	xaui32sysc_cr_data_out
);	// jesd204b

	inout		JESDRX_ATB_F_P;
	inout		JESDRX_ATB_S_M;
	inout		JESDRX_ATB_S_P;
	inout		JESDRX_GND;
	input		JESDRX_REF_CLK_M;
	input		JESDRX_REF_CLK_P;
	inout		JESDRX_RESREF_F;
	inout		JESDRX_RESREF_S;
	inout		JESDRX_VP;
	inout		JESDRX_VPDIG;
	inout		JESDRX_VPH;
	inout		JESDRX_VPTX0;
	inout		JESDRX_VPTX1;
	inout		JESDRX_VPTX2;
	inout		JESDRX_VPTX3;
	inout		JESDRX_VSSCORE_0;
	inout		JESDRX_VSSCORE_1;
	inout		JESDRX_VSSCORE_2;
	inout		JESDTX_ATB_F_P;
	inout		JESDTX_ATB_S_M;
	inout		JESDTX_ATB_S_P;
	inout		JESDTX_GND;
	input		JESDTX_REF_CLK_M;
	input		JESDTX_REF_CLK_P;
	inout		JESDTX_RESREF_F;
	inout		JESDTX_RESREF_S;
	inout		JESDTX_VP;
	inout		JESDTX_VPDIG;
	inout		JESDTX_VPH;
	inout		JESDTX_VPTX0;
	inout		JESDTX_VPTX1;
	inout		JESDTX_VPTX2;
	inout		JESDTX_VPTX3;
	inout		JESDTX_VSSCORE_0;
	inout		JESDTX_VSSCORE_1;
	inout		JESDTX_VSSCORE_2;
	input		JESD_RX0_M;
	input		JESD_RX0_P;
	input		JESD_RX1_M;
	input		JESD_RX1_P;
	input		JESD_RX2_M;
	input		JESD_RX2_P;
	input		JESD_RX3_M;
	input		JESD_RX3_P;
	output		JESD_TX0_M;
	output		JESD_TX0_P;
	output		JESD_TX1_M;
	output		JESD_TX1_P;
	output		JESD_TX2_M;
	output		JESD_TX2_P;
	output		JESD_TX3_M;
	output		JESD_TX3_P;
	input		bist_cen;
	input		bist_mode;
	input		bist_oen;
	output	[8:0]	frame_length_char;
	output	[8:0]	jesd204b_tx_frame_length_char;
	output	[7:0]	jesd204brx_active_lane;
	input	[7:0]	jesd204brx_bist_addr;
	input	[35:0]	jesd204brx_bist_d;
	input	[0:0]	jesd204brx_bist_wen;
	input		jesd204brx_clk;
	output	[3:0]	jesd204brx_end_of_frame;
	output	[31:0]	jesd204brx_frame_error;
	output		jesd204brx_intr;
	input		jesd204brx_pclk;
	output	[31:0]	jesd204brx_prdata;
	output		jesd204brx_pready;
	input		jesd204brx_preset;
	input		jesd204brx_psel;
	input		jesd204brx_reset;
	output	[3:0]	jesd204brx_start_of_frame;
	output		jesd204brx_sync_b;
	input		jesd204brx_sysref;
	output	[255:0]	jesd204brx_tdata;
	output		jesd204brx_tvalid;
	output	[39:0]	jesd204brx_txrx_lid_reg;
	input		jesd204btx_clk;
	output		jesd204btx_intr;
	input		jesd204btx_pclk;
	output	[31:0]	jesd204btx_prdata;
	output		jesd204btx_pready;
	input		jesd204btx_preset;
	input		jesd204btx_psel;
	input		jesd204btx_reset;
	output	[3:0]	jesd204btx_serdes_data_vld;
	input		jesd204btx_sync_b;
	input		jesd204btx_sysref;
	input	[127:0]	jesd204btx_tframe_data;
	output		jesd204btx_tframe_data_rdy;
	input		jesd204btx_tframe_data_vld;
	output	[1:0]	jesd2sysc_pma_dtb_out;
	output		jesd2sysc_pma_mplla_state;
	output		jesd2sysc_pma_mpllb_state;
	output		jesd2sysc_pma_rx0_ack;
	output	[1:0]	jesd2sysc_pma_rx0_adapt_sts;
	output		jesd2sysc_pma_rx0_los;
	output		jesd2sysc_pma_rx1_ack;
	output	[1:0]	jesd2sysc_pma_rx1_adapt_sts;
	output		jesd2sysc_pma_rx1_los;
	output		jesd2sysc_pma_rx2_ack;
	output	[1:0]	jesd2sysc_pma_rx2_adapt_sts;
	output		jesd2sysc_pma_rx2_los;
	output		jesd2sysc_pma_rx3_ack;
	output	[1:0]	jesd2sysc_pma_rx3_adapt_sts;
	output		jesd2sysc_pma_rx3_los;
	output		jesd2sysc_pma_tx0_ack;
	output		jesd2sysc_pma_tx0_detrx_result;
	output		jesd2sysc_pma_tx1_ack;
	output		jesd2sysc_pma_tx1_detrx_result;
	output		jesd2sysc_pma_tx2_ack;
	output		jesd2sysc_pma_tx2_detrx_result;
	output		jesd2sysc_pma_tx3_ack;
	output		jesd2sysc_pma_tx3_detrx_result;
	output		jesd2sysc_rtune_ack;
	input		jesd_pma_bs_acmode;
	input		jesd_pma_bs_actest;
	input		jesd_pma_bs_cdr;
	input		jesd_pma_bs_ce;
	input		jesd_pma_bs_rx_init;
	input		jesd_pma_bs_sdr;
	input		jesd_pma_bs_tdi;
	output		jesd_pma_bs_tdo;
	input		jesd_pma_bs_udr;
	output	[1:0]	jesdrx02sysc_pma_dtb_out;
	output		jesdrx02sysc_pma_mplla_state;
	output		jesdrx02sysc_pma_mpllb_state;
	output		jesdrx02sysc_pma_rx0_valid;
	output		jesdrx02sysc_pma_rx1_valid;
	output		jesdrx02sysc_pma_rx2_valid;
	output		jesdrx02sysc_pma_rx3_valid;
	output		jesdrx02sysc_rtune_ack;
	input		jesdrx0_pma_bs_acmode;
	input		jesdrx0_pma_bs_actest;
	input		jesdrx0_pma_bs_cdr;
	input		jesdrx0_pma_bs_ce;
	input		jesdrx0_pma_bs_rx_init;
	input		jesdrx0_pma_bs_sdr;
	input		jesdrx0_pma_bs_tdi;
	output		jesdrx0_pma_bs_tdo;
	input		jesdrx0_pma_bs_udr;
	input	[61:0]	jesdrxphy_scan_cr_para_in;
	output	[61:0]	jesdrxphy_scan_cr_para_out;
	input		jesdrxphy_scan_mplla_div16p5_clk;
	input		jesdrxphy_scan_mplla_div16p5_in;
	output		jesdrxphy_scan_mplla_div16p5_out;
	input		jesdrxphy_scan_mplla_div33_clk;
	input		jesdrxphy_scan_mplla_div66_clk;
	input		jesdrxphy_scan_mplla_div_clk;
	input		jesdrxphy_scan_mplla_div_in;
	output		jesdrxphy_scan_mplla_div_out;
	input		jesdrxphy_scan_mplla_dword_clk;
	input		jesdrxphy_scan_mplla_dword_in;
	output		jesdrxphy_scan_mplla_dword_out;
	input		jesdrxphy_scan_mplla_fb_clk;
	input		jesdrxphy_scan_mplla_fb_in;
	output		jesdrxphy_scan_mplla_fb_out;
	input		jesdrxphy_scan_mplla_oword_clk;
	input		jesdrxphy_scan_mplla_qword_clk;
	input		jesdrxphy_scan_mplla_qword_in;
	output		jesdrxphy_scan_mplla_qword_out;
	input		jesdrxphy_scan_mplla_ref_clk;
	input		jesdrxphy_scan_mplla_ref_in;
	output		jesdrxphy_scan_mplla_ref_out;
	input		jesdrxphy_scan_mplla_ssc_clk;
	input	[1:0]	jesdrxphy_scan_mplla_ssc_in;
	output	[1:0]	jesdrxphy_scan_mplla_ssc_out;
	input		jesdrxphy_scan_mplla_word_clk;
	input		jesdrxphy_scan_mplla_word_in;
	output		jesdrxphy_scan_mplla_word_out;
	input		jesdrxphy_scan_mpllb_div_clk;
	input		jesdrxphy_scan_mpllb_div_in;
	output		jesdrxphy_scan_mpllb_div_out;
	input		jesdrxphy_scan_mpllb_dword_clk;
	input		jesdrxphy_scan_mpllb_dword_in;
	output		jesdrxphy_scan_mpllb_dword_out;
	input		jesdrxphy_scan_mpllb_fb_clk;
	input		jesdrxphy_scan_mpllb_fb_in;
	output		jesdrxphy_scan_mpllb_fb_out;
	input		jesdrxphy_scan_mpllb_oword_clk;
	input		jesdrxphy_scan_mpllb_qword_clk;
	input		jesdrxphy_scan_mpllb_qword_in;
	output		jesdrxphy_scan_mpllb_qword_out;
	input		jesdrxphy_scan_mpllb_ref_clk;
	input		jesdrxphy_scan_mpllb_ref_in;
	output		jesdrxphy_scan_mpllb_ref_out;
	input		jesdrxphy_scan_mpllb_ssc_clk;
	input	[1:0]	jesdrxphy_scan_mpllb_ssc_in;
	output	[1:0]	jesdrxphy_scan_mpllb_ssc_out;
	input		jesdrxphy_scan_mpllb_word_clk;
	input		jesdrxphy_scan_mpllb_word_in;
	output		jesdrxphy_scan_mpllb_word_out;
	input		jesdrxphy_scan_ref_clk;
	input		jesdrxphy_scan_ref_dig_clk;
	input	[8:0]	jesdrxphy_scan_ref_dig_in;
	output	[8:0]	jesdrxphy_scan_ref_dig_out;
	input		jesdrxphy_scan_ref_in;
	output		jesdrxphy_scan_ref_out;
	input		jesdrxphy_scan_ref_range_clk;
	input	[17:0]	jesdrxphy_scan_ref_range_in;
	output	[17:0]	jesdrxphy_scan_ref_range_out;
	input		jesdrxphy_scan_rx0_adpt_clk;
	input	[4:0]	jesdrxphy_scan_rx0_adpt_in;
	output	[4:0]	jesdrxphy_scan_rx0_adpt_out;
	input		jesdrxphy_scan_rx0_asic_clk;
	input		jesdrxphy_scan_rx0_asic_in;
	output		jesdrxphy_scan_rx0_asic_out;
	input		jesdrxphy_scan_rx0_div16p5_clk;
	input		jesdrxphy_scan_rx0_div16p5_in;
	output		jesdrxphy_scan_rx0_div16p5_out;
	input		jesdrxphy_scan_rx0_dpll_clk;
	input		jesdrxphy_scan_rx0_dpll_in;
	output		jesdrxphy_scan_rx0_dpll_out;
	input		jesdrxphy_scan_rx0_dword_clk;
	input	[8:0]	jesdrxphy_scan_rx0_dword_in;
	output	[8:0]	jesdrxphy_scan_rx0_dword_out;
	input		jesdrxphy_scan_rx0_scope_clk;
	input		jesdrxphy_scan_rx0_scope_in;
	output		jesdrxphy_scan_rx0_scope_out;
	input		jesdrxphy_scan_rx0_stat_clk;
	input	[6:0]	jesdrxphy_scan_rx0_stat_in;
	output	[6:0]	jesdrxphy_scan_rx0_stat_out;
	input		jesdrxphy_scan_rx0_word_clk;
	input		jesdrxphy_scan_rx0_word_in;
	output		jesdrxphy_scan_rx0_word_out;
	input		jesdrxphy_scan_rx1_adpt_clk;
	input	[4:0]	jesdrxphy_scan_rx1_adpt_in;
	output	[4:0]	jesdrxphy_scan_rx1_adpt_out;
	input		jesdrxphy_scan_rx1_asic_clk;
	input		jesdrxphy_scan_rx1_asic_in;
	output		jesdrxphy_scan_rx1_asic_out;
	input		jesdrxphy_scan_rx1_div16p5_clk;
	input		jesdrxphy_scan_rx1_div16p5_in;
	output		jesdrxphy_scan_rx1_div16p5_out;
	input		jesdrxphy_scan_rx1_dpll_clk;
	input		jesdrxphy_scan_rx1_dpll_in;
	output		jesdrxphy_scan_rx1_dpll_out;
	input		jesdrxphy_scan_rx1_dword_clk;
	input	[8:0]	jesdrxphy_scan_rx1_dword_in;
	output	[8:0]	jesdrxphy_scan_rx1_dword_out;
	input		jesdrxphy_scan_rx1_scope_clk;
	input		jesdrxphy_scan_rx1_scope_in;
	output		jesdrxphy_scan_rx1_scope_out;
	input		jesdrxphy_scan_rx1_stat_clk;
	input	[6:0]	jesdrxphy_scan_rx1_stat_in;
	output	[6:0]	jesdrxphy_scan_rx1_stat_out;
	input		jesdrxphy_scan_rx1_word_clk;
	input		jesdrxphy_scan_rx1_word_in;
	output		jesdrxphy_scan_rx1_word_out;
	input		jesdrxphy_scan_rx2_adpt_clk;
	input	[4:0]	jesdrxphy_scan_rx2_adpt_in;
	output	[4:0]	jesdrxphy_scan_rx2_adpt_out;
	input		jesdrxphy_scan_rx2_asic_clk;
	input		jesdrxphy_scan_rx2_asic_in;
	output		jesdrxphy_scan_rx2_asic_out;
	input		jesdrxphy_scan_rx2_div16p5_clk;
	input		jesdrxphy_scan_rx2_div16p5_in;
	output		jesdrxphy_scan_rx2_div16p5_out;
	input		jesdrxphy_scan_rx2_dpll_clk;
	input		jesdrxphy_scan_rx2_dpll_in;
	output		jesdrxphy_scan_rx2_dpll_out;
	input		jesdrxphy_scan_rx2_dword_clk;
	input	[8:0]	jesdrxphy_scan_rx2_dword_in;
	output	[8:0]	jesdrxphy_scan_rx2_dword_out;
	input		jesdrxphy_scan_rx2_scope_clk;
	input		jesdrxphy_scan_rx2_scope_in;
	output		jesdrxphy_scan_rx2_scope_out;
	input		jesdrxphy_scan_rx2_stat_clk;
	input	[6:0]	jesdrxphy_scan_rx2_stat_in;
	output	[6:0]	jesdrxphy_scan_rx2_stat_out;
	input		jesdrxphy_scan_rx2_word_clk;
	input		jesdrxphy_scan_rx2_word_in;
	output		jesdrxphy_scan_rx2_word_out;
	input		jesdrxphy_scan_rx3_adpt_clk;
	input	[4:0]	jesdrxphy_scan_rx3_adpt_in;
	output	[4:0]	jesdrxphy_scan_rx3_adpt_out;
	input		jesdrxphy_scan_rx3_asic_clk;
	input		jesdrxphy_scan_rx3_asic_in;
	output		jesdrxphy_scan_rx3_asic_out;
	input		jesdrxphy_scan_rx3_div16p5_clk;
	input		jesdrxphy_scan_rx3_div16p5_in;
	output		jesdrxphy_scan_rx3_div16p5_out;
	input		jesdrxphy_scan_rx3_dpll_clk;
	input		jesdrxphy_scan_rx3_dpll_in;
	output		jesdrxphy_scan_rx3_dpll_out;
	input		jesdrxphy_scan_rx3_dword_clk;
	input	[8:0]	jesdrxphy_scan_rx3_dword_in;
	output	[8:0]	jesdrxphy_scan_rx3_dword_out;
	input		jesdrxphy_scan_rx3_scope_clk;
	input		jesdrxphy_scan_rx3_scope_in;
	output		jesdrxphy_scan_rx3_scope_out;
	input		jesdrxphy_scan_rx3_stat_clk;
	input	[6:0]	jesdrxphy_scan_rx3_stat_in;
	output	[6:0]	jesdrxphy_scan_rx3_stat_out;
	input		jesdrxphy_scan_rx3_word_clk;
	input		jesdrxphy_scan_rx3_word_in;
	output		jesdrxphy_scan_rx3_word_out;
	input		jesdrxphy_scan_sel;
	input		jesdrxphy_scan_set_rst;
	input		jesdrxphy_scan_shift;
	input		jesdrxphy_scan_tx0_ana_dword_clk;
	input		jesdrxphy_scan_tx0_ana_dword_in;
	output		jesdrxphy_scan_tx0_ana_dword_out;
	input		jesdrxphy_scan_tx0_ana_word_clk;
	input		jesdrxphy_scan_tx0_ana_word_in;
	output		jesdrxphy_scan_tx0_ana_word_out;
	input		jesdrxphy_scan_tx0_asic_dword_clk;
	input		jesdrxphy_scan_tx0_asic_dword_in;
	output		jesdrxphy_scan_tx0_asic_dword_out;
	input	[1:0]	jesdrxphy_scan_tx0_in;
	output	[1:0]	jesdrxphy_scan_tx0_out;
	input		jesdrxphy_scan_tx1_ana_dword_clk;
	input		jesdrxphy_scan_tx1_ana_dword_in;
	output		jesdrxphy_scan_tx1_ana_dword_out;
	input		jesdrxphy_scan_tx1_ana_word_clk;
	input		jesdrxphy_scan_tx1_ana_word_in;
	output		jesdrxphy_scan_tx1_ana_word_out;
	input		jesdrxphy_scan_tx1_asic_dword_clk;
	input		jesdrxphy_scan_tx1_asic_dword_in;
	output		jesdrxphy_scan_tx1_asic_dword_out;
	input	[1:0]	jesdrxphy_scan_tx1_in;
	output	[1:0]	jesdrxphy_scan_tx1_out;
	input		jesdrxphy_scan_tx2_ana_dword_clk;
	input		jesdrxphy_scan_tx2_ana_dword_in;
	output		jesdrxphy_scan_tx2_ana_dword_out;
	input		jesdrxphy_scan_tx2_ana_word_clk;
	input		jesdrxphy_scan_tx2_ana_word_in;
	output		jesdrxphy_scan_tx2_ana_word_out;
	input		jesdrxphy_scan_tx2_asic_dword_clk;
	input		jesdrxphy_scan_tx2_asic_dword_in;
	output		jesdrxphy_scan_tx2_asic_dword_out;
	input	[1:0]	jesdrxphy_scan_tx2_in;
	output	[1:0]	jesdrxphy_scan_tx2_out;
	input		jesdrxphy_scan_tx3_ana_dword_clk;
	input		jesdrxphy_scan_tx3_ana_dword_in;
	output		jesdrxphy_scan_tx3_ana_dword_out;
	input		jesdrxphy_scan_tx3_ana_word_clk;
	input		jesdrxphy_scan_tx3_ana_word_in;
	output		jesdrxphy_scan_tx3_ana_word_out;
	input		jesdrxphy_scan_tx3_asic_dword_clk;
	input		jesdrxphy_scan_tx3_asic_dword_in;
	output		jesdrxphy_scan_tx3_asic_dword_out;
	input	[1:0]	jesdrxphy_scan_tx3_in;
	output	[1:0]	jesdrxphy_scan_tx3_out;
	input	[61:0]	jesdtxphy_scan_cr_para_in;
	output	[61:0]	jesdtxphy_scan_cr_para_out;
	input		jesdtxphy_scan_mplla_div16p5_clk;
	input		jesdtxphy_scan_mplla_div16p5_in;
	output		jesdtxphy_scan_mplla_div16p5_out;
	input		jesdtxphy_scan_mplla_div33_clk;
	input		jesdtxphy_scan_mplla_div66_clk;
	input		jesdtxphy_scan_mplla_div_clk;
	input		jesdtxphy_scan_mplla_div_in;
	output		jesdtxphy_scan_mplla_div_out;
	input		jesdtxphy_scan_mplla_dword_clk;
	input		jesdtxphy_scan_mplla_dword_in;
	output		jesdtxphy_scan_mplla_dword_out;
	input		jesdtxphy_scan_mplla_fb_clk;
	input		jesdtxphy_scan_mplla_fb_in;
	output		jesdtxphy_scan_mplla_fb_out;
	input		jesdtxphy_scan_mplla_oword_clk;
	input		jesdtxphy_scan_mplla_qword_clk;
	input		jesdtxphy_scan_mplla_qword_in;
	output		jesdtxphy_scan_mplla_qword_out;
	input		jesdtxphy_scan_mplla_ref_clk;
	input		jesdtxphy_scan_mplla_ref_in;
	output		jesdtxphy_scan_mplla_ref_out;
	input		jesdtxphy_scan_mplla_ssc_clk;
	input	[1:0]	jesdtxphy_scan_mplla_ssc_in;
	output	[1:0]	jesdtxphy_scan_mplla_ssc_out;
	input		jesdtxphy_scan_mplla_word_clk;
	input		jesdtxphy_scan_mplla_word_in;
	output		jesdtxphy_scan_mplla_word_out;
	input		jesdtxphy_scan_mpllb_div_clk;
	input		jesdtxphy_scan_mpllb_div_in;
	output		jesdtxphy_scan_mpllb_div_out;
	input		jesdtxphy_scan_mpllb_dword_clk;
	input		jesdtxphy_scan_mpllb_dword_in;
	output		jesdtxphy_scan_mpllb_dword_out;
	input		jesdtxphy_scan_mpllb_fb_clk;
	input		jesdtxphy_scan_mpllb_fb_in;
	output		jesdtxphy_scan_mpllb_fb_out;
	input		jesdtxphy_scan_mpllb_oword_clk;
	input		jesdtxphy_scan_mpllb_qword_clk;
	input		jesdtxphy_scan_mpllb_qword_in;
	output		jesdtxphy_scan_mpllb_qword_out;
	input		jesdtxphy_scan_mpllb_ref_clk;
	input		jesdtxphy_scan_mpllb_ref_in;
	output		jesdtxphy_scan_mpllb_ref_out;
	input		jesdtxphy_scan_mpllb_ssc_clk;
	input	[1:0]	jesdtxphy_scan_mpllb_ssc_in;
	output	[1:0]	jesdtxphy_scan_mpllb_ssc_out;
	input		jesdtxphy_scan_mpllb_word_clk;
	input		jesdtxphy_scan_mpllb_word_in;
	output		jesdtxphy_scan_mpllb_word_out;
	input		jesdtxphy_scan_ref_clk;
	input		jesdtxphy_scan_ref_dig_clk;
	input	[8:0]	jesdtxphy_scan_ref_dig_in;
	output	[8:0]	jesdtxphy_scan_ref_dig_out;
	input		jesdtxphy_scan_ref_in;
	output		jesdtxphy_scan_ref_out;
	input		jesdtxphy_scan_ref_range_clk;
	input	[17:0]	jesdtxphy_scan_ref_range_in;
	output	[17:0]	jesdtxphy_scan_ref_range_out;
	input		jesdtxphy_scan_rx0_adpt_clk;
	input	[4:0]	jesdtxphy_scan_rx0_adpt_in;
	output	[4:0]	jesdtxphy_scan_rx0_adpt_out;
	input		jesdtxphy_scan_rx0_asic_clk;
	input		jesdtxphy_scan_rx0_asic_in;
	output		jesdtxphy_scan_rx0_asic_out;
	input		jesdtxphy_scan_rx0_div16p5_clk;
	input		jesdtxphy_scan_rx0_div16p5_in;
	output		jesdtxphy_scan_rx0_div16p5_out;
	input		jesdtxphy_scan_rx0_dpll_clk;
	input		jesdtxphy_scan_rx0_dpll_in;
	output		jesdtxphy_scan_rx0_dpll_out;
	input		jesdtxphy_scan_rx0_dword_clk;
	input	[8:0]	jesdtxphy_scan_rx0_dword_in;
	output	[8:0]	jesdtxphy_scan_rx0_dword_out;
	input		jesdtxphy_scan_rx0_scope_clk;
	input		jesdtxphy_scan_rx0_scope_in;
	output		jesdtxphy_scan_rx0_scope_out;
	input		jesdtxphy_scan_rx0_stat_clk;
	input	[6:0]	jesdtxphy_scan_rx0_stat_in;
	output	[6:0]	jesdtxphy_scan_rx0_stat_out;
	input		jesdtxphy_scan_rx0_word_clk;
	input		jesdtxphy_scan_rx0_word_in;
	output		jesdtxphy_scan_rx0_word_out;
	input		jesdtxphy_scan_rx1_adpt_clk;
	input	[4:0]	jesdtxphy_scan_rx1_adpt_in;
	output	[4:0]	jesdtxphy_scan_rx1_adpt_out;
	input		jesdtxphy_scan_rx1_asic_clk;
	input		jesdtxphy_scan_rx1_asic_in;
	output		jesdtxphy_scan_rx1_asic_out;
	input		jesdtxphy_scan_rx1_div16p5_clk;
	input		jesdtxphy_scan_rx1_div16p5_in;
	output		jesdtxphy_scan_rx1_div16p5_out;
	input		jesdtxphy_scan_rx1_dpll_clk;
	input		jesdtxphy_scan_rx1_dpll_in;
	output		jesdtxphy_scan_rx1_dpll_out;
	input		jesdtxphy_scan_rx1_dword_clk;
	input	[8:0]	jesdtxphy_scan_rx1_dword_in;
	output	[8:0]	jesdtxphy_scan_rx1_dword_out;
	input		jesdtxphy_scan_rx1_scope_clk;
	input		jesdtxphy_scan_rx1_scope_in;
	output		jesdtxphy_scan_rx1_scope_out;
	input		jesdtxphy_scan_rx1_stat_clk;
	input	[6:0]	jesdtxphy_scan_rx1_stat_in;
	output	[6:0]	jesdtxphy_scan_rx1_stat_out;
	input		jesdtxphy_scan_rx1_word_clk;
	input		jesdtxphy_scan_rx1_word_in;
	output		jesdtxphy_scan_rx1_word_out;
	input		jesdtxphy_scan_rx2_adpt_clk;
	input	[4:0]	jesdtxphy_scan_rx2_adpt_in;
	output	[4:0]	jesdtxphy_scan_rx2_adpt_out;
	input		jesdtxphy_scan_rx2_asic_clk;
	input		jesdtxphy_scan_rx2_asic_in;
	output		jesdtxphy_scan_rx2_asic_out;
	input		jesdtxphy_scan_rx2_div16p5_clk;
	input		jesdtxphy_scan_rx2_div16p5_in;
	output		jesdtxphy_scan_rx2_div16p5_out;
	input		jesdtxphy_scan_rx2_dpll_clk;
	input		jesdtxphy_scan_rx2_dpll_in;
	output		jesdtxphy_scan_rx2_dpll_out;
	input		jesdtxphy_scan_rx2_dword_clk;
	input	[8:0]	jesdtxphy_scan_rx2_dword_in;
	output	[8:0]	jesdtxphy_scan_rx2_dword_out;
	input		jesdtxphy_scan_rx2_scope_clk;
	input		jesdtxphy_scan_rx2_scope_in;
	output		jesdtxphy_scan_rx2_scope_out;
	input		jesdtxphy_scan_rx2_stat_clk;
	input	[6:0]	jesdtxphy_scan_rx2_stat_in;
	output	[6:0]	jesdtxphy_scan_rx2_stat_out;
	input		jesdtxphy_scan_rx2_word_clk;
	input		jesdtxphy_scan_rx2_word_in;
	output		jesdtxphy_scan_rx2_word_out;
	input		jesdtxphy_scan_rx3_adpt_clk;
	input	[4:0]	jesdtxphy_scan_rx3_adpt_in;
	output	[4:0]	jesdtxphy_scan_rx3_adpt_out;
	input		jesdtxphy_scan_rx3_asic_clk;
	input		jesdtxphy_scan_rx3_asic_in;
	output		jesdtxphy_scan_rx3_asic_out;
	input		jesdtxphy_scan_rx3_div16p5_clk;
	input		jesdtxphy_scan_rx3_div16p5_in;
	output		jesdtxphy_scan_rx3_div16p5_out;
	input		jesdtxphy_scan_rx3_dpll_clk;
	input		jesdtxphy_scan_rx3_dpll_in;
	output		jesdtxphy_scan_rx3_dpll_out;
	input		jesdtxphy_scan_rx3_dword_clk;
	input	[8:0]	jesdtxphy_scan_rx3_dword_in;
	output	[8:0]	jesdtxphy_scan_rx3_dword_out;
	input		jesdtxphy_scan_rx3_scope_clk;
	input		jesdtxphy_scan_rx3_scope_in;
	output		jesdtxphy_scan_rx3_scope_out;
	input		jesdtxphy_scan_rx3_stat_clk;
	input	[6:0]	jesdtxphy_scan_rx3_stat_in;
	output	[6:0]	jesdtxphy_scan_rx3_stat_out;
	input		jesdtxphy_scan_rx3_word_clk;
	input		jesdtxphy_scan_rx3_word_in;
	output		jesdtxphy_scan_rx3_word_out;
	input		jesdtxphy_scan_sel;
	input		jesdtxphy_scan_set_rst;
	input		jesdtxphy_scan_shift;
	input		jesdtxphy_scan_tx0_ana_dword_clk;
	input		jesdtxphy_scan_tx0_ana_dword_in;
	output		jesdtxphy_scan_tx0_ana_dword_out;
	input		jesdtxphy_scan_tx0_ana_word_clk;
	input		jesdtxphy_scan_tx0_ana_word_in;
	output		jesdtxphy_scan_tx0_ana_word_out;
	input		jesdtxphy_scan_tx0_asic_dword_clk;
	input		jesdtxphy_scan_tx0_asic_dword_in;
	output		jesdtxphy_scan_tx0_asic_dword_out;
	input	[1:0]	jesdtxphy_scan_tx0_in;
	output	[1:0]	jesdtxphy_scan_tx0_out;
	input		jesdtxphy_scan_tx1_ana_dword_clk;
	input		jesdtxphy_scan_tx1_ana_dword_in;
	output		jesdtxphy_scan_tx1_ana_dword_out;
	input		jesdtxphy_scan_tx1_ana_word_clk;
	input		jesdtxphy_scan_tx1_ana_word_in;
	output		jesdtxphy_scan_tx1_ana_word_out;
	input		jesdtxphy_scan_tx1_asic_dword_clk;
	input		jesdtxphy_scan_tx1_asic_dword_in;
	output		jesdtxphy_scan_tx1_asic_dword_out;
	input	[1:0]	jesdtxphy_scan_tx1_in;
	output	[1:0]	jesdtxphy_scan_tx1_out;
	input		jesdtxphy_scan_tx2_ana_dword_clk;
	input		jesdtxphy_scan_tx2_ana_dword_in;
	output		jesdtxphy_scan_tx2_ana_dword_out;
	input		jesdtxphy_scan_tx2_ana_word_clk;
	input		jesdtxphy_scan_tx2_ana_word_in;
	output		jesdtxphy_scan_tx2_ana_word_out;
	input		jesdtxphy_scan_tx2_asic_dword_clk;
	input		jesdtxphy_scan_tx2_asic_dword_in;
	output		jesdtxphy_scan_tx2_asic_dword_out;
	input	[1:0]	jesdtxphy_scan_tx2_in;
	output	[1:0]	jesdtxphy_scan_tx2_out;
	input		jesdtxphy_scan_tx3_ana_dword_clk;
	input		jesdtxphy_scan_tx3_ana_dword_in;
	output		jesdtxphy_scan_tx3_ana_dword_out;
	input		jesdtxphy_scan_tx3_ana_word_clk;
	input		jesdtxphy_scan_tx3_ana_word_in;
	output		jesdtxphy_scan_tx3_ana_word_out;
	input		jesdtxphy_scan_tx3_asic_dword_clk;
	input		jesdtxphy_scan_tx3_asic_dword_in;
	output		jesdtxphy_scan_tx3_asic_dword_out;
	input	[1:0]	jesdtxphy_scan_tx3_in;
	output	[1:0]	jesdtxphy_scan_tx3_out;
	input	[31:0]	paddr;
	input		penable;
	input	[31:0]	pwdata;
	input		pwrite;
	input	[31:0]	rxdata_k;
	input	[31:0]	rxdisparity_err;
	input	[31:0]	rxnot_in_table_err;
	input		scan_mode;
	input		sysc2jesd_pma_bg_en;
	input		sysc2jesd_pma_bs_rx_bigswing;
	input	[4:0]	sysc2jesd_pma_bs_rx_level;
	input		sysc2jesd_pma_bs_tx_lowswing;
	input		sysc2jesd_pma_lane0_rx2tx_par_lb_en;
	input		sysc2jesd_pma_lane0_tx2rx_ser_lb_en;
	input		sysc2jesd_pma_lane1_rx2tx_par_lb_en;
	input		sysc2jesd_pma_lane1_tx2rx_ser_lb_en;
	input		sysc2jesd_pma_lane2_rx2tx_par_lb_en;
	input		sysc2jesd_pma_lane2_tx2rx_ser_lb_en;
	input		sysc2jesd_pma_lane3_rx2tx_par_lb_en;
	input		sysc2jesd_pma_lane3_tx2rx_ser_lb_en;
	input	[6:0]	sysc2jesd_pma_mplla_bandwidth;
	input	[6:0]	sysc2jesd_pma_mplla_div_multiplier;
	input		sysc2jesd_pma_mplla_en;
	input	[8:0]	sysc2jesd_pma_mplla_fracn_ctrl;
	input	[7:0]	sysc2jesd_pma_mplla_multiplier;
	input	[2:0]	sysc2jesd_pma_mplla_ssc_clk_sel;
	input		sysc2jesd_pma_mplla_ssc_en;
	input	[2:0]	sysc2jesd_pma_mplla_ssc_range;
	input	[6:0]	sysc2jesd_pma_mpllb_bandwidth;
	input	[6:0]	sysc2jesd_pma_mpllb_div_multiplier;
	input		sysc2jesd_pma_mpllb_en;
	input	[8:0]	sysc2jesd_pma_mpllb_fracn_ctrl;
	input	[7:0]	sysc2jesd_pma_mpllb_multiplier;
	input	[2:0]	sysc2jesd_pma_mpllb_ssc_clk_sel;
	input		sysc2jesd_pma_mpllb_ssc_en;
	input	[2:0]	sysc2jesd_pma_mpllb_ssc_range;
	input		sysc2jesd_pma_ref_clk_div2_en;
	input		sysc2jesd_pma_ref_clk_en;
	input		sysc2jesd_pma_ref_clk_mplla_div2_en;
	input		sysc2jesd_pma_ref_clk_mpllb_div2_en;
	input	[2:0]	sysc2jesd_pma_ref_range;
	input		sysc2jesd_pma_rx_adapt_afe_en;
	input		sysc2jesd_pma_rx_adapt_dfe_en;
	input		sysc2jesd_pma_rx_align_en;
	input		sysc2jesd_pma_rx_cdr_ssc_en;
	input		sysc2jesd_pma_rx_cdr_track_en;
	input		sysc2jesd_pma_rx_cdr_vco_lowfreq;
	input		sysc2jesd_pma_rx_clk_shift;
	input		sysc2jesd_pma_rx_data_en;
	input		sysc2jesd_pma_rx_disable;
	input	[2:0]	sysc2jesd_pma_rx_eq_att_lvl;
	input	[4:0]	sysc2jesd_pma_rx_eq_ctle_boost;
	input	[2:0]	sysc2jesd_pma_rx_eq_ctle_pole;
	input	[7:0]	sysc2jesd_pma_rx_eq_dfe_tap1;
	input	[6:0]	sysc2jesd_pma_rx_eq_dfe_tap2;
	input	[6:0]	sysc2jesd_pma_rx_eq_dfe_tap3;
	input	[6:0]	sysc2jesd_pma_rx_eq_dfe_tap4;
	input	[6:0]	sysc2jesd_pma_rx_eq_dfe_tap5;
	input	[3:0]	sysc2jesd_pma_rx_eq_vga1_gain;
	input	[3:0]	sysc2jesd_pma_rx_eq_vga2_gain;
	input		sysc2jesd_pma_rx_invert;
	input		sysc2jesd_pma_rx_los_lfps_en;
	input	[2:0]	sysc2jesd_pma_rx_los_threshold;
	input		sysc2jesd_pma_rx_lpd;
	input	[1:0]	sysc2jesd_pma_rx_pstate;
	input	[1:0]	sysc2jesd_pma_rx_rate;
	input	[5:0]	sysc2jesd_pma_rx_ref_ld_val;
	input		sysc2jesd_pma_rx_req;
	input		sysc2jesd_pma_rx_term_acdc;
	input		sysc2jesd_pma_rx_term_en;
	input	[12:0]	sysc2jesd_pma_rx_vco_ld_val;
	input	[4:0]	sysc2jesd_pma_rx_vref_ctrl;
	input	[1:0]	sysc2jesd_pma_rx_width;
	input		sysc2jesd_pma_test_burnin;
	input		sysc2jesd_pma_test_powerdown;
	input		sysc2jesd_pma_tx_beacon_en;
	input		sysc2jesd_pma_tx_clk_rdy;
	input		sysc2jesd_pma_tx_data_en;
	input		sysc2jesd_pma_tx_detrx_req;
	input		sysc2jesd_pma_tx_disable;
	input	[5:0]	sysc2jesd_pma_tx_eq_main;
	input	[5:0]	sysc2jesd_pma_tx_eq_post;
	input	[5:0]	sysc2jesd_pma_tx_eq_pre;
	input	[3:0]	sysc2jesd_pma_tx_iboost_lvl;
	input		sysc2jesd_pma_tx_invert;
	input		sysc2jesd_pma_tx_lpd;
	input		sysc2jesd_pma_tx_mpllb_sel;
	input	[1:0]	sysc2jesd_pma_tx_pstate;
	input	[2:0]	sysc2jesd_pma_tx_rate;
	input		sysc2jesd_pma_tx_req;
	input		sysc2jesd_pma_tx_vboost_en;
	input	[2:0]	sysc2jesd_pma_tx_vboost_lvl;
	input	[1:0]	sysc2jesd_pma_tx_width;
	input		sysc2jesd_rtune_req;
	input		sysc2jesdrx0_pma_bg_en;
	input		sysc2jesdrx0_pma_bs_rx_bigswing;
	input	[4:0]	sysc2jesdrx0_pma_bs_rx_level;
	input		sysc2jesdrx0_pma_bs_tx_lowswing;
	input		sysc2jesdrx0_pma_lane0_rx2tx_par_lb_en;
	input		sysc2jesdrx0_pma_lane0_tx2rx_ser_lb_en;
	input		sysc2jesdrx0_pma_lane1_rx2tx_par_lb_en;
	input		sysc2jesdrx0_pma_lane1_tx2rx_ser_lb_en;
	input		sysc2jesdrx0_pma_lane2_rx2tx_par_lb_en;
	input		sysc2jesdrx0_pma_lane2_tx2rx_ser_lb_en;
	input		sysc2jesdrx0_pma_lane3_rx2tx_par_lb_en;
	input		sysc2jesdrx0_pma_lane3_tx2rx_ser_lb_en;
	input	[6:0]	sysc2jesdrx0_pma_mplla_bandwidth;
	input	[6:0]	sysc2jesdrx0_pma_mplla_div_multiplier;
	input		sysc2jesdrx0_pma_mplla_en;
	input	[8:0]	sysc2jesdrx0_pma_mplla_fracn_ctrl;
	input	[7:0]	sysc2jesdrx0_pma_mplla_multiplier;
	input	[2:0]	sysc2jesdrx0_pma_mplla_ssc_clk_sel;
	input		sysc2jesdrx0_pma_mplla_ssc_en;
	input	[2:0]	sysc2jesdrx0_pma_mplla_ssc_range;
	input	[6:0]	sysc2jesdrx0_pma_mpllb_bandwidth;
	input	[6:0]	sysc2jesdrx0_pma_mpllb_div_multiplier;
	input		sysc2jesdrx0_pma_mpllb_en;
	input	[8:0]	sysc2jesdrx0_pma_mpllb_fracn_ctrl;
	input	[7:0]	sysc2jesdrx0_pma_mpllb_multiplier;
	input	[2:0]	sysc2jesdrx0_pma_mpllb_ssc_clk_sel;
	input		sysc2jesdrx0_pma_mpllb_ssc_en;
	input	[2:0]	sysc2jesdrx0_pma_mpllb_ssc_range;
	input		sysc2jesdrx0_pma_ref_clk_div2_en;
	input		sysc2jesdrx0_pma_ref_clk_en;
	input		sysc2jesdrx0_pma_ref_clk_mplla_div2_en;
	input		sysc2jesdrx0_pma_ref_clk_mpllb_div2_en;
	input	[2:0]	sysc2jesdrx0_pma_ref_range;
	input		sysc2jesdrx0_pma_test_burnin;
	input		sysc2jesdrx0_pma_test_powerdown;
	input		sysc2jesdrx0_ref_use_pad;
	input		sysc2jesdtx_ref_use_pad;
	input	[15:0]	sysc2xaui2_cr_cap_addr;
	input	[15:0]	sysc2xaui2_cr_data_in;
	input		sysc2xaui2_cr_read;
	input		sysc2xaui2_cr_write;
	input	[15:0]	sysc2xaui3_cr_cap_addr;
	input	[15:0]	sysc2xaui3_cr_data_in;
	input		sysc2xaui3_cr_read;
	input		sysc2xaui3_cr_write;
	output	[15:0]	txdata_k;
	output	[15:0]	xaui22sysc_cr_data_out;
	output	[15:0]	xaui32sysc_cr_data_out;

	wire		inv_jesd204brx_clk;
	wire	[127:0]	jesd204btx_serdes_data_o;
	wire		jesd_pma_res_req_out;
	wire		jesd_pma_rx0_clk;
	wire	[19:0]	jesd_pma_rx0_data;
	wire		jesd_pma_rx1_clk;
	wire	[19:0]	jesd_pma_rx1_data;
	wire		jesd_pma_rx2_clk;
	wire	[19:0]	jesd_pma_rx2_data;
	wire		jesd_pma_rx3_clk;
	wire	[19:0]	jesd_pma_rx3_data;
	wire		jesdrx0_pma_res_req_out;




jesd204brx u_jesd204brx (
	.bist_cen ( bist_cen ),
	.bist_mode ( bist_mode ),
	.bist_oen ( bist_oen ),
	.frame_length_char ( frame_length_char ),
	.jesd204brx_active_lane ( jesd204brx_active_lane ),
	.jesd204brx_bist_addr ( jesd204brx_bist_addr ),
	.jesd204brx_bist_d ( jesd204brx_bist_d ),
	.jesd204brx_bist_wen ( jesd204brx_bist_wen ),
	.jesd204brx_clk ( jesd204brx_clk ),
	.jesd204brx_end_of_frame ( jesd204brx_end_of_frame ),
	.jesd204brx_frame_error ( jesd204brx_frame_error ),
	.jesd204brx_intr ( jesd204brx_intr ),
	.jesd204brx_pclk ( jesd204brx_pclk ),
	.jesd204brx_preset ( jesd204brx_preset ),
	.jesd204brx_serdes_data_i ( {12'h0, jesd_pma_rx3_data, 12'h0, jesd_pma_rx2_data, 12'h0, jesd_pma_rx1_data, 12'h0, jesd_pma_rx0_data} ),
	.jesd204brx_start_of_frame ( jesd204brx_start_of_frame ),
	.jesd204brx_sync_b ( jesd204brx_sync_b ),
	.jesd204brx_sysref ( jesd204brx_sysref ),
	.jesd204brx_tdata ( jesd204brx_tdata ),
	.jesd204brx_tvalid ( jesd204brx_tvalid ),
	.jesd204brx_txrx_lid_reg ( jesd204brx_txrx_lid_reg ),
	.jesd_pma_rx0_clk ( jesd_pma_rx0_clk ),
	.jesd_pma_rx1_clk ( jesd_pma_rx1_clk ),
	.jesd_pma_rx2_clk ( jesd_pma_rx2_clk ),
	.jesd_pma_rx3_clk ( jesd_pma_rx3_clk ),
	.paddr ( paddr ),
	.penable ( penable ),
	.prdata ( jesd204brx_prdata ),
	.pready ( jesd204brx_pready ),
	.psel ( jesd204brx_psel ),
	.pwdata ( pwdata ),
	.pwrite ( pwrite ),
	.rxdata_k ( rxdata_k ),
	.rxdisparity_err ( rxdisparity_err ),
	.rxnot_in_table_err ( rxnot_in_table_err ),
	.scan_mode ( scan_mode )
 ); 	// u_jesd204brx

jesd204b_misc u_jesd204b_misc (
	.inv_jesd204brx_clk ( inv_jesd204brx_clk ),
	.jesd204brx_clk ( jesd204brx_clk )
 ); 	// u_jesd204b_misc

jesd204btx u_jesd204btx (
	.jesd204b_tx_frame_length_char ( jesd204b_tx_frame_length_char ),
	.jesd204btx_clk ( jesd204btx_clk ),
	.jesd204btx_intr ( jesd204btx_intr ),
	.jesd204btx_pclk ( jesd204btx_pclk ),
	.jesd204btx_preset ( jesd204btx_preset ),
	.jesd204btx_serdes_data_o ( jesd204btx_serdes_data_o ),
	.jesd204btx_serdes_data_vld ( jesd204btx_serdes_data_vld ),
	.jesd204btx_sync_b ( jesd204btx_sync_b ),
	.jesd204btx_sysref ( jesd204btx_sysref ),
	.jesd204btx_tframe_data ( jesd204btx_tframe_data ),
	.jesd204btx_tframe_data_rdy ( jesd204btx_tframe_data_rdy ),
	.jesd204btx_tframe_data_vld ( jesd204btx_tframe_data_vld ),
	.paddr ( paddr ),
	.penable ( penable ),
	.prdata ( jesd204btx_prdata ),
	.pready ( jesd204btx_pready ),
	.psel ( jesd204btx_psel ),
	.pwdata ( pwdata ),
	.pwrite ( pwrite ),
	.scan_mode ( scan_mode ),
	.txdata_k ( txdata_k )
 ); 	// u_jesd204btx

dwc_pma u_jesd204btx_dwc_pma (
	.atb_f_p ( JESDTX_ATB_F_P ),
	.atb_s_m ( JESDTX_ATB_S_M ),
	.atb_s_p ( JESDTX_ATB_S_P ),
	.bg_en ( sysc2jesd_pma_bg_en ),
	.bs_acmode ( jesd_pma_bs_acmode ),
	.bs_actest ( jesd_pma_bs_actest ),
	.bs_cdr ( jesd_pma_bs_cdr ),
	.bs_ce ( jesd_pma_bs_ce ),
	.bs_rx_bigswing ( sysc2jesd_pma_bs_rx_bigswing ),
	.bs_rx_init ( jesd_pma_bs_rx_init ),
	.bs_rx_level ( sysc2jesd_pma_bs_rx_level ),
	.bs_sdr ( jesd_pma_bs_sdr ),
	.bs_tdi ( jesd_pma_bs_tdi ),
	.bs_tdo ( jesd_pma_bs_tdo ),
	.bs_tx_lowswing ( sysc2jesd_pma_bs_tx_lowswing ),
	.bs_udr ( jesd_pma_bs_udr ),
	.cr_para_addr ( sysc2xaui2_cr_cap_addr ),
	.cr_para_clk ( jesd204brx_pclk ),
	.cr_para_rd_data ( xaui22sysc_cr_data_out ),
	.cr_para_rd_en ( sysc2xaui2_cr_read ),
	.cr_para_wr_data ( sysc2xaui2_cr_data_in ),
	.cr_para_wr_en ( sysc2xaui2_cr_write ),
	.dtb_out ( jesd2sysc_pma_dtb_out ),
	.gd ( JESDTX_GND ),
	.lane0_rx2tx_par_lb_en ( sysc2jesd_pma_lane0_rx2tx_par_lb_en ),
	.lane0_tx2rx_ser_lb_en ( sysc2jesd_pma_lane0_tx2rx_ser_lb_en ),
	.lane1_rx2tx_par_lb_en ( sysc2jesd_pma_lane1_rx2tx_par_lb_en ),
	.lane1_tx2rx_ser_lb_en ( sysc2jesd_pma_lane1_tx2rx_ser_lb_en ),
	.lane2_rx2tx_par_lb_en ( sysc2jesd_pma_lane2_rx2tx_par_lb_en ),
	.lane2_tx2rx_ser_lb_en ( sysc2jesd_pma_lane2_tx2rx_ser_lb_en ),
	.lane3_rx2tx_par_lb_en ( sysc2jesd_pma_lane3_rx2tx_par_lb_en ),
	.lane3_tx2rx_ser_lb_en ( sysc2jesd_pma_lane3_tx2rx_ser_lb_en ),
	.mplla_bandwidth ( sysc2jesd_pma_mplla_bandwidth ),
	.mplla_div10_clk_en ( 1'b0 ),
	.mplla_div16p5_clk_en ( 1'b0 ),
	.mplla_div8_clk_en ( 1'b0 ),
	.mplla_div_clk_en ( 1'b0 ),
	.mplla_div_multiplier ( sysc2jesd_pma_mplla_div_multiplier ),
	.mplla_en ( sysc2jesd_pma_mplla_en ),
	.mplla_fracn_ctrl ( sysc2jesd_pma_mplla_fracn_ctrl ),
	.mplla_multiplier ( sysc2jesd_pma_mplla_multiplier ),
	.mplla_ssc_clk_sel ( sysc2jesd_pma_mplla_ssc_clk_sel ),
	.mplla_ssc_en ( sysc2jesd_pma_mplla_ssc_en ),
	.mplla_ssc_range ( sysc2jesd_pma_mplla_ssc_range ),
	.mplla_state ( jesd2sysc_pma_mplla_state ),
	.mpllb_bandwidth ( sysc2jesd_pma_mpllb_bandwidth ),
	.mpllb_div10_clk_en ( 1'b0 ),
	.mpllb_div8_clk_en ( 1'b0 ),
	.mpllb_div_multiplier ( sysc2jesd_pma_mpllb_div_multiplier ),
	.mpllb_en ( sysc2jesd_pma_mpllb_en ),
	.mpllb_fracn_ctrl ( sysc2jesd_pma_mpllb_fracn_ctrl ),
	.mpllb_multiplier ( sysc2jesd_pma_mpllb_multiplier ),
	.mpllb_ssc_clk_sel ( sysc2jesd_pma_mpllb_ssc_clk_sel ),
	.mpllb_ssc_en ( sysc2jesd_pma_mpllb_ssc_en ),
	.mpllb_ssc_range ( sysc2jesd_pma_mpllb_ssc_range ),
	.mpllb_state ( jesd2sysc_pma_mpllb_state ),
	.phy_reset ( jesd204btx_reset ),
	.ref_alt_clk_m ( inv_jesd204brx_clk ),
	.ref_alt_clk_p ( jesd204brx_clk ),
	.ref_clk_div2_en ( sysc2jesd_pma_ref_clk_div2_en ),
	.ref_clk_en ( sysc2jesd_pma_ref_clk_en ),
	.ref_clk_mplla_div2_en ( sysc2jesd_pma_ref_clk_mplla_div2_en ),
	.ref_clk_mpllb_div2_en ( sysc2jesd_pma_ref_clk_mpllb_div2_en ),
	.ref_pad_clk_m ( JESDTX_REF_CLK_M ),
	.ref_pad_clk_p ( JESDTX_REF_CLK_P ),
	.ref_range ( sysc2jesd_pma_ref_range ),
	.ref_repeat_clk_en ( 1'b0 ),
	.ref_use_pad ( sysc2jesdtx_ref_use_pad ),
	.res_ack_in ( jesd_pma_res_req_out ),
	.res_req_in ( 1'b0 ),
	.res_req_out ( jesd_pma_res_req_out ),
	.resref_f ( JESDTX_RESREF_F ),
	.resref_s ( JESDTX_RESREF_S ),
	.rtune_ack ( jesd2sysc_rtune_ack ),
	.rtune_req ( sysc2jesd_rtune_req ),
	.rx0_adapt_afe_en ( 1'b0 ),
	.rx0_adapt_dfe_en ( 1'b0 ),
	.rx0_align_en ( 1'b0 ),
	.rx0_cdr_ssc_en ( 1'b0 ),
	.rx0_cdr_track_en ( 1'b0 ),
	.rx0_cdr_vco_lowfreq ( 1'b0 ),
	.rx0_clk_shift ( 1'b0 ),
	.rx0_data_en ( 1'b0 ),
	.rx0_disable ( 1'b0 ),
	.rx0_div16p5_clk_en ( 1'b0 ),
	.rx0_eq_att_lvl ( 3'b000 ),
	.rx0_eq_ctle_boost ( 5'h0 ),
	.rx0_eq_ctle_pole ( 3'b000 ),
	.rx0_eq_dfe_tap1 ( 8'h0 ),
	.rx0_eq_dfe_tap2 ( 7'h0 ),
	.rx0_eq_dfe_tap3 ( 7'h0 ),
	.rx0_eq_dfe_tap4 ( 7'h0 ),
	.rx0_eq_dfe_tap5 ( 7'h0 ),
	.rx0_eq_vga1_gain ( 4'h0 ),
	.rx0_eq_vga2_gain ( 4'h0 ),
	.rx0_invert ( 1'b0 ),
	.rx0_los_lfps_en ( 1'b0 ),
	.rx0_los_threshold ( 3'b000 ),
	.rx0_lpd ( 1'b0 ),
	.rx0_pstate ( 2'b00 ),
	.rx0_rate ( 2'b00 ),
	.rx0_ref_ld_val ( 6'h0 ),
	.rx0_req ( 1'b0 ),
	.rx0_reset ( 1'b1 ),
	.rx0_term_acdc ( 1'b0 ),
	.rx0_term_en ( 1'b0 ),
	.rx0_vco_ld_val ( 13'h0 ),
	.rx0_width ( 2'b00 ),
	.rx1_adapt_afe_en ( 1'b0 ),
	.rx1_adapt_dfe_en ( 1'b0 ),
	.rx1_align_en ( 1'b0 ),
	.rx1_cdr_ssc_en ( 1'b0 ),
	.rx1_cdr_track_en ( 1'b0 ),
	.rx1_cdr_vco_lowfreq ( 1'b0 ),
	.rx1_clk_shift ( 1'b0 ),
	.rx1_data_en ( 1'b0 ),
	.rx1_disable ( 1'b0 ),
	.rx1_div16p5_clk_en ( 1'b0 ),
	.rx1_eq_att_lvl ( 3'b000 ),
	.rx1_eq_ctle_boost ( 5'h0 ),
	.rx1_eq_ctle_pole ( 3'b000 ),
	.rx1_eq_dfe_tap1 ( 8'h0 ),
	.rx1_eq_dfe_tap2 ( 7'h0 ),
	.rx1_eq_dfe_tap3 ( 7'h0 ),
	.rx1_eq_dfe_tap4 ( 7'h0 ),
	.rx1_eq_dfe_tap5 ( 7'h0 ),
	.rx1_eq_vga1_gain ( 4'h0 ),
	.rx1_eq_vga2_gain ( 4'h0 ),
	.rx1_invert ( 1'b0 ),
	.rx1_los_lfps_en ( 1'b0 ),
	.rx1_los_threshold ( 3'b000 ),
	.rx1_lpd ( 1'b0 ),
	.rx1_pstate ( 2'b00 ),
	.rx1_rate ( 2'b00 ),
	.rx1_ref_ld_val ( 6'h0 ),
	.rx1_req ( 1'b0 ),
	.rx1_reset ( 1'b1 ),
	.rx1_term_acdc ( 1'b0 ),
	.rx1_term_en ( 1'b0 ),
	.rx1_vco_ld_val ( 13'h0 ),
	.rx1_width ( 2'b00 ),
	.rx2_adapt_afe_en ( 1'b0 ),
	.rx2_adapt_dfe_en ( 1'b0 ),
	.rx2_align_en ( 1'b0 ),
	.rx2_cdr_ssc_en ( 1'b0 ),
	.rx2_cdr_track_en ( 1'b0 ),
	.rx2_cdr_vco_lowfreq ( 1'b0 ),
	.rx2_clk_shift ( 1'b0 ),
	.rx2_data_en ( 1'b0 ),
	.rx2_disable ( 1'b0 ),
	.rx2_div16p5_clk_en ( 1'b0 ),
	.rx2_eq_att_lvl ( 3'b000 ),
	.rx2_eq_ctle_boost ( 5'h0 ),
	.rx2_eq_ctle_pole ( 3'b000 ),
	.rx2_eq_dfe_tap1 ( 8'h0 ),
	.rx2_eq_dfe_tap2 ( 7'h0 ),
	.rx2_eq_dfe_tap3 ( 7'h0 ),
	.rx2_eq_dfe_tap4 ( 7'h0 ),
	.rx2_eq_dfe_tap5 ( 7'h0 ),
	.rx2_eq_vga1_gain ( 4'h0 ),
	.rx2_eq_vga2_gain ( 4'h0 ),
	.rx2_invert ( 1'b0 ),
	.rx2_los_lfps_en ( 1'b0 ),
	.rx2_los_threshold ( 3'b000 ),
	.rx2_lpd ( 1'b0 ),
	.rx2_pstate ( 2'b00 ),
	.rx2_rate ( 2'b00 ),
	.rx2_ref_ld_val ( 6'h0 ),
	.rx2_req ( 1'b0 ),
	.rx2_reset ( 1'b1 ),
	.rx2_term_acdc ( 1'b0 ),
	.rx2_term_en ( 1'b0 ),
	.rx2_vco_ld_val ( 13'h0 ),
	.rx2_width ( 2'b00 ),
	.rx3_adapt_afe_en ( 1'b0 ),
	.rx3_adapt_dfe_en ( 1'b0 ),
	.rx3_align_en ( 1'b0 ),
	.rx3_cdr_ssc_en ( 1'b0 ),
	.rx3_cdr_track_en ( 1'b0 ),
	.rx3_cdr_vco_lowfreq ( 1'b0 ),
	.rx3_clk_shift ( 1'b0 ),
	.rx3_data_en ( 1'b0 ),
	.rx3_disable ( 1'b0 ),
	.rx3_div16p5_clk_en ( 1'b0 ),
	.rx3_eq_att_lvl ( 3'b000 ),
	.rx3_eq_ctle_boost ( 5'h0 ),
	.rx3_eq_ctle_pole ( 3'b000 ),
	.rx3_eq_dfe_tap1 ( 8'h0 ),
	.rx3_eq_dfe_tap2 ( 7'h0 ),
	.rx3_eq_dfe_tap3 ( 7'h0 ),
	.rx3_eq_dfe_tap4 ( 7'h0 ),
	.rx3_eq_dfe_tap5 ( 7'h0 ),
	.rx3_eq_vga1_gain ( 4'h0 ),
	.rx3_eq_vga2_gain ( 4'h0 ),
	.rx3_invert ( 1'b0 ),
	.rx3_los_lfps_en ( 1'b0 ),
	.rx3_los_threshold ( 3'b000 ),
	.rx3_lpd ( 1'b0 ),
	.rx3_pstate ( 2'b00 ),
	.rx3_rate ( 2'b00 ),
	.rx3_ref_ld_val ( 6'h0 ),
	.rx3_req ( 1'b0 ),
	.rx3_reset ( 1'b1 ),
	.rx3_term_acdc ( 1'b0 ),
	.rx3_term_en ( 1'b0 ),
	.rx3_vco_ld_val ( 13'h0 ),
	.rx3_width ( 2'b00 ),
	.rx_vref_ctrl ( 5'h0 ),
	.scan_cr_para_in ( jesdtxphy_scan_cr_para_in ),
	.scan_cr_para_out ( jesdtxphy_scan_cr_para_out ),
	.scan_mode ( jesdtxphy_scan_sel ),
	.scan_mplla_div16p5_clk ( jesdtxphy_scan_mplla_div16p5_clk ),
	.scan_mplla_div16p5_in ( jesdtxphy_scan_mplla_div16p5_in ),
	.scan_mplla_div16p5_out ( jesdtxphy_scan_mplla_div16p5_out ),
	.scan_mplla_div33_clk ( jesdtxphy_scan_mplla_div33_clk ),
	.scan_mplla_div66_clk ( jesdtxphy_scan_mplla_div66_clk ),
	.scan_mplla_div_clk ( jesdtxphy_scan_mplla_div_clk ),
	.scan_mplla_div_in ( jesdtxphy_scan_mplla_div_in ),
	.scan_mplla_div_out ( jesdtxphy_scan_mplla_div_out ),
	.scan_mplla_dword_clk ( jesdtxphy_scan_mplla_dword_clk ),
	.scan_mplla_dword_in ( jesdtxphy_scan_mplla_dword_in ),
	.scan_mplla_dword_out ( jesdtxphy_scan_mplla_dword_out ),
	.scan_mplla_fb_clk ( jesdtxphy_scan_mplla_fb_clk ),
	.scan_mplla_fb_in ( jesdtxphy_scan_mplla_fb_in ),
	.scan_mplla_fb_out ( jesdtxphy_scan_mplla_fb_out ),
	.scan_mplla_oword_clk ( jesdtxphy_scan_mplla_oword_clk ),
	.scan_mplla_qword_clk ( jesdtxphy_scan_mplla_qword_clk ),
	.scan_mplla_qword_in ( jesdtxphy_scan_mplla_qword_in ),
	.scan_mplla_qword_out ( jesdtxphy_scan_mplla_qword_out ),
	.scan_mplla_ref_clk ( jesdtxphy_scan_mplla_ref_clk ),
	.scan_mplla_ref_in ( jesdtxphy_scan_mplla_ref_in ),
	.scan_mplla_ref_out ( jesdtxphy_scan_mplla_ref_out ),
	.scan_mplla_ssc_clk ( jesdtxphy_scan_mplla_ssc_clk ),
	.scan_mplla_ssc_in ( jesdtxphy_scan_mplla_ssc_in ),
	.scan_mplla_ssc_out ( jesdtxphy_scan_mplla_ssc_out ),
	.scan_mplla_word_clk ( jesdtxphy_scan_mplla_word_clk ),
	.scan_mplla_word_in ( jesdtxphy_scan_mplla_word_in ),
	.scan_mplla_word_out ( jesdtxphy_scan_mplla_word_out ),
	.scan_mpllb_div_clk ( jesdtxphy_scan_mpllb_div_clk ),
	.scan_mpllb_div_in ( jesdtxphy_scan_mpllb_div_in ),
	.scan_mpllb_div_out ( jesdtxphy_scan_mpllb_div_out ),
	.scan_mpllb_dword_clk ( jesdtxphy_scan_mpllb_dword_clk ),
	.scan_mpllb_dword_in ( jesdtxphy_scan_mpllb_dword_in ),
	.scan_mpllb_dword_out ( jesdtxphy_scan_mpllb_dword_out ),
	.scan_mpllb_fb_clk ( jesdtxphy_scan_mpllb_fb_clk ),
	.scan_mpllb_fb_in ( jesdtxphy_scan_mpllb_fb_in ),
	.scan_mpllb_fb_out ( jesdtxphy_scan_mpllb_fb_out ),
	.scan_mpllb_oword_clk ( jesdtxphy_scan_mpllb_oword_clk ),
	.scan_mpllb_qword_clk ( jesdtxphy_scan_mpllb_qword_clk ),
	.scan_mpllb_qword_in ( jesdtxphy_scan_mpllb_qword_in ),
	.scan_mpllb_qword_out ( jesdtxphy_scan_mpllb_qword_out ),
	.scan_mpllb_ref_clk ( jesdtxphy_scan_mpllb_ref_clk ),
	.scan_mpllb_ref_in ( jesdtxphy_scan_mpllb_ref_in ),
	.scan_mpllb_ref_out ( jesdtxphy_scan_mpllb_ref_out ),
	.scan_mpllb_ssc_clk ( jesdtxphy_scan_mpllb_ssc_clk ),
	.scan_mpllb_ssc_in ( jesdtxphy_scan_mpllb_ssc_in ),
	.scan_mpllb_ssc_out ( jesdtxphy_scan_mpllb_ssc_out ),
	.scan_mpllb_word_clk ( jesdtxphy_scan_mpllb_word_clk ),
	.scan_mpllb_word_in ( jesdtxphy_scan_mpllb_word_in ),
	.scan_mpllb_word_out ( jesdtxphy_scan_mpllb_word_out ),
	.scan_ref_clk ( jesdtxphy_scan_ref_clk ),
	.scan_ref_dig_clk ( jesdtxphy_scan_ref_dig_clk ),
	.scan_ref_dig_in ( jesdtxphy_scan_ref_dig_in ),
	.scan_ref_dig_out ( jesdtxphy_scan_ref_dig_out ),
	.scan_ref_in ( jesdtxphy_scan_ref_in ),
	.scan_ref_out ( jesdtxphy_scan_ref_out ),
	.scan_ref_range_clk ( jesdtxphy_scan_ref_range_clk ),
	.scan_ref_range_in ( jesdtxphy_scan_ref_range_in ),
	.scan_ref_range_out ( jesdtxphy_scan_ref_range_out ),
	.scan_rx0_adpt_clk ( jesdtxphy_scan_rx0_adpt_clk ),
	.scan_rx0_adpt_in ( jesdtxphy_scan_rx0_adpt_in ),
	.scan_rx0_adpt_out ( jesdtxphy_scan_rx0_adpt_out ),
	.scan_rx0_asic_clk ( jesdtxphy_scan_rx0_asic_clk ),
	.scan_rx0_asic_in ( jesdtxphy_scan_rx0_asic_in ),
	.scan_rx0_asic_out ( jesdtxphy_scan_rx0_asic_out ),
	.scan_rx0_div16p5_clk ( jesdtxphy_scan_rx0_div16p5_clk ),
	.scan_rx0_div16p5_in ( jesdtxphy_scan_rx0_div16p5_in ),
	.scan_rx0_div16p5_out ( jesdtxphy_scan_rx0_div16p5_out ),
	.scan_rx0_dpll_clk ( jesdtxphy_scan_rx0_dpll_clk ),
	.scan_rx0_dpll_in ( jesdtxphy_scan_rx0_dpll_in ),
	.scan_rx0_dpll_out ( jesdtxphy_scan_rx0_dpll_out ),
	.scan_rx0_dword_clk ( jesdtxphy_scan_rx0_dword_clk ),
	.scan_rx0_dword_in ( jesdtxphy_scan_rx0_dword_in ),
	.scan_rx0_dword_out ( jesdtxphy_scan_rx0_dword_out ),
	.scan_rx0_scope_clk ( jesdtxphy_scan_rx0_scope_clk ),
	.scan_rx0_scope_in ( jesdtxphy_scan_rx0_scope_in ),
	.scan_rx0_scope_out ( jesdtxphy_scan_rx0_scope_out ),
	.scan_rx0_stat_clk ( jesdtxphy_scan_rx0_stat_clk ),
	.scan_rx0_stat_in ( jesdtxphy_scan_rx0_stat_in ),
	.scan_rx0_stat_out ( jesdtxphy_scan_rx0_stat_out ),
	.scan_rx0_word_clk ( jesdtxphy_scan_rx0_word_clk ),
	.scan_rx0_word_in ( jesdtxphy_scan_rx0_word_in ),
	.scan_rx0_word_out ( jesdtxphy_scan_rx0_word_out ),
	.scan_rx1_adpt_clk ( jesdtxphy_scan_rx1_adpt_clk ),
	.scan_rx1_adpt_in ( jesdtxphy_scan_rx1_adpt_in ),
	.scan_rx1_adpt_out ( jesdtxphy_scan_rx1_adpt_out ),
	.scan_rx1_asic_clk ( jesdtxphy_scan_rx1_asic_clk ),
	.scan_rx1_asic_in ( jesdtxphy_scan_rx1_asic_in ),
	.scan_rx1_asic_out ( jesdtxphy_scan_rx1_asic_out ),
	.scan_rx1_div16p5_clk ( jesdtxphy_scan_rx1_div16p5_clk ),
	.scan_rx1_div16p5_in ( jesdtxphy_scan_rx1_div16p5_in ),
	.scan_rx1_div16p5_out ( jesdtxphy_scan_rx1_div16p5_out ),
	.scan_rx1_dpll_clk ( jesdtxphy_scan_rx1_dpll_clk ),
	.scan_rx1_dpll_in ( jesdtxphy_scan_rx1_dpll_in ),
	.scan_rx1_dpll_out ( jesdtxphy_scan_rx1_dpll_out ),
	.scan_rx1_dword_clk ( jesdtxphy_scan_rx1_dword_clk ),
	.scan_rx1_dword_in ( jesdtxphy_scan_rx1_dword_in ),
	.scan_rx1_dword_out ( jesdtxphy_scan_rx1_dword_out ),
	.scan_rx1_scope_clk ( jesdtxphy_scan_rx1_scope_clk ),
	.scan_rx1_scope_in ( jesdtxphy_scan_rx1_scope_in ),
	.scan_rx1_scope_out ( jesdtxphy_scan_rx1_scope_out ),
	.scan_rx1_stat_clk ( jesdtxphy_scan_rx1_stat_clk ),
	.scan_rx1_stat_in ( jesdtxphy_scan_rx1_stat_in ),
	.scan_rx1_stat_out ( jesdtxphy_scan_rx1_stat_out ),
	.scan_rx1_word_clk ( jesdtxphy_scan_rx1_word_clk ),
	.scan_rx1_word_in ( jesdtxphy_scan_rx1_word_in ),
	.scan_rx1_word_out ( jesdtxphy_scan_rx1_word_out ),
	.scan_rx2_adpt_clk ( jesdtxphy_scan_rx2_adpt_clk ),
	.scan_rx2_adpt_in ( jesdtxphy_scan_rx2_adpt_in ),
	.scan_rx2_adpt_out ( jesdtxphy_scan_rx2_adpt_out ),
	.scan_rx2_asic_clk ( jesdtxphy_scan_rx2_asic_clk ),
	.scan_rx2_asic_in ( jesdtxphy_scan_rx2_asic_in ),
	.scan_rx2_asic_out ( jesdtxphy_scan_rx2_asic_out ),
	.scan_rx2_div16p5_clk ( jesdtxphy_scan_rx2_div16p5_clk ),
	.scan_rx2_div16p5_in ( jesdtxphy_scan_rx2_div16p5_in ),
	.scan_rx2_div16p5_out ( jesdtxphy_scan_rx2_div16p5_out ),
	.scan_rx2_dpll_clk ( jesdtxphy_scan_rx2_dpll_clk ),
	.scan_rx2_dpll_in ( jesdtxphy_scan_rx2_dpll_in ),
	.scan_rx2_dpll_out ( jesdtxphy_scan_rx2_dpll_out ),
	.scan_rx2_dword_clk ( jesdtxphy_scan_rx2_dword_clk ),
	.scan_rx2_dword_in ( jesdtxphy_scan_rx2_dword_in ),
	.scan_rx2_dword_out ( jesdtxphy_scan_rx2_dword_out ),
	.scan_rx2_scope_clk ( jesdtxphy_scan_rx2_scope_clk ),
	.scan_rx2_scope_in ( jesdtxphy_scan_rx2_scope_in ),
	.scan_rx2_scope_out ( jesdtxphy_scan_rx2_scope_out ),
	.scan_rx2_stat_clk ( jesdtxphy_scan_rx2_stat_clk ),
	.scan_rx2_stat_in ( jesdtxphy_scan_rx2_stat_in ),
	.scan_rx2_stat_out ( jesdtxphy_scan_rx2_stat_out ),
	.scan_rx2_word_clk ( jesdtxphy_scan_rx2_word_clk ),
	.scan_rx2_word_in ( jesdtxphy_scan_rx2_word_in ),
	.scan_rx2_word_out ( jesdtxphy_scan_rx2_word_out ),
	.scan_rx3_adpt_clk ( jesdtxphy_scan_rx3_adpt_clk ),
	.scan_rx3_adpt_in ( jesdtxphy_scan_rx3_adpt_in ),
	.scan_rx3_adpt_out ( jesdtxphy_scan_rx3_adpt_out ),
	.scan_rx3_asic_clk ( jesdtxphy_scan_rx3_asic_clk ),
	.scan_rx3_asic_in ( jesdtxphy_scan_rx3_asic_in ),
	.scan_rx3_asic_out ( jesdtxphy_scan_rx3_asic_out ),
	.scan_rx3_div16p5_clk ( jesdtxphy_scan_rx3_div16p5_clk ),
	.scan_rx3_div16p5_in ( jesdtxphy_scan_rx3_div16p5_in ),
	.scan_rx3_div16p5_out ( jesdtxphy_scan_rx3_div16p5_out ),
	.scan_rx3_dpll_clk ( jesdtxphy_scan_rx3_dpll_clk ),
	.scan_rx3_dpll_in ( jesdtxphy_scan_rx3_dpll_in ),
	.scan_rx3_dpll_out ( jesdtxphy_scan_rx3_dpll_out ),
	.scan_rx3_dword_clk ( jesdtxphy_scan_rx3_dword_clk ),
	.scan_rx3_dword_in ( jesdtxphy_scan_rx3_dword_in ),
	.scan_rx3_dword_out ( jesdtxphy_scan_rx3_dword_out ),
	.scan_rx3_scope_clk ( jesdtxphy_scan_rx3_scope_clk ),
	.scan_rx3_scope_in ( jesdtxphy_scan_rx3_scope_in ),
	.scan_rx3_scope_out ( jesdtxphy_scan_rx3_scope_out ),
	.scan_rx3_stat_clk ( jesdtxphy_scan_rx3_stat_clk ),
	.scan_rx3_stat_in ( jesdtxphy_scan_rx3_stat_in ),
	.scan_rx3_stat_out ( jesdtxphy_scan_rx3_stat_out ),
	.scan_rx3_word_clk ( jesdtxphy_scan_rx3_word_clk ),
	.scan_rx3_word_in ( jesdtxphy_scan_rx3_word_in ),
	.scan_rx3_word_out ( jesdtxphy_scan_rx3_word_out ),
	.scan_set_rst ( jesdtxphy_scan_set_rst ),
	.scan_shift ( jesdtxphy_scan_shift ),
	.scan_shift_cg ( jesdtxphy_scan_shift ),
	.scan_tx0_ana_dword_clk ( jesdtxphy_scan_tx0_ana_dword_clk ),
	.scan_tx0_ana_dword_in ( jesdtxphy_scan_tx0_ana_dword_in ),
	.scan_tx0_ana_dword_out ( jesdtxphy_scan_tx0_ana_dword_out ),
	.scan_tx0_ana_word_clk ( jesdtxphy_scan_tx0_ana_word_clk ),
	.scan_tx0_ana_word_in ( jesdtxphy_scan_tx0_ana_word_in ),
	.scan_tx0_ana_word_out ( jesdtxphy_scan_tx0_ana_word_out ),
	.scan_tx0_asic_dword_clk ( jesdtxphy_scan_tx0_asic_dword_clk ),
	.scan_tx0_asic_dword_in ( jesdtxphy_scan_tx0_asic_dword_in ),
	.scan_tx0_asic_dword_out ( jesdtxphy_scan_tx0_asic_dword_out ),
	.scan_tx0_in ( jesdtxphy_scan_tx0_in ),
	.scan_tx0_out ( jesdtxphy_scan_tx0_out ),
	.scan_tx1_ana_dword_clk ( jesdtxphy_scan_tx1_ana_dword_clk ),
	.scan_tx1_ana_dword_in ( jesdtxphy_scan_tx1_ana_dword_in ),
	.scan_tx1_ana_dword_out ( jesdtxphy_scan_tx1_ana_dword_out ),
	.scan_tx1_ana_word_clk ( jesdtxphy_scan_tx1_ana_word_clk ),
	.scan_tx1_ana_word_in ( jesdtxphy_scan_tx1_ana_word_in ),
	.scan_tx1_ana_word_out ( jesdtxphy_scan_tx1_ana_word_out ),
	.scan_tx1_asic_dword_clk ( jesdtxphy_scan_tx1_asic_dword_clk ),
	.scan_tx1_asic_dword_in ( jesdtxphy_scan_tx1_asic_dword_in ),
	.scan_tx1_asic_dword_out ( jesdtxphy_scan_tx1_asic_dword_out ),
	.scan_tx1_in ( jesdtxphy_scan_tx1_in ),
	.scan_tx1_out ( jesdtxphy_scan_tx1_out ),
	.scan_tx2_ana_dword_clk ( jesdtxphy_scan_tx2_ana_dword_clk ),
	.scan_tx2_ana_dword_in ( jesdtxphy_scan_tx2_ana_dword_in ),
	.scan_tx2_ana_dword_out ( jesdtxphy_scan_tx2_ana_dword_out ),
	.scan_tx2_ana_word_clk ( jesdtxphy_scan_tx2_ana_word_clk ),
	.scan_tx2_ana_word_in ( jesdtxphy_scan_tx2_ana_word_in ),
	.scan_tx2_ana_word_out ( jesdtxphy_scan_tx2_ana_word_out ),
	.scan_tx2_asic_dword_clk ( jesdtxphy_scan_tx2_asic_dword_clk ),
	.scan_tx2_asic_dword_in ( jesdtxphy_scan_tx2_asic_dword_in ),
	.scan_tx2_asic_dword_out ( jesdtxphy_scan_tx2_asic_dword_out ),
	.scan_tx2_in ( jesdtxphy_scan_tx2_in ),
	.scan_tx2_out ( jesdtxphy_scan_tx2_out ),
	.scan_tx3_ana_dword_clk ( jesdtxphy_scan_tx3_ana_dword_clk ),
	.scan_tx3_ana_dword_in ( jesdtxphy_scan_tx3_ana_dword_in ),
	.scan_tx3_ana_dword_out ( jesdtxphy_scan_tx3_ana_dword_out ),
	.scan_tx3_ana_word_clk ( jesdtxphy_scan_tx3_ana_word_clk ),
	.scan_tx3_ana_word_in ( jesdtxphy_scan_tx3_ana_word_in ),
	.scan_tx3_ana_word_out ( jesdtxphy_scan_tx3_ana_word_out ),
	.scan_tx3_asic_dword_clk ( jesdtxphy_scan_tx3_asic_dword_clk ),
	.scan_tx3_asic_dword_in ( jesdtxphy_scan_tx3_asic_dword_in ),
	.scan_tx3_asic_dword_out ( jesdtxphy_scan_tx3_asic_dword_out ),
	.scan_tx3_in ( jesdtxphy_scan_tx3_in ),
	.scan_tx3_out ( jesdtxphy_scan_tx3_out ),
	.test_burnin ( sysc2jesd_pma_test_burnin ),
	.test_powerdown ( sysc2jesd_pma_test_powerdown ),
	.tx0_ack ( jesd2sysc_pma_tx0_ack ),
	.tx0_beacon_en ( sysc2jesd_pma_tx_beacon_en ),
	.tx0_clk ( jesd204btx_clk ),
	.tx0_clk_rdy ( sysc2jesd_pma_tx_clk_rdy ),
	.tx0_data ( jesd204btx_serdes_data_o[19:0] ),
	.tx0_data_en ( sysc2jesd_pma_tx_data_en ),
	.tx0_detrx_req ( sysc2jesd_pma_tx_detrx_req ),
	.tx0_detrx_result ( jesd2sysc_pma_tx0_detrx_result ),
	.tx0_disable ( sysc2jesd_pma_tx_disable ),
	.tx0_eq_main ( sysc2jesd_pma_tx_eq_main ),
	.tx0_eq_post ( sysc2jesd_pma_tx_eq_post ),
	.tx0_eq_pre ( sysc2jesd_pma_tx_eq_pre ),
	.tx0_iboost_lvl ( sysc2jesd_pma_tx_iboost_lvl ),
	.tx0_invert ( sysc2jesd_pma_tx_invert ),
	.tx0_lpd ( sysc2jesd_pma_tx_lpd ),
	.tx0_m ( JESD_TX0_M ),
	.tx0_mpllb_sel ( sysc2jesd_pma_tx_mpllb_sel ),
	.tx0_p ( JESD_TX0_P ),
	.tx0_pstate ( sysc2jesd_pma_tx_pstate ),
	.tx0_rate ( sysc2jesd_pma_tx_rate ),
	.tx0_req ( sysc2jesd_pma_tx_req ),
	.tx0_reset ( jesd204btx_reset ),
	.tx0_vboost_en ( sysc2jesd_pma_tx_vboost_en ),
	.tx0_width ( sysc2jesd_pma_tx_width ),
	.tx1_ack ( jesd2sysc_pma_tx1_ack ),
	.tx1_beacon_en ( sysc2jesd_pma_tx_beacon_en ),
	.tx1_clk ( jesd204btx_clk ),
	.tx1_clk_rdy ( sysc2jesd_pma_tx_clk_rdy ),
	.tx1_data ( jesd204btx_serdes_data_o[51:32] ),
	.tx1_data_en ( sysc2jesd_pma_tx_data_en ),
	.tx1_detrx_req ( sysc2jesd_pma_tx_detrx_req ),
	.tx1_detrx_result ( jesd2sysc_pma_tx1_detrx_result ),
	.tx1_disable ( sysc2jesd_pma_tx_disable ),
	.tx1_eq_main ( sysc2jesd_pma_tx_eq_main ),
	.tx1_eq_post ( sysc2jesd_pma_tx_eq_post ),
	.tx1_eq_pre ( sysc2jesd_pma_tx_eq_pre ),
	.tx1_iboost_lvl ( sysc2jesd_pma_tx_iboost_lvl ),
	.tx1_invert ( sysc2jesd_pma_tx_invert ),
	.tx1_lpd ( sysc2jesd_pma_tx_lpd ),
	.tx1_m ( JESD_TX1_M ),
	.tx1_mpllb_sel ( sysc2jesd_pma_tx_mpllb_sel ),
	.tx1_p ( JESD_TX1_P ),
	.tx1_pstate ( sysc2jesd_pma_tx_pstate ),
	.tx1_rate ( sysc2jesd_pma_tx_rate ),
	.tx1_req ( sysc2jesd_pma_tx_req ),
	.tx1_reset ( jesd204btx_reset ),
	.tx1_vboost_en ( sysc2jesd_pma_tx_vboost_en ),
	.tx1_width ( sysc2jesd_pma_tx_width ),
	.tx2_ack ( jesd2sysc_pma_tx2_ack ),
	.tx2_beacon_en ( sysc2jesd_pma_tx_beacon_en ),
	.tx2_clk ( jesd204btx_clk ),
	.tx2_clk_rdy ( sysc2jesd_pma_tx_clk_rdy ),
	.tx2_data ( jesd204btx_serdes_data_o[83:64] ),
	.tx2_data_en ( sysc2jesd_pma_tx_data_en ),
	.tx2_detrx_req ( sysc2jesd_pma_tx_detrx_req ),
	.tx2_detrx_result ( jesd2sysc_pma_tx2_detrx_result ),
	.tx2_disable ( sysc2jesd_pma_tx_disable ),
	.tx2_eq_main ( sysc2jesd_pma_tx_eq_main ),
	.tx2_eq_post ( sysc2jesd_pma_tx_eq_post ),
	.tx2_eq_pre ( sysc2jesd_pma_tx_eq_pre ),
	.tx2_iboost_lvl ( sysc2jesd_pma_tx_iboost_lvl ),
	.tx2_invert ( sysc2jesd_pma_tx_invert ),
	.tx2_lpd ( sysc2jesd_pma_tx_lpd ),
	.tx2_m ( JESD_TX2_M ),
	.tx2_mpllb_sel ( sysc2jesd_pma_tx_mpllb_sel ),
	.tx2_p ( JESD_TX2_P ),
	.tx2_pstate ( sysc2jesd_pma_tx_pstate ),
	.tx2_rate ( sysc2jesd_pma_tx_rate ),
	.tx2_req ( sysc2jesd_pma_tx_req ),
	.tx2_reset ( jesd204btx_reset ),
	.tx2_vboost_en ( sysc2jesd_pma_tx_vboost_en ),
	.tx2_width ( sysc2jesd_pma_tx_width ),
	.tx3_ack ( jesd2sysc_pma_tx3_ack ),
	.tx3_beacon_en ( sysc2jesd_pma_tx_beacon_en ),
	.tx3_clk ( jesd204btx_clk ),
	.tx3_clk_rdy ( sysc2jesd_pma_tx_clk_rdy ),
	.tx3_data ( jesd204btx_serdes_data_o[115:96] ),
	.tx3_data_en ( sysc2jesd_pma_tx_data_en ),
	.tx3_detrx_req ( sysc2jesd_pma_tx_detrx_req ),
	.tx3_detrx_result ( jesd2sysc_pma_tx3_detrx_result ),
	.tx3_disable ( sysc2jesd_pma_tx_disable ),
	.tx3_eq_main ( sysc2jesd_pma_tx_eq_main ),
	.tx3_eq_post ( sysc2jesd_pma_tx_eq_post ),
	.tx3_eq_pre ( sysc2jesd_pma_tx_eq_pre ),
	.tx3_iboost_lvl ( sysc2jesd_pma_tx_iboost_lvl ),
	.tx3_invert ( sysc2jesd_pma_tx_invert ),
	.tx3_lpd ( sysc2jesd_pma_tx_lpd ),
	.tx3_m ( JESD_TX3_M ),
	.tx3_mpllb_sel ( sysc2jesd_pma_tx_mpllb_sel ),
	.tx3_p ( JESD_TX3_P ),
	.tx3_pstate ( sysc2jesd_pma_tx_pstate ),
	.tx3_rate ( sysc2jesd_pma_tx_rate ),
	.tx3_req ( sysc2jesd_pma_tx_req ),
	.tx3_reset ( jesd204btx_reset ),
	.tx3_vboost_en ( sysc2jesd_pma_tx_vboost_en ),
	.tx3_width ( sysc2jesd_pma_tx_width ),
	.tx_vboost_lvl ( sysc2jesd_pma_tx_vboost_lvl ),
	.vp ( JESDTX_VP ),
	.vpdig ( JESDTX_VPDIG ),
	.vph ( JESDTX_VPH ),
	.vptx0 ( JESDTX_VPTX0 ),
	.vptx1 ( JESDTX_VPTX1 ),
	.vptx2 ( JESDTX_VPTX2 ),
	.vptx3 ( JESDTX_VPTX3 ),
	.vsscore_0 ( JESDTX_VSSCORE_0 ),
	.vsscore_1 ( JESDTX_VSSCORE_1 ),
	.vsscore_2 ( JESDTX_VSSCORE_2 )
 ); 	// u_jesd204btx_dwc_pma

dwc_pma u_jesd204brx0_dwc_pma (
	.atb_f_p ( JESDRX_ATB_F_P ),
	.atb_s_m ( JESDRX_ATB_S_M ),
	.atb_s_p ( JESDRX_ATB_S_P ),
	.bg_en ( sysc2jesdrx0_pma_bg_en ),
	.bs_acmode ( jesdrx0_pma_bs_acmode ),
	.bs_actest ( jesdrx0_pma_bs_actest ),
	.bs_cdr ( jesdrx0_pma_bs_cdr ),
	.bs_ce ( jesdrx0_pma_bs_ce ),
	.bs_rx_bigswing ( sysc2jesdrx0_pma_bs_rx_bigswing ),
	.bs_rx_init ( jesdrx0_pma_bs_rx_init ),
	.bs_rx_level ( sysc2jesdrx0_pma_bs_rx_level ),
	.bs_sdr ( jesdrx0_pma_bs_sdr ),
	.bs_tdi ( jesdrx0_pma_bs_tdi ),
	.bs_tdo ( jesdrx0_pma_bs_tdo ),
	.bs_tx_lowswing ( sysc2jesdrx0_pma_bs_tx_lowswing ),
	.bs_udr ( jesdrx0_pma_bs_udr ),
	.cr_para_addr ( sysc2xaui3_cr_cap_addr ),
	.cr_para_clk ( jesd204brx_pclk ),
	.cr_para_rd_data ( xaui32sysc_cr_data_out ),
	.cr_para_rd_en ( sysc2xaui3_cr_read ),
	.cr_para_wr_data ( sysc2xaui3_cr_data_in ),
	.cr_para_wr_en ( sysc2xaui3_cr_write ),
	.dtb_out ( jesdrx02sysc_pma_dtb_out ),
	.gd ( JESDRX_GND ),
	.lane0_rx2tx_par_lb_en ( sysc2jesdrx0_pma_lane0_rx2tx_par_lb_en ),
	.lane0_tx2rx_ser_lb_en ( sysc2jesdrx0_pma_lane0_tx2rx_ser_lb_en ),
	.lane1_rx2tx_par_lb_en ( sysc2jesdrx0_pma_lane1_rx2tx_par_lb_en ),
	.lane1_tx2rx_ser_lb_en ( sysc2jesdrx0_pma_lane1_tx2rx_ser_lb_en ),
	.lane2_rx2tx_par_lb_en ( sysc2jesdrx0_pma_lane2_rx2tx_par_lb_en ),
	.lane2_tx2rx_ser_lb_en ( sysc2jesdrx0_pma_lane2_tx2rx_ser_lb_en ),
	.lane3_rx2tx_par_lb_en ( sysc2jesdrx0_pma_lane3_rx2tx_par_lb_en ),
	.lane3_tx2rx_ser_lb_en ( sysc2jesdrx0_pma_lane3_tx2rx_ser_lb_en ),
	.mplla_bandwidth ( sysc2jesdrx0_pma_mplla_bandwidth ),
	.mplla_div10_clk_en ( 1'b0 ),
	.mplla_div16p5_clk_en ( 1'b0 ),
	.mplla_div8_clk_en ( 1'b0 ),
	.mplla_div_clk_en ( 1'b0 ),
	.mplla_div_multiplier ( sysc2jesdrx0_pma_mplla_div_multiplier ),
	.mplla_en ( sysc2jesdrx0_pma_mplla_en ),
	.mplla_fracn_ctrl ( sysc2jesdrx0_pma_mplla_fracn_ctrl ),
	.mplla_multiplier ( sysc2jesdrx0_pma_mplla_multiplier ),
	.mplla_ssc_clk_sel ( sysc2jesdrx0_pma_mplla_ssc_clk_sel ),
	.mplla_ssc_en ( sysc2jesdrx0_pma_mplla_ssc_en ),
	.mplla_ssc_range ( sysc2jesdrx0_pma_mplla_ssc_range ),
	.mplla_state ( jesdrx02sysc_pma_mplla_state ),
	.mpllb_bandwidth ( sysc2jesdrx0_pma_mpllb_bandwidth ),
	.mpllb_div10_clk_en ( 1'b0 ),
	.mpllb_div8_clk_en ( 1'b0 ),
	.mpllb_div_multiplier ( sysc2jesdrx0_pma_mpllb_div_multiplier ),
	.mpllb_en ( sysc2jesdrx0_pma_mpllb_en ),
	.mpllb_fracn_ctrl ( sysc2jesdrx0_pma_mpllb_fracn_ctrl ),
	.mpllb_multiplier ( sysc2jesdrx0_pma_mpllb_multiplier ),
	.mpllb_ssc_clk_sel ( sysc2jesdrx0_pma_mpllb_ssc_clk_sel ),
	.mpllb_ssc_en ( sysc2jesdrx0_pma_mpllb_ssc_en ),
	.mpllb_ssc_range ( sysc2jesdrx0_pma_mpllb_ssc_range ),
	.mpllb_state ( jesdrx02sysc_pma_mpllb_state ),
	.phy_reset ( jesd204brx_reset ),
	.ref_alt_clk_m ( inv_jesd204brx_clk ),
	.ref_alt_clk_p ( jesd204brx_clk ),
	.ref_clk_div2_en ( sysc2jesdrx0_pma_ref_clk_div2_en ),
	.ref_clk_en ( sysc2jesdrx0_pma_ref_clk_en ),
	.ref_clk_mplla_div2_en ( sysc2jesdrx0_pma_ref_clk_mplla_div2_en ),
	.ref_clk_mpllb_div2_en ( sysc2jesdrx0_pma_ref_clk_mpllb_div2_en ),
	.ref_pad_clk_m ( JESDRX_REF_CLK_M ),
	.ref_pad_clk_p ( JESDRX_REF_CLK_P ),
	.ref_range ( sysc2jesdrx0_pma_ref_range ),
	.ref_repeat_clk_en ( 1'b0 ),
	.ref_use_pad ( sysc2jesdrx0_ref_use_pad ),
	.res_ack_in ( jesdrx0_pma_res_req_out ),
	.res_req_in ( 1'b0 ),
	.res_req_out ( jesdrx0_pma_res_req_out ),
	.resref_f ( JESDRX_RESREF_F ),
	.resref_s ( JESDRX_RESREF_S ),
	.rtune_ack ( jesdrx02sysc_rtune_ack ),
	.rtune_req ( sysc2jesd_rtune_req ),
	.rx0_ack ( jesd2sysc_pma_rx0_ack ),
	.rx0_adapt_afe_en ( sysc2jesd_pma_rx_adapt_afe_en ),
	.rx0_adapt_dfe_en ( sysc2jesd_pma_rx_adapt_dfe_en ),
	.rx0_adapt_sts ( jesd2sysc_pma_rx0_adapt_sts ),
	.rx0_align_en ( sysc2jesd_pma_rx_align_en ),
	.rx0_cdr_ssc_en ( sysc2jesd_pma_rx_cdr_ssc_en ),
	.rx0_cdr_track_en ( sysc2jesd_pma_rx_cdr_track_en ),
	.rx0_cdr_vco_lowfreq ( sysc2jesd_pma_rx_cdr_vco_lowfreq ),
	.rx0_clk ( jesd_pma_rx0_clk ),
	.rx0_clk_shift ( sysc2jesd_pma_rx_clk_shift ),
	.rx0_data ( jesd_pma_rx0_data ),
	.rx0_data_en ( sysc2jesd_pma_rx_data_en ),
	.rx0_disable ( sysc2jesd_pma_rx_disable ),
	.rx0_div16p5_clk_en ( 1'b0 ),
	.rx0_eq_att_lvl ( sysc2jesd_pma_rx_eq_att_lvl ),
	.rx0_eq_ctle_boost ( sysc2jesd_pma_rx_eq_ctle_boost ),
	.rx0_eq_ctle_pole ( sysc2jesd_pma_rx_eq_ctle_pole ),
	.rx0_eq_dfe_tap1 ( sysc2jesd_pma_rx_eq_dfe_tap1 ),
	.rx0_eq_dfe_tap2 ( sysc2jesd_pma_rx_eq_dfe_tap2 ),
	.rx0_eq_dfe_tap3 ( sysc2jesd_pma_rx_eq_dfe_tap3 ),
	.rx0_eq_dfe_tap4 ( sysc2jesd_pma_rx_eq_dfe_tap4 ),
	.rx0_eq_dfe_tap5 ( sysc2jesd_pma_rx_eq_dfe_tap5 ),
	.rx0_eq_vga1_gain ( sysc2jesd_pma_rx_eq_vga1_gain ),
	.rx0_eq_vga2_gain ( sysc2jesd_pma_rx_eq_vga2_gain ),
	.rx0_invert ( sysc2jesd_pma_rx_invert ),
	.rx0_los ( jesd2sysc_pma_rx0_los ),
	.rx0_los_lfps_en ( sysc2jesd_pma_rx_los_lfps_en ),
	.rx0_los_threshold ( sysc2jesd_pma_rx_los_threshold ),
	.rx0_lpd ( sysc2jesd_pma_rx_lpd ),
	.rx0_m ( JESD_RX0_M ),
	.rx0_p ( JESD_RX0_P ),
	.rx0_pstate ( sysc2jesd_pma_rx_pstate ),
	.rx0_rate ( sysc2jesd_pma_rx_rate ),
	.rx0_ref_ld_val ( sysc2jesd_pma_rx_ref_ld_val ),
	.rx0_req ( sysc2jesd_pma_rx_req ),
	.rx0_reset ( jesd204brx_reset ),
	.rx0_term_acdc ( sysc2jesd_pma_rx_term_acdc ),
	.rx0_term_en ( sysc2jesd_pma_rx_term_en ),
	.rx0_valid ( jesdrx02sysc_pma_rx0_valid ),
	.rx0_vco_ld_val ( sysc2jesd_pma_rx_vco_ld_val ),
	.rx0_width ( sysc2jesd_pma_rx_width ),
	.rx1_ack ( jesd2sysc_pma_rx1_ack ),
	.rx1_adapt_afe_en ( sysc2jesd_pma_rx_adapt_afe_en ),
	.rx1_adapt_dfe_en ( sysc2jesd_pma_rx_adapt_dfe_en ),
	.rx1_adapt_sts ( jesd2sysc_pma_rx1_adapt_sts ),
	.rx1_align_en ( sysc2jesd_pma_rx_align_en ),
	.rx1_cdr_ssc_en ( sysc2jesd_pma_rx_cdr_ssc_en ),
	.rx1_cdr_track_en ( sysc2jesd_pma_rx_cdr_track_en ),
	.rx1_cdr_vco_lowfreq ( sysc2jesd_pma_rx_cdr_vco_lowfreq ),
	.rx1_clk ( jesd_pma_rx1_clk ),
	.rx1_clk_shift ( sysc2jesd_pma_rx_clk_shift ),
	.rx1_data ( jesd_pma_rx1_data ),
	.rx1_data_en ( sysc2jesd_pma_rx_data_en ),
	.rx1_disable ( sysc2jesd_pma_rx_disable ),
	.rx1_div16p5_clk_en ( 1'b0 ),
	.rx1_eq_att_lvl ( sysc2jesd_pma_rx_eq_att_lvl ),
	.rx1_eq_ctle_boost ( sysc2jesd_pma_rx_eq_ctle_boost ),
	.rx1_eq_ctle_pole ( sysc2jesd_pma_rx_eq_ctle_pole ),
	.rx1_eq_dfe_tap1 ( sysc2jesd_pma_rx_eq_dfe_tap1 ),
	.rx1_eq_dfe_tap2 ( sysc2jesd_pma_rx_eq_dfe_tap2 ),
	.rx1_eq_dfe_tap3 ( sysc2jesd_pma_rx_eq_dfe_tap3 ),
	.rx1_eq_dfe_tap4 ( sysc2jesd_pma_rx_eq_dfe_tap4 ),
	.rx1_eq_dfe_tap5 ( sysc2jesd_pma_rx_eq_dfe_tap5 ),
	.rx1_eq_vga1_gain ( sysc2jesd_pma_rx_eq_vga1_gain ),
	.rx1_eq_vga2_gain ( sysc2jesd_pma_rx_eq_vga2_gain ),
	.rx1_invert ( sysc2jesd_pma_rx_invert ),
	.rx1_los ( jesd2sysc_pma_rx1_los ),
	.rx1_los_lfps_en ( sysc2jesd_pma_rx_los_lfps_en ),
	.rx1_los_threshold ( sysc2jesd_pma_rx_los_threshold ),
	.rx1_lpd ( sysc2jesd_pma_rx_lpd ),
	.rx1_m ( JESD_RX1_M ),
	.rx1_p ( JESD_RX1_P ),
	.rx1_pstate ( sysc2jesd_pma_rx_pstate ),
	.rx1_rate ( sysc2jesd_pma_rx_rate ),
	.rx1_ref_ld_val ( sysc2jesd_pma_rx_ref_ld_val ),
	.rx1_req ( sysc2jesd_pma_rx_req ),
	.rx1_reset ( jesd204brx_reset ),
	.rx1_term_acdc ( sysc2jesd_pma_rx_term_acdc ),
	.rx1_term_en ( sysc2jesd_pma_rx_term_en ),
	.rx1_valid ( jesdrx02sysc_pma_rx1_valid ),
	.rx1_vco_ld_val ( sysc2jesd_pma_rx_vco_ld_val ),
	.rx1_width ( sysc2jesd_pma_rx_width ),
	.rx2_ack ( jesd2sysc_pma_rx2_ack ),
	.rx2_adapt_afe_en ( sysc2jesd_pma_rx_adapt_afe_en ),
	.rx2_adapt_dfe_en ( sysc2jesd_pma_rx_adapt_dfe_en ),
	.rx2_adapt_sts ( jesd2sysc_pma_rx2_adapt_sts ),
	.rx2_align_en ( sysc2jesd_pma_rx_align_en ),
	.rx2_cdr_ssc_en ( sysc2jesd_pma_rx_cdr_ssc_en ),
	.rx2_cdr_track_en ( sysc2jesd_pma_rx_cdr_track_en ),
	.rx2_cdr_vco_lowfreq ( sysc2jesd_pma_rx_cdr_vco_lowfreq ),
	.rx2_clk ( jesd_pma_rx2_clk ),
	.rx2_clk_shift ( sysc2jesd_pma_rx_clk_shift ),
	.rx2_data ( jesd_pma_rx2_data ),
	.rx2_data_en ( sysc2jesd_pma_rx_data_en ),
	.rx2_disable ( sysc2jesd_pma_rx_disable ),
	.rx2_div16p5_clk_en ( 1'b0 ),
	.rx2_eq_att_lvl ( sysc2jesd_pma_rx_eq_att_lvl ),
	.rx2_eq_ctle_boost ( sysc2jesd_pma_rx_eq_ctle_boost ),
	.rx2_eq_ctle_pole ( sysc2jesd_pma_rx_eq_ctle_pole ),
	.rx2_eq_dfe_tap1 ( sysc2jesd_pma_rx_eq_dfe_tap1 ),
	.rx2_eq_dfe_tap2 ( sysc2jesd_pma_rx_eq_dfe_tap2 ),
	.rx2_eq_dfe_tap3 ( sysc2jesd_pma_rx_eq_dfe_tap3 ),
	.rx2_eq_dfe_tap4 ( sysc2jesd_pma_rx_eq_dfe_tap4 ),
	.rx2_eq_dfe_tap5 ( sysc2jesd_pma_rx_eq_dfe_tap5 ),
	.rx2_eq_vga1_gain ( sysc2jesd_pma_rx_eq_vga1_gain ),
	.rx2_eq_vga2_gain ( sysc2jesd_pma_rx_eq_vga2_gain ),
	.rx2_invert ( sysc2jesd_pma_rx_invert ),
	.rx2_los ( jesd2sysc_pma_rx2_los ),
	.rx2_los_lfps_en ( sysc2jesd_pma_rx_los_lfps_en ),
	.rx2_los_threshold ( sysc2jesd_pma_rx_los_threshold ),
	.rx2_lpd ( sysc2jesd_pma_rx_lpd ),
	.rx2_m ( JESD_RX2_M ),
	.rx2_p ( JESD_RX2_P ),
	.rx2_pstate ( sysc2jesd_pma_rx_pstate ),
	.rx2_rate ( sysc2jesd_pma_rx_rate ),
	.rx2_ref_ld_val ( sysc2jesd_pma_rx_ref_ld_val ),
	.rx2_req ( sysc2jesd_pma_rx_req ),
	.rx2_reset ( jesd204brx_reset ),
	.rx2_term_acdc ( sysc2jesd_pma_rx_term_acdc ),
	.rx2_term_en ( sysc2jesd_pma_rx_term_en ),
	.rx2_valid ( jesdrx02sysc_pma_rx2_valid ),
	.rx2_vco_ld_val ( sysc2jesd_pma_rx_vco_ld_val ),
	.rx2_width ( sysc2jesd_pma_rx_width ),
	.rx3_ack ( jesd2sysc_pma_rx3_ack ),
	.rx3_adapt_afe_en ( sysc2jesd_pma_rx_adapt_afe_en ),
	.rx3_adapt_dfe_en ( sysc2jesd_pma_rx_adapt_dfe_en ),
	.rx3_adapt_sts ( jesd2sysc_pma_rx3_adapt_sts ),
	.rx3_align_en ( sysc2jesd_pma_rx_align_en ),
	.rx3_cdr_ssc_en ( sysc2jesd_pma_rx_cdr_ssc_en ),
	.rx3_cdr_track_en ( sysc2jesd_pma_rx_cdr_track_en ),
	.rx3_cdr_vco_lowfreq ( sysc2jesd_pma_rx_cdr_vco_lowfreq ),
	.rx3_clk ( jesd_pma_rx3_clk ),
	.rx3_clk_shift ( sysc2jesd_pma_rx_clk_shift ),
	.rx3_data ( jesd_pma_rx3_data ),
	.rx3_data_en ( sysc2jesd_pma_rx_data_en ),
	.rx3_disable ( sysc2jesd_pma_rx_disable ),
	.rx3_div16p5_clk_en ( 1'b0 ),
	.rx3_eq_att_lvl ( sysc2jesd_pma_rx_eq_att_lvl ),
	.rx3_eq_ctle_boost ( sysc2jesd_pma_rx_eq_ctle_boost ),
	.rx3_eq_ctle_pole ( sysc2jesd_pma_rx_eq_ctle_pole ),
	.rx3_eq_dfe_tap1 ( sysc2jesd_pma_rx_eq_dfe_tap1 ),
	.rx3_eq_dfe_tap2 ( sysc2jesd_pma_rx_eq_dfe_tap2 ),
	.rx3_eq_dfe_tap3 ( sysc2jesd_pma_rx_eq_dfe_tap3 ),
	.rx3_eq_dfe_tap4 ( sysc2jesd_pma_rx_eq_dfe_tap4 ),
	.rx3_eq_dfe_tap5 ( sysc2jesd_pma_rx_eq_dfe_tap5 ),
	.rx3_eq_vga1_gain ( sysc2jesd_pma_rx_eq_vga1_gain ),
	.rx3_eq_vga2_gain ( sysc2jesd_pma_rx_eq_vga2_gain ),
	.rx3_invert ( sysc2jesd_pma_rx_invert ),
	.rx3_los ( jesd2sysc_pma_rx3_los ),
	.rx3_los_lfps_en ( sysc2jesd_pma_rx_los_lfps_en ),
	.rx3_los_threshold ( sysc2jesd_pma_rx_los_threshold ),
	.rx3_lpd ( sysc2jesd_pma_rx_lpd ),
	.rx3_m ( JESD_RX3_M ),
	.rx3_p ( JESD_RX3_P ),
	.rx3_pstate ( sysc2jesd_pma_rx_pstate ),
	.rx3_rate ( sysc2jesd_pma_rx_rate ),
	.rx3_ref_ld_val ( sysc2jesd_pma_rx_ref_ld_val ),
	.rx3_req ( sysc2jesd_pma_rx_req ),
	.rx3_reset ( jesd204brx_reset ),
	.rx3_term_acdc ( sysc2jesd_pma_rx_term_acdc ),
	.rx3_term_en ( sysc2jesd_pma_rx_term_en ),
	.rx3_valid ( jesdrx02sysc_pma_rx3_valid ),
	.rx3_vco_ld_val ( sysc2jesd_pma_rx_vco_ld_val ),
	.rx3_width ( sysc2jesd_pma_rx_width ),
	.rx_vref_ctrl ( sysc2jesd_pma_rx_vref_ctrl ),
	.scan_cr_para_in ( jesdrxphy_scan_cr_para_in ),
	.scan_cr_para_out ( jesdrxphy_scan_cr_para_out ),
	.scan_mode ( jesdrxphy_scan_sel ),
	.scan_mplla_div16p5_clk ( jesdrxphy_scan_mplla_div16p5_clk ),
	.scan_mplla_div16p5_in ( jesdrxphy_scan_mplla_div16p5_in ),
	.scan_mplla_div16p5_out ( jesdrxphy_scan_mplla_div16p5_out ),
	.scan_mplla_div33_clk ( jesdrxphy_scan_mplla_div33_clk ),
	.scan_mplla_div66_clk ( jesdrxphy_scan_mplla_div66_clk ),
	.scan_mplla_div_clk ( jesdrxphy_scan_mplla_div_clk ),
	.scan_mplla_div_in ( jesdrxphy_scan_mplla_div_in ),
	.scan_mplla_div_out ( jesdrxphy_scan_mplla_div_out ),
	.scan_mplla_dword_clk ( jesdrxphy_scan_mplla_dword_clk ),
	.scan_mplla_dword_in ( jesdrxphy_scan_mplla_dword_in ),
	.scan_mplla_dword_out ( jesdrxphy_scan_mplla_dword_out ),
	.scan_mplla_fb_clk ( jesdrxphy_scan_mplla_fb_clk ),
	.scan_mplla_fb_in ( jesdrxphy_scan_mplla_fb_in ),
	.scan_mplla_fb_out ( jesdrxphy_scan_mplla_fb_out ),
	.scan_mplla_oword_clk ( jesdrxphy_scan_mplla_oword_clk ),
	.scan_mplla_qword_clk ( jesdrxphy_scan_mplla_qword_clk ),
	.scan_mplla_qword_in ( jesdrxphy_scan_mplla_qword_in ),
	.scan_mplla_qword_out ( jesdrxphy_scan_mplla_qword_out ),
	.scan_mplla_ref_clk ( jesdrxphy_scan_mplla_ref_clk ),
	.scan_mplla_ref_in ( jesdrxphy_scan_mplla_ref_in ),
	.scan_mplla_ref_out ( jesdrxphy_scan_mplla_ref_out ),
	.scan_mplla_ssc_clk ( jesdrxphy_scan_mplla_ssc_clk ),
	.scan_mplla_ssc_in ( jesdrxphy_scan_mplla_ssc_in ),
	.scan_mplla_ssc_out ( jesdrxphy_scan_mplla_ssc_out ),
	.scan_mplla_word_clk ( jesdrxphy_scan_mplla_word_clk ),
	.scan_mplla_word_in ( jesdrxphy_scan_mplla_word_in ),
	.scan_mplla_word_out ( jesdrxphy_scan_mplla_word_out ),
	.scan_mpllb_div_clk ( jesdrxphy_scan_mpllb_div_clk ),
	.scan_mpllb_div_in ( jesdrxphy_scan_mpllb_div_in ),
	.scan_mpllb_div_out ( jesdrxphy_scan_mpllb_div_out ),
	.scan_mpllb_dword_clk ( jesdrxphy_scan_mpllb_dword_clk ),
	.scan_mpllb_dword_in ( jesdrxphy_scan_mpllb_dword_in ),
	.scan_mpllb_dword_out ( jesdrxphy_scan_mpllb_dword_out ),
	.scan_mpllb_fb_clk ( jesdrxphy_scan_mpllb_fb_clk ),
	.scan_mpllb_fb_in ( jesdrxphy_scan_mpllb_fb_in ),
	.scan_mpllb_fb_out ( jesdrxphy_scan_mpllb_fb_out ),
	.scan_mpllb_oword_clk ( jesdrxphy_scan_mpllb_oword_clk ),
	.scan_mpllb_qword_clk ( jesdrxphy_scan_mpllb_qword_clk ),
	.scan_mpllb_qword_in ( jesdrxphy_scan_mpllb_qword_in ),
	.scan_mpllb_qword_out ( jesdrxphy_scan_mpllb_qword_out ),
	.scan_mpllb_ref_clk ( jesdrxphy_scan_mpllb_ref_clk ),
	.scan_mpllb_ref_in ( jesdrxphy_scan_mpllb_ref_in ),
	.scan_mpllb_ref_out ( jesdrxphy_scan_mpllb_ref_out ),
	.scan_mpllb_ssc_clk ( jesdrxphy_scan_mpllb_ssc_clk ),
	.scan_mpllb_ssc_in ( jesdrxphy_scan_mpllb_ssc_in ),
	.scan_mpllb_ssc_out ( jesdrxphy_scan_mpllb_ssc_out ),
	.scan_mpllb_word_clk ( jesdrxphy_scan_mpllb_word_clk ),
	.scan_mpllb_word_in ( jesdrxphy_scan_mpllb_word_in ),
	.scan_mpllb_word_out ( jesdrxphy_scan_mpllb_word_out ),
	.scan_ref_clk ( jesdrxphy_scan_ref_clk ),
	.scan_ref_dig_clk ( jesdrxphy_scan_ref_dig_clk ),
	.scan_ref_dig_in ( jesdrxphy_scan_ref_dig_in ),
	.scan_ref_dig_out ( jesdrxphy_scan_ref_dig_out ),
	.scan_ref_in ( jesdrxphy_scan_ref_in ),
	.scan_ref_out ( jesdrxphy_scan_ref_out ),
	.scan_ref_range_clk ( jesdrxphy_scan_ref_range_clk ),
	.scan_ref_range_in ( jesdrxphy_scan_ref_range_in ),
	.scan_ref_range_out ( jesdrxphy_scan_ref_range_out ),
	.scan_rx0_adpt_clk ( jesdrxphy_scan_rx0_adpt_clk ),
	.scan_rx0_adpt_in ( jesdrxphy_scan_rx0_adpt_in ),
	.scan_rx0_adpt_out ( jesdrxphy_scan_rx0_adpt_out ),
	.scan_rx0_asic_clk ( jesdrxphy_scan_rx0_asic_clk ),
	.scan_rx0_asic_in ( jesdrxphy_scan_rx0_asic_in ),
	.scan_rx0_asic_out ( jesdrxphy_scan_rx0_asic_out ),
	.scan_rx0_div16p5_clk ( jesdrxphy_scan_rx0_div16p5_clk ),
	.scan_rx0_div16p5_in ( jesdrxphy_scan_rx0_div16p5_in ),
	.scan_rx0_div16p5_out ( jesdrxphy_scan_rx0_div16p5_out ),
	.scan_rx0_dpll_clk ( jesdrxphy_scan_rx0_dpll_clk ),
	.scan_rx0_dpll_in ( jesdrxphy_scan_rx0_dpll_in ),
	.scan_rx0_dpll_out ( jesdrxphy_scan_rx0_dpll_out ),
	.scan_rx0_dword_clk ( jesdrxphy_scan_rx0_dword_clk ),
	.scan_rx0_dword_in ( jesdrxphy_scan_rx0_dword_in ),
	.scan_rx0_dword_out ( jesdrxphy_scan_rx0_dword_out ),
	.scan_rx0_scope_clk ( jesdrxphy_scan_rx0_scope_clk ),
	.scan_rx0_scope_in ( jesdrxphy_scan_rx0_scope_in ),
	.scan_rx0_scope_out ( jesdrxphy_scan_rx0_scope_out ),
	.scan_rx0_stat_clk ( jesdrxphy_scan_rx0_stat_clk ),
	.scan_rx0_stat_in ( jesdrxphy_scan_rx0_stat_in ),
	.scan_rx0_stat_out ( jesdrxphy_scan_rx0_stat_out ),
	.scan_rx0_word_clk ( jesdrxphy_scan_rx0_word_clk ),
	.scan_rx0_word_in ( jesdrxphy_scan_rx0_word_in ),
	.scan_rx0_word_out ( jesdrxphy_scan_rx0_word_out ),
	.scan_rx1_adpt_clk ( jesdrxphy_scan_rx1_adpt_clk ),
	.scan_rx1_adpt_in ( jesdrxphy_scan_rx1_adpt_in ),
	.scan_rx1_adpt_out ( jesdrxphy_scan_rx1_adpt_out ),
	.scan_rx1_asic_clk ( jesdrxphy_scan_rx1_asic_clk ),
	.scan_rx1_asic_in ( jesdrxphy_scan_rx1_asic_in ),
	.scan_rx1_asic_out ( jesdrxphy_scan_rx1_asic_out ),
	.scan_rx1_div16p5_clk ( jesdrxphy_scan_rx1_div16p5_clk ),
	.scan_rx1_div16p5_in ( jesdrxphy_scan_rx1_div16p5_in ),
	.scan_rx1_div16p5_out ( jesdrxphy_scan_rx1_div16p5_out ),
	.scan_rx1_dpll_clk ( jesdrxphy_scan_rx1_dpll_clk ),
	.scan_rx1_dpll_in ( jesdrxphy_scan_rx1_dpll_in ),
	.scan_rx1_dpll_out ( jesdrxphy_scan_rx1_dpll_out ),
	.scan_rx1_dword_clk ( jesdrxphy_scan_rx1_dword_clk ),
	.scan_rx1_dword_in ( jesdrxphy_scan_rx1_dword_in ),
	.scan_rx1_dword_out ( jesdrxphy_scan_rx1_dword_out ),
	.scan_rx1_scope_clk ( jesdrxphy_scan_rx1_scope_clk ),
	.scan_rx1_scope_in ( jesdrxphy_scan_rx1_scope_in ),
	.scan_rx1_scope_out ( jesdrxphy_scan_rx1_scope_out ),
	.scan_rx1_stat_clk ( jesdrxphy_scan_rx1_stat_clk ),
	.scan_rx1_stat_in ( jesdrxphy_scan_rx1_stat_in ),
	.scan_rx1_stat_out ( jesdrxphy_scan_rx1_stat_out ),
	.scan_rx1_word_clk ( jesdrxphy_scan_rx1_word_clk ),
	.scan_rx1_word_in ( jesdrxphy_scan_rx1_word_in ),
	.scan_rx1_word_out ( jesdrxphy_scan_rx1_word_out ),
	.scan_rx2_adpt_clk ( jesdrxphy_scan_rx2_adpt_clk ),
	.scan_rx2_adpt_in ( jesdrxphy_scan_rx2_adpt_in ),
	.scan_rx2_adpt_out ( jesdrxphy_scan_rx2_adpt_out ),
	.scan_rx2_asic_clk ( jesdrxphy_scan_rx2_asic_clk ),
	.scan_rx2_asic_in ( jesdrxphy_scan_rx2_asic_in ),
	.scan_rx2_asic_out ( jesdrxphy_scan_rx2_asic_out ),
	.scan_rx2_div16p5_clk ( jesdrxphy_scan_rx2_div16p5_clk ),
	.scan_rx2_div16p5_in ( jesdrxphy_scan_rx2_div16p5_in ),
	.scan_rx2_div16p5_out ( jesdrxphy_scan_rx2_div16p5_out ),
	.scan_rx2_dpll_clk ( jesdrxphy_scan_rx2_dpll_clk ),
	.scan_rx2_dpll_in ( jesdrxphy_scan_rx2_dpll_in ),
	.scan_rx2_dpll_out ( jesdrxphy_scan_rx2_dpll_out ),
	.scan_rx2_dword_clk ( jesdrxphy_scan_rx2_dword_clk ),
	.scan_rx2_dword_in ( jesdrxphy_scan_rx2_dword_in ),
	.scan_rx2_dword_out ( jesdrxphy_scan_rx2_dword_out ),
	.scan_rx2_scope_clk ( jesdrxphy_scan_rx2_scope_clk ),
	.scan_rx2_scope_in ( jesdrxphy_scan_rx2_scope_in ),
	.scan_rx2_scope_out ( jesdrxphy_scan_rx2_scope_out ),
	.scan_rx2_stat_clk ( jesdrxphy_scan_rx2_stat_clk ),
	.scan_rx2_stat_in ( jesdrxphy_scan_rx2_stat_in ),
	.scan_rx2_stat_out ( jesdrxphy_scan_rx2_stat_out ),
	.scan_rx2_word_clk ( jesdrxphy_scan_rx2_word_clk ),
	.scan_rx2_word_in ( jesdrxphy_scan_rx2_word_in ),
	.scan_rx2_word_out ( jesdrxphy_scan_rx2_word_out ),
	.scan_rx3_adpt_clk ( jesdrxphy_scan_rx3_adpt_clk ),
	.scan_rx3_adpt_in ( jesdrxphy_scan_rx3_adpt_in ),
	.scan_rx3_adpt_out ( jesdrxphy_scan_rx3_adpt_out ),
	.scan_rx3_asic_clk ( jesdrxphy_scan_rx3_asic_clk ),
	.scan_rx3_asic_in ( jesdrxphy_scan_rx3_asic_in ),
	.scan_rx3_asic_out ( jesdrxphy_scan_rx3_asic_out ),
	.scan_rx3_div16p5_clk ( jesdrxphy_scan_rx3_div16p5_clk ),
	.scan_rx3_div16p5_in ( jesdrxphy_scan_rx3_div16p5_in ),
	.scan_rx3_div16p5_out ( jesdrxphy_scan_rx3_div16p5_out ),
	.scan_rx3_dpll_clk ( jesdrxphy_scan_rx3_dpll_clk ),
	.scan_rx3_dpll_in ( jesdrxphy_scan_rx3_dpll_in ),
	.scan_rx3_dpll_out ( jesdrxphy_scan_rx3_dpll_out ),
	.scan_rx3_dword_clk ( jesdrxphy_scan_rx3_dword_clk ),
	.scan_rx3_dword_in ( jesdrxphy_scan_rx3_dword_in ),
	.scan_rx3_dword_out ( jesdrxphy_scan_rx3_dword_out ),
	.scan_rx3_scope_clk ( jesdrxphy_scan_rx3_scope_clk ),
	.scan_rx3_scope_in ( jesdrxphy_scan_rx3_scope_in ),
	.scan_rx3_scope_out ( jesdrxphy_scan_rx3_scope_out ),
	.scan_rx3_stat_clk ( jesdrxphy_scan_rx3_stat_clk ),
	.scan_rx3_stat_in ( jesdrxphy_scan_rx3_stat_in ),
	.scan_rx3_stat_out ( jesdrxphy_scan_rx3_stat_out ),
	.scan_rx3_word_clk ( jesdrxphy_scan_rx3_word_clk ),
	.scan_rx3_word_in ( jesdrxphy_scan_rx3_word_in ),
	.scan_rx3_word_out ( jesdrxphy_scan_rx3_word_out ),
	.scan_set_rst ( jesdrxphy_scan_set_rst ),
	.scan_shift ( jesdrxphy_scan_shift ),
	.scan_shift_cg ( jesdrxphy_scan_shift ),
	.scan_tx0_ana_dword_clk ( jesdrxphy_scan_tx0_ana_dword_clk ),
	.scan_tx0_ana_dword_in ( jesdrxphy_scan_tx0_ana_dword_in ),
	.scan_tx0_ana_dword_out ( jesdrxphy_scan_tx0_ana_dword_out ),
	.scan_tx0_ana_word_clk ( jesdrxphy_scan_tx0_ana_word_clk ),
	.scan_tx0_ana_word_in ( jesdrxphy_scan_tx0_ana_word_in ),
	.scan_tx0_ana_word_out ( jesdrxphy_scan_tx0_ana_word_out ),
	.scan_tx0_asic_dword_clk ( jesdrxphy_scan_tx0_asic_dword_clk ),
	.scan_tx0_asic_dword_in ( jesdrxphy_scan_tx0_asic_dword_in ),
	.scan_tx0_asic_dword_out ( jesdrxphy_scan_tx0_asic_dword_out ),
	.scan_tx0_in ( jesdrxphy_scan_tx0_in ),
	.scan_tx0_out ( jesdrxphy_scan_tx0_out ),
	.scan_tx1_ana_dword_clk ( jesdrxphy_scan_tx1_ana_dword_clk ),
	.scan_tx1_ana_dword_in ( jesdrxphy_scan_tx1_ana_dword_in ),
	.scan_tx1_ana_dword_out ( jesdrxphy_scan_tx1_ana_dword_out ),
	.scan_tx1_ana_word_clk ( jesdrxphy_scan_tx1_ana_word_clk ),
	.scan_tx1_ana_word_in ( jesdrxphy_scan_tx1_ana_word_in ),
	.scan_tx1_ana_word_out ( jesdrxphy_scan_tx1_ana_word_out ),
	.scan_tx1_asic_dword_clk ( jesdrxphy_scan_tx1_asic_dword_clk ),
	.scan_tx1_asic_dword_in ( jesdrxphy_scan_tx1_asic_dword_in ),
	.scan_tx1_asic_dword_out ( jesdrxphy_scan_tx1_asic_dword_out ),
	.scan_tx1_in ( jesdrxphy_scan_tx1_in ),
	.scan_tx1_out ( jesdrxphy_scan_tx1_out ),
	.scan_tx2_ana_dword_clk ( jesdrxphy_scan_tx2_ana_dword_clk ),
	.scan_tx2_ana_dword_in ( jesdrxphy_scan_tx2_ana_dword_in ),
	.scan_tx2_ana_dword_out ( jesdrxphy_scan_tx2_ana_dword_out ),
	.scan_tx2_ana_word_clk ( jesdrxphy_scan_tx2_ana_word_clk ),
	.scan_tx2_ana_word_in ( jesdrxphy_scan_tx2_ana_word_in ),
	.scan_tx2_ana_word_out ( jesdrxphy_scan_tx2_ana_word_out ),
	.scan_tx2_asic_dword_clk ( jesdrxphy_scan_tx2_asic_dword_clk ),
	.scan_tx2_asic_dword_in ( jesdrxphy_scan_tx2_asic_dword_in ),
	.scan_tx2_asic_dword_out ( jesdrxphy_scan_tx2_asic_dword_out ),
	.scan_tx2_in ( jesdrxphy_scan_tx2_in ),
	.scan_tx2_out ( jesdrxphy_scan_tx2_out ),
	.scan_tx3_ana_dword_clk ( jesdrxphy_scan_tx3_ana_dword_clk ),
	.scan_tx3_ana_dword_in ( jesdrxphy_scan_tx3_ana_dword_in ),
	.scan_tx3_ana_dword_out ( jesdrxphy_scan_tx3_ana_dword_out ),
	.scan_tx3_ana_word_clk ( jesdrxphy_scan_tx3_ana_word_clk ),
	.scan_tx3_ana_word_in ( jesdrxphy_scan_tx3_ana_word_in ),
	.scan_tx3_ana_word_out ( jesdrxphy_scan_tx3_ana_word_out ),
	.scan_tx3_asic_dword_clk ( jesdrxphy_scan_tx3_asic_dword_clk ),
	.scan_tx3_asic_dword_in ( jesdrxphy_scan_tx3_asic_dword_in ),
	.scan_tx3_asic_dword_out ( jesdrxphy_scan_tx3_asic_dword_out ),
	.scan_tx3_in ( jesdrxphy_scan_tx3_in ),
	.scan_tx3_out ( jesdrxphy_scan_tx3_out ),
	.test_burnin ( sysc2jesdrx0_pma_test_burnin ),
	.test_powerdown ( sysc2jesdrx0_pma_test_powerdown ),
	.tx0_beacon_en ( 1'b0 ),
	.tx0_clk ( 1'b0 ),
	.tx0_clk_rdy ( 1'b0 ),
	.tx0_data ( 20'h0 ),
	.tx0_data_en ( 1'b0 ),
	.tx0_detrx_req ( 1'b0 ),
	.tx0_disable ( 1'b0 ),
	.tx0_eq_main ( 6'h0 ),
	.tx0_eq_post ( 6'h0 ),
	.tx0_eq_pre ( 6'h0 ),
	.tx0_iboost_lvl ( 4'h0 ),
	.tx0_invert ( 1'b0 ),
	.tx0_lpd ( 1'b0 ),
	.tx0_mpllb_sel ( 1'b0 ),
	.tx0_pstate ( 2'b00 ),
	.tx0_rate ( 3'b000 ),
	.tx0_req ( 1'b0 ),
	.tx0_reset ( 1'b1 ),
	.tx0_vboost_en ( 1'b0 ),
	.tx0_width ( 2'b00 ),
	.tx1_beacon_en ( 1'b0 ),
	.tx1_clk ( 1'b0 ),
	.tx1_clk_rdy ( 1'b0 ),
	.tx1_data ( 20'h0 ),
	.tx1_data_en ( 1'b0 ),
	.tx1_detrx_req ( 1'b0 ),
	.tx1_disable ( 1'b0 ),
	.tx1_eq_main ( 6'h0 ),
	.tx1_eq_post ( 6'h0 ),
	.tx1_eq_pre ( 5'h0 ),
	.tx1_iboost_lvl ( 4'h0 ),
	.tx1_invert ( 1'b0 ),
	.tx1_lpd ( 1'b0 ),
	.tx1_mpllb_sel ( 1'b0 ),
	.tx1_pstate ( 2'b00 ),
	.tx1_rate ( 3'b000 ),
	.tx1_req ( 1'b0 ),
	.tx1_reset ( 1'b1 ),
	.tx1_vboost_en ( 1'b0 ),
	.tx1_width ( 1'b0 ),
	.tx2_beacon_en ( 1'b0 ),
	.tx2_clk ( 1'b0 ),
	.tx2_clk_rdy ( 1'b0 ),
	.tx2_data ( 20'h0 ),
	.tx2_data_en ( 1'b0 ),
	.tx2_detrx_req ( 1'b0 ),
	.tx2_disable ( 1'b0 ),
	.tx2_eq_main ( 6'h0 ),
	.tx2_eq_post ( 6'h0 ),
	.tx2_eq_pre ( 6'h0 ),
	.tx2_iboost_lvl ( 4'h0 ),
	.tx2_invert ( 1'b0 ),
	.tx2_lpd ( 1'b0 ),
	.tx2_mpllb_sel ( 1'b0 ),
	.tx2_pstate ( 2'b00 ),
	.tx2_rate ( 3'b000 ),
	.tx2_req ( 1'b0 ),
	.tx2_reset ( 1'b1 ),
	.tx2_vboost_en ( 1'b0 ),
	.tx2_width ( 2'b00 ),
	.tx3_beacon_en ( 1'b0 ),
	.tx3_clk ( 1'b0 ),
	.tx3_clk_rdy ( 1'b0 ),
	.tx3_data ( 20'h0 ),
	.tx3_data_en ( 1'b0 ),
	.tx3_detrx_req ( 1'b0 ),
	.tx3_disable ( 1'b0 ),
	.tx3_eq_main ( 6'h0 ),
	.tx3_eq_post ( 6'h0 ),
	.tx3_eq_pre ( 6'h0 ),
	.tx3_iboost_lvl ( 4'h0 ),
	.tx3_invert ( 1'b0 ),
	.tx3_lpd ( 1'b0 ),
	.tx3_mpllb_sel ( 1'b0 ),
	.tx3_pstate ( 2'b00 ),
	.tx3_rate ( 3'b000 ),
	.tx3_req ( 1'b0 ),
	.tx3_reset ( 1'b1 ),
	.tx3_vboost_en ( 1'b0 ),
	.tx3_width ( 2'b00 ),
	.tx_vboost_lvl ( 3'b000 ),
	.vp ( JESDRX_VP ),
	.vpdig ( JESDRX_VPDIG ),
	.vph ( JESDRX_VPH ),
	.vptx0 ( JESDRX_VPTX0 ),
	.vptx1 ( JESDRX_VPTX1 ),
	.vptx2 ( JESDRX_VPTX2 ),
	.vptx3 ( JESDRX_VPTX3 ),
	.vsscore_0 ( JESDRX_VSSCORE_0 ),
	.vsscore_1 ( JESDRX_VSSCORE_1 ),
	.vsscore_2 ( JESDRX_VSSCORE_2 )
 ); 	// u_jesd204brx0_dwc_pma





endmodule 	// jesd204b


