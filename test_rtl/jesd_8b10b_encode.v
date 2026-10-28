

// This module is the basic building block of transmit encoder. It takes in a 9 bit 
// bit character and generates the corresponding 10 bit symbold data 
// The disparity logic is handled outside this module and to facilitate it 
// the module generates positive disparity 10 bit symbol,  negative disparity 10 bit symbol 
// and control signal flip_disparity.The output flip_disparity is asserted when the 10 bit symbol has unequal number of 
// ones and zeros.
module jesd_8b10b_encode(

   input [7:0]      din,            // character to be encoded
   input            din_k,          // bit indicating whether din is a control character or data character
   input            clk,            // primary clock
   input            rst,            // Reset
   output reg flip_disparity,       // if 1 indicates that encoded symbol value is not neutral hence the subsequent symbol encoding should change the disparity table
   output reg [9:0] dout_pos_disp,  // 10 bit encoded symbol using positive disparity lookup
   output reg [9:0] dout_neg_disp   // 10 bit encoded symbol using negative disparity lookup
                        );
   wire [9:0] dout_pos_disp_next ;
   wire [9:0] dout_neg_disp_next ;   
   reg        flip_disparity_next;
   
   always @(posedge clk or posedge rst) begin
      if (rst) begin
        dout_pos_disp  <= 10'b0010111001;    //   D0.0 
        dout_neg_disp  <= 10'b1101000110;
        flip_disparity <= 1'b0;
      end
      else begin
        dout_pos_disp <= {dout_pos_disp_next[6],dout_pos_disp_next[7],dout_pos_disp_next[8],dout_pos_disp_next[9],
                          dout_pos_disp_next[0],dout_pos_disp_next[1],dout_pos_disp_next[2],dout_pos_disp_next[3],
                          dout_pos_disp_next[4],dout_pos_disp_next[5]};
        dout_neg_disp <= {dout_neg_disp_next[6],dout_neg_disp_next[7],dout_neg_disp_next[8],dout_neg_disp_next[9],
                          dout_neg_disp_next[0],dout_neg_disp_next[1],dout_neg_disp_next[2],dout_neg_disp_next[3],
                          dout_neg_disp_next[4],dout_neg_disp_next[5]};
        flip_disparity <= flip_disparity_next;
      end 
   end
   wire special_4bit_pos_code = (din[4:0] == 5'h11) || (din[4:0] == 5'h12) || (din[4:0] == 5'h14);
   wire special_4bit_neg_code = (din[4:0] == 5'h0B) || (din[4:0] == 5'h0D) || (din[4:0] == 5'h0E);
   assign    dout_pos_disp_next  = {calc_3b_4b_pos(din,din_k,special_4bit_pos_code),calc_5b_6b_pos(din,din_k)}; 
   assign    dout_neg_disp_next  = {calc_3b_4b_neg(din,din_k,special_4bit_pos_code,special_4bit_neg_code),
                                     calc_5b_6b_neg(din,din_k)};

   
   always @(*) begin
      case ({din_k,din[7:0]})
        9'h003: flip_disparity_next = 1'b1;   
        9'h005: flip_disparity_next = 1'b1;   
        9'h006: flip_disparity_next = 1'b1;   
        9'h007: flip_disparity_next = 1'b1;   
        9'h009: flip_disparity_next = 1'b1;   
        9'h00A: flip_disparity_next = 1'b1;   
        9'h00B: flip_disparity_next = 1'b1;   
        9'h00C: flip_disparity_next = 1'b1;   
        9'h00D: flip_disparity_next = 1'b1;   
        9'h00E: flip_disparity_next = 1'b1;   
        9'h011: flip_disparity_next = 1'b1;   
        9'h012: flip_disparity_next = 1'b1;   
        9'h013: flip_disparity_next = 1'b1;   
        9'h014: flip_disparity_next = 1'b1;   
        9'h015: flip_disparity_next = 1'b1;   
        9'h016: flip_disparity_next = 1'b1;   
        9'h019: flip_disparity_next = 1'b1;   
        9'h01A: flip_disparity_next = 1'b1;   
        9'h01C: flip_disparity_next = 1'b1;   
        9'h020: flip_disparity_next = 1'b1;   
        9'h021: flip_disparity_next = 1'b1;   
        9'h022: flip_disparity_next = 1'b1;   
        9'h024: flip_disparity_next = 1'b1;   
        9'h028: flip_disparity_next = 1'b1;   
        9'h02F: flip_disparity_next = 1'b1;   
        9'h030: flip_disparity_next = 1'b1;   
        9'h037: flip_disparity_next = 1'b1;   
        9'h038: flip_disparity_next = 1'b1;   
        9'h03B: flip_disparity_next = 1'b1;   
        9'h03D: flip_disparity_next = 1'b1;   
        9'h03E: flip_disparity_next = 1'b1;   
        9'h03F: flip_disparity_next = 1'b1;   
        9'h040: flip_disparity_next = 1'b1;   
        9'h041: flip_disparity_next = 1'b1;   
        9'h042: flip_disparity_next = 1'b1;   
        9'h044: flip_disparity_next = 1'b1;   
        9'h048: flip_disparity_next = 1'b1;   
        9'h04F: flip_disparity_next = 1'b1;   
        9'h050: flip_disparity_next = 1'b1;   
        9'h057: flip_disparity_next = 1'b1;   
        9'h058: flip_disparity_next = 1'b1;   
        9'h05B: flip_disparity_next = 1'b1;   
        9'h05D: flip_disparity_next = 1'b1;   
        9'h05E: flip_disparity_next = 1'b1;   
        9'h05F: flip_disparity_next = 1'b1;   
        9'h060: flip_disparity_next = 1'b1;   
        9'h061: flip_disparity_next = 1'b1;   
        9'h062: flip_disparity_next = 1'b1;   
        9'h064: flip_disparity_next = 1'b1;   
        9'h068: flip_disparity_next = 1'b1;   
        9'h06F: flip_disparity_next = 1'b1;   
        9'h070: flip_disparity_next = 1'b1;   
        9'h077: flip_disparity_next = 1'b1;   
        9'h078: flip_disparity_next = 1'b1;   
        9'h07B: flip_disparity_next = 1'b1;   
        9'h07D: flip_disparity_next = 1'b1;   
        9'h07E: flip_disparity_next = 1'b1;   
        9'h07F: flip_disparity_next = 1'b1;   
        9'h083: flip_disparity_next = 1'b1;   
        9'h085: flip_disparity_next = 1'b1;   
        9'h086: flip_disparity_next = 1'b1;   
        9'h087: flip_disparity_next = 1'b1;   
        9'h089: flip_disparity_next = 1'b1;   
        9'h08A: flip_disparity_next = 1'b1;   
        9'h08B: flip_disparity_next = 1'b1;   
        9'h08C: flip_disparity_next = 1'b1;   
        9'h08D: flip_disparity_next = 1'b1;   
        9'h08E: flip_disparity_next = 1'b1;   
        9'h091: flip_disparity_next = 1'b1;   
        9'h092: flip_disparity_next = 1'b1;   
        9'h093: flip_disparity_next = 1'b1;   
        9'h094: flip_disparity_next = 1'b1;   
        9'h095: flip_disparity_next = 1'b1;   
        9'h096: flip_disparity_next = 1'b1;   
        9'h099: flip_disparity_next = 1'b1;   
        9'h09A: flip_disparity_next = 1'b1;   
        9'h09C: flip_disparity_next = 1'b1;   
        9'h0A0: flip_disparity_next = 1'b1;   
        9'h0A1: flip_disparity_next = 1'b1;   
        9'h0A2: flip_disparity_next = 1'b1;   
        9'h0A4: flip_disparity_next = 1'b1;   
        9'h0A8: flip_disparity_next = 1'b1;   
        9'h0AF: flip_disparity_next = 1'b1;   
        9'h0B0: flip_disparity_next = 1'b1;   
        9'h0B7: flip_disparity_next = 1'b1;   
        9'h0B8: flip_disparity_next = 1'b1;   
        9'h0BB: flip_disparity_next = 1'b1;   
        9'h0BD: flip_disparity_next = 1'b1;   
        9'h0BE: flip_disparity_next = 1'b1;   
        9'h0BF: flip_disparity_next = 1'b1;   
        9'h0C0: flip_disparity_next = 1'b1;   
        9'h0C1: flip_disparity_next = 1'b1;   
        9'h0C2: flip_disparity_next = 1'b1;   
        9'h0C4: flip_disparity_next = 1'b1;   
        9'h0C8: flip_disparity_next = 1'b1;   
        9'h0CF: flip_disparity_next = 1'b1;   
        9'h0D0: flip_disparity_next = 1'b1;   
        9'h0D7: flip_disparity_next = 1'b1;   
        9'h0D8: flip_disparity_next = 1'b1;   
        9'h0DB: flip_disparity_next = 1'b1;   
        9'h0DD: flip_disparity_next = 1'b1;   
        9'h0DE: flip_disparity_next = 1'b1;   
        9'h0DF: flip_disparity_next = 1'b1;   
        9'h0E3: flip_disparity_next = 1'b1;   
        9'h0E5: flip_disparity_next = 1'b1;   
        9'h0E6: flip_disparity_next = 1'b1;   
        9'h0E7: flip_disparity_next = 1'b1;   
        9'h0E9: flip_disparity_next = 1'b1;   
        9'h0EA: flip_disparity_next = 1'b1;   
        9'h0EB: flip_disparity_next = 1'b1;   
        9'h0EC: flip_disparity_next = 1'b1;   
        9'h0ED: flip_disparity_next = 1'b1;   
        9'h0EE: flip_disparity_next = 1'b1;   
        9'h0F1: flip_disparity_next = 1'b1;   
        9'h0F2: flip_disparity_next = 1'b1;   
        9'h0F3: flip_disparity_next = 1'b1;   
        9'h0F4: flip_disparity_next = 1'b1;   
        9'h0F5: flip_disparity_next = 1'b1;   
        9'h0F6: flip_disparity_next = 1'b1;   
        9'h0F9: flip_disparity_next = 1'b1;   
        9'h0FA: flip_disparity_next = 1'b1;   
        9'h0FC: flip_disparity_next = 1'b1;   
        9'h17C: flip_disparity_next = 1'b1;   
        9'h1BC: flip_disparity_next = 1'b1;
        default :flip_disparity_next = 1'b0;
      endcase // case {din_k,din}
   end // always @ (*)
   
   
   function [5:0] calc_5b_6b_pos(input [7:0]datain , input dink);
      begin
         if (dink==1'b0) begin
            case (datain[4:0]) 
              5'h00: calc_5b_6b_pos = 6'b100111 ; 
              5'h01: calc_5b_6b_pos = 6'b011101 ; 
              5'h02: calc_5b_6b_pos = 6'b101101 ; 
              5'h03: calc_5b_6b_pos = 6'b110001 ; 
              5'h04: calc_5b_6b_pos = 6'b110101 ; 
              5'h05: calc_5b_6b_pos = 6'b101001 ; 
              5'h06: calc_5b_6b_pos = 6'b011001 ; 
              5'h07: calc_5b_6b_pos = 6'b111000 ; 
              5'h08: calc_5b_6b_pos = 6'b111001 ; 
              5'h09: calc_5b_6b_pos = 6'b100101 ; 
              5'h0A: calc_5b_6b_pos = 6'b010101 ; 
              5'h0B: calc_5b_6b_pos = 6'b110100 ; 
              5'h0C: calc_5b_6b_pos = 6'b001101 ; 
              5'h0D: calc_5b_6b_pos = 6'b101100 ; 
              5'h0E: calc_5b_6b_pos = 6'b011100 ; 
              5'h0F: calc_5b_6b_pos = 6'b010111 ; 
              5'h10: calc_5b_6b_pos = 6'b011011 ; 
              5'h11: calc_5b_6b_pos = 6'b100011 ; 
              5'h12: calc_5b_6b_pos = 6'b010011 ; 
              5'h13: calc_5b_6b_pos = 6'b110010 ; 
              5'h14: calc_5b_6b_pos = 6'b001011 ; 
              5'h15: calc_5b_6b_pos = 6'b101010 ; 
              5'h16: calc_5b_6b_pos = 6'b011010 ; 
              5'h17: calc_5b_6b_pos = 6'b111010 ; 
              5'h18: calc_5b_6b_pos = 6'b110011 ; 
              5'h19: calc_5b_6b_pos = 6'b100110 ; 
              5'h1A: calc_5b_6b_pos = 6'b010110 ; 
              5'h1B: calc_5b_6b_pos = 6'b110110 ; 
              5'h1C: calc_5b_6b_pos = 6'b001110 ; 
              5'h1D: calc_5b_6b_pos = 6'b101110 ; 
              5'h1E: calc_5b_6b_pos = 6'b011110 ; 
              5'h1F: calc_5b_6b_pos = 6'b101011 ; 
            endcase // case (datain[4:0])
         end // if (dink==1'b0)
         else begin
            case (datain[4:0])
              'h1C : calc_5b_6b_pos = 6'b001111 ; //default value is for K=1 and D=5'h1C
              default : calc_5b_6b_pos = 6'b000000;
            endcase // case (datain)
         end
      end      
   endfunction // calc_5b_6b_pos

   function [5:0] calc_5b_6b_neg(input [7:0] datain , input dink);
      begin
         if (dink == 1'b0) begin
            case(datain[4:0])
              3,5,6,9,10,11,12,13,14,17,18,19,20,21,22,25,26,28:calc_5b_6b_neg = calc_5b_6b_pos(datain , dink);           
              default:calc_5b_6b_neg = ~calc_5b_6b_pos(datain, dink);             
            endcase // case (datain[4:0])
         end         
         else begin
            calc_5b_6b_neg = ~calc_5b_6b_pos(datain , dink);
         end
      end
   endfunction // calc_5b_6b_neg

   function [3:0] calc_3b_4b_pos(input [7:0] datain , input dink,input special_pos_encoding);
      begin
         case (datain[7:5])
           3'h1:calc_3b_4b_pos = 4'b1001;
           3'h2:calc_3b_4b_pos = 4'b0101;
           3'h3:calc_3b_4b_pos = ^calc_5b_6b_pos(datain,dink) ? 4'b1100 : 4'b0011;        
           3'h4:calc_3b_4b_pos = ^calc_5b_6b_pos(datain,dink) ? 4'b1101 : 4'b0010;                
           3'h5:calc_3b_4b_pos = 4'b1010;
           3'h6:calc_3b_4b_pos = 4'b0110;
           3'h7: begin
              if (dink == 0) begin
                 if (special_pos_encoding)
                   calc_3b_4b_pos = ^calc_5b_6b_pos(datain,dink) ? 4'b0111 : 4'b0001;
                 else
                   calc_3b_4b_pos = ^calc_5b_6b_pos(datain,dink) ? 4'b1110 : 4'b0001;                
              end           
              else calc_3b_4b_pos = 4'b1000;              
           end
           default:calc_3b_4b_pos = ^calc_5b_6b_pos(datain,dink) ? 4'b1011 : 4'b0100 ;        
         endcase // case (datain(7:5))
      end
   endfunction // calc_3b_4b_pos

   function [3:0] calc_3b_4b_neg(input [7:0] datain , input dink,input special_pos_encoding,input special_neg_encoding);
      begin
         calc_3b_4b_neg = ~calc_3b_4b_pos(datain,dink,special_pos_encoding);                                                 
         if (dink == 0) begin
            case (datain[7:5])
              3'h1,3'h2,3'h5,3'h6:calc_3b_4b_neg = calc_3b_4b_pos(datain,dink,special_pos_encoding);
              3'h7:begin
                 if (special_pos_encoding) 
                   calc_3b_4b_neg = 4'b0001;
                 else if (special_neg_encoding)
                   calc_3b_4b_neg = 4'b1000;
                 else
                   calc_3b_4b_neg = ~calc_3b_4b_pos(datain,dink,special_pos_encoding);
              end
            endcase // case (datain(7:5))
         end // if (dink == 0)
      end
   endfunction // calc_3b_4b_neg
   
   
endmodule // jesd_8b10b_encode
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
