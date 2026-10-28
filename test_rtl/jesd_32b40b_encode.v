

// This module has 4 instance of jesd_8b10b_encode module and logic to maintain running disparity
// based on the outputs of each of the 4 instances. 
// It also has the option to set the running disparity of first symbol transmitted after exiting
// elecidle state
module jesd_32b40b_encode(
   input [31:0]      din,     //Input data 4 characters per clock 
   input [3:0]       din_k,   //1 bit corresponding to each character on din. Value of 1 indicates the character is a control character else it is data character 
   input             din_vld, //1 bit signal indicating the fact that the transmit stream on din & din_k is valid and should be transmitted
   input             clk, // Primary clock 
   input             rst, // Primary reset
   input             first_symbol_disparity, // Value of 1 indicates the first symbol should be transmitted with positive disparity
   output reg [39:0] dout, // 4 symbols of 10 bit encoded data
   output            dout_vld // control bit indicating valid information on dout. 
                         );
   wire [9:0]    dout0_pos_disp, dout0_neg_disp, dout1_pos_disp, dout1_neg_disp, dout2_pos_disp, dout2_neg_disp, dout3_pos_disp , dout3_neg_disp;   
   wire [9:0]    dout0_next, dout1_next, dout2_next, dout3_next;
   wire [9:0]    dout0, dout1, dout2, dout3;
   reg     disp_next_0,disp_next_1,disp_next_2,disp_next_3;
   wire [3:0] flip_disparity;
   
   
   assign dout0_next = disp_next_0 ? dout0_pos_disp :  dout0_neg_disp;
   assign dout1_next = disp_next_1 ? dout1_pos_disp  :  dout1_neg_disp;
   assign dout2_next = disp_next_2 ? dout2_pos_disp :  dout2_neg_disp;
   assign dout3_next = disp_next_3 ? dout3_pos_disp :  dout3_neg_disp;
   reg curr_disp;
   reg [1:0]     dp_latency;
   assign dout_vld = dp_latency[1];
   
   always @(posedge clk or posedge rst) begin
      if (rst) begin
         dp_latency <= 2'b00;
         curr_disp <= 1'b0;
         dout <= 'h0;
      end
      else begin
         dp_latency[1] <= dp_latency[0];
         dp_latency[0] <= din_vld;      
         dout <= {dout3_next, dout2_next, dout1_next, dout0_next};

         if (~dp_latency[0]) // starting with known disparity on first data
           curr_disp <= first_symbol_disparity;
         else
           curr_disp <= flip_disparity[3] ? ~disp_next_3 : disp_next_3;
      end // else: !if(rst)
   end // always @ (posedge clk or posedge rst)
   



   jesd_8b10b_encode char_0(
                           .clk             (clk),
                           .rst             (rst),
                           .din             (din[07:00]),
                           .din_k           (din_k[0]),
                           .flip_disparity  (flip_disparity[0]),
                           .dout_pos_disp   (dout0_pos_disp),
                           .dout_neg_disp   (dout0_neg_disp)
                           );

   jesd_8b10b_encode char_1(
                           .clk             (clk),
                           .rst             (rst),
                           .din             (din[15:08]),
                           .din_k           (din_k[1]),
                           .flip_disparity  (flip_disparity[1]),                           
                           .dout_pos_disp   (dout1_pos_disp),
                           .dout_neg_disp   (dout1_neg_disp)
                           );

   jesd_8b10b_encode char_2(
                           .clk             (clk),
                           .rst             (rst),
                           .din             (din[23:16]),
                           .din_k           (din_k[2]),
                           .flip_disparity  (flip_disparity[2]),                           
                           .dout_pos_disp   (dout2_pos_disp),
                           .dout_neg_disp   (dout2_neg_disp)
                           );

   jesd_8b10b_encode char_3(
                           .clk             (clk),
                           .rst             (rst),
                           .din             (din[31:24]),
                           .din_k           (din_k[3]),
                           .flip_disparity  (flip_disparity[3]),                           
                           .dout_pos_disp   (dout3_pos_disp),
                           .dout_neg_disp   (dout3_neg_disp)
                           );
   
   

   always @ (*) begin
      disp_next_0= curr_disp;        
   end
   
   always @ (*) begin
      if (flip_disparity[0])
        disp_next_1 = ~disp_next_0;
      else
        disp_next_1 = disp_next_0;
   end

   always @ (*) begin
      if (flip_disparity[1])
        disp_next_2 = ~disp_next_1;
      else
        disp_next_2 = disp_next_1;
   end // always @ begin
   
   always @ (*) begin
       if (flip_disparity[2])
        disp_next_3 = ~disp_next_2;
      else
        disp_next_3 = disp_next_2;
   end // always @ begin
   
   
endmodule // jesd_32b40b_encode
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
