

// This module serves as a shell module to instantiate the per lane replay logic. It also incorporates the logic to map a physical lane to a logical lane using the value
// programmed in txrx_lid_reg 
module jesd_replay_lid_mux #(parameter JESD_NO_LANES=8)
  (
   input                            clk_character,       // Primary clock
   input                            rst_clk_character,   // Primary reset
   input [8:0]                      frame_length_char,   // Length of frame in octets
   input [7:0]                      active_lane,         // Control signal representing which lane is part of the link 
   input [5*JESD_NO_LANES-1:0]      txrx_lid_reg,        // Register with details on which physical lane should be mapped to which logical lane
   input                            rx_tvalid,           // Control signal from link layer indicating valid user data/frame markers available on inputs rx_
   input [(4*JESD_NO_LANES)-1:0]     rx_frame_error,      // 1 bit per octet per lane to indicate the reception status. When high indicates the corresponding octet is bad.This marker leads the rx_tdata by one clock.
   input [3:0]                      rx_end_of_frame,     // 1 bit per octet per lane to indicate octet position in frame. When high indicates the corresponding octet is last octet. This marker leads the rx_tdata by one clock.
   input [3:0]                      rx_start_of_frame,   // 1 bit per octet per lane to indicate octet position in frame. When high indicates the corresponding octet is first octet. This marker leads the rx_tdata by one clock.
   input [(32*JESD_NO_LANES)-1:0]    rx_tdata,            // 4 octets of user data stream per lane
   input [(32*JESD_NO_LANES)-1:0]    replay_ram_rd_data,  

   output [32*JESD_NO_LANES-1:0]     replay_ram_wr_data,
   output [6:0]                     replay_ram_write_addr,
   output [6:0]                     replay_ram_read_addr,
   output                           replay_ram_write_en,
   output                           replay_ram_read_en,
   output reg [32*JESD_NO_LANES-1:0] data_to_tl,
   output reg                       data_to_tl_vld
   );
   

  
  
      
   wire [(32*JESD_NO_LANES)-1:0] d2_lid_mux;      
   wire [7*JESD_NO_LANES-1:0]  replay_ram_wr_addr,replay_ram_rd_addr;
   wire [JESD_NO_LANES-1:0]    replay_ram_rd_en,replay_ram_wr_en,combined_error_in_frame_o,d2_lid_mux_vld,replay_ctl_fifo_full;
   wire [4*JESD_NO_LANES-1:0]    combined_byte_en_o;
  
  function integer lid_calculate (input integer LANE_NUMBER);

    if (LANE_NUMBER >18)
      lid_calculate = 4;
    else if (LANE_NUMBER >12)
      lid_calculate = 3;
    else if (LANE_NUMBER > 6)
      lid_calculate = 2;
    else 
      lid_calculate = 1;
  endfunction
  
  localparam LID_REG_SIZE = lid_calculate (JESD_NO_LANES);
  wire [(32*LID_REG_SIZE*6)-1:0] d2_lid_mux_pad;
   
   // Use only outputs of physical lane 0
   assign replay_ram_write_addr = replay_ram_wr_addr[6:0];
   assign replay_ram_read_addr = replay_ram_rd_addr[6:0];
   assign replay_ram_write_en = replay_ram_wr_en[0];
   assign replay_ram_read_en = replay_ram_rd_en[0];
   
   reg                          rx_tvalid_r;
   
   always @(posedge clk_character or posedge rst_clk_character) begin
       if (rst_clk_character) begin
          rx_tvalid_r <= 1'b0;
          data_to_tl_vld <= 1'b0;
       end
       else begin
          rx_tvalid_r <= rx_tvalid;
          data_to_tl_vld <= d2_lid_mux_vld[0];
       end
    end
   
   wire [31:0] tport_byte_en;
   generate if (JESD_NO_LANES < 24) begin : no_lanes_not_8
      assign tport_byte_en = {{(8-JESD_NO_LANES)*4{1'b1}},~rx_frame_error};
      assign d2_lid_mux_pad = {{(8-JESD_NO_LANES)*32{1'b0}},d2_lid_mux};
   end
   endgenerate

   generate if (JESD_NO_LANES == 24) begin : no_lanes_8
      assign tport_byte_en = ~rx_frame_error;
      assign d2_lid_mux_pad = d2_lid_mux;
   end
   endgenerate      
   
genvar ln_cnt;
   generate for (ln_cnt = 0; ln_cnt < JESD_NO_LANES; ln_cnt = ln_cnt + 1) begin : lane_generate
      

      
   jesd_lane_replay #(
                    // Parameters
                    .ERR_COMBINING            ((ln_cnt == 0) ? 1 : 0))
     jesd_lane_replay (
                      // Outputs
                      .replay_ram_wr_data(replay_ram_wr_data[31+(ln_cnt*32):ln_cnt*32]),
                      .replay_ram_rd_addr(replay_ram_rd_addr[6+(ln_cnt*7):ln_cnt*7]),
                      .replay_ram_wr_addr(replay_ram_wr_addr[6+(ln_cnt*7):ln_cnt*7]),
                      .replay_ram_wr_en (replay_ram_wr_en[ln_cnt]),
                      .replay_ram_rd_en (replay_ram_rd_en[ln_cnt]),                      
                      .combined_byte_en_o(combined_byte_en_o[3+(ln_cnt*4):ln_cnt*4]),
                      .combined_error_in_frame_o(combined_error_in_frame_o[ln_cnt]),
                      .replay_ctl_fifo_full(replay_ctl_fifo_full[ln_cnt]),
                      .d2_lid_mux   (d2_lid_mux[31+(ln_cnt*32):ln_cnt*32]),
                      .d2_lid_mux_vld(d2_lid_mux_vld[ln_cnt]),
                      // Inputs
                      .clk_character    (clk_character),
                      .rst_clk_character(rst_clk_character),
                      .frame_length_char(frame_length_char[8:0]),
                      .active_lane      (active_lane[7:0]),
                      .tport_marker_vld (rx_tvalid),
                      .tport_byte_en    (tport_byte_en),
                      .tport_data_eof   (rx_end_of_frame),
                      .tport_data_sof   (rx_start_of_frame),
                      .tport_data       (rx_tdata[31+(ln_cnt*32):ln_cnt*32]),
                      .tport_data_vld   (rx_tvalid_r),
                      .combined_byte_en_i(combined_byte_en_o[3:0]),
                      .combined_error_in_frame_i(combined_error_in_frame_o[0]),
                      .replay_ram_rd_data(replay_ram_rd_data[31+(ln_cnt*32):ln_cnt*32]));

        if (ln_cnt<6)             
        begin
          always @(posedge clk_character or posedge rst_clk_character) begin
            if (rst_clk_character) begin
              data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= 32'h0;               
            end
            else begin
              case (txrx_lid_reg[4+(ln_cnt*5):(ln_cnt*5)])         
                default:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*0):32*0];
                  5'h1:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*1):32*1];
                  5'h2:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*2):32*2];
                  5'h3:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*3):32*3];
                  5'h4:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*4):32*4];
                  5'h5:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*5):32*5];
                endcase // case (txrx_lid_reg[3+(ln_cnt*4):(ln_cnt*4)])
            end
         end
        end
        if (JESD_NO_LANES >5)
          begin
          if (ln_cnt>5 && ln_cnt <12)
            begin
            always @(posedge clk_character or posedge rst_clk_character) begin
              if (rst_clk_character) begin
                data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= 32'h0;               
              end
              else begin
                case (txrx_lid_reg[4+(ln_cnt*5):(ln_cnt*5)])         
                    5'h6:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*6):32*6];               
                    5'h7:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*7):32*7];              
                    5'h8:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*8):32*8];              
                    5'h9:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*9):32*9];              
                    5'ha:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*10):32*10];              
                    5'hb:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*11):32*11];                               
                endcase // case (txrx_lid_reg[3+(ln_cnt*4):(ln_cnt*4)])
              end
            end
          end  
        end         
        if (JESD_NO_LANES >11)
        begin
          if (ln_cnt>11 && ln_cnt <18)
          begin
            always @(posedge clk_character or posedge rst_clk_character) begin
              if (rst_clk_character) begin
                data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= 32'h0;               
              end
              else begin
                case (txrx_lid_reg[4+(ln_cnt*5):(ln_cnt*5)])              
                 5'hc:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*12):32*12];                             
                 5'hd:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*13):32*13];              
                 5'he:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*14):32*14];              
                 5'hf:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*15):32*15];                       
                 5'h10:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*16):32*16];              
                 5'h11:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*17):32*17];              
                endcase // case (txrx_lid_reg[3+(ln_cnt*4):(ln_cnt*4)])
              end
            end       
          end
        end
        if (JESD_NO_LANES >17)
        begin
          if (ln_cnt > 17)          
          begin
            always @(posedge clk_character or posedge rst_clk_character) begin
              if (rst_clk_character) begin
                data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= 32'h0;               
              end
              else begin
                case (txrx_lid_reg[4+(ln_cnt*5):(ln_cnt*5)])              
                 5'h12:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*18):32*18];                             
                 5'h13:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*19):32*19];              
                 5'h14:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*20):32*20];              
                 5'h15:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*21):32*21];              
                 5'h16:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*22):32*22];              
                 5'h17:data_to_tl[31+(ln_cnt*32):ln_cnt*32] <= d2_lid_mux_pad[31+(32*23):32*23];              
                endcase // case (txrx_lid_reg[3+(ln_cnt*4):(ln_cnt*4)])
              end
            end             
          end
        end
   end endgenerate

                                                          
endmodule // jesd_replay_lid_mux
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
