

// The content of the mem array in this module needs to be modified according to the requirements of the 50 octet JTSPAT pattern
module jesd_ctp_rom (
  clk       , // Clock Input
  rst       , // Clock Input
  rd_addr , // Read Address Input
  rd_en  ,     // Read Enable Input
  rd_data  // Read Data Output
); 
  parameter DSIZE = 8 ;
  parameter ASIZE = 8 ;
  parameter ROM_DEPTH = 1 << ASIZE;

  input clk;
  input rst;
   
  input [ASIZE-1:0] rd_addr ;
  input rd_en ;
  output reg [DSIZE-1:0] rd_data ;

  wire [DSIZE-1:0] mem [0:ROM_DEPTH-1];
  //`ifdef VENDOR_RAM
  //   initial begin
  //      $display ("%m Block ROM code is not added yet");
  //      $finish;      
  //   end
  //`else
  /*   initial
    begin
      rd_data<='h1;
    end */

  // Memory Read Block 
  always @ (posedge clk or posedge rst)
   begin : MEM_READ
      if (rst)
         rd_data <= 'h0; 
      else
      if (rd_en) begin
        rd_data <= mem[rd_addr]; 

      end else begin
         rd_data <= 'h0; 
      end  
   end
   
  //   assign  rd_data = mem[rd_addr]; 

  //8b not reversed JSPAT
  // localparam K28_5=8'hbc;
  // localparam JSP1=8'b10000001; //D1.4
  // localparam JSP2=8'b01010000; //D16.2
  // localparam JSP3=8'b11111000; //D24.7
  // localparam JSP4=8'b10011110; //D30.4
  // localparam JSP5 =8'b11001001; //D9.6
  // localparam JSP6 =8'b10101010; //D10.5
  // localparam JSP7 =8'b01010000; //D16.2
  // localparam JSP8 =8'b11100111; //D7.7
  // localparam JSP9 =8'b00011000; //D24.0
  // localparam JSP10 =8'b01101101; //D13.3
  // localparam JSP11 =8'b10010111; //D23.4
  // localparam JSP12 =8'b01001101; //D13.2
  // localparam JSP13 =8'b11101101; //D13.7
  // localparam JSP14 =8'b10000001; //D1.4
  // localparam JSP15 =8'b11000111; //D7.6
  // localparam JSP16 =8'b01000000; //D0.2
  // localparam JSP17 =8'b10110101; //D21.5
  // localparam JSP18 =8'b00110110; //D22.1
  // localparam JSP19 =8'b10010111; //D23.4
  // localparam JSP20 =8'b00010100; //D20.0
  // localparam JSP21 =8'b00111011; //D27.1
  // localparam JSP22 =8'b11111110; //D30.7
  // localparam JSP23 =8'b11110001; //D17.7
  // localparam JSP24 =8'b01100100; //D4.3
  // localparam JSP25 =8'b11000110; //D6.6
  // localparam JSP26 =8'b10110111; //D23.5
  // localparam JSP27 =8'b01100111; //D7.3
  // localparam JSP28 =8'b01110011; //D19.3
  // localparam JSP29 =8'b10111011; //D27.5
  // localparam JSP30 =8'b01110011; //D19.3
  // localparam JSP31 =8'b01100101; //D5.3
  // localparam JSP32 =8'b00110110; //D22.1
  // localparam JSP33 =8'b00000101; //D5.0
  // localparam JSP34 =8'b10101111; //D15.5
  // localparam JSP35 =8'b11111000; //D24.7
  // localparam JSP36 =8'b01110000; //D16.3
  // localparam JSP37 =8'b01000001; //D1.2
  // localparam JSP38 =8'b10110111; //D23.5
  // localparam JSP39 =8'b11110100; //D20.7
  // localparam JSP40 =8'b11101011; //D11.7
  // localparam JSP41 =8'b11110100; //D20.7
  // localparam JSP42 =8'b11110010; //D18.7
  // localparam JSP43 =8'b00011101; //D29.0
  // localparam JSP44 =8'b11010000; //D16.6 
  // localparam JSP45 =8'b01111001; //D25.3
  // localparam JSP46 =8'b00000001; //D1.0
  // localparam JSP47 =8'b00110010; //D18.1
  // localparam JSP48 =8'b10111110; //D30.5
  // localparam JSP49 =8'b01000101; //D5.2
  // localparam JSP50 =8'b11010101; //D21.6
  localparam JTSP1=8'b10000001; //D1.4
  localparam JTSP2=8'b01010000; //D16.2
  localparam JTSP3=8'b11111000; //D24.7
  localparam JTSP4=8'b10011110; //D30.4
  localparam JTSP5 =8'b11001001; //D9.6
  localparam JTSP6 =8'b10101010; //D10.5
  localparam JTSP7 =8'b01010000; //D16.2
  localparam JTSP8 =8'b11100111; //D7.7
  localparam JTSP9 =8'b00011000; //D24.0
  localparam JTSP10 =8'b01101101; //D13.3
  localparam JTSP11 =8'b10010111; //D23.4
  localparam JTSP12 =8'b01001101; //D13.2
  localparam JTSP13 =8'b11101101; //D13.7
  localparam JTSP14 =8'b10000001; //D1.4
  localparam JTSP15 =8'b11000111; //D7.6
  localparam JTSP16 =8'b01000000; //D0.2
  localparam JTSP17 =8'b10110101; //D21.5
  localparam JTSP18 =8'b00110110; //D22.1
  localparam JTSP19 =8'b10010111; //D23.4
  localparam JTSP20 =8'b00010100; //D20.0
  localparam JTSP21 =8'b00111011; //D27.1
  localparam JTSP22 =8'b11111110; //D30.7
  localparam JTSP23 =8'b11110001; //D17.7
  localparam JTSP24 =8'b01100100; //D4.3
  localparam JTSP25 =8'b11000110; //D6.6
  localparam JTSP26 =8'b10110111; //D23.5
  localparam JTSP27 =8'b01100111; //D7.3
  localparam JTSP28 =8'b01110011; //D19.3
  localparam JTSP29 =8'b10111011; //D27.5
  localparam JTSP30 =8'b01110011; //D19.3
  localparam JTSP31 =8'b01100101; //D5.3
  localparam JTSP32 =8'b00110110; //D22.1
  localparam JTSP33 =8'b00000101; //D5.0
  localparam JTSP34 =8'b10101111; //D15.5
  localparam JTSP35 =8'b11111000; //D24.7
  localparam JTSP36 =8'b01110000; //D16.3
  localparam JTSP37 =8'b01000001; //D1.2

  localparam JTSP38 =8'b10110111; //D23.5
  localparam JTSP39 =8'b01011101; //D29.2
  localparam JTSP40 =8'b00111111; //D31.1
  localparam JTSP41 =8'b10001010; //D10.4
  localparam JTSP42 =8'b01000100; //D4.2
  localparam JTSP43 =8'b10100101; //D5.5
  localparam JTSP44 =8'b01001010; //D10.2 
  localparam JTSP45 =8'b10110101; //D21.5
  localparam JTSP46 =8'b01001010; //D10,2
  localparam JTSP47 =8'b10110101; //D21.5

  localparam JTSP48 =8'b11110100; //D20.7
  localparam JTSP49 =8'b11101011; //D11.7
  localparam JTSP50 =8'b11110100; //D20.7
  localparam JTSP51 =8'b11110010; //D18.7
  localparam JTSP52 =8'b00011101; //D29.0
  localparam JTSP53 =8'b11010000; //D16.6 
  localparam JTSP54 =8'b01111001; //D25.3
  localparam JTSP55 =8'b00000001; //D1.0
  localparam JTSP56 =8'b00110010; //D18.1
  localparam JTSP57 =8'b10111110; //D30.5
  localparam JTSP58 =8'b01000101; //D5.2
  localparam JTSP59 =8'b11010101; //D21.6

  localparam JTSP60=8'b10000001; //D1.4
  localparam JTSP61=8'b01010000; //D16.2
  localparam JTSP62=8'b11111000; //D24.7
  localparam JTSP63=8'b10011110; //D30.4
  localparam JTSP64 =8'b11001001; //D9.6
  localparam JTSP65 =8'b10101010; //D10.5
  localparam JTSP66 =8'b01010000; //D16.2
  localparam JTSP67 =8'b11100111; //D7.7
  localparam JTSP68 =8'b00011000; //D24.0
  localparam JTSP69 =8'b01101101; //D13.3
  localparam JTSP70 =8'b10010111; //D23.4
  localparam JTSP71 =8'b01001101; //D13.2
  localparam JTSP72 =8'b11101101; //D13.7
  localparam JTSP73 =8'b10000001; //D1.4
  localparam JTSP74 =8'b11000111; //D7.6
  localparam JTSP75 =8'b01000000; //D0.2
  localparam JTSP76 =8'b10110101; //D21.5
  localparam JTSP77 =8'b00110110; //D22.1
  localparam JTSP78 =8'b10010111; //D23.4
  localparam JTSP79 =8'b00010100; //D20.0
  localparam JTSP80 =8'b00111011; //D27.1
  localparam JTSP81 =8'b11111110; //D30.7
  localparam JTSP82 =8'b11110001; //D17.7
  localparam JTSP83 =8'b01100100; //D4.3
  localparam JTSP84 =8'b11000110; //D6.6
  localparam JTSP85 =8'b10110111; //D23.5
  localparam JTSP86 =8'b01100111; //D7.3
  localparam JTSP87 =8'b01110011; //D19.3
  localparam JTSP88 =8'b10111011; //D27.5
  localparam JTSP89 =8'b01110011; //D19.3
  localparam JTSP90 =8'b01100101; //D5.3
  localparam JTSP91 =8'b00110110; //D22.1
  localparam JTSP92 =8'b00000101; //D5.0
  localparam JTSP93 =8'b10101111; //D15.5
  localparam JTSP94 =8'b11111000; //D24.7
  localparam JTSP95 =8'b01110000; //D16.3
  localparam JTSP96 =8'b01000001; //D1.2
  localparam JTSP97 =8'b10110111; //D23.5

  localparam JTSP98 =8'b01111011; //D27.3
  localparam JTSP99 =8'b00000011; //D3.0
  localparam JTSP100 =8'b11100011; //D3.7
  localparam JTSP101 =8'b11101110; //D14.7
  localparam JTSP102 =8'b01111100; //D28.3 // HEX 7C
  localparam JTSP103 =8'b01111110; //D30.3 // HEX 7E
  localparam JTSP104 =8'b01111110; //D30.3 // HEX 7E
  localparam JTSP105 =8'b11100111; //D7.7
  localparam JTSP106 =8'b11100111; //D7.7

  localparam JTSP107 =8'b11110100; //D20.7
  localparam JTSP108 =8'b11101011; //D11.7
  localparam JTSP109 =8'b11110100; //D20.7
  localparam JTSP110 =8'b11110010; //D18.7
  localparam JTSP111 =8'b00011101; //D29.0
  localparam JTSP112 =8'b11010000; //D16.6 
  localparam JTSP113 =8'b01111001; //D25.3
  localparam JTSP114 =8'b00000001; //D1.0
  localparam JTSP115 =8'b00110010; //D18.1 HEX 32
  localparam JTSP116 =8'b10111110; //D30.5
  localparam JTSP117 =8'b01000101; //D5.2
  localparam JTSP118 =8'b11010101; //D21.6



  //   always @ (*) 
//  initial
//  begin
  //assign mem[0] = {4'h0,JTSP50,8'h0,8'h0,JTSP1};//36'h0_0000_0000; 8150f89e
  assign mem[0] = {4'h0,JTSP2,JTSP1,8'h0,8'h0};//36'h0_0000_0000; 8150f89e
  assign mem[1] = {4'h0,JTSP6,JTSP5,JTSP4,JTSP3};//36'h0_1111_1111; c9aa50e7
  assign mem[2] = {4'h0,JTSP10,JTSP9,JTSP8,JTSP7};//36'h0_2222_2222; 186d974d
  assign mem[3] = {4'h0,JTSP14,JTSP13,JTSP12,JTSP11};//36'h0_3333_3333; ed81c740
  assign mem[4] = {4'h0,JTSP18,JTSP17,JTSP16,JTSP15};//36'h0_4444_4444; b5369714
  assign mem[5] = {4'h0,JTSP22,JTSP21,JTSP20,JTSP19};//36'h0_5555_5555; 3bfef164
  assign mem[6] = {4'h0,JTSP26,JTSP25,JTSP24,JTSP23};//36'h0_6666_6666; c6b76773 
  assign mem[7] = {4'h0,JTSP30,JTSP29,JTSP28,JTSP27};//36'h0_7777_7777; bb796536
  assign mem[8] = {4'h0,JTSP34,JTSP33,JTSP32,JTSP31};//36'h0_8888_8888; 05aff870
  assign mem[9] = {4'h0,JTSP38,JTSP37,JTSP36,JTSP35};//36'h0_9999_9999; 41b7f4eb 
  assign mem[10] = {4'h0,JTSP42,JTSP41,JTSP40,JTSP39};//36'h0_aaaa_aaaa; f4f21dd0
  assign mem[11] = {4'h0,JTSP46,JTSP45,JTSP44,JTSP43};//36'hf_bcbc_bcbc; 79013cbe
  assign mem[12] = {4'b0,JTSP50,JTSP49,JTSP48,JTSP47};//36'h0_cccc_cccc; d545bcbc
  assign mem[13] = {4'b0,JTSP54,JTSP53,JTSP52,JTSP51};//36'h0_dddd_dddd;//
  assign mem[14] = {4'b0,JTSP58,JTSP57,JTSP56,JTSP55};//36'h0_dddd_dddd;//
  assign mem[15] = {4'b0,JTSP62,JTSP61,JTSP60,JTSP59};//36'h0_dddd_dddd;//
  assign mem[16] = {4'b0,JTSP66,JTSP65,JTSP64,JTSP63};//36'h0_dddd_dddd;//
  assign mem[17] = {4'b0,JTSP70,JTSP69,JTSP68,JTSP67};//36'h0_dddd_dddd;//
  assign mem[18] = {4'b0,JTSP74,JTSP73,JTSP72,JTSP71};//36'h0_dddd_dddd;//
  assign mem[19] = {4'b0,JTSP78,JTSP77,JTSP76,JTSP75};//36'h0_dddd_dddd;//
  assign mem[20] = {4'b0,JTSP82,JTSP81,JTSP80,JTSP79};//36'h0_dddd_dddd;//
  assign mem[21] = {4'b0,JTSP86,JTSP85,JTSP84,JTSP83};//36'h0_dddd_dddd;//
  assign mem[22] = {4'b0,JTSP90,JTSP89,JTSP88,JTSP87};//36'h0_dddd_dddd;//
  assign mem[23] = {4'b0,JTSP94,JTSP93,JTSP92,JTSP91};//36'h0_dddd_dddd;//
  assign mem[24] = {4'b0,JTSP98,JTSP97,JTSP96,JTSP95};//36'h0_dddd_dddd;//                    
  assign mem[25] = {4'b0,JTSP102,JTSP101,JTSP100,JTSP99};//36'h0_dddd_dddd;//                    
  assign mem[26] = {4'b0,JTSP106,JTSP105,JTSP104,JTSP103};//36'h0_dddd_dddd;//                    
  assign mem[27] = {4'b0,JTSP110,JTSP109,JTSP108,JTSP107};//36'h0_dddd_dddd;//                    
  assign mem[28] = {4'b0,JTSP114,JTSP113,JTSP112,JTSP111};//36'h0_dddd_dddd;//                    
  assign mem[29] = {4'b0,JTSP118,JTSP117,JTSP116,JTSP115};//36'h0_dddd_dddd;//                         
       
                                        
  //     mem[14] = 36'h0_eeee_eeee; //{JTSP4,JTSP4,JTSP4,JTSP4};
  //     mem[15] = 36'h0_ffff_ffff;
//    end
   
//`endif   
endmodule // jesd_ctp_rom

//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
