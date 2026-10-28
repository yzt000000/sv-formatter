

// This module is used as a building block to create Read on Clear statistical counters.It relies on toggle interface rd_req , rd_ack pair to determine
// a read access. The signal incr_count[3:0] allows the internal counter to be incremented by up to 4 counts (as the datapath is 4 octets wide)
// If the counters reach the max value , the implemented logic takes care of preveinting a rollover.
module jesd_rc_counter
  #(parameter COUNTER_WIDTH=32)
  ( input clk_character,   // clk domain for source of statistical counter increment logic
    input             rst_clk_character, // primary reset
    input [3:0]       incr_count, // control signal clk_character domain. A value of 1 on a bit indicates increment the counter by 1. Thus max increment per clock is 4
    input             clk_cpu, // Register read clock 
    output reg [COUNTER_WIDTH-1:0] counter, // Value of counter should be used when rd_ack signal value changes to match the rd_req signal

    // Toggle interface req ack pair . Request is  active if req != ack
    input             rd_req, //clk_cpu
    output wire       rd_ack //clk_cpu

   );
   reg [COUNTER_WIDTH-1:0]         int_counter;
   wire [COUNTER_WIDTH:0]          int_counter_nxt;
   localparam DELTA_WIDTH = COUNTER_WIDTH == 1 ? 1 : 3;
   wire [DELTA_WIDTH-1:0]          delta;
   assign delta = COUNTER_WIDTH == 1? incr_count[0]: incr_count[0] + incr_count[1] + incr_count[2] + incr_count[3];   
//    generate begin : width_block
//       if (COUNTER_WIDTH == 1) 
//          assign delta = incr_count[0];
//       else
//          assign delta = incr_count[0] + incr_count[1] + incr_count[2] + incr_count[3];
//    end
//    endgenerate
   
   reg                rd_req_sync_r0;
   wire               rd_req_sync;

   assign int_counter_nxt =  {1'b0, int_counter} + {{(COUNTER_WIDTH+1-DELTA_WIDTH){1'b0}}, delta};
        
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         int_counter <= 'h0;
         rd_req_sync_r0 <= 1'b0;
         counter <= {COUNTER_WIDTH{1'b0}};                  
      end
      else begin
         rd_req_sync_r0 <= rd_req_sync;
         if (rd_req_sync ^ rd_req_sync_r0) begin
            int_counter <= delta;
            counter <= int_counter;
          end
//         else if (int_counter_nxt < {1'b1,{COUNTER_WIDTH{1'b0}}}) // prevent overflows
         else if (int_counter_nxt[COUNTER_WIDTH] == 1'b0) // prevent overflows
           int_counter <= int_counter_nxt[COUNTER_WIDTH-1:0];
         else int_counter <= {COUNTER_WIDTH{1'b1}};
      end
   end // always @ (posedge clk_character or posedge rst_clk_character)

   

   jesd_simple_sync #(.REG_IP(0))
   req_sync (.src_signal (rd_req),
             .src_clk    (1'b0),
             .dest_clk   (clk_character), 
             .dest_signal (rd_req_sync)
             );
                     


   jesd_simple_sync #(.REG_IP(0))
   ack_sync (.src_signal (rd_req_sync_r0),
             .src_clk    (1'b0),
             .dest_clk   (clk_cpu), 
             .dest_signal (rd_ack)
             );
                     
endmodule // jesd_rc_counter
                     
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
