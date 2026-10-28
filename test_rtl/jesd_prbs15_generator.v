

module jesd_prbs15_generator (
  input                             rst_clk_character,
  input                             prbs_test_enable_reg,
  input                             clk_character,
  
  output[31:0]                      prbs_data,
  output[3:0]                       prbs_k,
  output reg                        prbs_vld
);
  reg [31:0] bus32;
  reg [3:0] bus32_k;
  reg [14:0] prbs;

  assign prbs_k = bus32_k;

  wire[31:0] calculated_prbs_15;
  assign   prbs_data=bus32;


  assign calculated_prbs_15[31]= prbs[14]^prbs[13];
  assign calculated_prbs_15[30]= prbs[13]^prbs[12];
  assign calculated_prbs_15[29]= prbs[12]^prbs[11];
  assign calculated_prbs_15[28]= prbs[11]^prbs[10];
  assign calculated_prbs_15[27]= prbs[10]^prbs[9];
  assign calculated_prbs_15[26]= prbs[9]^prbs[8];
  assign calculated_prbs_15[25]= prbs[8]^prbs[7];
  assign calculated_prbs_15[24]= prbs[7]^prbs[6];
  assign calculated_prbs_15[23]= prbs[6]^prbs[5];
  assign calculated_prbs_15[22]= prbs[5]^prbs[4];
  assign calculated_prbs_15[21]= prbs[4]^prbs[3];
  assign calculated_prbs_15[20]= prbs[3]^prbs[2];
  assign calculated_prbs_15[19]= prbs[2]^prbs[1];
  assign calculated_prbs_15[18]= prbs[1]^prbs[0];
  assign calculated_prbs_15[17]= prbs[0]^calculated_prbs_15[31];
  assign calculated_prbs_15[16]= calculated_prbs_15[31]^calculated_prbs_15[30];
  assign calculated_prbs_15[15]= calculated_prbs_15[30]^calculated_prbs_15[29];
  assign calculated_prbs_15[14]= calculated_prbs_15[29]^calculated_prbs_15[28];
  assign calculated_prbs_15[13]= calculated_prbs_15[28]^calculated_prbs_15[27];
  assign calculated_prbs_15[12]= calculated_prbs_15[27]^calculated_prbs_15[26];  
  assign calculated_prbs_15[11]= calculated_prbs_15[26]^calculated_prbs_15[25];
  assign calculated_prbs_15[10]= calculated_prbs_15[25]^calculated_prbs_15[24];    
  assign calculated_prbs_15[9]= calculated_prbs_15[24]^calculated_prbs_15[23];
  assign calculated_prbs_15[8]= calculated_prbs_15[23]^calculated_prbs_15[22];
  assign calculated_prbs_15[7]= calculated_prbs_15[22]^calculated_prbs_15[21];
  assign calculated_prbs_15[6]= calculated_prbs_15[21]^calculated_prbs_15[20];
  assign calculated_prbs_15[5]= calculated_prbs_15[20]^calculated_prbs_15[19];
  assign calculated_prbs_15[4]= calculated_prbs_15[19]^calculated_prbs_15[18];
  assign calculated_prbs_15[3]= calculated_prbs_15[18]^calculated_prbs_15[17];              
  assign calculated_prbs_15[2]= calculated_prbs_15[17]^calculated_prbs_15[16];              
  assign calculated_prbs_15[1]= calculated_prbs_15[16]^calculated_prbs_15[15];
  assign calculated_prbs_15[0]= calculated_prbs_15[15]^calculated_prbs_15[14];
    


  // function [3:0] calculate_k (input[31:0] data);
  // begin
  //   if(data[7:0]=='hfc || data[7:0]=='h7c || data[7:0]=='hbc ||data[7:0]=='h1c || data[7:0]=='h3c|| data[7:0]=='h5c||data[7:0]=='h9c|| data[7:0]=='hdc|| data[7:0]=='hf7|| data[7:0]=='hfb|| data[7:0]=='hfd || data[7:0]=='hfe)
  //    calculate_k[0]='h1;
  //   else
  //    calculate_k[0]='h0;
  //   if(data[15:8]=='hfc || data[15:8]=='h7c || data[15:8]=='hbc ||data[15:8]=='h1c || data[15:8]=='h3c|| data[15:8]=='h5c||data[15:8]=='h9c|| data[15:8]=='hdc|| data[15:8]=='hf7|| data[15:8]=='hfb|| data[15:8]=='hfd || data[15:8]=='hfe)
  //    calculate_k[1]='h1;
  //   else
  //    calculate_k[1]='h0;
  //   if(data[23:16]=='hfc || data[23:16]=='h7c || data[23:16]=='hbc ||data[23:16]=='h1c || data[23:16]=='h3c|| data[23:16]=='h5c||data[23:16]=='h9c|| data[23:16]=='hdc|| data[23:16]=='hf7|| data[23:16]=='hfb|| data[23:16]=='hfd || data[23:16]=='hfe)     
  //    calculate_k[2]='h1;
  //   else
  //    calculate_k[2]='h0;
  //   if(data[31:24]=='hfc || data[31:24]=='h7c || data[31:24]=='hbc ||data[31:24]=='h1c || data[31:24]=='h3c|| data[31:24]=='h5c||data[31:24]=='h9c|| data[31:24]=='hdc|| data[31:24]=='hf7|| data[31:24]=='hfb|| data[31:24]=='hfd || data[31:24]=='hfe)    
  //    calculate_k[3]='h1;
  //   else
  //    calculate_k[3]='h0;
  // end
  //endfunction

  //reg [17:0] calculated_prbs_15_r;='hFFFFFFFF;
  //genvar j;
  //generate
  //for (j=0;j<4;j=j+1)begin
  always@(posedge clk_character or posedge rst_clk_character)
  begin
    if (rst_clk_character) begin
      bus32    <='hffffffff;
      prbs_vld <='h0;
      bus32_k  <='h0;
      prbs     <='h7FFF;
    end
    else begin
      if (~prbs_test_enable_reg) begin
        bus32    <='hffffffff;
        prbs_vld <='h0;
        bus32_k  <='h0;
        prbs     <='h7FFF;
      end
      else
      begin 
        bus32      <= {prbs,calculated_prbs_15[31:15]};
        prbs_vld   <='h1;
        prbs[14:0] <=calculated_prbs_15[14:0];
      end
    end
  end
    

endmodule
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
