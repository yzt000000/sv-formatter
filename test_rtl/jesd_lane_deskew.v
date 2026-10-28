

// This module is instantiated once per lane and is responsible for deskewing the lanes by using Receive Buffer Delay parameter. It takes in input of received data stream afterjesd_lane_fs_sm  stripes off the K28.5 (comma characters). The deskew output of the lanes is then fed to ilas_monitor logic.

module jesd_lane_deskew
   #(parameter ASIZE = 8,
     parameter DSIZE = 36)   
  (
   input              clk_character,        // primary clock
   input              rst_clk_character,    // primary reset
   input [31:0]       frame_data,           // received data 
   input [03:0]       frame_data_k,         // received data  control character qualifier 
   input              frame_data_vld,       // when high indicates presence of valid non comma data stream on frame_data  
   input              comb_cgs_sync_req,    // Input to reset the deskew logic in case of resynchronisation
   input [10:0]       rbd_char_cnt,         // Quasi Static input from CSR to delay the read from de-skew ram post sync_req de-assertion. Final granularity is in terms of rounded up dwords
   input [2:0]        subclass,             
   input [10:0]       mf_len, // carries  length of multiframe in octets
   input   	          comb_frame_data_vld, 
   input              lmfc_boundary,        // LMFC boundary. Reset counters
   input              mf_is_long,          // Next multiframe will be long. Used to control write address
   input  [DSIZE-1:0] sdpr_rd_data,         // Valid one clk after sdpr_rd_en=1
                                            
   output reg         underrun_err,         // When asserted indicates that this instance did not receive any character on the frame_data* interface within the allocated time (rbd_char_cnt) post sync_req de-assertion. Remedy is try increasing rbd_char_cnt
   output reg         overrun_err,          // When asserted indicates that this instance received too many characters on the frame_data* interface within the allocated time (rbd_char_cnt) post sync_req de-assertion.Remedy is try decreasing rbd_char_cnt or increase the deskew RAM depth
   output reg         dskew_err,            // combination of overrun_err & underrun_err. This will cause sync_b assertion
   output reg [31:0]  dskew_frame_data,     // deskewed data
   output reg [03:0]  dskew_frame_data_k,   // deskewed data  control character qualifier 
   output reg         dskew_frame_data_vld, // when high indicates presence of valid non comma deskewed data stream on desked_frame_data  
   output [ASIZE-1:0] sdpr_wr_addr,
   output             sdpr_wr_en,
   output [DSIZE-1:0] sdpr_wr_data,
   output [ASIZE-1:0] sdpr_rd_addr,
   output             sdpr_rd_en
);

   reg [10:0]       char_cnt;
   reg              rd_en;

   reg [ASIZE-1:0] rd_addr;
   reg [ASIZE-1:0] wr_addr;
   wire [ASIZE-1:0] nxt_wr_addr = wr_addr + 3'h4;
   wire               wr_en = ~comb_cgs_sync_req & frame_data_vld;
   wire [DSIZE-1:0] wr_data = {frame_data_k,frame_data};
   

   wire [8:0]       mf_len_less_4 = mf_len[10:2] - 9'h001;  // Multiframe length minus 4;
   reg              rd_started;
   reg              first_data;


   wire [10:0]  current_char_cnt = lmfc_boundary ? 11'h0 : char_cnt;
   reg          current_mf_is_long;
   // Underruns may happen as a result of successive K28.5 char reception causing FS_SM to transition into FS_INIT   
   always @ (posedge clk_character or posedge rst_clk_character)
   begin
      if (rst_clk_character)
      begin
        char_cnt     <= 11'h0;
        rd_en        <= 1'b0;   
        underrun_err <= 1'b0;
        rd_addr      <= 'h0;
        rd_started   <= 1'b0;
        current_mf_is_long <= 1'b0;
      end
      else
      begin
        if (comb_cgs_sync_req || !frame_data_vld)
        begin
          rd_en              <= 1'b0;    
          underrun_err       <= 1'b0;
          rd_addr            <= 'h0;
          rd_started   <= 1'b0;
          current_mf_is_long <= 1'b0;
        end
        else if ((rd_addr != wr_addr) || wr_en)
        begin
          if ( !rd_en )
          begin
            if (current_char_cnt[10:2] == rbd_char_cnt[10:2])
            begin
              rd_en        <= 1'b1;
              rd_addr      <= 'h0;
              rd_started   <= 1'b0;
            end
          end
          else 
          begin
            if (rd_addr=='h0)
              current_mf_is_long <= mf_is_long;

            if (current_char_cnt[10:2] == rbd_char_cnt[10:2])
              rd_addr      <= 'h0;
            else
              rd_addr <= rd_addr + 3'h4;

            if ((rd_addr != wr_addr) && (!underrun_err))
            begin
              rd_en <= 1'b1;
            end
            else
            begin
              underrun_err <= 1'b1;
              rd_en <= 1'b0;
            end         
          end  // !rd_en
        end  // started
        if (lmfc_boundary) begin
          char_cnt <= 11'h4;   
        end
        else 
          char_cnt <= char_cnt + 11'h4 ;
      end
   end // always @ (posedge clk_character or posedge rst_clk_character)


   wire long_addr = rd_addr=='h0 ? mf_is_long : current_mf_is_long;
   //Generally overrun should not happen. It indicates a much larger value of rbd_char_cnt was programmed compared to allocated 
   // storage space for deskew
   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
        wr_addr            <= 'h0;
        overrun_err        <= 1'b0;          
      end
      else if (comb_cgs_sync_req || !frame_data_vld) begin
        wr_addr            <= 'h0;
        overrun_err        <= 1'b0; 
      end
      else if (frame_data_vld) begin
        //if (wr_addr >=  {mf_len_less_4, mf_len[1:0]})
        if (((wr_addr[ASIZE-1:2] == mf_len_less_4) && !long_addr) || (wr_addr[ASIZE-1:2] > mf_len_less_4))
        begin
          wr_addr            <= 'h0;
        end
        else
        begin
          wr_addr <= nxt_wr_addr;       
        end
        if ((wr_addr == rd_addr) && rd_started)
          overrun_err <= 1'b1;      
      end 
   end // always @ (posedge clk_character or posedge rst_clk_character)
   
   
   
   reg              dskew_frame_data_vld_next;
   
   always @ (posedge clk_character) begin
      dskew_err <= overrun_err | underrun_err;
      dskew_frame_data_vld_next <=  ~comb_cgs_sync_req & rd_en & ~overrun_err & ~underrun_err;      
   end
   
   always @ (posedge clk_character) begin 
      {dskew_frame_data_k,dskew_frame_data} <= sdpr_rd_data;
      dskew_frame_data_vld <= dskew_frame_data_vld_next;      
   end
   
   assign sdpr_wr_addr = {wr_addr[ASIZE-1:2], 2'b00};
   assign sdpr_wr_en   = wr_en;
   assign sdpr_wr_data = wr_data;
   assign sdpr_rd_addr = rd_addr;
   assign sdpr_rd_en   = rd_en;
   
endmodule // jesd_lane_deskew

// Local Variables:
// verilog-library-directories:(".")
// End:
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
