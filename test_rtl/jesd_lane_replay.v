

// This module implements the replay of a frame on per lane basis. Lane 0 instance is a special instance as it looks at the byte enables across all lanes and if any active lane// has a bad byte it triggers replay of previous frame on all the lanes. It feeds this information via combined_byte_en_o & combined_error_in_frame_o outputs and peer lanes receive this information via combined_byte_en_i and combined_error_in_frame_i  inputs.
// The replay logic is broken into 2 separate implementations, one caters to frame lengths less than or equal to 4 and the other one caters to frame lengths greater than 4.
// The former one does not use any RAM or Fifo resources and it solely relies on local pipeline stage variables but the latter one uses a RAM and control fifo to store  the valid frames. 
// For latter case the write state machine alsigns the first octet of frame to byte 0 of the dword and then writes the dwords to replay ram , the trailing residue portion (incomplete DWORD)  of a frame is pushed into a control fifo provided the entire frame is received without errors. 
// For latter case the read logic relies on the control fifo being non empty and its job is to repack non dword aligned portion of previous frame  and the dword aligned portion of the current frame and non dword aligned portion of curent frame to form a running stream wihout any holes. 

module jesd_lane_replay
  #(parameter ERR_COMBINING=1)   
  (
   input             clk_character,        // primary clock
   input             rst_clk_character,    // primary reset
   input [8:0]       frame_length_char,    // determines which logic to use for implementing replay   
   input [7:0]       active_lane,          // One bit per lane.Used to selectively filter out errors on lanes which are not part of link
   input             tport_marker_vld,     // Control signal when high indicates availability of user markers  on tport signals
   input [31:0]      tport_byte_en,        // 4 bits Per lane . When 1 indicates corresponding byte on {tport_data[lane7],tport_data[lane6],......tport_data[lane0]} is valid 
   input [3:0]       tport_data_eof,       // 1 bit per octet of tport_data , when 1 indicates last octet of a frame . Leads tport_data  by one clock.
   input [3:0]       tport_data_sof,       // 1 bit per octet of tport_data , when 1 indicates first octet of a frame . Leads tport_data  by one clock.    
   input [31:0]      tport_data,           // received data stream
   input             tport_data_vld,       // Control signal when high indicates availability of user data  on tport_data bits. One clock delayed version of tport_marker_vld
   input [3:0]       combined_byte_en_i,   // Input port relevant for Instances corresponding to non zero lane. 
   input             combined_error_in_frame_i, // Input port relevant for Instances corresponding to non zero lane. 
   input [31:0]      replay_ram_rd_data, // Will be part of 32*NO_LANES bus . Connects to replay ram which is placed at top level
   output reg [31:0] replay_ram_wr_data, // Will be part of 32*NO_LANES bus. Connects to replay ram which is placed at top level
   output reg [6:0]  replay_ram_rd_addr, // Will be used from lane 0 only. Connects to replay ram which is placed at top level , common read address for all lanes
   output reg [6:0]  replay_ram_wr_addr, // Will be used from lane 0 only.Connects to replay ram which is placed at top level , common write address for all lanes
   output reg        replay_ram_wr_en, // Will be used from lane 0 only.Connects to replay ram which is placed at top level , common write enable port
   output            replay_ram_rd_en, // Will be used from lane 0 only.Connects to replay ram which is placed at top level , common read enable port   
   output [3:0]      combined_byte_en_o, // Lane 0 generates these using  tport_byte_en[31:0] and passes it to peer lanes via combined_byte_en_i  
   output            combined_error_in_frame_o, // Lane 0 generates these using  tport_byte_en[31:0],tport_data_eof,tport_data_sof and passes it to peer lanes via combined_error_in_frame_i
   output            replay_ctl_fifo_full, // debug signal
   output reg [31:0] d2_lid_mux, // Transport layer data stream with replay. Will be part of 32*NO_LANES bus
   output reg        d2_lid_mux_vld // Control signal when high indicates availability of user data  on d2_lid_mux
   );
   
   // Block to combine error information from multiple lanes. Note byte enables from individual lanes are 
   // leading the corresponding data by one posedge so the combining logcic latency ends up aligning the byte enables to data
   // the tport_data_sof marker needs to be delayed to align with tport_data and combined_byte_en
   // error info in form of combined_byte_en is used by replay logic to handle replay when F < 5
   // and error info in form of single signal "combined_error_in_frame" is used by replay logic to handle  when F > 5
   
   reg [3:0]         combined_byte_en;
   reg               combined_error_in_frame;
   
   generate
      if (ERR_COMBINING==1) begin:l0_combine_err_info
         reg   [3:0] combined_byte_en_next;
         reg [8:0]   char_cnt;
         reg         error_in_next_frame, accumulated_error, error_in_curr_frame_combo,error_in_next_frame_combo;
         
         always @(*) begin
            combined_byte_en_next = tport_byte_en[3:0];            
            case (active_lane)
              8'h3:begin
                   combined_byte_en_next = tport_byte_en[3:0] & tport_byte_en[7:4];
              end
              8'h7:begin
                   combined_byte_en_next = tport_byte_en[3:0] & tport_byte_en[7:4] & tport_byte_en[11:8];
              end
              8'hF:begin
                   combined_byte_en_next = tport_byte_en[3:0] & tport_byte_en[7:4] & tport_byte_en[11:8] & tport_byte_en[15:12];
              end
              8'h1F:begin
                   combined_byte_en_next = tport_byte_en[3:0] & tport_byte_en[7:4] & tport_byte_en[11:8] & tport_byte_en[15:12] 
                     & tport_byte_en[19:16];
              end
              8'h3F:begin
                   combined_byte_en_next = tport_byte_en[3:0] & tport_byte_en[7:4] & tport_byte_en[11:8] & tport_byte_en[15:12] 
                & tport_byte_en[19:16] & tport_byte_en[23:20];
              end
              8'h7F:begin
                   combined_byte_en_next = tport_byte_en[3:0] & tport_byte_en[7:4] & tport_byte_en[11:8] & tport_byte_en[15:12] 
                & tport_byte_en[19:16] & tport_byte_en[23:20] & tport_byte_en[27:24];
              end
              8'hFF:begin
                   combined_byte_en_next = tport_byte_en[3:0] & tport_byte_en[7:4] & tport_byte_en[11:8] & tport_byte_en[15:12] 
                     & tport_byte_en[19:16] & tport_byte_en[23:20] & tport_byte_en[27:24] & tport_byte_en[31:28];
              end
            endcase // case (active_lane)
         end // always @ begin
         
         
         always @(posedge clk_character or posedge rst_clk_character) begin   
            if (rst_clk_character) begin
               combined_byte_en <= 4'h0 ;      
            end
            else begin
               combined_byte_en <= combined_byte_en_next ;      
            end
         end
         
         
         always @(*) begin   
            case (char_cnt)
              'h1:begin
                 error_in_curr_frame_combo = (combined_byte_en_next[0] != 1'b1)  | error_in_next_frame;
                 error_in_next_frame_combo = (combined_byte_en_next[3:1] != 3'b111);
              end
              'h2:begin
                 error_in_curr_frame_combo = (combined_byte_en_next[1:0] != 2'b11) | error_in_next_frame;
                 error_in_next_frame_combo = (combined_byte_en_next[3:2] != 2'b11);
              end  
              'h3:begin
                 error_in_curr_frame_combo = (combined_byte_en_next[2:0] != 3'b111) | error_in_next_frame;
                 error_in_next_frame_combo = (combined_byte_en_next[3] != 1'b1);       
              end
              default : begin
                 error_in_curr_frame_combo = (combined_byte_en_next != 4'hf) | error_in_next_frame;
                 error_in_next_frame_combo = 1'b0;
              end
            endcase // case (char_cnt)
         end // always @ (*)
         
         always @(posedge clk_character or posedge rst_clk_character) begin
            if (rst_clk_character) begin
               char_cnt <= 'h0;
               error_in_next_frame <= 1'b0;
               accumulated_error <= 1'b0;
               combined_error_in_frame <= 1'b0;      
            end
            else if (tport_marker_vld) begin 
               error_in_next_frame <= error_in_next_frame_combo;
               if (char_cnt > 3'h4) begin
                  char_cnt <= char_cnt - 3'h4;
                  combined_error_in_frame <= 1'b0;              
                  accumulated_error <= error_in_curr_frame_combo | accumulated_error;        
               end
               else begin
                  combined_error_in_frame <= error_in_curr_frame_combo | accumulated_error;
                  char_cnt <=  (frame_length_char - 3'h4) + char_cnt;
                  accumulated_error <= 1'b0;        
               end
            end
            else begin
               char_cnt <= frame_length_char;
               accumulated_error <= 1'b0;
               error_in_next_frame <= 1'b0;
               accumulated_error <= 1'b0;
               combined_error_in_frame <= 1'b0;      
            end // else: !if(byte_en_in_vld)
         end // always @ (posedge clk_character or posedge rst_clk_character)
      end // block: l0_combine_err_info      
      else begin:other_lane_combine_err_info
         always @ (*) begin
            combined_byte_en = combined_byte_en_i;
            combined_error_in_frame = combined_error_in_frame_i;
         end // always @ begin      
      end
   endgenerate
   
   
   assign combined_byte_en_o = combined_byte_en;
   assign combined_error_in_frame_o =  combined_error_in_frame;
   
   // Per lane code 
   reg low_frame_vld, up_frame_vld,up_frame_vld_r;
   reg [3:0] combined_byte_en_r,sof_marker,sof_marker_r,eof_marker;
   reg       tport_data_vld_r;
   reg [31:0] tport_data_r;
   // Replay logic for frame length less than 5 in other cases this mux will output 0
   // Frame length 1,2,4 use 2 dwords (tport_data and output stage replay_data_mode_fl_lt5)
   // Frame length 3 uses 4 dwords (tport_data_r,tport_data, output stage replay_data_mode_fl_lt5 and replay_data_mode_fl_lt5_r)
   
   reg [31:0] replay_data_mode_fl_lt5_next,replay_data_mode_fl_lt5,replay_data_mode_fl_lt5_r;
   reg        replay_val_mode_fl_lt5_next,replay_val_mode_fl_lt5;
   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         combined_byte_en_r <= 4'h0;
         sof_marker <= 4'h0;          
         sof_marker_r <= 4'h0;   
         eof_marker <= 4'h0;          
         tport_data_vld_r <= 1'b0;
         tport_data_r <= 32'h0;
         replay_data_mode_fl_lt5 <= 32'h0;
         replay_data_mode_fl_lt5_r <= 32'h0;          
         replay_val_mode_fl_lt5 <= 1'b0;     
         up_frame_vld_r <= 1'b0;          
      end
      else if (tport_marker_vld) begin
         combined_byte_en_r <= combined_byte_en;
         sof_marker <= tport_data_sof;                    
         sof_marker_r <= sof_marker;    
         eof_marker <= tport_data_eof;                    
         tport_data_vld_r <= tport_data_vld;
         tport_data_r <= tport_data;
         replay_data_mode_fl_lt5 <= replay_data_mode_fl_lt5_next;
         replay_data_mode_fl_lt5_r <= replay_data_mode_fl_lt5;                 
         replay_val_mode_fl_lt5 <= replay_val_mode_fl_lt5_next;    
         up_frame_vld_r <= up_frame_vld;
      end // if (tport_marker_vld)
      else begin
         combined_byte_en_r <= 4'h0;
         sof_marker <= 4'h0;          
         sof_marker_r <= 4'h0;   
         eof_marker <= 4'h0;          
         tport_data_vld_r <= 1'b0;
         tport_data_r <= 32'h0;
         replay_data_mode_fl_lt5 <= 32'h0;
         replay_data_mode_fl_lt5_r <= 32'h0;          
         replay_val_mode_fl_lt5 <= 1'b0;     
         up_frame_vld_r <= 1'b0;      
      end
   end // always @ (posedge clk_character or posdedge rst_clk_character)
   
   
   
   // Following logic acts a look ahead and is only used in case of F=3
   always @ (*) begin
      low_frame_vld = 1'b0;
      up_frame_vld = 1'b0;
      case (sof_marker_r)
        4'b1001:begin
           low_frame_vld = combined_byte_en_r[2] & combined_byte_en_r[1] & combined_byte_en_r[0];
           up_frame_vld = combined_byte_en_r[3] & combined_byte_en[1] & combined_byte_en[0];            
        end
        4'b0100:begin
           low_frame_vld = up_frame_vld_r;
           up_frame_vld = combined_byte_en_r[3] & combined_byte_en_r[2] & combined_byte_en[0];                        
        end
        4'b0010:begin
           low_frame_vld = up_frame_vld_r;
           up_frame_vld = combined_byte_en_r[3] & combined_byte_en_r[2] & combined_byte_en_r[1];                                    
        end
      endcase
   end // always @ begin
   
   
   always @(*)begin
      replay_data_mode_fl_lt5_next = 32'h0;    
      replay_val_mode_fl_lt5_next = 1'b0;     
      case (frame_length_char)
        1: begin
           replay_val_mode_fl_lt5_next = tport_data_vld;
           
           if (combined_byte_en[0]) replay_data_mode_fl_lt5_next[7:0] = tport_data[7:0];
           else replay_data_mode_fl_lt5_next[7:0] = replay_data_mode_fl_lt5[31:24];
           
           if (combined_byte_en[1]) replay_data_mode_fl_lt5_next[15:8] = tport_data[15:8];
           else if(combined_byte_en[0]) replay_data_mode_fl_lt5_next[15:8] = tport_data[7:0];
           else replay_data_mode_fl_lt5_next[15:8] = replay_data_mode_fl_lt5[31:24];
           
           if (combined_byte_en[2]) replay_data_mode_fl_lt5_next[23:16] = tport_data[23:16];              
           else if (combined_byte_en[1]) replay_data_mode_fl_lt5_next[23:16] = tport_data[15:8];
           else if(combined_byte_en[0]) replay_data_mode_fl_lt5_next[23:16] = tport_data[7:0];
           else replay_data_mode_fl_lt5_next[23:16] = replay_data_mode_fl_lt5[31:24];
           
           if (combined_byte_en[3]) replay_data_mode_fl_lt5_next[31:24] = tport_data[31:24];                            
           else if (combined_byte_en[2]) replay_data_mode_fl_lt5_next[31:24] = tport_data[23:16];              
           else if (combined_byte_en[1]) replay_data_mode_fl_lt5_next[31:24] = tport_data[15:8];
           else if(combined_byte_en[0]) replay_data_mode_fl_lt5_next[31:24] = tport_data[7:0];
           else replay_data_mode_fl_lt5_next[31:24] = replay_data_mode_fl_lt5[31:24];
        end
        2: begin
           replay_val_mode_fl_lt5_next = tport_data_vld;           
           if (combined_byte_en[1] & combined_byte_en[0] ) replay_data_mode_fl_lt5_next[15:0] = tport_data[15:0];
           else replay_data_mode_fl_lt5_next[15:0] = replay_data_mode_fl_lt5[31:16];
           
           if (combined_byte_en[3] & combined_byte_en[2] ) replay_data_mode_fl_lt5_next[31:16] = tport_data[31:16];              
           else if (combined_byte_en[1] & combined_byte_en[0] ) replay_data_mode_fl_lt5_next[31:16] = tport_data[15:0];
           else replay_data_mode_fl_lt5_next[31:16] = replay_data_mode_fl_lt5[31:16];
        end
        4:begin
           replay_val_mode_fl_lt5_next = tport_data_vld;           
           if (combined_byte_en != 4'hF) 
             replay_data_mode_fl_lt5_next = replay_data_mode_fl_lt5;
           else
             replay_data_mode_fl_lt5_next = tport_data;
        end
        3:begin
           replay_val_mode_fl_lt5_next = tport_data_vld_r;
           case (sof_marker_r)
             4'b1001:begin
                if (low_frame_vld) 
                  replay_data_mode_fl_lt5_next[23:0] = tport_data_r[23:0];
                else
                  replay_data_mode_fl_lt5_next[23:0] = replay_data_mode_fl_lt5[31:8];
                
                if (up_frame_vld)
                  replay_data_mode_fl_lt5_next[31:24] = tport_data_r[31:24];
                else if (low_frame_vld)
                  replay_data_mode_fl_lt5_next[31:24] = tport_data_r[7:0];
                else
                  replay_data_mode_fl_lt5_next[31:24] = replay_data_mode_fl_lt5[15:8];
             end
             4'b0100:begin
                if (low_frame_vld) 
                  replay_data_mode_fl_lt5_next[15:0] = tport_data_r[15:0];
                else
                  replay_data_mode_fl_lt5_next[15:0] = replay_data_mode_fl_lt5[23:8];
                
                if (up_frame_vld)
                  replay_data_mode_fl_lt5_next[31:16] = tport_data_r[31:16];
                else if (low_frame_vld)
                  replay_data_mode_fl_lt5_next[31:16] = {tport_data_r[7:0],replay_data_mode_fl_lt5[31:24]};
                else
                  replay_data_mode_fl_lt5_next[31:16] = replay_data_mode_fl_lt5[15:0];                
             end
             4'b0010:begin
                if (low_frame_vld) 
                  replay_data_mode_fl_lt5_next[7:0] = tport_data_r[7:0];
                else
                  replay_data_mode_fl_lt5_next[7:0] = replay_data_mode_fl_lt5[15:8];
                
                if (up_frame_vld) 
                  replay_data_mode_fl_lt5_next[31:8] = tport_data_r[31:8];
                else if (low_frame_vld)
                  replay_data_mode_fl_lt5_next[31:8] = {tport_data_r[7:0],replay_data_mode_fl_lt5[31:16]};
                else 
                  replay_data_mode_fl_lt5_next[31:8] = {replay_data_mode_fl_lt5[15:0],replay_data_mode_fl_lt5_r[31:24]};
             end
           endcase // case (sof_marker_r)
        end // case: 3
      endcase // case (frame_length_char)         
   end // always @ begin
   
   
   
   
   //worst case frame size is 256 octets requiring local storage of 512 bytes, 256 for replay and 256 for
   //writing next valid frame. 
   
   // logic  to write data to replay buffer in case length is greater than 5.
   // It ensures that the octet representing sof is stored at [7:0] in the RAM. 
   
   // Info to be pushed in control fifo after verifying entire frame was valid
   reg [31:0]   residual_eof_data;
   reg [6:0]    wr_end_addr,wr_start_addr,wr_start_addr_r;    
   
   reg          fifo_push;
   reg [1:0]    wr_residue_bc;

//   always @(*) begin   
   always @(posedge clk_character or posedge rst_clk_character) begin
     if (rst_clk_character)
      replay_ram_wr_data <= 'h0;
     else
      case (wr_residue_bc) 
        default:replay_ram_wr_data <= tport_data;
        'h1:replay_ram_wr_data <= {tport_data[23:0],tport_data_r[31:24]};
        'h2:replay_ram_wr_data <= {tport_data[15:0],tport_data_r[31:16]};
        'h3:replay_ram_wr_data <= {tport_data[7:0],tport_data_r[31:08]};
      endcase
   end // always @ begin
   
  
   
   
   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character)  begin
         wr_start_addr_r <= {7{1'b0}};
         wr_start_addr <= {7{1'b0}};         
         wr_end_addr <= {7{1'b1}};         
         replay_ram_wr_addr <= {7{1'b1}};
         replay_ram_wr_en <= 1'b0;
         wr_residue_bc <= 2'h0; // Assuming the first frame after reset will start at byte 0
         fifo_push <= 1'b0;
         residual_eof_data <= 'h0;
      end
      else if (!tport_marker_vld)  begin
         wr_start_addr_r <= {7{1'b0}};
         wr_start_addr <= {7{1'b0}};         
         wr_end_addr <= {7{1'b1}};         
         replay_ram_wr_addr <= {7{1'b1}};
         replay_ram_wr_en <= 1'b0;
         wr_residue_bc <= 4'h0; // Assuming the first frame after reset will start at byte 0
         fifo_push <= 1'b0;
      end
      else if (frame_length_char > 4) begin
         fifo_push <= 1'b0;
         replay_ram_wr_en <= 1'b0;
         wr_start_addr_r <= wr_start_addr;
         if (tport_data_vld) begin
            case (eof_marker)
              4'b0000:begin
                 fifo_push <= 1'b0;
                 replay_ram_wr_addr <= replay_ram_wr_addr + 1'b1;
                 replay_ram_wr_en <= 1'b1;
              end
              4'b0001:begin
                 wr_residue_bc <= 2'h3;                         
                 if (combined_error_in_frame)
                   // not restoring to start address as we have default increment when we enable write                   
                   replay_ram_wr_addr <=  wr_end_addr; 
                 else begin
                    fifo_push <= 1'b1;
                    case (wr_residue_bc)
                      default:begin
                         residual_eof_data <= tport_data[7:0];
                         wr_end_addr <= replay_ram_wr_addr;
                         wr_start_addr <= replay_ram_wr_addr + 1'b1;
                      end
                      1:begin
                         residual_eof_data <= {tport_data[7:0],tport_data_r[31:24]};
                         wr_end_addr <= replay_ram_wr_addr;
                         wr_start_addr <= replay_ram_wr_addr + 1'b1;
                      end
                      2:begin
                         residual_eof_data <= {tport_data[7:0],tport_data_r[31:16]};
                         wr_end_addr <= replay_ram_wr_addr;
                         wr_start_addr <= replay_ram_wr_addr + 1'b1;
                      end
                      3:begin
                         residual_eof_data <= {tport_data[7:0],tport_data_r[31:08]};
                         wr_end_addr <= replay_ram_wr_addr;
                         wr_start_addr <= replay_ram_wr_addr + 1'b1;                         
                      end
                    endcase // case (wr_residue_bc)
                 end // else: !if(combined_error_in_frame)                 
              end // case: 4'b0001           
              4'b0010:begin
                   wr_residue_bc <= 2'h2;
                 if (combined_error_in_frame) 
                   replay_ram_wr_addr <=  wr_end_addr;
                 else begin
                    fifo_push <= 1'b1;                    
                    case (wr_residue_bc)
                      default:begin
                         residual_eof_data <= tport_data[15:0];
                         wr_end_addr <= replay_ram_wr_addr;
                         wr_start_addr <= replay_ram_wr_addr + 1'b1;                         
                      end
                      1:begin
                         residual_eof_data <= {tport_data[15:0],tport_data_r[31:24]};
                         wr_end_addr <= replay_ram_wr_addr;
                         wr_start_addr <= replay_ram_wr_addr + 1'b1;                         
                      end
                      2:begin
                         residual_eof_data <= {tport_data[15:0],tport_data_r[31:16]};
                         wr_end_addr <= replay_ram_wr_addr;
                         wr_start_addr <= replay_ram_wr_addr + 1'b1;                         
                      end
                      3:begin
                         residual_eof_data <= tport_data[15:8];
                         wr_end_addr <= replay_ram_wr_addr+1'b1;
                         replay_ram_wr_addr <= replay_ram_wr_addr + 1'b1;
                         replay_ram_wr_en <= 1'b1;                       
                         wr_start_addr <= replay_ram_wr_addr + 2'h2;   
                      end
                    endcase // case (wr_residue_bc)
                 end // else: !if(combined_error_in_frame)
              end // case: 4'b0010           
              4'b0100:begin
                 wr_residue_bc <= 2'h1;
                 if (combined_error_in_frame) 
                   replay_ram_wr_addr <=  wr_end_addr;
                 else begin 
                    fifo_push <= 1'b1;                   
                    case (wr_residue_bc)
                      default:begin
                         residual_eof_data <= tport_data[23:0];
                         wr_end_addr <= replay_ram_wr_addr;
                         wr_start_addr <= replay_ram_wr_addr + 1'b1;
                      end
                      1:begin
                         residual_eof_data <= {tport_data[23:0],tport_data_r[31:24]};
                         wr_end_addr <= replay_ram_wr_addr;
                         wr_start_addr <= replay_ram_wr_addr + 1'b1;
                      end
                      2:begin
                         residual_eof_data <= tport_data[23:16];
                         wr_end_addr <= replay_ram_wr_addr+1'b1;
                         replay_ram_wr_addr <= replay_ram_wr_addr + 1'b1;
                         replay_ram_wr_en <= 1'b1;
                         wr_start_addr <= replay_ram_wr_addr + 2'h2;   
                      end
                      3:begin
                         residual_eof_data <= tport_data[23:8];
                         wr_end_addr <= replay_ram_wr_addr+1'b1;
                         replay_ram_wr_addr <= replay_ram_wr_addr + 1'b1;
                         replay_ram_wr_en <= 1'b1;
                         wr_start_addr <= replay_ram_wr_addr + 2'h2;   
                      end
                    endcase // case (wr_residue_bc)
                 end // else: !if(combined_error_in_frame)
              end // case: 4'b0100
              4'b1000:begin
                 wr_residue_bc <= 2'h0;
                 if (combined_error_in_frame) 
                   replay_ram_wr_addr <=  wr_end_addr;
                 else begin
                    fifo_push <= 1'b1;                    
                    case (wr_residue_bc)
                      default:begin
                         residual_eof_data <= tport_data;
                         wr_end_addr <= replay_ram_wr_addr;
                         wr_start_addr <= replay_ram_wr_addr + 1'b1;
                      end
                      1:begin
                         residual_eof_data <= tport_data[31:24];
                         wr_end_addr <= replay_ram_wr_addr+1'b1;
                         replay_ram_wr_addr <= replay_ram_wr_addr + 1'b1;
                         replay_ram_wr_en <= 1'b1;
                         wr_start_addr <= replay_ram_wr_addr + 2'h2;   
                      end
                      2:begin
                         residual_eof_data <= tport_data[31:16];
                         wr_end_addr <= replay_ram_wr_addr+1'b1;
                         replay_ram_wr_addr <= replay_ram_wr_addr + 1'b1;
                         replay_ram_wr_en <= 1'b1;
                         wr_start_addr <= replay_ram_wr_addr + 2'h2;   
                      end
                      3:begin
                         residual_eof_data <= tport_data[31:8];
                         wr_end_addr <= replay_ram_wr_addr+1'b1;
                         replay_ram_wr_addr <= replay_ram_wr_addr + 1'b1;
                         replay_ram_wr_en <= 1'b1;
                         wr_start_addr <= replay_ram_wr_addr + 2'h2;   
                      end
                    endcase // case (wr_residue_bc)
                 end // else: !if(combined_error_in_frame)
              end // case: 4'b1000
            endcase // case (eof_marker)
         end // if (tport_data_vld)
      end // if (frame_length_char > 4)
   end // always @ (posedge clk_character or rst_clk_character)


   
   // Logic to read from replay RAM
   localparam INVALID=2'b00,VALID=2'b01,WAIT_STATUS=2'b10,VALID_SF=2'b11;
   
   reg [31:0]  residue_data,ctx_rd_eof_data;
   reg [2:0]   rd_residue_bc;   
   reg [6:0]   ctx_rd_start_addr,ctx_rd_end_addr;    
   
   reg [31:0]  replay_data_mode_fl_gt4,replay_ram_rd_data_r;
   reg         replay_val_mode_fl_gt4;
   reg         fifo_empty_r1;
   reg         fifo_empty_r2;
   reg         fifo_empty_r3;      
   reg         fifo_pop;   
   wire [47:0] fifo_rd_data;
   wire        fifo_empty;
   reg [1:0]   rd_addr_state,rd_addr_state_next;
   reg [6:0]   replay_ram_rd_addr_next;
   reg [31:0]  eof_info_r2,eof_info_r1,eof_info,next_eof_info;
   reg         insert_eof_r2,insert_eof_r1,insert_eof,insert_eof_next;   
   reg         rd_en_r2,rd_en_r1,rd_en,rd_en_next;
   wire [2:0]  rd_eof_byte_count = (frame_length_char[1:0] == 2'h0) ? 3'h4 : {1'b0,frame_length_char[1:0]};   
   wire [31:0] rd_eof_data = eof_info_r2[31:0];
   reg [3:0]   cumm_eof_cnt;
   wire [3:0]  cumm_eof_cnt_next = cumm_eof_cnt + {2'b00, frame_length_char[1:0]};
   reg         ld_cum_eof_cnt,clr_cum_eof_cnt;
   
   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         replay_ram_rd_addr <= {7{1'b1}};         
         rd_addr_state <= INVALID;
         eof_info_r2 <= 35'h0;
         eof_info_r1 <= 35'h0;
         eof_info <= 35'h0;
         insert_eof_r2 <= 1'b0;
         insert_eof_r1 <= 1'b0;
         insert_eof <= 1'b0;
         rd_en_r2 <= 1'b0;
         rd_en_r1 <= 1'b0;
         rd_en <= 1'b0;
         fifo_empty_r1 <= 1'b1;
         fifo_empty_r2 <= 1'b1;
         fifo_empty_r3 <= 1'b1;  
         cumm_eof_cnt <= 4'h0;                
      end
      else begin
         replay_ram_rd_addr <= replay_ram_rd_addr_next;
         rd_addr_state <= rd_addr_state_next;
         eof_info_r2 <= eof_info_r1;
         eof_info_r1 <= eof_info;
         eof_info <= next_eof_info;         
         insert_eof_r2 <= insert_eof_r1;
         insert_eof_r1 <= insert_eof;
         insert_eof <= insert_eof_next;         
         rd_en_r2 <= rd_en_r1;
         rd_en_r1 <= rd_en;
         rd_en <= rd_en_next;
         fifo_empty_r1 <= fifo_empty;         
         fifo_empty_r2 <= fifo_empty_r1;
         fifo_empty_r3 <= fifo_empty_r2;
         if  (clr_cum_eof_cnt)
           cumm_eof_cnt <= cumm_eof_cnt_next - 'h4;
         else if (ld_cum_eof_cnt)
           cumm_eof_cnt <= cumm_eof_cnt_next;         
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)
   
   
   always @(*) begin
      replay_ram_rd_addr_next = replay_ram_rd_addr;
      rd_addr_state_next = rd_addr_state;
      rd_en_next = rd_en;
      fifo_pop = 1'b0;
      insert_eof_next = 1'b0;      
      next_eof_info = 'h0;  
      clr_cum_eof_cnt = 1'b0;
      ld_cum_eof_cnt = 1'b0;
      
      case (rd_addr_state)
        INVALID:begin
           if (!fifo_empty_r3) begin
                    fifo_pop = 1'b1;
                    replay_ram_rd_addr_next = fifo_rd_data[38:32];
                    rd_addr_state_next = (frame_length_char[1:0] == 2'b00) ? VALID_SF : VALID;
                    rd_en_next = 1'b1;
           end
           else replay_ram_rd_addr_next = replay_ram_rd_addr;
           // case (frame_length_char[1:0])
           //   2'b00:begin
           //      if (!fifo_empty_r1) begin
           //         fifo_pop = 1'b1;
           //         replay_ram_rd_addr_next = fifo_rd_data[38:32];
           //         rd_addr_state_next = VALID_SF;
           //         rd_en_next = 1'b1;
           //      end
           //      else replay_ram_rd_addr_next = replay_ram_rd_addr;
           //   end
           //   default:begin
           //      if (!fifo_empty) begin
           //         fifo_pop = 1'b1;
           //         replay_ram_rd_addr_next = fifo_rd_data[38:32];
           //         rd_addr_state_next = VALID;
           //         rd_en_next = 1'b1;
           //      end
           //      else replay_ram_rd_addr_next = replay_ram_rd_addr;
           //   end
           // endcase // case (frame_length_char)
        end // case: INVALID
        VALID_SF:begin // This state is useful for handling frame lengths aligned to 4. Ensures insert_eof 
           // is deasserted atleast for one clock after assertion
           if (insert_eof == 1'b0) begin
              if (replay_ram_rd_addr == ctx_rd_end_addr) begin
                 insert_eof_next = 1'b1;
                 next_eof_info = ctx_rd_eof_data;
                 fifo_pop = !fifo_empty;
                 replay_ram_rd_addr_next = !fifo_empty ? fifo_rd_data[38:32] : ctx_rd_start_addr;
              end
              else replay_ram_rd_addr_next = replay_ram_rd_addr + 1'b1;
           end
        end
        VALID:  begin // This state is useful for handling frame lengths not aligned to 4
           if (replay_ram_rd_addr == ctx_rd_end_addr) begin
              if (cumm_eof_cnt_next > 'h3)  begin
                 rd_addr_state_next = WAIT_STATUS;
                 clr_cum_eof_cnt = 1'b1;
                 insert_eof_next =  1'b1;              
                 next_eof_info = ctx_rd_eof_data;           
              end
              else begin
                 fifo_pop = !fifo_empty;
                 replay_ram_rd_addr_next = !fifo_empty ? fifo_rd_data[38:32] : ctx_rd_start_addr;                                
                 insert_eof_next =  1'b1;              
                 next_eof_info = ctx_rd_eof_data;
                 ld_cum_eof_cnt = 1'b1;
              end
           end
           else replay_ram_rd_addr_next = replay_ram_rd_addr + 1'b1;
        end // case: VALID
        WAIT_STATUS:begin
           fifo_pop = !fifo_empty;
           replay_ram_rd_addr_next = !fifo_empty ? fifo_rd_data[38:32] : ctx_rd_start_addr;                          
           rd_addr_state_next = VALID;
        end
      endcase // case (rd_addr_state)
   end // always @ (posedge clk_character)
   
   always @ (posedge clk_character or posedge rst_clk_character)  begin
      if (rst_clk_character) begin
         ctx_rd_eof_data <= 32'h0;
         ctx_rd_start_addr <= {7{1'b0}};
         ctx_rd_end_addr <= {7{1'b1}};
         replay_ram_rd_data_r <= 32'h0;            
      end
      else begin
         replay_ram_rd_data_r <= replay_ram_rd_data;          
         if (fifo_pop) begin
            ctx_rd_eof_data <= fifo_rd_data[31:0];             
            ctx_rd_start_addr <= fifo_rd_data[38:32];
            ctx_rd_end_addr <= fifo_rd_data[46:40];          
         end
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or rst_clk_character)
   
   wire [47:0]  fifo_wr_data = {1'b0,wr_end_addr,1'b0,wr_start_addr_r,residual_eof_data} ;
   

   
   jesd_sync_fifo jesd_sync_fifo(
                               // Outputs
                               .rdata           (fifo_rd_data),
                               .wfull           (replay_ctl_fifo_full),    
                               .rempty          (fifo_empty),
                               .afull           (),
                               // Inputs
                               .wdata           (fifo_wr_data),
                               .winc            (fifo_push),
                               .rinc            (fifo_pop),
                               .flush           (1'b0),
                               .clk             (clk_character),
                               .rst             (rst_clk_character));
      
   
   


   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         residue_data <= 32'h0;
         rd_residue_bc <= 2'h0;
         replay_data_mode_fl_gt4 <= 32'h0;
         replay_val_mode_fl_gt4 <= 1'b0;         
      end
      else if(tport_marker_vld == 1'b0) begin
         residue_data <= 32'h0;
         rd_residue_bc <= 2'h0;
         replay_data_mode_fl_gt4 <= 32'h0;
         replay_val_mode_fl_gt4 <= 1'b0;   
      end
      else  begin
         if (insert_eof_r2 || rd_en_r2 || replay_val_mode_fl_gt4) begin
            replay_val_mode_fl_gt4 <= 1'b1 ;  
            residue_data <= replay_ram_rd_data_r;       
            if (insert_eof_r2 == 1'b0) begin
               case (rd_residue_bc)
                 default : replay_data_mode_fl_gt4 <= replay_ram_rd_data_r[31:0]; 
                 1:replay_data_mode_fl_gt4 <= {replay_ram_rd_data_r[23:0],residue_data[31:24]};
                 2:replay_data_mode_fl_gt4 <= {replay_ram_rd_data_r[15:0],residue_data[31:16]};
                 3:replay_data_mode_fl_gt4 <= {replay_ram_rd_data_r[7:0],residue_data[31:08]};
               endcase // case (rd_residue_bc)
            end else begin
               rd_residue_bc <= ((rd_eof_byte_count + rd_residue_bc) > 3'h3) ? (rd_eof_byte_count + rd_residue_bc) - 3'h4 :
                                (rd_eof_byte_count + rd_residue_bc) ;
               case (rd_residue_bc)
                 0:begin
                    case (rd_eof_byte_count)
                      3'h1:replay_data_mode_fl_gt4 <= {replay_ram_rd_data_r[23:0],rd_eof_data[7:0]};
                      3'h2:replay_data_mode_fl_gt4 <= {replay_ram_rd_data_r[15:0],rd_eof_data[15:0]};
                      3'h3:replay_data_mode_fl_gt4 <= {replay_ram_rd_data_r[7:0],rd_eof_data[23:0]};
                      default:replay_data_mode_fl_gt4 <= rd_eof_data[31:0];
                    endcase // case (rd_eof_byte_count)
                 end // case: 0
                 1:begin
                    case (rd_eof_byte_count)
                      3'h1: replay_data_mode_fl_gt4 <= {replay_ram_rd_data_r[15:0],rd_eof_data[7:0],residue_data[31:24]};
                      3'h2: replay_data_mode_fl_gt4 <= {replay_ram_rd_data_r[7:0],rd_eof_data[15:0],residue_data[31:24]};
                      3'h3: replay_data_mode_fl_gt4 <= {rd_eof_data[23:0],residue_data[31:24]};
                      default: begin 
                         replay_data_mode_fl_gt4 <= {rd_eof_data[23:0],residue_data[31:24]};
                         residue_data <= {rd_eof_data[31:24],24'h0};              
                      end
                    endcase // case (rd_eof_byte_count)
                 end // case: 1
                 2:begin
                    case (rd_eof_byte_count)
                      3'h1: replay_data_mode_fl_gt4 <= {replay_ram_rd_data_r[7:0],rd_eof_data[7:0],residue_data[31:16]};
                      3'h2: replay_data_mode_fl_gt4 <= {rd_eof_data[15:0],residue_data[31:16]};
                      3'h3: begin
                         replay_data_mode_fl_gt4 <= {rd_eof_data[15:0],residue_data[31:16]};
                         residue_data <= {rd_eof_data[23:16],24'h0};                            
                      end
                      default: begin 
                         replay_data_mode_fl_gt4 <= {rd_eof_data[15:0],residue_data[31:24]};
                         residue_data <= {rd_eof_data[31:16],16'h0};
                      end
                    endcase // case (rd_eof_byte_count)                 
                 end // case: 2
                 3:begin
                    case (rd_eof_byte_count)
                      3'h1: replay_data_mode_fl_gt4 <= {rd_eof_data[7:0],residue_data[31:08]};
                      3'h2: begin
                         replay_data_mode_fl_gt4 <= {rd_eof_data[7:0],residue_data[31:08]};
                         residue_data <= {rd_eof_data[15:8],24'h0};              
                      end
                      3'h3: begin
                         replay_data_mode_fl_gt4 <= {rd_eof_data[7:0],residue_data[31:08]};
                         residue_data <= {rd_eof_data[23:8],16'h00};              
                      end
                      default: begin
                         replay_data_mode_fl_gt4 <= {rd_eof_data[7:0],residue_data[31:08]};
                         residue_data <= {rd_eof_data[31:8],8'h00};              
                      end
                    endcase // case (rd_eof_byte_count)
                 end // case: 3
               endcase // case (rd_residue_bc)
            end // else: !if(insert_eof_r2 == 1'b0)
         end // if (insert_eof_r2 | (rd_en_r2 & !replay_val_mode_fl_gt4))
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or rst_clk_character)


   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         d2_lid_mux <= 32'h0;
         d2_lid_mux_vld <= 1'b0;
      end
      else begin
         if (frame_length_char < 5) begin
            d2_lid_mux <= replay_data_mode_fl_lt5 ;
            d2_lid_mux_vld <= replay_val_mode_fl_lt5 ;
         end
         else begin
            d2_lid_mux <=  replay_data_mode_fl_gt4;
            d2_lid_mux_vld <= replay_val_mode_fl_gt4;            
         end
      end
   end // always @ (posedge clk_character or posedge rst_clk_character)

   assign replay_ram_rd_en = rd_en;
   
endmodule // jesd_lane_replay



// Local Variables:
// verilog-library-directories:(".")
// End:
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
