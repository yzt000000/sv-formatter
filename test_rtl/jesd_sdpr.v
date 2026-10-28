

// This module serves as single clock SRAM with independent read write ports.It is used for storing per lane data stream for deskew purposes 
// and combined data stream for replay buffer
module jesd_sdpr (
clk       , // Clock Input
wr_addr , // Write Address Input
wr_data    , // Write Data Input
wr_en      , // Write Enable Input
rd_addr , // Read Address Input
rd_en  ,     // Read Enable Input
rd_data  // Read Data Output

); 

parameter DSIZE = 8 ;
parameter ASIZE = 8 ;
parameter RAM_DEPTH = 1 << ASIZE;

   input clk;
   
input [ASIZE-1:0] wr_addr ;
input wr_en ;
input [DSIZE-1:0] wr_data ; 
input [ASIZE-1:0] rd_addr ;
input rd_en ;
output reg [DSIZE-1:0] rd_data ;
reg [DSIZE-1:0] mem [0:RAM_DEPTH-1];
`ifdef VENDOR_RAM
   initial begin
      $display ("%m Block RAM code is not added yet");
      $finish;      
   end
`else
// Memory Write Block 

always @ (posedge clk)
begin : MEM_WRITE
  if (wr_en ) begin
     mem[wr_addr] <= wr_data;
  end
end

  

// Memory Read Block 
always @ (posedge clk)
  begin : MEM_READ
     if (rd_en) begin
        rd_data <= mem[rd_addr]; 
     end else begin
        rd_data <= 'h0; 
     end  
  end
   
`endif   
endmodule // End of Module jesd_sdpr

//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
