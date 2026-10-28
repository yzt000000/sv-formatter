

// This module ensures that if user data is preceeded by ILAS then the first octet of user data is placed on octet 0 of the link to transport layer interface. 
// Due to the self synchronous descrambler if certain octet is corrupted (not in table error or unexpectded K) the subsequent 2 octets will also be corrupted. This module 
// regenerates the byte_en to ensure the above behavior is accounted for.
// The frame/multi frame markers on the tport_data_*f signals are leading the corresponding data by one clock. This is in accordance with the reference Xilinx IP 
// and is the default mode of operation. 

module jesd_lane_ilas_filter
  #(parameter LEADING_MARKERS=1)
  (
   input             clk_character,       // Primary clock
   input             rst_clk_character,   // Primary reset
   input [3:0]       unscr_byte_en,       // Value of 0 on bit indicates corresponding byte reception has an error.
   input [3:0]       unscr_data_eof,      // Value of 1 on bit indicates corresponding byte is the last byte of the frame.
   input [3:0]       unscr_data_eomf,     // Value of 1 on bit indicates corresponding byte is the last byte of the multi-frame.
   input [3:0]       unscr_data_sof,      // Value of 1 on bit indicates corresponding byte is the first byte of the frame.
   input [3:0]       unscr_data_somf,     // Value of 1 on bit indicates corresponding byte is the first byte of the mult-frame. 
   input [31:0]      unscr_data,          // Bus carrying packed optional ILAS and User data
   input             unscr_data_vld,      // Control signal indicating valid informatsion is present on all the unscr_* signals
   input [3:0]       unscr_user_data,     // Value of 1 on bit indicates corresponding byte is the part of user data.This helps distinguish the ILAS portion of the stream from the user data stream 
   input             bypass_dscr,         // Information to determine if octet corruption should be extrapolated due to self synchronous nature of the de-scrambler
   
   output reg [3:0]  tport_byte_en,       // Value of 0 on bit indicates corresponding byte reception has an error. If LEADING_MARKERS==1 leads tport_data by a clock                 
   output reg [3:0]  tport_data_eof,      // Value of 1 on bit indicates corresponding byte is the last byte of the frame .If LEADING_MARKERS==1 leads tport_data by a clock          
   output reg [3:0]  tport_data_eomf,     // Value of 1 on bit indicates corresponding byte is the last byte of the multi-frame. If LEADING_MARKERS==1 leads tport_data by a clock    
   output reg [3:0]  tport_data_sof,      // Value of 1 on bit indicates corresponding byte is the first byte of the frame. If LEADING_MARKERS==1 leads tport_data by a clock         
   output reg [3:0]  tport_data_somf,     // Value of 1 on bit indicates corresponding byte is the first byte of the mult-frame. If LEADING_MARKERS==1 leads tport_data by a clock    
   output reg [31:0] tport_data,          // Bus carrying unpacked user data first byte of first frame will be on bits [7:0]. If LEADING_MARKERS==1 lags above mareksr by a clock    
   output reg        tport_data_vld       // Control signal indicating valid informatsion is present on all the tport_* signals is valid. Note on the very first clock where the signal goes high if LEADING_MARKERS==1
                                          //  then information on tport_data is invalid
   );
   // Logic to recompute byte enables : in case descrambler is active one corrupted byte causes next 2 bytes to be corrupted
   wire [3:0]        re_computed_byte_en;
   reg [3:0]         unscr_byte_en_r;
   assign            re_computed_byte_en[3] = unscr_byte_en[3] & (bypass_dscr || (unscr_byte_en[2] & unscr_byte_en[1]));
   assign            re_computed_byte_en[2] = unscr_byte_en[2] & (bypass_dscr || (unscr_byte_en[1] & unscr_byte_en[0]));
   assign            re_computed_byte_en[1] = unscr_byte_en[1] & (bypass_dscr || (unscr_byte_en[0] & unscr_byte_en_r[3]));
   assign            re_computed_byte_en[0] = unscr_byte_en[0] & (bypass_dscr || (unscr_byte_en_r[3] & unscr_byte_en_r[2]));
   

   reg [3:0]         re_computed_byte_en_r0, unscr_data_eof_r0,unscr_data_eomf_r0,unscr_data_sof_r0,unscr_data_somf_r0;
   reg [31:0]        unscr_data_r0;

   
   reg [3:0]  next_tport_byte_en,next_tport_data_eof,next_tport_data_eomf,next_tport_data_sof,next_tport_data_somf;
   reg [31:0] next_tport_data;
   reg        next_tport_data_vld;
   reg [3:0]  unscr_user_data_r;
   
   
   always @(*) begin
      next_tport_data_vld = (unscr_user_data_r != 4'h0);      
      case (unscr_user_data_r)
        4'b1000:begin
           next_tport_byte_en   = {re_computed_byte_en[2:0]   ,re_computed_byte_en_r0[3]};
           next_tport_data_eof  = {unscr_data_eof[2:0]  ,unscr_data_eof_r0[3]};
           next_tport_data_eomf = {unscr_data_eomf[2:0] ,unscr_data_eomf_r0[3]};
           next_tport_data_sof  = {unscr_data_sof[2:0]  ,unscr_data_sof_r0[3]};
           next_tport_data_somf = {unscr_data_somf[2:0] ,unscr_data_somf_r0[3]};
           next_tport_data      = {unscr_data[23:0]     ,unscr_data_r0[31:24]};           
        end
        4'b1100:begin
           next_tport_byte_en   = {re_computed_byte_en[1:0]   ,re_computed_byte_en_r0[3:2]};
           next_tport_data_eof  = {unscr_data_eof[1:0]  ,unscr_data_eof_r0[3:2]};
           next_tport_data_eomf = {unscr_data_eomf[1:0] ,unscr_data_eomf_r0[3:2]};
           next_tport_data_sof  = {unscr_data_sof[1:0]  ,unscr_data_sof_r0[3:2]};
           next_tport_data_somf = {unscr_data_somf[1:0] ,unscr_data_somf_r0[3:2]};
           next_tport_data      = {unscr_data[15:0]     ,unscr_data_r0[31:16]};           
        end
        4'b1110:begin
           next_tport_byte_en   = {re_computed_byte_en[0]   ,re_computed_byte_en_r0[3:1]};
           next_tport_data_eof  = {unscr_data_eof[0]  ,unscr_data_eof_r0[3:1]};
           next_tport_data_eomf = {unscr_data_eomf[0] ,unscr_data_eomf_r0[3:1]};
           next_tport_data_sof  = {unscr_data_sof[0]  ,unscr_data_sof_r0[3:1]};
           next_tport_data_somf = {unscr_data_somf[0] ,unscr_data_somf_r0[3:1]};
           next_tport_data      = {unscr_data[7:0]    ,unscr_data_r0[31:08]};           
        end
        default:begin
           next_tport_byte_en   = re_computed_byte_en_r0;
           next_tport_data_eof  = unscr_data_eof_r0;
           next_tport_data_eomf = unscr_data_eomf_r0;
           next_tport_data_sof  = unscr_data_sof_r0;
           next_tport_data_somf = unscr_data_somf_r0;
           next_tport_data      = unscr_data_r0;
        end
      endcase // case (alignment)
   end // always @ (*)

   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         unscr_byte_en_r        <= 'h0;
         re_computed_byte_en_r0 <= 'h0;
         unscr_data_eof_r0      <= 'h0;
         unscr_data_eomf_r0     <= 'h0;
         unscr_data_sof_r0      <= 'h0;
         unscr_data_somf_r0     <= 'h0;
         unscr_data_r0          <= 'h0;
      end
      else begin
         unscr_byte_en_r        <= unscr_byte_en;
         re_computed_byte_en_r0 <= re_computed_byte_en;
         unscr_data_eof_r0      <= unscr_data_eof;
         unscr_data_eomf_r0     <= unscr_data_eomf;
         unscr_data_sof_r0      <= unscr_data_sof;
         unscr_data_somf_r0     <= unscr_data_somf;
         unscr_data_r0          <= unscr_data;
      end
   end

   reg [31:0] tport_data_int;
   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         tport_byte_en   <= 'h0;
         tport_data_eof  <= 'h0;
         tport_data_eomf <= 'h0;
         tport_data_sof  <= 'h0;
         tport_data_somf <= 'h0;
         tport_data_vld  <= 1'b0;
         tport_data      <= 'h0;         
         if (LEADING_MARKERS != 0)      
            tport_data_int  <= 'h0;
      end
      else begin
         tport_byte_en   <= next_tport_byte_en;
         tport_data_eof  <= next_tport_data_eof;
         tport_data_eomf <= next_tport_data_eomf;
         tport_data_sof  <= next_tport_data_sof;
         tport_data_somf <= next_tport_data_somf;
         tport_data_vld  <= next_tport_data_vld;      
         if (LEADING_MARKERS == 0)      
           tport_data       <= next_tport_data;
         else begin
            tport_data_int  <= next_tport_data;
            tport_data      <= tport_data_int;         
         end
      end
   end // always @ (posedge clk_character)
   
   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character)
        unscr_user_data_r <= 4'h0;
      else if (unscr_data_vld) begin
        unscr_user_data_r  <= (unscr_user_data_r == 4'h0) ? unscr_user_data :
                              (unscr_user_data == 4'hF) ? unscr_user_data_r : 4'h0;
      end
      else unscr_user_data_r <= 4'h0;
      
   end
   

   
endmodule // jesd_lane_ilas_filter
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
