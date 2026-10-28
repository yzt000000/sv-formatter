

module jesd_jtspat_analyzer  
   (

 input                        tx_rx_enable_jtspat_test,
  input                            clk_character,
  input                            rst_clk_character,
 
 input[31:0]                             jtspat_data,
 input                                   jtspat_vld,
 output [3:0]                            jtspat_err_count,
 output [3:0]                            jtspat_vld_count
 );

//////////// 8b format
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

wire [7:0] jtspat_stored_data_1 [37:0];
wire [7:0] jtspat_stored_data_2 [8:0];
wire [7:0] jtspat_stored_data_3 [12:0];
wire [7:0] jtspat_stored_data_4 [8:0];
 
assign jtspat_stored_data_1[37]=JTSP1;
assign jtspat_stored_data_1[36]=JTSP2;
assign jtspat_stored_data_1[35]=JTSP3;
assign jtspat_stored_data_1[34]=JTSP4;
assign jtspat_stored_data_1[33]=JTSP5;
assign jtspat_stored_data_1[32]=JTSP6;
assign jtspat_stored_data_1[31]=JTSP7;
assign jtspat_stored_data_1[30]=JTSP8;
assign jtspat_stored_data_1[29]=JTSP9;
assign jtspat_stored_data_1[28]=JTSP10;
assign jtspat_stored_data_1[27]=JTSP11;
assign jtspat_stored_data_1[26]=JTSP12;
assign jtspat_stored_data_1[25]=JTSP13;
assign jtspat_stored_data_1[24]=JTSP14;
assign jtspat_stored_data_1[23]=JTSP15;
assign jtspat_stored_data_1[22]=JTSP16;
assign jtspat_stored_data_1[21]=JTSP17;
assign jtspat_stored_data_1[20]=JTSP18;
assign jtspat_stored_data_1[19]=JTSP19;
assign jtspat_stored_data_1[18]=JTSP20;
assign jtspat_stored_data_1[17]=JTSP21;
assign jtspat_stored_data_1[16]=JTSP22;
assign jtspat_stored_data_1[15]=JTSP23;
assign jtspat_stored_data_1[14]=JTSP24;
assign jtspat_stored_data_1[13]=JTSP25;
assign jtspat_stored_data_1[12]=JTSP26;
assign jtspat_stored_data_1[11]=JTSP27;
assign jtspat_stored_data_1[10]=JTSP28;
assign jtspat_stored_data_1[9]=JTSP29;
assign jtspat_stored_data_1[8]=JTSP30;
assign jtspat_stored_data_1[7]=JTSP31;
assign jtspat_stored_data_1[6]=JTSP32;
assign jtspat_stored_data_1[5]=JTSP33;
assign jtspat_stored_data_1[4]=JTSP34;
assign jtspat_stored_data_1[3]=JTSP35;
assign jtspat_stored_data_1[2]=JTSP36;
assign jtspat_stored_data_1[1]=JTSP37;
assign jtspat_stored_data_1[0]=JTSP38;

assign jtspat_stored_data_2[8]=JTSP39;
assign jtspat_stored_data_2[7]=JTSP40;
assign jtspat_stored_data_2[6]=JTSP41;
assign jtspat_stored_data_2[5]=JTSP42;
assign jtspat_stored_data_2[4]=JTSP43;
assign jtspat_stored_data_2[3]=JTSP44;
assign jtspat_stored_data_2[2]=JTSP45;
assign jtspat_stored_data_2[1]=JTSP46;
assign jtspat_stored_data_2[0]=JTSP47;

assign jtspat_stored_data_3[11]=JTSP48;
assign jtspat_stored_data_3[10]=JTSP49;
assign jtspat_stored_data_3[9]=JTSP50;
assign jtspat_stored_data_3[8]=JTSP51;
assign jtspat_stored_data_3[7]=JTSP52;
assign jtspat_stored_data_3[6]=JTSP53;
assign jtspat_stored_data_3[5]=JTSP54;
assign jtspat_stored_data_3[4]=JTSP55;
assign jtspat_stored_data_3[3]=JTSP56;
assign jtspat_stored_data_3[2]=JTSP57;
assign jtspat_stored_data_3[1]=JTSP58;
assign jtspat_stored_data_3[0]=JTSP59;

// assign jtspat_stored_data[58]=JTSP60;
// assign jtspat_stored_data[57]=JTSP61;
// assign jtspat_stored_data[56]=JTSP62;
// assign jtspat_stored_data[55]=JTSP63;
// assign jtspat_stored_data[54]=JTSP64;
// assign jtspat_stored_data[53]=JTSP65;
// assign jtspat_stored_data[52]=JTSP66;
// assign jtspat_stored_data[51]=JTSP67;
// assign jtspat_stored_data[50]=JTSP68;
// assign jtspat_stored_data[49]=JTSP69;
// assign jtspat_stored_data[48]=JTSP70;
// assign jtspat_stored_data[47]=JTSP71;
// assign jtspat_stored_data[46]=JTSP72;
// assign jtspat_stored_data[45]=JTSP73;
// assign jtspat_stored_data[44]=JTSP74;
// assign jtspat_stored_data[43]=JTSP75;
// assign jtspat_stored_data[42]=JTSP76;
// assign jtspat_stored_data[41]=JTSP77;
// assign jtspat_stored_data[40]=JTSP78;
// assign jtspat_stored_data[39]=JTSP79;
// assign jtspat_stored_data[38]=JTSP80;
// assign jtspat_stored_data[37]=JTSP81;
// assign jtspat_stored_data[36]=JTSP82;
// assign jtspat_stored_data[35]=JTSP83;
// assign jtspat_stored_data[34]=JTSP84;
// assign jtspat_stored_data[33]=JTSP85;
// assign jtspat_stored_data[32]=JTSP86;
// assign jtspat_stored_data[31]=JTSP87;
// assign jtspat_stored_data[30]=JTSP88;
// assign jtspat_stored_data[29]=JTSP89;
// assign jtspat_stored_data[28]=JTSP90;
// assign jtspat_stored_data[27]=JTSP91;
// assign jtspat_stored_data[26]=JTSP92;
// assign jtspat_stored_data[25]=JTSP93;
// assign jtspat_stored_data[24]=JTSP94;
// assign jtspat_stored_data[23]=JTSP95;
// assign jtspat_stored_data[22]=JTSP96;
// assign jtspat_stored_data[21]=JTSP97;

assign jtspat_stored_data_4[8]=JTSP98;
assign jtspat_stored_data_4[7]=JTSP99;
assign jtspat_stored_data_4[6]=JTSP100;
assign jtspat_stored_data_4[5]=JTSP101;
assign jtspat_stored_data_4[4]=JTSP102;
assign jtspat_stored_data_4[3]=JTSP103;
assign jtspat_stored_data_4[2]=JTSP104;
assign jtspat_stored_data_4[1]=JTSP105;
assign jtspat_stored_data_4[0]=JTSP106;

// assign jtspat_stored_data[11]=JTSP107;
// assign jtspat_stored_data[10]=JTSP108;
// assign jtspat_stored_data[9]=JTSP109;
// assign jtspat_stored_data[8]=JTSP110;
// assign jtspat_stored_data[7]=JTSP111;
// assign jtspat_stored_data[6]=JTSP112;
// assign jtspat_stored_data[5]=JTSP113;
// assign jtspat_stored_data[4]=JTSP114;
// assign jtspat_stored_data[3]=JTSP115;
// assign jtspat_stored_data[2]=JTSP116;
// assign jtspat_stored_data[1]=JTSP117;
// assign jtspat_stored_data[0]=JTSP118;





// assign jtspat_stored_data[48]='h50;
// assign jtspat_stored_data[47]='hf8;
// assign jtspat_stored_data[46]='h9e;
// assign jtspat_stored_data[45] ='hc9;
// assign jtspat_stored_data[44] ='haa;
// assign jtspat_stored_data[43] ='h50;
// assign jtspat_stored_data[42] ='he7;
// assign jtspat_stored_data[41] ='h18;
// assign jtspat_stored_data[40] ='h6d;
// assign jtspat_stored_data[39] ='h97;
// assign jtspat_stored_data[38] ='h4d;
// assign jtspat_stored_data[37] ='hed;
// assign jtspat_stored_data[36] ='h81;
// assign jtspat_stored_data[35] ='hc7;
// assign jtspat_stored_data[34] ='h40;
// assign jtspat_stored_data[33] ='hb5;
// assign jtspat_stored_data[32] ='h36;
// assign jtspat_stored_data[31] ='h97;
// assign jtspat_stored_data[30] ='h14;
// assign jtspat_stored_data[29] ='h3b;
// assign jtspat_stored_data[28] ='hfe;
// assign jtspat_stored_data[27] ='hf1;
// assign jtspat_stored_data[26] ='h64;
// assign jtspat_stored_data[25] ='hc6;
// assign jtspat_stored_data[24] ='hb7;
// assign jtspat_stored_data[23] ='h67;
// assign jtspat_stored_data[22] ='h73;
// assign jtspat_stored_data[21] ='hbb;
// assign jtspat_stored_data[20] ='h73;
// assign jtspat_stored_data[19] ='h65;
// assign jtspat_stored_data[18] ='h36;
// assign jtspat_stored_data[17] ='h05;
// assign jtspat_stored_data[16] ='haf;
// assign jtspat_stored_data[15] ='hf8;
// assign jtspat_stored_data[14] ='h70;
// assign jtspat_stored_data[13] ='h41;
// assign jtspat_stored_data[12] ='hb7;
// assign jtspat_stored_data[11] ='hf4;
// assign jtspat_stored_data[10] ='heb;
// assign jtspat_stored_data[9] ='hf4;
// assign jtspat_stored_data[8] ='hf2;
// assign jtspat_stored_data[7] ='h1d;
// assign jtspat_stored_data[6] ='hd0;
// assign jtspat_stored_data[5] ='h79;
// assign jtspat_stored_data[4] ='h01;
// assign jtspat_stored_data[3] ='h3c;
// assign jtspat_stored_data[2] ='hbe;
// assign jtspat_stored_data[1] ='h45;
// assign jtspat_stored_data[0] ='hd5;

reg [7:0] data_count;
reg [37:0]detector_stored_data_1 ;
reg [8:0]detector_stored_data_2 ;
reg [11:0]detector_stored_data_3 ;
reg [8:0]detector_stored_data_4 ;

reg detected_jtspat;

reg   [7:0] jtspat_data_delayed [43:0];
genvar i;
wire jtspat_ok_w_1,jtspat_ok_w_2,jtspat_ok_w_3,jtspat_ok_w_4;

reg [3:0] jtspat_err_count_r;
reg [3:0] jtspat_vld_count_r;
reg [3:0] sync_state;
assign jtspat_err_count = jtspat_err_count_r;
assign jtspat_vld_count = jtspat_vld_count_r;

assign jtspat_ok_w_1 = &detector_stored_data_1; 
assign jtspat_ok_w_2 = &detector_stored_data_2; 
assign jtspat_ok_w_3 = &detector_stored_data_3; 
assign jtspat_ok_w_4 = &detector_stored_data_4;


//State machine to detect the sequence. The JTSPAT sequence is divided in 6 blocks and two of them have the same incoming data.
parameter state_1=4'b0, state_2=4'b1, state_3=4'b010, state_4=4'b011, state_5=4'b100, state_6=4'b101;

always@(posedge clk_character or posedge rst_clk_character)
begin
  if (rst_clk_character)
  begin
    sync_state<='h0;
    detected_jtspat<='h0;
    data_count<='h0;
  end
  else if (tx_rx_enable_jtspat_test=='h0)
  begin
    sync_state<='h0;
    detected_jtspat<='h0;
    data_count<='h0;
  end

  else
  begin
    case (sync_state)
      state_1:
      begin
        data_count<='h0;
        if (jtspat_ok_w_1)
          sync_state<=state_2;
        else 
        begin
          sync_state<=state_1;
        end
      end
      state_2: 
      begin
        if (jtspat_ok_w_2)
          sync_state<=state_3;
        else 
        begin
          if (data_count>'d3)
          begin
            data_count<='d31;
            sync_state<='h0;
          end
          else 
            sync_state<=state_2;
        end
      end
      state_3: 
      begin
        if (jtspat_ok_w_3)
          sync_state<=state_4;
        else 
        begin
          if (data_count>'d6)
          begin
            sync_state<='h0;
          data_count<='d31;
          end
          else 
            sync_state<=state_3;
        end
      end
      state_4: 
      begin
        if (jtspat_ok_w_1)
          sync_state<=state_5;
        else 
        begin
          if (data_count>'d16)
          begin
            sync_state<='h0;
          data_count<='d31;
          end
          else 
            sync_state<=state_4;
        end
      end
      state_5: 
      begin
        if (jtspat_ok_w_4)
          sync_state<=state_6;
        else 
        begin
          if (data_count>'d17)
          begin
            sync_state<='h0;
            data_count<='d31;
          end
          else 
            sync_state<=state_5;
        end
      end  
      state_6: 
      begin
        if (jtspat_ok_w_3)
        begin
          sync_state<=state_1;
          detected_jtspat<='h1;
          data_count<='d31;
        end
        else 
          sync_state<=state_6;
      end
      default:
        sync_state<=state_1;
    endcase
    if (sync_state !=state_1)
      data_count<= data_count + 'h1;
    if (data_count>=20)
    begin//4
      sync_state<='h0;     
      detected_jtspat<='h0;  
      data_count<='h0;
    end
  end
end

reg [7:0] no_sync;

always @(posedge clk_character or posedge rst_clk_character)
begin //1
  if (rst_clk_character)
  begin
    no_sync<='h0;
    jtspat_err_count_r<='h0;
    jtspat_vld_count_r <='h0;
  end
  else if (~tx_rx_enable_jtspat_test)
  begin
    no_sync<='h0;
    jtspat_err_count_r<='h0;
    jtspat_vld_count_r <='h0;
  end
  else 
  begin
    if (jtspat_err_count_r=='h1)
      jtspat_err_count_r<='h0;
    if (jtspat_vld_count_r =='h1)  
      jtspat_vld_count_r <='h0;
    if (sync_state ==state_1)
      no_sync<=no_sync+'h1;
    else 
      no_sync<='h0;
    if (no_sync >'d10)
    begin
      jtspat_err_count_r<=jtspat_err_count_r + 'h1;
      no_sync<='h0;
    end
    if(data_count>='d20)// && detected_jtspat=='h1)
    begin//2
      if ( detected_jtspat=='h1)
      begin//3
        jtspat_vld_count_r<= jtspat_vld_count_r +'h1;
      end//3
      else
      begin //4
        jtspat_err_count_r<=jtspat_err_count_r + 'h1;
      end//4
    end
  end//2
end//1


always@(posedge clk_character or posedge rst_clk_character)
begin
  if (rst_clk_character)
  begin
    jtspat_data_delayed[0][7:0] <= 'h0;
    jtspat_data_delayed[1][7:0] <= 'h0;
    jtspat_data_delayed[2][7:0] <= 'h0;
    jtspat_data_delayed[3][7:0] <= 'h0;
  end
  else if (~tx_rx_enable_jtspat_test)
  begin
    jtspat_data_delayed[0][7:0] <= 'h0;
    jtspat_data_delayed[1][7:0] <= 'h0;
    jtspat_data_delayed[2][7:0] <= 'h0;
    jtspat_data_delayed[3][7:0] <= 'h0;
  end
  else
  begin
    jtspat_data_delayed[0][7:0] <= jtspat_data[31:24];
    jtspat_data_delayed[1][7:0] <= jtspat_data[23:16];
    jtspat_data_delayed[2][7:0] <= jtspat_data[15:8];
    jtspat_data_delayed[3][7:0] <= jtspat_data[7:0];
  end
end

generate
for (i=0; i<=9; i=i+1) begin :shift_data
  always@(posedge clk_character or posedge rst_clk_character)
  begin
    if (rst_clk_character)
    begin
      jtspat_data_delayed[i*4+4][7:0] <='h0;
      jtspat_data_delayed[i*4+5][7:0] <='h0;
      jtspat_data_delayed[i*4+6][7:0] <='h0;
      jtspat_data_delayed[i*4+7][7:0] <='h0;
    
    end
    else if (~tx_rx_enable_jtspat_test)
    begin
      jtspat_data_delayed[i*4+4][7:0] <= 'h0;
      jtspat_data_delayed[i*4+5][7:0] <= 'h0;
      jtspat_data_delayed[i*4+6][7:0] <= 'h0;
      jtspat_data_delayed[i*4+7][7:0] <= 'h0;
    end
    else
    begin
      jtspat_data_delayed[i*4+4][7:0] <=jtspat_data_delayed[i*4][7:0];
      jtspat_data_delayed[i*4+5][7:0] <=jtspat_data_delayed[i*4+1][7:0];
      jtspat_data_delayed[i*4+6][7:0] <=jtspat_data_delayed[i*4+2][7:0];
      jtspat_data_delayed[i*4+7][7:0] <=jtspat_data_delayed[i*4+3][7:0];
    end
  end
end
endgenerate

generate
for (i=0; i<38; i=i+1) begin : detect_jtspat
  always@(posedge clk_character or posedge rst_clk_character)
  begin
    if (rst_clk_character)
    begin
      detector_stored_data_1[i] <='h0;
    end
    else if (~tx_rx_enable_jtspat_test)
    begin
      detector_stored_data_1[i] <='h0;
    end
    else
    begin
      if(jtspat_data_delayed[i]==jtspat_stored_data_1[i])
      begin
        detector_stored_data_1[i]<='h1;
      end
      else if(jtspat_data_delayed[i+1]==jtspat_stored_data_1[i])
      begin
        detector_stored_data_1[i]<='h1;
      end
      else if(jtspat_data_delayed[i+2]==jtspat_stored_data_1[i])
      begin
        detector_stored_data_1[i]<='h1;
      end
      else if(jtspat_data_delayed[i+3]==jtspat_stored_data_1[i])
      begin
        detector_stored_data_1[i]<='h1;
      end  
      else 
      begin
        detector_stored_data_1[i]<='h0;      
      end
    end
  end
end


for (i=0; i<9; i=i+1) begin : detect_jtspat_2
  always@(posedge clk_character or posedge rst_clk_character)
  begin
    if (rst_clk_character)
    begin
      detector_stored_data_2[i] <='h0;
    end
    else if (~tx_rx_enable_jtspat_test)
    begin
      detector_stored_data_2[i] <='h0;
    end
    else
    begin
      if(jtspat_data_delayed[i]==jtspat_stored_data_2[i])
      begin
        detector_stored_data_2[i]<='h1;
      end
      else if(jtspat_data_delayed[i+1]==jtspat_stored_data_2[i])
      begin
        detector_stored_data_2[i]<='h1;
      end
      else if(jtspat_data_delayed[i+2]==jtspat_stored_data_2[i])
      begin
        detector_stored_data_2[i]<='h1;
      end
      else if(jtspat_data_delayed[i+3]==jtspat_stored_data_2[i])
      begin
        detector_stored_data_2[i]<='h1;
      end  
      else 
      begin
        detector_stored_data_2[i]<='h0;
      end
    end
  end
end

for (i=0; i<12; i=i+1) begin : detect_jtspat_3
  always@(posedge clk_character or posedge rst_clk_character)
  begin
    if (rst_clk_character)
    begin
      detector_stored_data_3[i] <='h0;
    end
    else if (~tx_rx_enable_jtspat_test)
    begin
      detector_stored_data_3[i] <='h0;
    end
    else
    begin
      if(jtspat_data_delayed[i]==jtspat_stored_data_3[i])
      begin
        detector_stored_data_3[i]<='h1;
      end
      else if(jtspat_data_delayed[i+1]==jtspat_stored_data_3[i])
      begin
        detector_stored_data_3[i]<='h1;
      end
      else if(jtspat_data_delayed[i+2]==jtspat_stored_data_3[i])
      begin
        detector_stored_data_3[i]<='h1;
      end
      else if(jtspat_data_delayed[i+3]==jtspat_stored_data_3[i])
      begin
        detector_stored_data_3[i]<='h1;
      end  
      else 
      begin
        detector_stored_data_3[i]<='h0;
      end
    end
  end
end

for (i=0; i<9; i=i+1) begin : detect_jtspat_4
  always@(posedge clk_character or posedge rst_clk_character)
  begin
    if (rst_clk_character)
    begin
      detector_stored_data_4[i] <='h0;
    end
    else if (~tx_rx_enable_jtspat_test)
    begin
      detector_stored_data_4[i] <='h0;
    end
    else
    begin
      if(jtspat_data_delayed[i]==jtspat_stored_data_4[i])
      begin
        detector_stored_data_4[i]<='h1;
      end
      else if(jtspat_data_delayed[i+1]==jtspat_stored_data_4[i])
      begin
        detector_stored_data_4[i]<='h1;
      end
      else if(jtspat_data_delayed[i+2]==jtspat_stored_data_4[i])
      begin
        detector_stored_data_4[i]<='h1;
      end
      else if(jtspat_data_delayed[i+3]==jtspat_stored_data_4[i])
      begin
        detector_stored_data_4[i]<='h1;
      end  
      else 
      begin
        detector_stored_data_4[i]<='h0;
      end
    end
  end
end

endgenerate


 

endmodule
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
