



module ram_2_clk_1wr1r

#(parameter DWID =32,
 parameter DEP =1024,
 parameter AWID =10)
 
 (
 //write ports
 input             clk_a,
 input             wen_a_i,
 input  [AWID-1:0] addr_a_i,
 input  [DWID-1:0] wdata_a_i,
 //Read ports
 input             clk_b,
 input             ren_b_i,
 input  [AWID-1:0] addr_b_i,
 output [DWID-1:0] rdata_b_o
 );
 
 reg [DWID-1:0] ram [DEP-1:0];
 
 // Port a
 always @(posedge clk_a)
 begin
  if(wen_a_i)
  begin
   ram [addr_a_i] <= wdata_a_i;
  end
 end
 
// always @(posedge clk_b)
// begin
//  if (ren_b_i)
//  begin
assign   rdata_b_o = ram [addr_b_i];
 // end
//end
	
endmodule
 
  
	
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
