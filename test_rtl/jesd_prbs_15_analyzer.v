

module jesd_prbs_15_analyzer (

 input                            prbs_test_enable_reg,
 input                             clk_character,
 input                             rst_clk_character,
 
 input[31:0]                       prbs_data,
 input                             prbs_vld,
 output [3:0]                  prbs_vld_count,
 output [3:0]                  prbs_err_count
  );
 reg prbs_ok;
 reg [31:0] prbs_last;
 reg [15:0] prbs_count;
 reg [15:0] prbs_ok_count;
 reg [3:0] prbs_vld_count_r;
 reg [3:0] prbs_err_count_r;
 
 assign prbs_vld_count=prbs_vld_count_r;
 assign prbs_err_count=prbs_err_count_r;
 
 always@(posedge clk_character or posedge rst_clk_character)
  if (rst_clk_character)
   prbs_last <= 'h0;
  else
   prbs_last <= prbs_data;
 
 wire [31:0] calculated_prbs_15;
 

  assign calculated_prbs_15[31]= prbs_last[14]^prbs_last[13];
  assign calculated_prbs_15[30]= prbs_last[13]^prbs_last[12];
  assign calculated_prbs_15[29]= prbs_last[12]^prbs_last[11];
  assign calculated_prbs_15[28]= prbs_last[11]^prbs_last[10];
  assign calculated_prbs_15[27]= prbs_last[10]^prbs_last[9];
  assign calculated_prbs_15[26]= prbs_last[9]^prbs_last[8];
  assign calculated_prbs_15[25]= prbs_last[8]^prbs_last[7];
  assign calculated_prbs_15[24]= prbs_last[7]^prbs_last[6];
  assign calculated_prbs_15[23]= prbs_last[6]^prbs_last[5];
  assign calculated_prbs_15[22]= prbs_last[5]^prbs_last[4];
  assign calculated_prbs_15[21]= prbs_last[4]^prbs_last[3];
  assign calculated_prbs_15[20]= prbs_last[3]^prbs_last[2];
  assign calculated_prbs_15[19]= prbs_last[2]^prbs_last[1];
  assign calculated_prbs_15[18]= prbs_last[1]^prbs_last[0];
  assign calculated_prbs_15[17]= prbs_last[0]^calculated_prbs_15[31];
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
 
 always @(posedge clk_character or posedge rst_clk_character)
  if (rst_clk_character)
   prbs_ok <= 1'b0;
  else
   prbs_ok <= (prbs_data == calculated_prbs_15);
 
 always @(posedge clk_character or posedge rst_clk_character)
  if (rst_clk_character)
   begin
    prbs_count<='h0;
    prbs_ok_count<='h0;
    prbs_vld_count_r<='h0;
    prbs_err_count_r<='h0;
   end
  else
   if (~prbs_test_enable_reg) begin
    prbs_count<='h0;
    prbs_ok_count<='h0;
    prbs_vld_count_r<='h0;
    prbs_err_count_r<='h0;
   end
   else begin
    if (prbs_vld_count_r=='h1)
     prbs_vld_count_r <='h0;
    if (prbs_err_count_r=='h1)
     prbs_err_count_r <='h0;
    prbs_count<=prbs_count+'h1;
    if (prbs_ok)
      prbs_ok_count <= prbs_ok_count+'h1;
    else
    begin
      prbs_ok_count <= 'h0;
    end
    if (prbs_count==15'h7fff)
    begin
      prbs_count<='h0;
      if (prbs_ok_count>=15'h7ffe)
      begin
       prbs_vld_count_r<=prbs_vld_count_r +'h1;
      end
      else
      begin
      prbs_err_count_r <= prbs_err_count_r + 'h1;
      end
      prbs_ok_count<= 'h0;
    end
  end
 
endmodule

//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
