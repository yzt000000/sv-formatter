

// The module has support to take in seed and 32 bit data and generate 32 bit output scrambled data
// It follows the polynomial listed in the JESD204B spec. Asserting seed_vld signal along with data_vld signal
// will override the internally stored seed.Bit order of the seed bus may need to be flipped.
// If bypass_scr is asserted the data_in is simply passed to data_out. Latency of this module is 1 clock.


module jesd_scrambler32(
  input              clk_character,     //primary clock
  input              rst_clk_character, //primary reset
  input [14:0]       seed,              //initial scrambler state
  input              seed_vld,          //when 1 and unscr_data_vld is high indicates seed input should be used as scrambler state
  input              unscr_data_vld,    //Input signal indicating valid information present on unscr_data
  input              dis_scr,           //When 1 scrambling is bypassed
  output reg         scr_data_vld,      //Output signal indicating valid information present on scr_data
  input [ 31:0]      unscr_data,        //Input data to be scrambled
  output [ 31:0]     scr_data,          //Output scrambled data 
  output reg [ 14:0] curr_lfsr          //Debug port
);
	 wire [ 31:0]       data_in;
	 reg [ 31:0]        data_out;
   
  // Flip octet positions at input as the scrambler uses bit 31 as the first bit

  assign data_in[31:24] = unscr_data[07:00];
  assign data_in[23:16] = unscr_data[15:08];
  assign data_in[15:08] = unscr_data[23:16];
  assign data_in[07:00] = unscr_data[31:24];
/*   
   assign  data_in[31:24] = {unscr_data[0],unscr_data[1],unscr_data[2],unscr_data[3],unscr_data[4],unscr_data[5],unscr_data[6],unscr_data[7]};
  assign  data_in[23:16] = {unscr_data[8],unscr_data[9],unscr_data[10],unscr_data[11],unscr_data[12],unscr_data[13],unscr_data[14],unscr_data[15]};
  assign  data_in[15:08] = {unscr_data[16],unscr_data[17],unscr_data[18],unscr_data[19],unscr_data[20],unscr_data[21],unscr_data[22],unscr_data[23]};
  assign  data_in[07:00] = {unscr_data[24],unscr_data[25],unscr_data[26],unscr_data[27],unscr_data[28],unscr_data[29],unscr_data[30],unscr_data[31]};
*/
  // Flip octet positions at output as the scrambler uses bit 31 as the first bit

  assign scr_data[31:24] = data_out[07:00];
  assign scr_data[23:16] = data_out[15:08];
  assign scr_data[15:08] = data_out[23:16];
  assign scr_data[07:00] = data_out[31:24];

/*
   assign  scr_data[31:24] = {data_out[0],data_out[1],data_out[2],data_out[3],data_out[4],data_out[5],data_out[6],data_out[7]};
  assign  scr_data[23:16] = {data_out[8],data_out[9],data_out[10],data_out[11],data_out[12],data_out[13],data_out[14],data_out[15]};
  assign  scr_data[15:08] = {data_out[16],data_out[17],data_out[18],data_out[19],data_out[20],data_out[21],data_out[22],data_out[23]};
  assign  scr_data[07:00] = {data_out[24],data_out[25],data_out[26],data_out[27],data_out[28],data_out[29],data_out[30],data_out[31]};
*/   

  wire [14:0]        next_seed = (seed_vld & unscr_data_vld) ? seed : curr_lfsr;


  always @(posedge clk_character or posedge rst_clk_character) begin
    if(rst_clk_character) begin
      curr_lfsr <= 15'h0;
    end else begin
      if(unscr_data_vld) begin
          curr_lfsr[  0] <= next_seed[  2] ^ next_seed[  4] ^ data_in[ 29] ^ data_in[ 28] ^ data_in[ 14];
          curr_lfsr[  1] <= next_seed[  3] ^ next_seed[  5] ^ data_in[ 28] ^ data_in[ 27] ^ data_in[ 13];
          curr_lfsr[  2] <= next_seed[  4] ^ next_seed[  6] ^ data_in[ 27] ^ data_in[ 26] ^ data_in[ 12];
          curr_lfsr[  3] <= next_seed[  5] ^ next_seed[  7] ^ data_in[ 26] ^ data_in[ 25] ^ data_in[ 11];
          curr_lfsr[  4] <= next_seed[  6] ^ next_seed[  8] ^ data_in[ 25] ^ data_in[ 24] ^ data_in[ 10];
          curr_lfsr[  5] <= next_seed[  7] ^ next_seed[  9] ^ data_in[ 24] ^ data_in[ 23] ^ data_in[  9];
          curr_lfsr[  6] <= next_seed[  8] ^ next_seed[ 10] ^ data_in[ 23] ^ data_in[ 22] ^ data_in[  8];
          curr_lfsr[  7] <= next_seed[  9] ^ next_seed[ 11] ^ data_in[ 22] ^ data_in[ 21] ^ data_in[  7];
          curr_lfsr[  8] <= next_seed[ 10] ^ next_seed[ 12] ^ data_in[ 21] ^ data_in[ 20] ^ data_in[  6];
          curr_lfsr[  9] <= next_seed[ 11] ^ next_seed[ 13] ^ data_in[ 20] ^ data_in[ 19] ^ data_in[  5];
          curr_lfsr[ 10] <= next_seed[ 12] ^ next_seed[ 14] ^ data_in[ 19] ^ data_in[ 18] ^ data_in[  4];
          curr_lfsr[ 11] <= next_seed[  0] ^ next_seed[  1] ^ next_seed[ 13] ^ data_in[ 31] ^ data_in[ 18] ^ data_in[ 17] ^ data_in[  3];
          curr_lfsr[ 12] <= next_seed[  1] ^ next_seed[  2] ^ next_seed[ 14] ^ data_in[ 30] ^ data_in[ 17] ^ data_in[ 16] ^ data_in[  2];
          curr_lfsr[ 13] <= next_seed[  0] ^ next_seed[  1] ^ next_seed[  2] ^ next_seed[  3] ^ data_in[ 31] ^ data_in[ 29] ^ data_in[ 16] ^ data_in[ 15] ^ data_in[  1];
          curr_lfsr[ 14] <= next_seed[  1] ^ next_seed[  2] ^ next_seed[  3] ^ next_seed[  4] ^ data_in[ 30] ^ data_in[ 28] ^ data_in[ 15] ^ data_in[ 14] ^ data_in[  0];
      end // if (unscr_data_vld)
    end // else: !if(rst_clk_character)
  end // always @ (posedge clk_character or posedge rst_clk_character)

  always @(posedge clk_character or posedge rst_clk_character) begin
    if(rst_clk_character) begin
      scr_data_vld <= 1'h0;
      data_out <= 32'h0;       
    end else begin
      scr_data_vld <= unscr_data_vld;
      if(unscr_data_vld ) begin
         if (dis_scr == 1'b1)
           data_out <= data_in;
         else begin
            data_out[ 31] <= next_seed[  0] ^ next_seed[  1] ^ data_in[ 31];
            data_out[ 30] <= next_seed[  1] ^ next_seed[  2] ^ data_in[ 30];
            data_out[ 29] <= next_seed[  2] ^ next_seed[  3] ^ data_in[ 29];
            data_out[ 28] <= next_seed[  3] ^ next_seed[  4] ^ data_in[ 28];
            data_out[ 27] <= next_seed[  4] ^ next_seed[  5] ^ data_in[ 27];
            data_out[ 26] <= next_seed[  5] ^ next_seed[  6] ^ data_in[ 26];
            data_out[ 25] <= next_seed[  6] ^ next_seed[  7] ^ data_in[ 25];
            data_out[ 24] <= next_seed[  7] ^ next_seed[  8] ^ data_in[ 24];
            data_out[ 23] <= next_seed[  8] ^ next_seed[  9] ^ data_in[ 23];
            data_out[ 22] <= next_seed[  9] ^ next_seed[ 10] ^ data_in[ 22];
            data_out[ 21] <= next_seed[ 10] ^ next_seed[ 11] ^ data_in[ 21];
            data_out[ 20] <= next_seed[ 11] ^ next_seed[ 12] ^ data_in[ 20];
            data_out[ 19] <= next_seed[ 12] ^ next_seed[ 13] ^ data_in[ 19];
            data_out[ 18] <= next_seed[ 13] ^ next_seed[ 14] ^ data_in[ 18];
            data_out[ 17] <= next_seed[  0] ^ next_seed[  1] ^ next_seed[ 14] ^ data_in[ 31] ^ data_in[ 17];
            data_out[ 16] <= next_seed[  0] ^ next_seed[  2] ^ data_in[ 31] ^ data_in[ 30] ^ data_in[ 16];
            data_out[ 15] <= next_seed[  1] ^ next_seed[  3] ^ data_in[ 30] ^ data_in[ 29] ^ data_in[ 15];
            data_out[ 14] <= next_seed[  2] ^ next_seed[  4] ^ data_in[ 29] ^ data_in[ 28] ^ data_in[ 14];
            data_out[ 13] <= next_seed[  3] ^ next_seed[  5] ^ data_in[ 28] ^ data_in[ 27] ^ data_in[ 13];
            data_out[ 12] <= next_seed[  4] ^ next_seed[  6] ^ data_in[ 27] ^ data_in[ 26] ^ data_in[ 12];
            data_out[ 11] <= next_seed[  5] ^ next_seed[  7] ^ data_in[ 26] ^ data_in[ 25] ^ data_in[ 11];
            data_out[ 10] <= next_seed[  6] ^ next_seed[  8] ^ data_in[ 25] ^ data_in[ 24] ^ data_in[ 10];
            data_out[  9] <= next_seed[  7] ^ next_seed[  9] ^ data_in[ 24] ^ data_in[ 23] ^ data_in[  9];
            data_out[  8] <= next_seed[  8] ^ next_seed[ 10] ^ data_in[ 23] ^ data_in[ 22] ^ data_in[  8];
            data_out[  7] <= next_seed[  9] ^ next_seed[ 11] ^ data_in[ 22] ^ data_in[ 21] ^ data_in[  7];
            data_out[  6] <= next_seed[ 10] ^ next_seed[ 12] ^ data_in[ 21] ^ data_in[ 20] ^ data_in[  6];
            data_out[  5] <= next_seed[ 11] ^ next_seed[ 13] ^ data_in[ 20] ^ data_in[ 19] ^ data_in[  5];
            data_out[  4] <= next_seed[ 12] ^ next_seed[ 14] ^ data_in[ 19] ^ data_in[ 18] ^ data_in[  4];
            data_out[  3] <= next_seed[  0] ^ next_seed[  1] ^ next_seed[ 13] ^ data_in[ 31] ^ data_in[ 18] ^ data_in[ 17] ^ data_in[  3];
            data_out[  2] <= next_seed[  1] ^ next_seed[  2] ^ next_seed[ 14] ^ data_in[ 30] ^ data_in[ 17] ^ data_in[ 16] ^ data_in[  2];
            data_out[  1] <= next_seed[  0] ^ next_seed[  1] ^ next_seed[  2] ^ next_seed[  3] ^ data_in[ 31] ^ data_in[ 29] ^ data_in[ 16] ^ data_in[ 15] ^ data_in[  1];
            data_out[  0] <= next_seed[  1] ^ next_seed[  2] ^ next_seed[  3] ^ next_seed[  4] ^ data_in[ 30] ^ data_in[ 28] ^ data_in[ 15] ^ data_in[ 14] ^ data_in[  0];
         end // else: !if(dis_scr == 1'b1)
      end // if (unscr_data_vld)
    end // else: !if(rst_clk_character)
  end // always @ (posedge clk_character or posedge rst_clk_character)

   
endmodule // jesd_scrambler32
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
