

// This module takes care of asserting the sync_b signal either in response to request from code group synchronization state machine,deskew logic or 
// the logic detecting and accumulating errors during a multiframe
module jesd_sync_gen
  #(parameter NO_LANES=8,
    parameter MAST_INST=1)
  (
   input [NO_LANES-1:0] active_lane,       // 1 bit per lane . If bit value is 1 that means the lane is part of the JESD204B link
   
   input                ignore_symbol_err, // If 1 do not report symbol_errors to sync_b generation logic
   input                ignore_dskew_err,  // If 1 do not report deskew errors to sync_b generation logic  
   input                ignore_frame_alignment_err, // If 1 do not report frame alignment errors to sync_b generation logic  
   input                ignore_mframe_alignment_err,// If 1 do not report multi frame alignment errors to sync_b generation logic  
   input                fw_sync_req, // clk_cpu domain signal. If 1 indicates firmware initiated sync request. Should be held high until captured_fw_sync_req is asserted.
   input [7:0]          txrx_f_reg, // may need to cut latency of sysref(lh) detection when clk_frame is faster than clk_character
   input [10:0]         mf_len,     // length of multiframe in bytes
   
   input [NO_LANES-1:0] cgs_sync_req, // One bit per lane. If a bit is 1 it means request from code group synchronization state machine to assert sync_b
   input [NO_LANES-1:0] dskew_err, // One bit per lane. If a bit is 1 it means request from deskew module to assert sync_b
   input [NO_LANES-1:0] frame_alignment_err, // One bit per lane. If a bit is 1 it means request from frame align monitor to assert sync_b
   input [NO_LANES-1:0] mframe_alignment_err,// One bit per lane. If a bit is 1 it means request from multi frame align monitor to assert sync_b
   input [NO_LANES-1:0] mframe_symbol_err,// One bit per lane. If a bit is 1 it means request error monitor to assert sync_b
   input [3:0]          min_sync_duration,// Based on the value of F we decide the number of clocks from which sync_b should be asserted
   input [4:0]          num_k, // carries value of k - 1
   input [1:0]          subclass,// carries value of subclass
   // Clocks. Please note that clk_character and clock frame need to have
   // a known relationsship and have co-inciding rising edges at least sometimes.
   // The contraints need to be set up such that there is a maximum delay 
   // of 1/4 clk from clk_character to clk_frame and vice versa
   input                clk_character, //
   input                clk_cpu, // 
   input                rst_clk_character,
   input                sysref, // signal sampled using clk_character
   input                lmfc_div2_i, // In case the instance is configured as slave this signal provides time reference when operating in subclass 2. Ignored if the instance is a master
   output reg           lmfc_div2_o, // In case the instance is configured as master this signal provides time reference when operating in subclass 2.Ignored if the instance is configured as slave
   output reg           sync_b, // Sync signal connected to link partner
   output reg           comb_cgs_sync_req, // combined code group synchronization request in clk_character domain reported to all all lanes.
   output               lmfc_boundary,       // Indicates assertion of sysref signal and reset of core's LMFC
   output reg           mf_is_long,
   output               captured_fw_sync_req // clk_cpu domain signal. Handshake signal to register block confirming reception of firmware initiated sync request
   );

  localparam  SR_START  = 3'b000,
              SR_INPROG = 3'b001,
              SR_DONE   = 3'b010,
              S_ERR_1   = 3'b011,
              S_ERR_2   = 3'b100;
   
   reg       symbol_err;
   reg [2:0] curr_state,next_state;
   reg       next_sync_b;
   reg [5:0] kcnt;
   reg [3:0] min_sync_duration_cnt;

   wire      ld_min_sync_duration_cnt;
   reg       sysref_r0;
   reg       lmfc_r0;
   wire      sysref_toggle;
   reg       lmfc_div2;

   wire             resync_request_p2;
   
   reg [10:0]       mf_cnt;                            // Remaining number of octet in the multiframe
   wire [10:0]      nxt_mf_cnt;                        // Remaining number of octet in the multiframe
   wire             cur_mf_is_long;                   // Current multiframe is a long cycle
   wire             nxt_mf_is_long;                   // Next  multiframe is a long cycle
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

   assign    sysref_toggle =  ~sysref_r0 & sysref;


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
   assign nxt_frm_cnt      = max_frm_cnt ? frm_len[1:0] ? {7'h00, frm_cnt[1:0] - frm_len[1:0]} : 9'h00 : {frm_cnt[8:2] + 7'h01, frm_cnt[1:0]};

   assign     nxt_mf_cnt = (max_mf_cnt && !first_cnt) ? mf_len[1:0] ? {8'h00, cnt_low_in_nxt_mf } : 10'h000 : mf_cnt + 10'h004;

   wire   lmfc_i_event = lmfc_div2 ^ lmfc_r0;

   always @ (posedge clk_character or posedge rst_clk_character) begin
     if (rst_clk_character) begin
       mf_cnt         <= 'h0;
       frm_cnt        <= 'h0;
       first_cnt      <= 1'b0;
       lmfc_div2_o    <= 1'b0;
       frame_boundary <= 1'b0;
     end
     else begin
       frame_boundary <= 1'b0;
       if (sysref_toggle && subclass==2'b01) begin
         // allow a little bit of uncertainty on the sampling of the
         // synchronization signal (in subclass 2)
         mf_cnt        <= 'h0; //(!first_cnt && !max_mf_cnt) ? ( (mf_cnt[1:0] == 2'b0) ? 10'h000 : {8'h00, mf_cnt[1:0]+ mf_len[1:0]} ) : nxt_mf_cnt;
         first_cnt     <= ~first_cnt;
         lmfc_div2_o   <= ~lmfc_div2_o;
         frm_cnt       <= 9'h00;
         frame_boundary <= 1'b1;
       end
       else if (lmfc_i_event && subclass==2'b10 && MAST_INST==0) begin
         // allow a little bit of uncertainty on the sampling of the
         // synchronization signal (in subclass 2)
         mf_cnt[10:2]  <= 'h1;
         first_cnt     <= ~first_cnt;
         lmfc_div2_o   <= ~lmfc_div2_o;
         frm_cnt       <= 9'h00;
         frame_boundary <= 1'b1;
       end
       else begin
         mf_cnt        <= nxt_mf_cnt;
         first_cnt     <= max_mf_cnt;
         lmfc_div2_o   <= lmfc_div2_o ^ (max_mf_cnt && (nxt_mf_cnt[1:0]==2'b00));
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


   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         sysref_r0      <= 1'b1;
         lmfc_r0        <= 1'b0;
         lmfc_div2      <= 1'b0;
      end
      else begin
         sysref_r0      <= sysref;
         lmfc_r0        <= lmfc_div2;
         lmfc_div2      <= lmfc_div2_i;
      end // 
   end
   
        
   always @(posedge clk_character or posedge rst_clk_character) begin
     if (rst_clk_character) 
       kcnt <= 6'h0;
     else if (frame_boundary)
       if ((lmfc_boundary) || kcnt == 0)
          kcnt <= num_k;
       else 
         kcnt <= kcnt - 1'b1;
   end 

 // Counter to ensure sync request is signalled for atleast these many frame clks (5 frame clks + 9 octets)
  always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) 
        min_sync_duration_cnt <= 4'h0;
      else if (frame_boundary)
        if (ld_min_sync_duration_cnt) 
          min_sync_duration_cnt <= min_sync_duration;
        else if (min_sync_duration_cnt > 0)
          min_sync_duration_cnt <= min_sync_duration_cnt - 1'b1;
  end 
   

   // function combine_lane_info(input [NO_LANES-1:0] raw_err, input err_type_mask);
   //    if (err_type_mask == 1'b1)
   //      combine_lane_info = 1'b0;
   //    else
   //      combine_lane_info = |(raw_err & active_lane) ;      
   // endfunction // combine_lane_info

   wire combined_falign_err = ignore_frame_alignment_err ? 1'b0 : |(frame_alignment_err & active_lane);
   wire combined_mfalign_err = ignore_mframe_alignment_err ? 1'b0 : |(mframe_alignment_err & active_lane);
   wire combined_dskew_err = ignore_dskew_err ? 1'b0 : | (dskew_err & active_lane);
   wire combined_cgs_sync_req = |(cgs_sync_req & active_lane);


   wire raw_sync_req = combined_falign_err  || combined_mfalign_err || combined_dskew_err || combined_cgs_sync_req || resync_request_p2;

        

   reg  sync_b_clk_char_r;
   reg  raw_sync_req_r;
   
   //raw_sync_req can be as wide as 1 clk_character . Follwing logic will ensure it is stretched till sync_b is asserted
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
        raw_sync_req_r <= 1'b0;
      end
      else
        if (raw_sync_req)
          raw_sync_req_r <= raw_sync_req;
        else if(sync_b == 1'b0)
          raw_sync_req_r <= 1'b0;
   end
   


   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
        comb_cgs_sync_req <= 1'b1;
        sync_b_clk_char_r <= 1'b0;         
      end
      else begin
        sync_b_clk_char_r <= sync_b;                 
        if (comb_cgs_sync_req == 1'b0)
          comb_cgs_sync_req <= raw_sync_req;
        else 
          comb_cgs_sync_req <= sync_b & ~sync_b_clk_char_r ? 1'b0 : 1'b1;
      end // else: !if(rst_clk_character)      
   end // always @ (posedge clk_character or posedge rst_clk_character)
   


   //mframe_symbol_err can be as wide as 1 clk_character . Follwing logic will ensure it is stretched till sync_b is asserted
   wire combined_mframe_symbol_err = ignore_symbol_err ? 1'b0 : |(mframe_symbol_err & active_lane);   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character)
        symbol_err <= 1'b0;
      else
        symbol_err <= combined_mframe_symbol_err | (symbol_err & sync_b);
   end


   jesd_simple_sync s_req_capture_p2(
                    .src_signal(fw_sync_req),
                    .src_clk(clk_cpu),
                    .dest_clk(clk_character), 
                    .dest_signal(resync_request_p2));

   jesd_simple_sync  #(.REG_IP(0)) 
   s_resp_capture_p2(
                    .src_signal(resync_request_p2),
                    .src_clk(1'b0),
                    .dest_clk(clk_cpu), 
                    .dest_signal(captured_fw_sync_req));


//  `define TIMEOUT 
       reg time_is_over;
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
//  `endif
    
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
  `endif
    */
   // Sync request to be used in state machine (after clock domain conversion)
   wire resync_request_clk_frame = raw_sync_req_r | time_is_over;


   assign ld_min_sync_duration_cnt = (next_state == SR_INPROG) && (curr_state != SR_INPROG);
   
   always @ (*) begin
      next_state =  curr_state;
      next_sync_b = sync_b;      
      case (curr_state)
        SR_INPROG:begin
           if (min_sync_duration_cnt == 0) begin
              if (~resync_request_clk_frame) begin
                 case (subclass)
                   2'b00:begin // Frame boundary
                      next_state = SR_DONE;
                      next_sync_b = 1'b1; 
                   end
                   default:begin
                      if (lmfc_boundary) begin // LMFC boundary
                         next_state = SR_DONE;
                         next_sync_b = 1'b1;
                      end
                   end                   
                 endcase // case endcase
              end // if (~resync_request_clk_frame)
           end // if (min_sync_duration_cnt == 0)
        end // case: SR_INPROG
        SR_DONE:begin
           if (resync_request_clk_frame) begin 
              next_state =  SR_INPROG;
              next_sync_b = 1'b0;
           end
           else if (symbol_err) begin
             if (num_k==0) begin             // Just assert low  for two frames if K=1 (=> F>=17)
               next_state =  S_ERR_1;
               next_sync_b = 1'b0;              
             end
             else if ((num_k == 1) && lmfc_boundary) begin  // For K=2, assert at LMFC (=> F>=9)
               next_state =  S_ERR_1;
               next_sync_b = 1'b0;              
             end
             else if (kcnt <= 2)  begin     // K must be at least 3 to achieve kcnt=2
               if (frm_len<9'h03)          // For F=1, ~SYNC as an error report will be asserted for 4 frame cycles, for F=2 for 2 frame cycles
                 next_state =  SR_DONE;
               else
                 next_state =  S_ERR_1;
               next_sync_b = 1'b0;              
             end
           end
        end // case: SR_DONE
        S_ERR_1:begin
           if (resync_request_clk_frame) begin 
              next_state =  SR_INPROG;
              next_sync_b = 1'b0;
           end
           else next_state =  S_ERR_2;
        end
        S_ERR_2:begin
           if (resync_request_clk_frame) begin 
              next_state =  SR_INPROG;
              next_sync_b = 1'b0;
           end
           else begin
              next_state = SR_DONE;
              next_sync_b = 1'b1;               
           end           
        end
        default:begin //SR_START
           next_sync_b = 1'b0;
           next_state = SR_INPROG;
        end        
      endcase // case (curr_state)
   end // always @ begin
   
 always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         curr_state <= SR_START;
         sync_b <= 1'b0;         
      end
      else if (frame_boundary) begin
        curr_state <= next_state;
        sync_b <= next_sync_b ;
      end
 end
   
endmodule // jesd_sync_gen
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
