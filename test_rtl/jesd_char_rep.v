

// This module takes care of replacing the character at end of frame and/or end of multiframe with /F/ and/or /A/
// The replacement mux is implemented using function cmux. Frames with length less than 4 require different logic
// for processing hence each of the octets on the 32 bit data path has special logic to handle it.

module jesd_char_rep
  (
   input             clk_character,           // primary clock
   input             rst_clk_character,       // primary reset
   input [8:0]       frame_length_char,       // number of octets per frame
   input [10:0]      mframe_length_char,      // number of octets per multi frame
   input             disable_eof_char_rep,    // control bit set to 1 to disable /F/ insertion 
   input             disable_eomf_char_rep,   // control bit set to 1 to disable /A/ insertion 
   input             dis_scr,                 // control bit used in replacement logic . If 1 indicates scrambling is disabled
   input [31:0]      scr_data,                // 4 octets of input frame data
   input             scr_data_vld,            // control bit when 1 inidcates scr_data has valid information
   input             unscr_data_rdy,          // Request to transport layer for first data. Indicates start of frame/multiframe
   output reg [31:0] process_data,            // 4 octets of output frame data
   output reg [3:0]  process_data_k,          // 1 bit corresponding per octet of process_data to represent whether the octet is control character or data character
   output reg        process_data_vld         // control bit when 1 indicates prcoess_data* signals have valid information
   );

// Counters to generate eof and eomf_marker when frame is more than 1 dword
reg [10:0] remaining_mframe_count;
reg [8:0] remaining_frame_count;

// Combo signals generated using above counters
reg [3:0] eomf_marker_next;
reg [3:0] eof_marker_next;


// Registered version of above signals
reg [3:0] eof_marker; 
reg [3:0] eomf_marker;
   

// Flops to store information of last octet of previous frame and its replacement status
reg [7:0] pframe_loct_r;
reg pframe_rep_r;

//Combo signals to be driven as output on next clock
reg [7:0] ud0_next;
reg       udk0_next;
reg [7:0] ud1_next;
reg       udk1_next;
reg [7:0] ud2_next;
reg       udk2_next;
reg [7:0] ud3_next;
reg       udk3_next;

// Replacement status of octets on scr_data_r
reg       oct_0_st;
reg       oct_1_st;
reg       oct_2_st;
reg       oct_3_st;
   reg [31:0] scr_data_r;
   reg        scr_data_vld_r;
   
   

always @(posedge clk_character or posedge rst_clk_character) begin
   if (rst_clk_character) begin
      process_data_vld <= 1'b0;
      process_data_k <= 4'h0;
      process_data <= 32'h0;
      scr_data_r <= 32'h0;
      scr_data_vld_r <= 1'b0;      
   end
   else begin
      scr_data_r <= scr_data;  
      scr_data_vld_r <= scr_data_vld;
      process_data_vld <= scr_data_vld_r;
      process_data_k <= {udk3_next,udk2_next,udk1_next,udk0_next};
      process_data <= {ud3_next,ud2_next,ud1_next,ud0_next};
   end
 end // always @ (posedge clk_character)
   

always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) 
        remaining_mframe_count <= 11'h0;
      else if (!unscr_data_rdy)
        remaining_mframe_count <= 11'h0;
      else if ((remaining_mframe_count ==  11'h0) || disable_eomf_char_rep)
        remaining_mframe_count <= mframe_length_char;
      else if (scr_data_vld) begin
         if (remaining_mframe_count > 'h4) 
           remaining_mframe_count <= remaining_mframe_count - 11'h4;
         else 
           remaining_mframe_count <= (mframe_length_char - 11'h4) + {8'h0,remaining_mframe_count[2:0]};
      end
end // always @ (posedge clk_character)

   always @(*) begin
      case (remaining_mframe_count)
        1:eomf_marker_next = 4'h1;        
        2:eomf_marker_next = 4'h2;
        3:eomf_marker_next = 4'h4;
        4:eomf_marker_next = 4'h8;
        default: eomf_marker_next = 4'h0;
      endcase // case (remaining_mframe_count)
   end


   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) 
        remaining_frame_count <= 9'h0;
      else if (!unscr_data_rdy)
        remaining_frame_count <= 9'h0;
      else if ((remaining_frame_count == 9'h0) || disable_eof_char_rep)
        remaining_frame_count <= (frame_length_char > 9'h4) ? frame_length_char : 9'h0;      
      else if ((scr_data_vld) && (frame_length_char > 9'h4)) begin
         if (remaining_frame_count > 9'h4) 
           remaining_frame_count <= remaining_frame_count - 9'h4;
         else 
           remaining_frame_count <= (frame_length_char - 9'h4) + {6'h0,remaining_frame_count[2:0]};
      end
   end // always @ (posedge clk_character)
   
   
   
   always @(*) begin
      if (scr_data_vld) begin
         case (frame_length_char)
           1:eof_marker_next = 4'hF;
           2:eof_marker_next = 4'hA;
           4:eof_marker_next = 4'h8;
           3:begin 
              case (eof_marker)
                4'b0100:eof_marker_next =   4'b0010;
                4'b0010:eof_marker_next =   4'b1001;
                default:eof_marker_next =   4'b0100;
              endcase
           end
           default:begin
              case (remaining_frame_count)
                1:eof_marker_next = 4'h1;        
                2:eof_marker_next = 4'h2;
                3:eof_marker_next = 4'h4;
                4:eof_marker_next = 4'h8;
                default: eof_marker_next = 4'h0;
              endcase // case (remaining_mframe_count)
           end
         endcase // case (frame_length_char)
      end // if (scr_data_vld)
      else eof_marker_next = 4'h0;
   end // always @ begin
   

   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
        eof_marker <= 4'h0;
        eomf_marker <= 4'h0;         
      end
      else if (!unscr_data_rdy) begin
        eof_marker <= 4'h0;
        eomf_marker <= 4'h0;         
      end
      else if (scr_data_vld) begin
         eof_marker <= eof_marker_next;
         eomf_marker <= eomf_marker_next;
      end
      else begin
        eof_marker <= 4'h0;
        eomf_marker <= 4'h0;          
      end
   end // always @ (posedge clk_character)
   
   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         pframe_loct_r <= 8'h00;
         pframe_rep_r <= 1'b1;  // Setting this flag will avoid replacement attempt on end of first frame
      end
      else if (!unscr_data_rdy) begin
         pframe_loct_r <= 8'h00;
         pframe_rep_r <= 1'b1;  // Setting this flag will avoid replacement attempt on end of first frame
      end
      else if (scr_data_vld_r) begin
         if (frame_length_char > 'h4) begin // will have a single bit 1 in the eof_marker
            if (eof_marker !='h0) pframe_rep_r <= oct_0_st || oct_1_st || oct_2_st || oct_3_st;            
            case (eof_marker)
              4'b0001:pframe_loct_r <= scr_data_r[7:0]; 
              4'b0010:pframe_loct_r <= scr_data_r[15:8];
              4'b0100:pframe_loct_r <= scr_data_r[23:16];
              4'b1000:pframe_loct_r <= scr_data_r[31:24];                                          
            endcase // case (eof_marker)
         end
         else begin // may have multiple bits in eof as 1 so we need to look at the latest(highest) eof octet replacement status
            if (frame_length_char[1:0] != 2'b11) begin
               pframe_loct_r <= scr_data_r[31:24];
               pframe_rep_r <= oct_3_st;                          
            end
            else begin
               pframe_rep_r <= oct_1_st || oct_2_st || oct_3_st; // oct_0_st should not be carried forward as it is superceeded by  oct_3_st              
               case (eof_marker)
                  4'b0100:pframe_loct_r <= scr_data_r[23:16];
                  4'b0010:pframe_loct_r <= scr_data_r[15:8];
                  4'b1001:pframe_loct_r <= scr_data_r[31:24];  
               endcase // case (sp_eof_marker)
            end // else: !if(frame_length_char[1:0] != 2'b11)
         end // else: !if(frame_length_char > 'h4)
      end // if (scr_data_vld)
   end // always @ (posedge clk_character)
   
   always @(*) begin
      {oct_0_st,udk0_next,ud0_next} = cmux(dis_scr,pframe_rep_r,eomf_marker[0],eof_marker[0],scr_data_r[7:0],pframe_loct_r); 
   end // always @ begin

   always @(*) begin
      case (frame_length_char)
        1:{oct_1_st,udk1_next,ud1_next} = cmux(dis_scr,oct_0_st,eomf_marker[1],1'b1,scr_data_r[15:8],scr_data_r[7:0]);
        default:{oct_1_st,udk1_next,ud1_next} = cmux(dis_scr,pframe_rep_r,eomf_marker[1],eof_marker[1],scr_data_r[15:8],pframe_loct_r); 
      endcase // case (frame_length_char)
   end
   

   
   always @(*) begin
      case (frame_length_char)
        1:{oct_2_st,udk2_next,ud2_next} = cmux(dis_scr,oct_1_st,eomf_marker[2],1'b1,scr_data_r[23:16],scr_data_r[15:8]);
        default:  {oct_2_st,udk2_next,ud2_next} = cmux(dis_scr,pframe_rep_r,eomf_marker[2],eof_marker[2],scr_data_r[23:16],pframe_loct_r);
      endcase // case (frame_length_char)
   end // always @ begin

   always @(*) begin
      case (frame_length_char)
        1:{oct_3_st,udk3_next,ud3_next} = cmux(dis_scr,oct_2_st,eomf_marker[3],1'b1,scr_data_r[31:24],scr_data_r[23:16]);
        2:{oct_3_st,udk3_next,ud3_next} = cmux(dis_scr,oct_1_st,eomf_marker[3],1'b1,scr_data_r[31:24],scr_data_r[15:8]);
        3:{oct_3_st,udk3_next,ud3_next} = cmux(dis_scr,oct_0_st,eomf_marker[3],eof_marker[3],scr_data_r[31:24],scr_data_r[7:0]);
        default:{oct_3_st,udk3_next,ud3_next} = cmux(dis_scr,pframe_rep_r,eomf_marker[3],eof_marker[3],scr_data_r[31:24],pframe_loct_r);         
      endcase // case (frame_length_char[1:0])
   end // always @ begin
   

   



   function [9:0] cmux (input disable_scr,
                        input       prev_eof_replaced,
                        input       eomf,
                        input       eof,
                        input [7:0] data_in,
                        input [7:0] prev_frame_loctet);
      
      reg                           replacement_status;
      reg [7:0]                     replacement_data;
      reg                           replacement_datak;
      begin
         replacement_status = 1'b0;
         replacement_data = data_in;
         replacement_datak = 1'b0;

         if (eomf) begin
            if (disable_scr == 1'b0) begin
               if (data_in == 'h7C) begin
                  replacement_datak = 1'b1;
                  replacement_status = 1'b1;
               end
            end
            else begin
               if (data_in == prev_frame_loctet) begin
                  replacement_data = 'h7C;
                  replacement_datak = 1'b1;
                  replacement_status = 1'b1;
               end
            end
         end // if (eomf)
         else if (eof) begin
            if (disable_scr == 1'b0) begin
               if (data_in == 'hFC) begin
                  replacement_datak = 1'b1;
                  replacement_status = 1'b1;
               end
            end
            else if (prev_eof_replaced == 1'b0) begin
               if (data_in == prev_frame_loctet) begin
                  replacement_data = 'hFC;
                  replacement_datak = 1'b1;
                  replacement_status = 1'b1;
               end
            end
         end // if (eof)
         cmux = {replacement_status,replacement_datak,replacement_data};
      end
   endfunction // cmux
   
      
            
   
   


endmodule // jesd_char_rep
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
