

// This module is the basic building block of receive decoder. It takes in a 10 
// bit symbol and generates the corresponding 9 bit data in form of {dout_k,dout} 
// and not_in_table_err signal.
// The disparity logic is handled outside this module and to facilitate it 
// the module also generates signals (pos_table_hit and neg_table_hit) to indicate whether 
// the 10 bit input symbol is part of positive lookup table or part of the negative lookup 
// table. The output flip_disparity is asserted when the 10 bit symbol has unequal number of 
// ones and zeros.
module jesd_10b8b_decode
  (input            clk,                 // corresponds to clk_character in our design
   input            rst,                 // Reset, active high
   input [9:0]      symbol_in,           // 10 bit symbol to be decoded
   output reg [7:0] dout,                // decoded character value, corresponds to previous clk symbol_in value
   output reg       dout_k,              // when high indicates decoded character is control else data, corresponds to previous clk symbol_in value
   output reg       flip_disparity,
//   output reg       symbol_disparity,
   output reg       not_in_table_err,    // when high indicates symbol could not be decoded, corresponds to previous clk symbol_in value
   output reg       pos_table_hit,       // when high indicates symbol matched lookup in postive disparity table, corresponds to previous clk symbol_in value
   output reg       neg_table_hit        // when high indicates symbol matched lookup in negative disparity table, corresponds to previous clk symbol_in value
   );

   reg [7:0] dout_next;
   reg       dout_k_next; 
//   reg       symbol_disparity_next;
   wire      flip_disparity_next;
   wire      not_in_table_err_next;
   wire  [4:0] l5bit_pos_dec_val,l5bit_neg_dec_val;
   wire [2:0]  u3bit_pos_dec_val,u3bit_neg_dec_val;
   wire        l6bit_pos_hit, l6bit_pos_k, l6bit_neg_hit, l6bit_neg_k, u4bit_pos_hit, u4bit_neg_hit;
   wire neg_hit = l6bit_neg_hit & u4bit_neg_hit;
   wire pos_hit = l6bit_pos_hit & u4bit_pos_hit;

   // The decode logic functions used bit 'a' to be at most significant bit position of 6 bit code and
   // bit 'f' to be at most significant bit position of 4 bit code (i.e. {fghj,abcdei}) but the actual 
   // bit placement from serdes is in format {jhgf,iedcba}.The following wire takes care of the above discrepancy

   wire [9:0] symbol_in_reversed = {symbol_in[6],symbol_in[7],symbol_in[8],symbol_in[9],
                                    symbol_in[0],symbol_in[1],symbol_in[2],symbol_in[3],symbol_in[4],symbol_in[5]};

/*
  Some of the generic points (observations) used while creating the decode logic are listed below    
 - For Value of 5 bit code = 3,5,6,9,10,11,12,13,14,17,18,19,20,21,22,25,26,28 '6' bit code is same in both disparity and the resultant 6bit code has odd disparity
 - For Value of 5 bit code = 0,1,2,4,7,8,15,16,23,24,27,29,30,31 6 bit code is inv in the parity tables. (Note 1)
 - For value of 3 bit codes 1,2,5,6 the value of 4 bit codes is independent of the 5 bit variable and the value of 4 bit code is same in both parity tables
 - For value of 3 bit codes 0,3,4,7 the value of 4 bit codes is dependent on the 5 bit variable and the value of 4 bit code is inverted in parity tables .
 - Note 1 : Value of 7 and 26 are special cases with odd parity in the resulatnt 6 bit code rest all are even parity
 - Note 2 . It is possible that for a given symbol the decode logic may find a match in positive table and negative table
  */

   // Some wires to detect exceptions around decoding of 4 bit portion of the symbols
   wire special_6bit_pos_code =   (symbol_in_reversed[5:0] == 6'b100011) || 
        (symbol_in_reversed[5:0] == 6'b010011) ||
        (symbol_in_reversed[5:0] == 6'b001011);

   wire special_6bit_neg_code =  (symbol_in_reversed[5:0] == 6'b110100)
        || (symbol_in_reversed[5:0] ==   6'b101100) ||  (symbol_in_reversed[5:0] == 6'b011100);
   
   
   always @(posedge clk or posedge rst) begin
     if (rst) begin
       dout <= 'h0;
       dout_k <= 1'b0;
       flip_disparity <= 1'b0;
       not_in_table_err <= 1'b0;
       pos_table_hit <= 1'b0;
       neg_table_hit <= 1'b0;
     end
     else begin
       dout <= dout_next;
       dout_k <= dout_k_next;
       flip_disparity <= flip_disparity_next;
//       symbol_disparity <= symbol_disparity_next;
       not_in_table_err <= not_in_table_err_next;
       pos_table_hit <= pos_hit;
       neg_table_hit <= neg_hit;      
     end
   end
wire l6bit_parity, u4bit_parity;
   assign l6bit_parity = ^(symbol_in_reversed[5:0]);
   assign u4bit_parity = ^(symbol_in_reversed[9:6]);
   assign flip_disparity_next = pos_hit || neg_hit ? ~(l6bit_parity ^ u4bit_parity) : 1'b0; // detect non neutral valid code

   // Following function takes in the 6bit code to generates following 7 bit output information based on lookup of positive disparity table
   // {whether_6_bit_val_is_legal_or_not,whether_6_bit_val_is_legal_or_notrepresentingcontrol_char,corresponding_5bit_val[4:0]}   
   function [6:0] search_5_in_pos(input [5:0] symbol_in_reversed );      
      reg [4:0] temp0;
      reg       temp1;
      reg       temp2;
      begin         
         temp0 = 5'b11100; //28.x
         temp1 = 1'b0; // no hit
         temp2 = 1'b0; // K

         case (symbol_in_reversed[5:0])
           6'b100111:begin
              temp0 = 5'b00000;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b011101:begin
              temp0 = 5'b00001;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b101101:begin
              temp0 = 5'b00010;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b110001:begin
              temp0 = 5'b00011;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b110101:begin
              temp0 = 5'b00100;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b101001:begin
              temp0 = 5'b00101;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b011001:begin
              temp0 = 5'b00110;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b111000:begin
              temp0 = 5'b00111;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b111001:begin
              temp0 = 5'b01000;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b100101:begin
              temp0 = 5'b01001;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b010101:begin
              temp0 = 5'b01010;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b110100:begin
              temp0 = 5'b01011;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b001101:begin
              temp0 = 5'b01100;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b101100:begin
              temp0 = 5'b01101;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b011100:begin
              temp0 = 5'b01110;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b010111:begin
              temp0 = 5'b01111;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b011011:begin
              temp0 = 5'b10000;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b100011:begin
              temp0 = 5'b10001;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b010011:begin
              temp0 = 5'b10010;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b110010:begin
              temp0 = 5'b10011;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b001011:begin
              temp0 = 5'b10100;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b101010:begin
              temp0 = 5'b10101;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b011010:begin
              temp0 = 5'b10110;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b111010:begin
              temp0 = 5'b10111;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b110011:begin
              temp0 = 5'b11000;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b100110:begin
              temp0 = 5'b11001;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b010110:begin
              temp0 = 5'b11010;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b110110:begin
              temp0 = 5'b11011;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b001110:begin
              temp0 = 5'b11100;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b001111:begin
              temp0 = 5'b11100;
              temp1 = 1'b1;
              temp2 = 1'b1;
           end
           6'b101110:begin
              temp0 = 5'b11101;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b011110:begin
              temp0 = 5'b11110;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b101011:begin
              temp0 = 5'b11111;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
         endcase // case (symbol_in_reversed[5:0])
         search_5_in_pos = {temp1,temp2,temp0};      
      end      
   endfunction // search_5_in_pos

   // Following function takes in the 6bit code to generates following 7 bit output information based on lookup of negative disparity table
   // {whether_6_bit_val_is_legal_or_not,whether_6_bit_val_is_legal_or_notrepresentingcontrol_char,corresponding_5bit_val[4:0]}      
   function [6:0] search_5_in_neg(input [5:0] symbol_in_reversed );      
      reg [4:0] temp0 ;
      reg       temp1 ;
      reg       temp2 ;
      begin         
         temp0 = 5'b11100; //28.x
         temp1 = 1'b0; // no hit
         temp2 = 1'b0; // K
         case (symbol_in_reversed[5:0])
           6'b011000:begin
              temp0 = 5'b00000 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b100010:begin
              temp0 = 5'b00001 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b010010:begin
              temp0 = 5'b00010 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b110001:begin
              temp0 = 5'b00011 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b001010:begin
              temp0 = 5'b00100 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b101001:begin
              temp0 = 5'b00101 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b011001:begin
              temp0 = 5'b00110 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b000111:begin
              temp0 = 5'b00111 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b000110:begin
              temp0 = 5'b01000 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b100101:begin
              temp0 = 5'b01001 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b010101:begin
              temp0 = 5'b01010 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b110100:begin
              temp0 = 5'b01011 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b001101:begin
              temp0 = 5'b01100 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b101100:begin
              temp0 = 5'b01101 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b011100:begin
              temp0 = 5'b01110 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b101000:begin
              temp0 = 5'b01111 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b100100:begin
              temp0 = 5'b10000 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b100011:begin
              temp0 = 5'b10001 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b010011:begin
              temp0 = 5'b10010 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b110010:begin
              temp0 = 5'b10011 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b001011:begin
              temp0 = 5'b10100 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b101010:begin
              temp0 = 5'b10101 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b011010:begin
              temp0 = 5'b10110 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b000101:begin
              temp0 = 5'b10111 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b001100:begin
              temp0 = 5'b11000 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b100110:begin
              temp0 = 5'b11001 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b010110:begin
              temp0 = 5'b11010 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b001001:begin
              temp0 = 5'b11011 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b001110:begin
              temp0 = 5'b11100 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b110000:begin
              temp0 = 5'b11100 ;
              temp1 = 1'b1;
              temp2 = 1'b1;
           end
           6'b010001:begin
              temp0 = 5'b11101 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b100001:begin
              temp0 = 5'b11110 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
           6'b010100:begin
              temp0 = 5'b11111 ;
              temp1 = 1'b1;
              temp2 = 1'b0;
           end
         endcase // case (symbol_in_reversed[5:0])
         search_5_in_neg = {temp1,temp2,temp0};
      end
      endfunction // search_5_in_neg

   // The following functions qualifies that the 4 bit code is legal and generates the corresponding 3 bit decoded value 
   // using lookup in positive disparity table. To qualify the 4 bit code as legal we need to take into account certain outputs 
   // generated by 6 bit decode logic
   function [3:0] search_3_in_pos(input [3:0] symbol_in_reversed, input symbol_k, input low_6_bit_parity,input sp_qual);
      reg [2:0] temp0;
      reg       temp1;
      begin
         temp0 = 3'b010;
         temp1 = 1'b0;

         if (symbol_k == 1'b0) begin
            case (symbol_in_reversed[3:0])
              4'b0100:begin
                 temp0 = 3'b000 ;
                 temp1 = (low_6_bit_parity == 1'b0);
              end
              4'b1011:begin
                 temp0 = 3'b000 ;
                 temp1 = (low_6_bit_parity == 1'b1);
              end
              4'b1001:begin
                 temp0 = 3'b001 ;
                 temp1 = 1'b1;
              end
              4'b0101:begin
                 temp0 = 3'b010 ;
                 temp1 = 1'b1;
              end
              4'b0011:begin
                 temp0 = 3'b011 ;
                 temp1 = (low_6_bit_parity == 1'b0);                 
              end
              4'b1100:begin
                 temp0 = 3'b011 ;
                 temp1 = (low_6_bit_parity == 1'b1);                                  
              end              
              4'b0010:begin
                 temp0 = 3'b100 ;                 
                 temp1 = (low_6_bit_parity == 1'b0); 
              end
              4'b1101:begin
                 temp0 = 3'b100 ;
                 temp1 = (low_6_bit_parity == 1'b1);  
              end
              4'b1010:begin
                 temp0 = 3'b101 ;
                 temp1 = 1'b1;
              end
              4'b0110:begin
                 temp0 = 3'b110 ;
                 temp1 = 1'b1;
              end
              4'b0001:begin
                 temp0 = 3'b111 ;
                 temp1 = (low_6_bit_parity == 1'b0);  
              end
              4'b1110:begin
                 temp0 = 3'b111 ;
                 temp1 = (low_6_bit_parity == 1'b1) & ~sp_qual;  
              end              
              4'b0111:begin
                 temp0 = 3'b111 ;
                 temp1 = (low_6_bit_parity == 1'b1) & sp_qual;  
              end
            endcase // case (symbol_in_reversed[3:0])
         end // if (symbol_k == 1'b0)
         else  begin
            case (symbol_in_reversed[3:0])
              4'b0100:begin
                 temp0 = 3'b000;
                 temp1 = 1'b1;                 
              end
              4'b0101:begin
                 temp0 = 3'b010;
                 temp1 = 1'b1;                                  
              end
              4'b0011:begin
                 temp0 = 3'b011;
                 temp1 = 1'b1;                                  
              end
              4'b0010:begin
                 temp0 = 3'b100;
                 temp1 = 1'b1;                                  
              end
              4'b1010:begin
                 temp0 = 3'b101;
                 temp1 = 1'b1;                                  
              end
              4'b1000:begin
                 temp0 = 3'b111;
                 temp1 = 1'b1;                                  
              end
            endcase // case (symbol_in_reversed[3:0])
         end // else: !if(symbol_k == 1'b0)
         search_3_in_pos = {temp1,temp0};
      end      
   endfunction // search_3_in_pos

   // The following functions qualifies that the 4 bit code is legal and generates the corresponding 3 bit decoded value 
   // using lookup in negative disparity table. To qualify the 4 bit code as legal we need to take into account certain outputs 
   // generated by 6 bit decode logic
   function [3:0] search_3_in_neg(input [3:0] symbol_in_reversed, input symbol_k, input low_6_bit_parity,input sp_qual);
      reg [2:0] temp0;
      reg       temp1;
      begin
         temp0 = 3'b010;
         temp1 = 1'b0;
         if (symbol_k == 1'b0) begin
            case (symbol_in_reversed[3:0])
              4'b0100:begin
                 temp0 = 3'b000 ;
                 temp1 = (low_6_bit_parity == 1'b1);
              end
              4'b1011:begin
                 temp0 = 3'b000 ;
                 temp1 = (low_6_bit_parity == 1'b0);
              end
              4'b1001:begin
                 temp0 = 3'b001 ;
                 temp1 = 1'b1;
              end
              4'b0101:begin
                 temp0 = 3'b010 ;
                 temp1 = 1'b1;
              end
              4'b0011:begin
                 temp0 = 3'b011 ;
                 temp1 = (low_6_bit_parity == 1'b1);                 
              end
              4'b1100:begin
                 temp0 = 3'b011 ;
                 temp1 = (low_6_bit_parity == 1'b0);                                  
              end              
              4'b0010:begin
                 temp0 = 3'b100 ;                 
                 temp1 = (low_6_bit_parity == 1'b1); 
              end
              4'b1101:begin
                 temp0 = 3'b100 ;
                 temp1 = (low_6_bit_parity == 1'b0);  
              end
              4'b1010:begin
                 temp0 = 3'b101 ;
                 temp1 = 1'b1;
              end
              4'b0110:begin
                 temp0 = 3'b110 ;
                 temp1 = 1'b1;
              end
              4'b0001:begin
                 temp0 = 3'b111 ;
                 temp1 = (low_6_bit_parity == 1'b1) & ~sp_qual;  
              end
              4'b1110:begin
                 temp0 = 3'b111 ;
                 temp1 = (low_6_bit_parity == 1'b0) & ~sp_qual;  
              end
              4'b1000:begin
                 temp0 = 3'b111;
                 temp1 = sp_qual;                                  
              end              
            endcase // case (symbol_in_reversed[3:0])
         end // if (symbol_k == 1'b0)
         else begin
            case (symbol_in_reversed[3:0])
              4'b1011:begin
                 temp0 = 3'b000;
                 temp1 = 1'b1;                 
              end
              4'b1010:begin
                 temp0 = 3'b010;
                 temp1 = 1'b1;                                  
              end
              4'b1100:begin
                 temp0 = 3'b011;
                 temp1 = 1'b1;                                  
              end
              4'b1101:begin
                 temp0 = 3'b100;
                 temp1 = 1'b1;                                  
              end
              4'b0101:begin
                 temp0 = 3'b101;
                 temp1 = 1'b1;                                  
              end
              4'b0111:begin
                 temp0 = 3'b111;
                 temp1 = 1'b1;                                  
              end
            endcase // case (symbol_in_reversed[3:0])
         end // else: !if(symbol_k == 1'b0)
         search_3_in_neg = {temp1,temp0};
      end      
   endfunction // search_3_in_neg

   
               
   assign {l6bit_pos_hit,l6bit_pos_k, l5bit_pos_dec_val} = search_5_in_pos(symbol_in_reversed[5:0]);
   assign {l6bit_neg_hit,l6bit_neg_k, l5bit_neg_dec_val} = search_5_in_neg(symbol_in_reversed[5:0]);
   wire l6bit_is_k = l6bit_pos_k | l6bit_neg_k;   
   assign {u4bit_pos_hit,u3bit_pos_dec_val} = search_3_in_pos(symbol_in_reversed[9:6],l6bit_pos_k,l6bit_parity,special_6bit_pos_code);
   assign {u4bit_neg_hit,u3bit_neg_dec_val} = search_3_in_neg(symbol_in_reversed[9:6],l6bit_neg_k,l6bit_parity,special_6bit_neg_code);

   
   assign    not_in_table_err_next = ~pos_hit & ~neg_hit;


   always @(*) begin
      case ({neg_hit,pos_hit})
        2'b10:begin
         dout_next = {u3bit_neg_dec_val,l5bit_neg_dec_val};
         dout_k_next = l6bit_neg_k;
        end
        2'b11,2'b01:begin
           dout_next = {u3bit_pos_dec_val,l5bit_pos_dec_val};
           dout_k_next = l6bit_pos_k;
        end
        default:begin
           dout_next = 8'h5C;
           dout_k_next = 1'b1;
        end
      endcase // case ({neg_hit,pos_hit})
   end // always @ (*)

   
   
endmodule // jesd_10b8b_decode

// Debug code . Can be cleaned up later
// if ((not_in_table_err_next) && (symbol_in != 'h000)) begin
//   $display("%m not_in_table_err asserted symbol_in = 0x%0h/0x%0h, 0x%0h  @%0t",
//            symbol_in,symbol_in_reversed,{l6bit_neg_hit,u4bit_neg_hit,l6bit_pos_hit,u4bit_pos_hit},$time);
// end
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
