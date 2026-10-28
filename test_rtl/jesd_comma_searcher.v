


module jesd_comma_searcher #(parameter DATA_WIDTH = 4)
   (  
      input                                rst_i,
      input                                clk_i,
      input [ (DATA_WIDTH*10)-1 : 0 ]      data_i,
      input                                disable_i,
      output reg [ (DATA_WIDTH*10)-1 : 0 ] data_o,
      output [3:0]                         stat_delay_o
      );
   
  localparam COMMA_POS = 7'b1111100;
  localparam COMMA_NEG = 7'b0000011;

   
   reg [ ((DATA_WIDTH+1)*10)-1 : 0 ]   data_i_del;
   reg [ 3 : 0 ]                       int_delay;               // Measured bit delay to obtain alignment

   integer comma_ptr;
   integer i;   


   reg [6:0] tmp [9:0];
   
   
   always @*
     begin   // Find the comma and calculate the delay
        comma_ptr = int_delay;
        for (i = 0; i < 10; i = i+1 )
          begin
             tmp[i] = data_i_del >> (i);                               
             if ( (tmp[i] == COMMA_POS) || (tmp[i] == COMMA_NEG))
               comma_ptr = i;
          end   
     end        

   always @(posedge clk_i or posedge rst_i)
     begin 
        if ( rst_i )
          begin
             data_i_del <= 'h0;
             int_delay  <= 'h0;
          end
        else 
          begin   // Find the comma and calculate the delay
             data_i_del <= {data_i,data_i_del[ (DATA_WIDTH+1)*10-1 : DATA_WIDTH*10 ]};
             if ( !disable_i )
               int_delay <= comma_ptr;
          end
     end
   
   
   always @(posedge clk_i or posedge rst_i)
     begin
        if ( rst_i )
          data_o <= 'h0;
        else
          if (int_delay != 0)
            data_o <= data_i_del >> int_delay;
          else
            data_o <= data_i;
     end
   
  assign stat_delay_o = int_delay;

endmodule


//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
