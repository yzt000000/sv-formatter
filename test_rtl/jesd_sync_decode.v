

// This module takes care of decoding the sync_b signal and generates request to code group synchronization state machine, or 
// the logic detecting and accumulating errors during a multiframe

module jesd_sync_decode #(parameter NO_LANES=8)
  (
  input [4:0]      num_k,                 // Used to align de-assertion of internal request to CGS state machine with multi frame boundary
  input            sync_b,                // Sync signal from link partner
  input [1:0]      txrx_subclass_reg,     // current subclass  operation
  input            clk_character,         // primary clock 
  input            rst_clk_character,     // primary reset
  input            sysref,                // external reference event used in subclass 1 for frame/multiframe alignmemt 
  input [7:0]      txrx_f_reg,            // Length of frame in bytes (less 1)
  input [10:0]     mf_len,                // length of multiframe in bytes
  output           lmfc_boundary,         // Indicates assertion of sysref signal and reset of core's LMFC
  output reg [5:0] frame_clks_sync_lh_to_next_lmfc_boundary, // Status of counters to report any phase discrepancy via CSR. This is used by firmware to compute fields transmitted as part of ILAS
  output reg       captured_sync_lh_ph_info, // When high indicates the information on frame_clks_sync_lh_to_next_lmfc_boundary is valid
  output reg       start_cgs_tx_sync_dec,  // When high indicates Link Synchronisation Request to CGS state machine of active lanes 
  output reg       error_decoded_on_sync   // When high indicates peer link partnert reported receive errors at end of previous multiframe via sync_b signal
);

   
  reg [5:0]        kcnt;
                   
  wire             sync_b_s0;
  reg              sync_b_r0;
  reg              sysref_r0;
  wire             sysref_toggle;
  wire             sync_b_event;

  reg [10:0]       mf_cnt;                            // Remaining number of octet in the multiframe

  wire [10:0]      nxt_mf_cnt;                        // Remaining number of octet in the multiframe
  wire             cur_mf_is_long;                   // Current multiframe is a long cycle
  wire             nxt_mf_is_long;                   // Next  multiframe is a long cycle
  reg              mf_is_long;                       // Multiframe is a long cycle
  reg  [8:0]       mf_len_less_8;                     // Multiframe length minus 8
  reg  [8:0]       mf_len_less_4;                     // Multiframe length minus 4
  reg  [8:0]       frm_len;
  reg  [6:0]       frm_len_less_4;                    // Frame length minus 4
  reg  [6:0]       frm_len_less_8;                    // Frame length minus 8
  reg              max_mf_cnt;                      // Multiframe counter MSBs are all0
  reg              first_cnt;

  reg              max_frm_cnt;                      // Frane counter MSBs are all0
  wire             next_max_frm_cnt;                 // Frane counter MSBs are all0 - next value
  reg [8:0]        frm_cnt;                          // Number of bytes processed in current frame
  reg              frame_boundary;                   // A frame boundary is reached

  reg [2:0]        sync_b_low_count;

  reg [2:0]        min_sync_duration_sync_req;

  reg              time_is_over;
  
  
  jesd_simple_sync  #(.REG_IP(0)) 
  sync_b_retime (
                   .src_signal(sync_b),
                   .src_clk(1'b0),
                   .dest_clk(clk_character), 
                   .dest_signal(sync_b_s0));

  always @(posedge clk_character or posedge rst_clk_character) begin
    if (rst_clk_character) begin
      sync_b_r0                                <= 1'b0;    
      sync_b_low_count                         <= 3'h0;
      start_cgs_tx_sync_dec                    <= 1'b1;
      error_decoded_on_sync                    <= 1'b0; 
      frame_clks_sync_lh_to_next_lmfc_boundary <= 'h0;
      captured_sync_lh_ph_info                 <= 1'b0;         
      min_sync_duration_sync_req               <= 3'b001;
    end
    else
    begin
      sync_b_r0  <= sync_b_s0;
      case (frm_len)
        1:       min_sync_duration_sync_req  <= 3'b000;
        2:       min_sync_duration_sync_req  <= 3'b001;
        3:       min_sync_duration_sync_req  <= 3'b010;
        default: min_sync_duration_sync_req  <= 3'b011;
      endcase

      if (frame_boundary) begin
        if (sync_b == 1'b0) begin
          error_decoded_on_sync <= 1'b0;       
          captured_sync_lh_ph_info <= 1'b0;              
          if (sync_b_low_count == min_sync_duration_sync_req) 
            start_cgs_tx_sync_dec <= 1'b1 ;
          else
            sync_b_low_count      <= sync_b_low_count + 1'b1;
        end
        else begin
          start_cgs_tx_sync_dec <= 1'b0 | time_is_over;
          sync_b_low_count  <= 'h0;
          
          if (start_cgs_tx_sync_dec) begin
            frame_clks_sync_lh_to_next_lmfc_boundary <= kcnt+1;
            captured_sync_lh_ph_info <= 1'b1;
          end
          else if (sync_b_low_count != 'h0)
            error_decoded_on_sync <= 1'b1;

        end
      end
    end
  end

  assign    sysref_toggle =  ~sysref_r0 & sysref;
  assign    sync_b_event  =  ~sync_b_r0 & sync_b_s0;


  wire [1:0] cnt_low_in_nxt_mf = mf_cnt[1:0] + mf_len[1:0];
  assign cur_mf_is_long = {1'b0, mf_cnt[1:0]} + {1'b0, mf_len[1:0]} > 3'b011;
  assign nxt_mf_is_long = ({1'b0, cnt_low_in_nxt_mf} + {1'b0, mf_len[1:0]} > 3'b011) | (mf_len[1:0] == 2'b00);

  always @ (posedge clk_character or posedge rst_clk_character) begin
    if (rst_clk_character) begin
      mf_len_less_4  <= 'h0;
      mf_len_less_8  <= 'h0;
      frm_len        <= 'h0;
      frm_len_less_4 <= 'h0;
      frm_len_less_8 <= 'h0;
      max_mf_cnt     <= 1'b1;
      max_frm_cnt    <= 8'h00;
      mf_is_long     <= 1'b0;
    end
    else begin
      mf_len_less_4  <= mf_len[10:2] - 9'h001;  // Multiframe length minus 4
      mf_len_less_8  <= mf_len[10:2] - 9'h002;  // Multiframe length minus 8
      frm_len        <= txrx_f_reg + 1'b1;
      frm_len_less_4 <= frm_len[8:2] - 7'h01;  // Frame length minus 4
      frm_len_less_8 <= frm_len[8:2] - 7'h02;  // Frame length minus 8
      max_mf_cnt     <= (((mf_cnt[10:2] >= mf_len_less_8) & !cur_mf_is_long ) | (mf_cnt[10:2] == mf_len_less_4)) & ~max_mf_cnt & ~sysref_toggle;
      mf_is_long     <= cur_mf_is_long;
      max_frm_cnt    <= next_max_frm_cnt;
    end
  end

  wire [8:0] nxt_frm_cnt;

   assign next_max_frm_cnt = (((frm_cnt[8:2] >= frm_len_less_4) | ((frm_cnt[8:2] == frm_len_less_8) & ( frm_cnt[1:0] >= frm_len[1:0]))) & ~max_frm_cnt) | ((frm_len_less_4==0) & ( frm_cnt[1:0] >= frm_len[1:0]));
  assign nxt_frm_cnt = max_frm_cnt ? frm_len[1:0] ? {7'h00, frm_cnt[1:0] - frm_len[1:0]} : 9'h00 : {frm_cnt[8:2] + 7'h01, frm_cnt[1:0]};

  assign  nxt_mf_cnt = (max_mf_cnt && !first_cnt) ? mf_len[1:0] ? {8'h00, cnt_low_in_nxt_mf } : 10'h000 : mf_cnt + 10'h004;

  always @ (posedge clk_character or posedge rst_clk_character) begin
    if (rst_clk_character) begin
      mf_cnt         <= 'h0;
      frm_cnt        <= 'h0;
      first_cnt      <= 1'b0;
      frame_boundary <= 1'b0;
    end
    else begin
      frame_boundary <= 1'b0;
      if (sysref_toggle && txrx_subclass_reg==2'b01) begin
        // allow a little bit of uncertainty on the sampling of the
        // synchronization signal (in subclass 2)
        mf_cnt        <= 'h0;
        first_cnt     <= ~first_cnt;
        frm_cnt       <= 9'h0;
        frame_boundary <= 1'b1;
      end
      else if (sync_b_event && txrx_subclass_reg==2'b10) begin
        // allow a little bit of uncertainty on the sampling of the
        // synchronization signal (in subclass 2)
        mf_cnt         <= 'h0;
        frame_boundary <= 1'b1;
        first_cnt      <= ~first_cnt;
        frm_cnt        <= 9'h0;
      end
      else begin
        mf_cnt        <= nxt_mf_cnt;
        first_cnt     <= max_mf_cnt;
        if (txrx_f_reg[7:2]==0) begin     // F <= 4
          frame_boundary <= 1'b1;
          frm_cnt        <= 'h0;
        end
        else begin
          frame_boundary <= next_max_frm_cnt;
          frm_cnt        <= nxt_frm_cnt;
        end
      end
    end
  end

  assign lmfc_boundary = first_cnt;

  `define TIMEOUT 

//  `ifdef    TIMEOUT
    reg [31:0] counter1, counter2;
    
    
    
    always @(posedge clk_character or posedge rst_clk_character)
    begin
      if (rst_clk_character)
      begin
        counter1<=64'h0;
        counter2<=64'h0;
        time_is_over<=1'h0;
      end
      else
      begin
        if (lmfc_boundary)
          counter1<= counter1 +1'h1;
        if (counter1==32'hFFF_FFFF)
        begin
          counter2<= counter2+1'h1;
          counter1<=1'h0;
        end
        if (counter2==31'h3)     
          time_is_over<=1'h1;
        else
          time_is_over<=time_is_over;
      end
    end 
  //`endif
    
/*   `ifndef    TIMEOUT
    always @(posedge clk_character or posedge rst_clk_character)
    begin
      if (rst_clk_character)
      begin
        time_is_over<=1'h0;     
      end
      else 
      begin
        time_is_over<=time_is_over;
      end
    end
  `endif */
  
  always @(posedge clk_character or posedge rst_clk_character) begin
    if (rst_clk_character) begin
      sysref_r0      <= 1'b0;
    end
    else begin
      sysref_r0      <= sysref;
    end // 
  end
  
       
  always @(posedge clk_character or posedge rst_clk_character) begin
    if (rst_clk_character) 
      kcnt <= 6'h0;
    else if (frame_boundary)
      if ((first_cnt) || kcnt == 0)
        kcnt <= num_k;
      else 
        kcnt <= kcnt - 1'b1;
  end 

  
endmodule // jesd_sync_decode
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
