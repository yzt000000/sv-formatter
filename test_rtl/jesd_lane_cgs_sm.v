

// This module is instantiated for each individual lane and it processes the received data dword stream.
// Note since  each clk_character feeds 4 octets to the state machine so the state transitions may not have a 
// one to one correspondence with the states described in the spec(the spec assumes one octet processing per clock)
// Refer section 7.1 of JESD204B spec for further details on the requirements 

module jesd_lane_cgs_sm
  (input             clk_character,                  // primary clock
   input             rst_clk_character,              // asynchronous reset
   input [31:0]      rxdata,                         // received data stream dword , first byte on octet 0 and 4th byte on octet 3
   input [03:0]      rxdata_k,                       // received data stream control character qualifier
   input             rxdata_vld,                     // level signal when high indicates receive data stream is active
   input [3:0]       rxdisparity_err,                // one bit per octed of rxdata. Indicates if the symbol decoding encountered a disparity error
   input [3:0]       rxnot_in_table_err,             // one bit per octed of rxdata. Indicates if the symbol decoding encountered a not in table error  
   input             enable_module,                  // control bit from rx csr .
   input             comb_cgs_sync_req,
   output reg        cgs_sync_req                    // When high indicates that the lane has encountered errors on 4 consecutive symbols and thus needs to re-achieve symbol lock
   );
   localparam  CGS_INIT=4'b0001,
               CGS_CHECK=4'b0010,
               CGS_DATA=4'b0100,
               CGS_PRE_INIT=4'b1000;
   reg[3:0] cgs_curr_state, cgs_next_state;

   // used to ensure a single received symbol is counted as valid K or valid and not as both   
   reg [3:0]   count_towards_comma,count_towards_comma_nxt;
   
   
   wire [3:0]  raw_valid_data;  // used to count 4 consecutive K28.5 and /or valid symbols 
   assign raw_valid_data[0] = rxdata_vld & ~rxdisparity_err[0] & ~rxnot_in_table_err[0];
   assign raw_valid_data[1] = rxdata_vld & ~rxdisparity_err[1] & ~rxnot_in_table_err[1];
   assign raw_valid_data[2] = rxdata_vld & ~rxdisparity_err[2] & ~rxnot_in_table_err[2];
   assign raw_valid_data[3] = rxdata_vld & ~rxdisparity_err[3] & ~rxnot_in_table_err[3];

   wire [3:0]  valid_k_28_5;
   assign valid_k_28_5[0] =  raw_valid_data[0] & (rxdata[07:00] == 8'hBC) & rxdata_k[0];
   assign valid_k_28_5[1] =  raw_valid_data[1] & (rxdata[15:08] == 8'hBC) & rxdata_k[1];
   assign valid_k_28_5[2] =  raw_valid_data[2] & (rxdata[23:16] == 8'hBC) & rxdata_k[2];
   assign valid_k_28_5[3] =  raw_valid_data[3] & (rxdata[31:24] == 8'hBC) & rxdata_k[3];   


   // invalid data from portion left over after accounting for K symbols   
   reg [3:0]   count_towards_data,count_towards_data_nxt;
 
   wire [3:0]  invalid_data = count_towards_data & ~raw_valid_data;
   
   


   reg [2:0]   invalid_data_cnt;
   wire [2:0]  any_invalid_data_cnt = invalid_data[3] + invalid_data[2] + invalid_data[1] + invalid_data[0];
   wire [2:0]  invalid_data_cnt_nxt = invalid_data_cnt + any_invalid_data_cnt;

   reg         clr_invalid_data_cnt;
   reg [1:0]   invalid_threshold_nxt ,invalid_threshold;
   reg         cgs_sync_req_nxt;
   // to flush count of invalid octets upto last clk but retain count of invalid octets in current clock                 
   reg         retain_any_invalid_data_cnt;
   

   
   
   always @(*) begin
      count_towards_comma_nxt = count_towards_comma;
      count_towards_data_nxt = count_towards_data;      
      cgs_next_state = cgs_curr_state;                                     
      invalid_threshold_nxt = invalid_threshold;
      cgs_sync_req_nxt = cgs_sync_req;
      retain_any_invalid_data_cnt  = 1'b0;
      clr_invalid_data_cnt = 1'b0;
      
      case (cgs_curr_state)
        CGS_INIT:begin //single or multiple clocks
           cgs_sync_req_nxt = 1'b1;     
           clr_invalid_data_cnt = 1'b1;
           invalid_threshold_nxt = 2;           
           if ((count_towards_comma == (valid_k_28_5 & count_towards_comma))  // check for 4 consecutive K28.5
              & !(invalid_data_cnt_nxt > {1'b0, invalid_threshold}))
             begin             
              count_towards_comma_nxt = 4'h0;
              cgs_next_state = CGS_CHECK;
              cgs_sync_req_nxt = 1'b0; 
              clr_invalid_data_cnt = 1'b0;                          
              count_towards_data_nxt = get_consecutive_marker(raw_valid_data & count_towards_data);
             end // if ((count_towards_comma == (valid_k_28_5 & count_towards_comma))...
           else begin
              count_towards_comma_nxt = get_consecutive_marker(valid_k_28_5);
              count_towards_data_nxt  = ~get_consecutive_marker(valid_k_28_5);
           end // else: !if((count_towards_comma == (valid_k_28_5 & count_towards_comma))...
        end // case: CGS_INIT
        CGS_CHECK:begin
           if (invalid_data_cnt_nxt > {1'b0, invalid_threshold})  begin
              cgs_next_state = CGS_INIT;
              count_towards_comma_nxt = get_consecutive_marker(valid_k_28_5);
              count_towards_data_nxt = ~get_consecutive_marker(valid_k_28_5);
              clr_invalid_data_cnt = 1'b1;
              invalid_threshold_nxt = 2;                                              
           end else if (count_towards_data == (raw_valid_data & count_towards_data)) begin
              cgs_next_state = CGS_DATA;
              retain_any_invalid_data_cnt = 1'b1;
              invalid_threshold_nxt = 3;
              count_towards_data_nxt = 4'hF;           
           end
           else begin
              count_towards_data_nxt =  get_consecutive_marker(raw_valid_data);
           end // else: !if(count_towards_data == (raw_valid_data & count_towards_data))
        end // case: CGS_INIT
        CGS_DATA:begin
           if (invalid_data_cnt_nxt > {1'b0, invalid_threshold}) begin
              cgs_next_state = CGS_INIT; // This arc needs to be added due to processing of 4 symbols pe clock
              count_towards_comma_nxt = get_consecutive_marker(valid_k_28_5);
              count_towards_data_nxt = ~get_consecutive_marker(valid_k_28_5);
              clr_invalid_data_cnt = 1'b1;
              invalid_threshold_nxt = 2;              
           end else if (invalid_data_cnt_nxt > 0) begin
              cgs_next_state = CGS_CHECK;
              invalid_threshold_nxt = 2;                 
           end           
           if (comb_cgs_sync_req)
           begin
              cgs_next_state = CGS_INIT;
              count_towards_comma_nxt = 4'hF;
           end
        end
        default:begin // CGS_PRE_INIT
           count_towards_comma_nxt = 4'hF;
           count_towards_data_nxt = 4'h0;           
           clr_invalid_data_cnt = 1'b1;
           invalid_threshold_nxt = 2;
           cgs_sync_req_nxt = 1'b1;                      
           if (enable_module) begin
              cgs_next_state = CGS_INIT;
           end
        end
      endcase
   end // always @ (*)

   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) 
        invalid_data_cnt <= 3'h0;      
      else if (clr_invalid_data_cnt)
        invalid_data_cnt <= 3'h0;
      else if (retain_any_invalid_data_cnt)
        invalid_data_cnt <= any_invalid_data_cnt;      
      else
        invalid_data_cnt <= invalid_data_cnt_nxt;
   end

   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         cgs_curr_state <= CGS_PRE_INIT;
         invalid_threshold <= 2'h2;
         count_towards_comma <= 4'hF;
         count_towards_data <= 4'h0;
         cgs_sync_req <= 1'b0;         
      end else begin
         cgs_curr_state <= cgs_next_state;
         invalid_threshold <= invalid_threshold_nxt;
         count_towards_comma <= count_towards_comma_nxt;
         count_towards_data <= count_towards_data_nxt;
         cgs_sync_req <= cgs_sync_req_nxt;         
      end
   end

   // Using received valid value generates 4 bit mask to indicate expected valid consecutive value in next clock
   function [3:0] get_consecutive_marker(input [3:0] curr_marker);
      casex (curr_marker)  
        4'b10xx:get_consecutive_marker = 4'b0111;
        4'b110x:get_consecutive_marker = 4'b0011;
        4'b1110:get_consecutive_marker = 4'b0001;
        4'b1111:get_consecutive_marker = 4'b0000;        
        default:get_consecutive_marker = 4'b1111;
      endcase // casex (raw_valid_data & count_towards_data)
   endfunction
   
   
endmodule // jesd_lane_cgs_sm
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
