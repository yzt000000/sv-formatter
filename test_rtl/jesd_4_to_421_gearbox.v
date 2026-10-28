

// This module operates in clk_serdes domain and takes care of ensuring that
// 4 consecutive symbols  clubbed together are presented to the next stage as per the// size of the interface of serdes moudle. The size of the output bus can be 1,2,4 symbols
module jesd_4_to_421_gearbox
  #(
   //! Valid values 1,2,4 . 
   parameter NO_SERDES_WORDS = 1,
   parameter WORD_SIZE = 10
   )
   (
    input                                        clk_serdes,       // primary clock
    input                                        rst_clk_serdes,   // async reset
    input [(4*WORD_SIZE)-1:0]                    data_in,          // 4 symbols of input data
    input                                        data_in_vld,      // 1 bit control signal indicating the presence valid symbols on data_in
    output reg                                   data_in_rdy,      // 1 bit handshake signal to request new set of symbols on data_in
    output reg                                   serdes_symbol_vld, //1 bit control signal indicating the presence valid symbol(s) on serdes_symbol. Negated version should be connected to txelecidle 
    output reg [(NO_SERDES_WORDS*WORD_SIZE)-1:0] serdes_symbol // 1, 2, 4 symbols of output data
   );

   generate
      if (NO_SERDES_WORDS == 4) begin :NO_SERDES_WORDS_1
         always @ (posedge clk_serdes or posedge rst_clk_serdes) begin
            if (rst_clk_serdes) begin
               data_in_rdy <= 1'b0;
               serdes_symbol_vld <= 1'b0;
               serdes_symbol <= 'h0;
            end
            else begin
               serdes_symbol <= data_in;
               serdes_symbol_vld <= data_in_vld;
               data_in_rdy <= data_in_vld;
            end
         end
      end
      else if (NO_SERDES_WORDS == 2) begin :NO_SERDES_WORDS_2 // NO_SERDES_WORDS == 1 or 2
         reg [39:0] data_in_r;
         always @ (posedge clk_serdes or posedge rst_clk_serdes) begin
            if (rst_clk_serdes) begin
               data_in_r <= 'h0;
               data_in_rdy <= 1'b0;
               serdes_symbol_vld <= 1'b0;
               serdes_symbol <= 'h0;
            end
            else begin
               case (data_in_rdy)
                 1:begin
                    serdes_symbol <= data_in_r[39:20];
                    data_in_rdy <= 1'b0;
                    serdes_symbol_vld <= 1'b1;                                                                         
                 end
                 default:begin
                    serdes_symbol <= data_in[19:00];
                    data_in_rdy <= data_in_vld;
                    data_in_r <= data_in;
                    serdes_symbol_vld <= data_in_vld;                       
                 end
               endcase // case (data_in_rdy)                  
            end // else: !if(rst_clk_serdes)
         end // always @ (posedge clk_serdes or posedge rst_clk_serdes)
      end // if (NO_SERDES_WORDS == 2)
      else begin : NO_SERDES_WORDS_DEF 
         reg [1:0] data_cnt;
         reg [39:0] data_in_r;
         always @ (posedge clk_serdes or posedge rst_clk_serdes) begin
            if (rst_clk_serdes) begin
               data_in_rdy <= 1'b0;
               data_cnt <= 3'h0;
               serdes_symbol_vld <= 1'b0;
               serdes_symbol <= 'h0;
               data_in_r <= 'h0;
            end
            else begin
               case (data_cnt)
                 3:begin
                    serdes_symbol <= data_in_r[39:30];
                    data_in_rdy <= 1'b0;
                    serdes_symbol_vld <= 1'b1;
                    data_cnt <= 2'b00;                       
                 end
                 2:begin
                    serdes_symbol <= data_in_r[29:20];
                    data_in_rdy <= 1'b0;
                    serdes_symbol_vld <= 1'b1;
                    data_cnt <= 2'b11;                                              
                 end
                 1:begin
                    serdes_symbol <= data_in_r[19:10];
                    data_in_rdy <= 1'b0;
                    serdes_symbol_vld <= 1'b1;                       
                    data_cnt <= 2'b10;                                                                     
                 end
                 default:begin
                    serdes_symbol <= data_in[09:00];
                    data_in_rdy <= data_in_vld;
                    data_in_r <= data_in;
                    serdes_symbol_vld <= data_in_vld;                       
                    data_cnt <= data_in_vld ? 2'b01 : 2'b00;
                 end
               endcase // case (data_cnt)
            end // else: !if(rst_clk_serdes)
         end // always @ (posedge clk_serdes or posedge rst_clk_serdes)
      end // else: NO_SERDES_WORDS_DEF 
   endgenerate
   
endmodule // jesd_4_to_421_gearbox
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
