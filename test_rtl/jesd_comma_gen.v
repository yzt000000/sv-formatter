

// This module is responsible for generating the code group synchronisation sequence for each lane.
// The length of the code group sequence is either multiple of frame or multiframe depending on the
// subclass.

module jesd_comma_gen (
  input            clk_character,          // primary clock
  input            rst_clk_character,      // primary reset
  input            start_cgs_tx_sync_dec,  // When high indicates that sync_b decode module has decoded a link syncronisation request
  input            start_cgs_tx_fw_req,    // When toggled indicates that firmware has initiated link syncronisation request
  input [1:0]      subclass,               // current subclass value 
  input            active_lane,            // Bit indicating the lane is part of current link
  input            lmfc_boundary,          // Local multiframe counter boundary
  output [31:0]    comma_data,             // 4 octets of transmit data stream  carrying the CGS octets
  output [3:0]     comma_data_k,           // 1 bit corresponding to each octet of comma_data. Indication of whether the chracter is contol character or data 
  output reg [1:0] comma_data_bc,          // indcates number of octets on comma_data that should be packed into Tx data stream . 00 implies all 4 octets should be packed
  output reg       comma_data_vld          // 1 bit control signal indicating valid information on comma_data_* outputs                                                    
);
   
   
      
  localparam COMMA_CODE = 9'h1BC;
  assign comma_data_k = {4{COMMA_CODE[8]}};
  assign comma_data = {4{COMMA_CODE[7:0]}};

               
  always @(posedge clk_character or posedge rst_clk_character) begin
    if (rst_clk_character) begin
      comma_data_vld <= 'h1;
      comma_data_bc <= 2'b00;
    end
    else begin
      comma_data_bc <= 2'b00;
      if (start_cgs_tx_sync_dec || start_cgs_tx_fw_req || !active_lane)
        comma_data_vld <= 1'b1;
      else if (lmfc_boundary || subclass==2'b00)
        comma_data_vld <= 1'b0;
    end // else: !if(rst_clk_character)
  end // always @ (posedge clk_character or posedge rst_clk_character)


endmodule // jesd_comma_gen

//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
