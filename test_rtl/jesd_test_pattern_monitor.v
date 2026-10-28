

module jesd_test_pattern_monitor
  (
   input            clk_character,
   input            rst_clk_character,
   input [1:0]      test_mode, 

   //Following inputs are straight from decoder output
   input [31:0]     rxdata,
   input [03:0]     rxdata_k, 
   input            rxdata_vld,
   input [3:0]      rxdisparity_err,
   input [3:0]      rxnot_in_table_err,
   // Following input is from lane alignment & frame alignment monitor
   input [3:0]      scr_data_eof,

   output reg [3:0] incr_comma_frame_count,
   output reg [3:0] incr_err_count
   );

   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character)
        incr_err_count <= 4'h0;
      else if (((test_mode == 2'h2) || (test_mode == 2'h1)) & rxdata_vld)
        incr_err_count <= rxdisparity_err | rxnot_in_table_err;
   end

   
      

   wire [3:0]     raw_valid_data;  
   assign raw_valid_data[0] = rxdata_vld & ~rxdisparity_err[0] & ~rxnot_in_table_err[0];
   assign raw_valid_data[1] = rxdata_vld & ~rxdisparity_err[1] & ~rxnot_in_table_err[1];
   assign raw_valid_data[2] = rxdata_vld & ~rxdisparity_err[2] & ~rxnot_in_table_err[2];
   assign raw_valid_data[3] = rxdata_vld & ~rxdisparity_err[3] & ~rxnot_in_table_err[3];

   wire [3:0]       valid_k_28_5;
   assign valid_k_28_5[0] =  raw_valid_data[0] & (rxdata[07:00] == 8'hBC) & rxdata_k[0];
   assign valid_k_28_5[1] =  raw_valid_data[1] & (rxdata[15:08] == 8'hBC) & rxdata_k[1];
   assign valid_k_28_5[2] =  raw_valid_data[2] & (rxdata[23:16] == 8'hBC) & rxdata_k[2];
   assign valid_k_28_5[3] =  raw_valid_data[3] & (rxdata[31:24] == 8'hBC) & rxdata_k[3];   

   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character)
        incr_comma_frame_count <= 4'h0;
      else if ((test_mode == 2'h1) & rxdata_vld)
        incr_comma_frame_count <= valid_k_28_5;
      else if ((test_mode == 2'h2))
        incr_comma_frame_count <= scr_data_eof;      
   end
      
endmodule // jesd_test_pattern_monitor

// Local Variables:
// verilog-library-directories:(".")
// End:
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
