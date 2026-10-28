

// This module operates in clk_serdes domain and takes care of ensuring that
// 4 consecutive symbols are clubbed together and presented to the next stage
// The size of the input bus can be 1,2,4 symbols
module jesd_421_to_4_gearbox
  #(
   //! Valid values 1,2,4 . 
   parameter NO_SERDES_WORDS = 1,
   parameter WORD_SIZE = 10
   )
   (input                                   clk_serdes,        // primary clock
    input                                   rst_clk_serdes,    // async reset
    input                                   serdes_symbol_vld, // lh edge indicates start of received symbol stream, value of 0 indicates reset restart counting of symbols
    input [(NO_SERDES_WORDS*WORD_SIZE)-1:0] serdes_symbol,     // actual symbol input from serdes module
    output [(4*WORD_SIZE)-1:0]              data_out,          // 4 symbos clubbed together
    output                                  data_out_vld       // lh edge indicates start of received symbol stream, value of 0 indicates break in input data stream
   );


   
   generate
   if (NO_SERDES_WORDS == 4) begin : NO_SERDES_WORDS_4
      assign data_out = serdes_symbol;
      assign data_out_vld = serdes_symbol_vld;      
   end
   else begin :NO_SERDES_WORDS_1_2 // NO_SERDES_WORDS == 1 or 2
      reg  [2:0] curr_cnt;
      wire [2:0] RATIO = (NO_SERDES_WORDS == 2) ? 2 : 4; // changed localparam to wire as we had issues with xilinx ISE. Indicates Ratio of OP width to ip width
      assign data_out_vld = (curr_cnt == 4) ? 1'b1 : 1'b0;
      
      always @ (posedge clk_serdes or posedge rst_clk_serdes) begin
         if (rst_clk_serdes) begin
            curr_cnt <= 3'b000;            
         end
         else if (serdes_symbol_vld) begin
            if (data_out_vld)
              curr_cnt <= NO_SERDES_WORDS;
            else
              curr_cnt <= curr_cnt + NO_SERDES_WORDS;
         end
         else
           curr_cnt <= 3'b000;                       
      end // always @ (posedge clk_serdes or posedge rst_clk_serdes)

      reg [(NO_SERDES_WORDS*WORD_SIZE)-1:0] serdes_symbol_0,serdes_symbol_1,serdes_symbol_2,serdes_symbol_3;
      
      always @ (posedge clk_serdes or posedge rst_clk_serdes) begin
         if (rst_clk_serdes) begin
            serdes_symbol_0 <= 'h0;
            serdes_symbol_1 <= 'h0;
            serdes_symbol_2 <= 'h0;
            serdes_symbol_3 <= 'h0;
         end
         else if (serdes_symbol_vld) begin
            serdes_symbol_0 <= serdes_symbol;
            serdes_symbol_1 <= serdes_symbol_0;
            serdes_symbol_2 <= serdes_symbol_1;            
            serdes_symbol_3 <= serdes_symbol_2;            
         end     
      end

      reg [(4*WORD_SIZE)-1:0]              data_out_temp;
      
      assign data_out = data_out_temp;
      always @(*) begin
         if (NO_SERDES_WORDS == 2)
            data_out_temp = {serdes_symbol_0,serdes_symbol_1};
         else
           data_out_temp = {serdes_symbol_0,serdes_symbol_1,serdes_symbol_2,serdes_symbol_3};
      end
   end // else: !if(RATIO == 1)
   endgenerate
   
endmodule // jesd_421_to_4_gearbox
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
