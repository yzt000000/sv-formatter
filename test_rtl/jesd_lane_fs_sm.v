

// This module implements the requirements for Figure 45 & 46 (if txrx_resync_on_comma_disable is 1)  in JESD204B spec.
// It also combines the received errors during a multiframe "N" and passes this information to jesd_sync_gen module so that 
// it can assert sync_b signal (for 2 frame clocks) at end of mutiframe N+1.


module jesd_lane_fs_sm
  (input             clk_character,        // primary clock
   input             rst_clk_character,    // primary reset
   input [31:0]      rxdata,               // received data stream with comma and non comma data characters
   input [03:0]      rxdata_k,             // receive data stream control character qualifier
   input             rxdata_vld,           // when high indicates presence of characters on rxdata
   input [3:0]       rxdisparity_err,      // signal to indicate disparity error was detected during decoding of corersponding character on rxdata 
   input [3:0]       rxnot_in_table_err,   // signal to indicate not in table error was detected during decoding of corresponding character on rxdata 
   input             comb_cgs_sync_req,    // signal to reset the state machine due to loss of sync across all lanes(reported by sync generator module)
   input             cgs_sync_req,         // signal to reset the state machine due to loss of sync for this lane (reported by Code Group Synchronization (CGS) State Machine)
   input             txrx_resync_on_comma_disable, // Run time parameter to decide behavior on reception of comma characters on an established link
   input [10:0]      mframe_length_char,   // Number of characters in a multiframe
   output reg        lane_disparity_err,   // One bit signal by logically oring  rxdisparity_err. Eventaully feeds into interrupt logic 
   output reg        lane_not_in_table_err, // One bit signal by logically oring  rxnot_in_table_err. Eventaully feeds into interrupt logic 

   output reg        mframe_symbol_err, // One bit signal to report errors (disparity/not in table) within a multiframe. This eventually translates to assertion of sync_b for frame clocks
   output reg [31:0] frame_data,   // receive data stream post removal of comma characters, fed to lane deskew logic 
   output reg [03:0] frame_data_k, // control character qualifier for frame_data
   output reg        frame_data_vld // when high indicates presence of characters on frame_data
   );

  localparam FS_INIT=2'b00,FS_CHECK=2'b01,FS_DATA=2'b10;
  reg[1:0] fs_curr_state, fs_next_state;

   // used to count 4 consecutive K28.5 and /or valid symbols.
   //  Note disparity errors are don't care  refer table 15 of JESD204B spec for description of invalid 
   wire [3:0]  raw_valid_data;
   assign raw_valid_data[0] = rxdata_vld & ~rxnot_in_table_err[0];
   assign raw_valid_data[1] = rxdata_vld & ~rxnot_in_table_err[1];
   assign raw_valid_data[2] = rxdata_vld & ~rxnot_in_table_err[2];
   assign raw_valid_data[3] = rxdata_vld & ~rxnot_in_table_err[3];

   wire [3:0]  valid_k_28_5;
   assign valid_k_28_5[0] =  raw_valid_data[0] & (rxdata[07:00] == 8'hBC) & rxdata_k[0] ;
   assign valid_k_28_5[1] =  raw_valid_data[1] & (rxdata[15:08] == 8'hBC) & rxdata_k[1] ;
   assign valid_k_28_5[2] =  raw_valid_data[2] & (rxdata[23:16] == 8'hBC) & rxdata_k[2] ;
   assign valid_k_28_5[3] =  raw_valid_data[3] & (rxdata[31:24] == 8'hBC) & rxdata_k[3] ;


   

   reg [3:0]   check_for_valid_k_28_5_nxt;
   reg [3:0]   check_for_valid_k_28_5;
   reg lock_data_alignment;
   reg [1:0]   data_alignment;   
   reg [31:0]  rxdata_r;
   reg [3:0]   rxdata_k_r;
   reg [3:0]   rxdisparity_err_r;
   reg [3:0]   rxnot_in_table_err_r;
   
   
   always @(*) begin
      casex(valid_k_28_5)
        4'b10xx:check_for_valid_k_28_5_nxt = 4'b1111;
        4'b110x:check_for_valid_k_28_5_nxt = 4'b0111;
        4'b1110:check_for_valid_k_28_5_nxt = 4'b0011;
        4'b1111:check_for_valid_k_28_5_nxt = 4'b0001;
        default:check_for_valid_k_28_5_nxt = 4'b1111; 
      endcase
   end

   wire   lcl_cgs_sync_req = txrx_resync_on_comma_disable ? comb_cgs_sync_req : cgs_sync_req;
   
   always @(*) begin
      fs_next_state = fs_curr_state;              
      lock_data_alignment = 1'b0;                                     
      case (fs_curr_state)
        FS_CHECK:begin
           if (check_for_valid_k_28_5 == (valid_k_28_5 & check_for_valid_k_28_5))
             fs_next_state = FS_INIT;
           else
             fs_next_state = valid_k_28_5[3] ? FS_CHECK : FS_DATA;             
        end // case: FS_CHECK
        FS_DATA:begin
            if (txrx_resync_on_comma_disable) 
              fs_next_state = lcl_cgs_sync_req ? FS_INIT : FS_DATA;
           else
             fs_next_state = valid_k_28_5[3] ? FS_CHECK : comb_cgs_sync_req? FS_INIT : FS_DATA;           
        end
        default:begin// FS_INIT
           if ((~lcl_cgs_sync_req) & (valid_k_28_5 != 4'hF)) begin
              if (txrx_resync_on_comma_disable) fs_next_state = FS_DATA;
              else fs_next_state = valid_k_28_5[3] ? FS_CHECK : FS_DATA;
             lock_data_alignment = 1'b1;              
           end
        end // case: FS_INIT
      endcase
   end // always @ (*)
   
   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) 
        data_alignment <= 2'b00;      
      else if (lock_data_alignment) begin
         data_alignment <= ~valid_k_28_5[0] ? 2'b00 :
                              ~valid_k_28_5[1] ? 2'b01 :
                              ~valid_k_28_5[2] ? 2'b10 :
                              2'b11;
      end
   end

      always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
        fs_curr_state   <=   FS_INIT;
        check_for_valid_k_28_5 <= 4'hF;
      end
      else begin         
         fs_curr_state   <=   fs_next_state;
         check_for_valid_k_28_5 <= check_for_valid_k_28_5_nxt;
      end
   end

   
   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         rxdata_r <= 'h0;
         rxdata_k_r <= 'h0;
         rxdisparity_err_r <= 'h0;
         rxnot_in_table_err_r <= 'h0;
      end
      else begin
         rxdata_r <= rxdata;
         rxdata_k_r <= rxdata_k;
         rxdisparity_err_r <= rxdisparity_err;
         rxnot_in_table_err_r <= rxnot_in_table_err;
      end
   end

   reg [3:0] symbol_err;
   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         frame_data_vld <= 1'b0;
         frame_data <= 32'h0;
         frame_data_k <= 4'h0;
         symbol_err <= 4'h0;
      end else if (lcl_cgs_sync_req) begin
         frame_data_vld <= 1'b0;
         frame_data <= 32'h0;
         frame_data_k <= 4'h0;
         symbol_err <= 4'h0;
      end
      else begin
         frame_data_vld <= (fs_curr_state != FS_INIT);         
        case (data_alignment)
          2'b01:begin
             frame_data <= {rxdata[07:00],rxdata_r[31:08]};
             frame_data_k <= {rxdata_k[0],rxdata_k_r[3:1]};
             symbol_err   <= {rxdisparity_err[0]|rxnot_in_table_err[0],rxdisparity_err_r[3:1]|rxnot_in_table_err_r[3:1]};
        end
          2'b10:begin
             frame_data <= {rxdata[15:00],rxdata_r[31:16]};
             frame_data_k <= {rxdata_k[1:0],rxdata_k_r[3:2]};
             symbol_err   <= {rxdisparity_err[1:0]|rxnot_in_table_err[1:0],rxdisparity_err_r[3:2]|rxnot_in_table_err_r[3:2]};
          end
          2'b11:begin
             frame_data <= {rxdata[23:00],rxdata_r[31:24]};
             frame_data_k <= {rxdata_k[2:0],rxdata_k_r[3]};
             symbol_err   <= {rxdisparity_err[2:0]|rxnot_in_table_err[2:0],rxdisparity_err_r[3]|rxnot_in_table_err_r[3]};
          end
          default:begin 
             frame_data <= rxdata_r;
             frame_data_k <= rxdata_k_r;
             symbol_err   <= rxdisparity_err_r|rxnot_in_table_err_r;           
          end
        endcase // case (data_alignment)
      end // else: !if(cgs_sync_req || comb_cgs_sync_req)
   end // always (@ posedge clk_character or posedge rst_clk_character)
   
   
   

   reg [10:0] char_cnt;
   reg [3:0]  count_err_towards_curr_mf;
   reg        next_mframe_symbol_err,clr_mframe_symbol_err;
   
   wire mframe_symbol_err_comb = ((symbol_err & count_err_towards_curr_mf) != 4'h0) |
                                  (mframe_symbol_err & ~clr_mframe_symbol_err);

   wire next_mframe_symbol_err_comb = ((symbol_err & ~count_err_towards_curr_mf) != 4'h0);


   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character)begin
         char_cnt <= 11'h0;
         clr_mframe_symbol_err <= 1'b0;
         next_mframe_symbol_err <= 1'b0;         
      end
      else if (frame_data_vld) begin   
         if (char_cnt > 11'h3) begin
            char_cnt <= char_cnt - 11'h4;
            next_mframe_symbol_err <= 1'b0;
            clr_mframe_symbol_err <= 1'b0;            
         end
         else begin
           char_cnt <= ({9'h0, char_cnt[1:0]} + mframe_length_char) - 11'h4  ;
           next_mframe_symbol_err <= next_mframe_symbol_err_comb;
           clr_mframe_symbol_err <= 1'b1;
         end
      end // if (frame_data_vld)
      else begin
         char_cnt    <= mframe_length_char;
         clr_mframe_symbol_err <= 1'b0;
         next_mframe_symbol_err <= 1'b0;         
      end
   end // always @ (posedge clk_character or posedge rst_clk_character)
   

   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character)
        mframe_symbol_err <= 1'b0;
      else if (frame_data_vld)
         mframe_symbol_err  <= mframe_symbol_err_comb | next_mframe_symbol_err;
      else
        mframe_symbol_err <= 1'b0;      
   end // always @ (posedge clk_character or posedge rst_clk_character)
   
   
   always @(*) begin
      count_err_towards_curr_mf = 4'hF;      
      if (char_cnt < 4) begin
         case (char_cnt[1:0]) 
            'h01:count_err_towards_curr_mf = 4'h1;
            'h02:count_err_towards_curr_mf = 4'h3;
            'h03:count_err_towards_curr_mf = 4'h7;
            default:count_err_towards_curr_mf = 4'hF;
         endcase // case (char_cnt)
      end
   end // always @ begin

   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         lane_disparity_err <= 1'b0;
         lane_not_in_table_err <= 1'b0;         
      end
      else if (cgs_sync_req) begin
         lane_disparity_err <= 1'b0;
         lane_not_in_table_err <= 1'b0;                  
      end
      else begin
         lane_disparity_err <= |(rxdisparity_err);
         lane_not_in_table_err <= |(rxnot_in_table_err);                  
      end
               
   end

       
endmodule // jesd_lane_fs_sm
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
