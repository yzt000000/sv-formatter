

// jesd_simple_sync is used to transfer signals across 2 clock domains . If the source signal is combinational
// then one should set the parameter REG_IP=1 and also connect the src_clk pin to the source clock domain
// else REG_IP=0 and src_clk can be left floating.
module jesd_simple_sync
  #(parameter WIDTH=1,
    parameter REG_IP=1)
  (
   input [WIDTH-1:0]  src_signal,
   input              src_clk,
   input              dest_clk, 
   output [WIDTH-1:0] dest_signal                     
   );

   reg [WIDTH-1:0] src_signal_r0,dest_signal_r0,dest_signal_r1;
   
   always @(posedge src_clk)
     src_signal_r0 <= src_signal;

   always @(posedge dest_clk) begin
     if (REG_IP)
       dest_signal_r0 <= src_signal_r0;
     else
       dest_signal_r0 <= src_signal;
     dest_signal_r1 <= dest_signal_r0;
   end
   
   assign dest_signal = dest_signal_r1;   
endmodule // jesd_simple_sync

//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
