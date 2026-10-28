

// The module has support to take in seed and 32 bit data and generate 32 bit output descrambled data
// It follows the polynomial listed in the JESD204B spec. Asserting seed_vld signal along with data_vld signal
// will override the internally stored seed. If bypass_scr is asserted the data_in is simply passed to data_out.
// Latency of this module is 1 clock.
// Self synchronizing de-scrambler and first 2 bytes of processed data should be ignored else correct seed shoule 
// be provided using the seed, seed_vld signals.Bit order of the seed bus may need to be flipped.

module jesd_dscrambler32(
	input              clk,            // Primary clock . In our case clk_character
	input              reset,          // Asynchronous active high reset 
  input [14:0]       seed,           // External seed. 
	input              seed_vld,       // When high along with scr_data_vld indicates we need to replace the stored seed with this value
	input              scr_data_vld,   // When high Indicates that 32 bit data on scr_data needs to be processed
	input [ 31:0]      scr_data,       // Input data stream
  input              bypass_dscr,    // Signal to turn of descrambling but maintain the latency of the block
                        
	output reg         unscr_data_vld, // When high Indicates that 32 bit data on unscr_data is valid
	output [ 31:0]     unscr_data,     // Output data stream
	output reg [ 14:0] curr_lfsr       // Output for debug purpose                       
);
	 wire [ 31:0]       data_in;
	 reg [ 31:0]        data_out;

  // Flip octet positions at input as the scrambler uses bit 31 as the first bit
  
  assign data_in[31:24] = scr_data[07:00];
  assign data_in[23:16] = scr_data[15:08];
  assign data_in[15:08] = scr_data[23:16];
  assign data_in[07:00] = scr_data[31:24];
/*
   
   assign  data_in[31:24] = {scr_data[0],scr_data[1],scr_data[2],scr_data[3],scr_data[4],scr_data[5],scr_data[6],scr_data[7]};
  assign  data_in[23:16] = {scr_data[8],scr_data[9],scr_data[10],scr_data[11],scr_data[12],scr_data[13],scr_data[14],scr_data[15]};
  assign  data_in[15:08] = {scr_data[16],scr_data[17],scr_data[18],scr_data[19],scr_data[20],scr_data[21],scr_data[22],scr_data[23]};
  assign  data_in[07:00] = {scr_data[24],scr_data[25],scr_data[26],scr_data[27],scr_data[28],scr_data[29],scr_data[30],scr_data[31]};
*/
  // Flip octet positions at output as the scrambler uses bit 31 as the first bit

  assign unscr_data[31:24] = data_out[07:00];
  assign unscr_data[23:16] = data_out[15:08];
  assign unscr_data[15:08] = data_out[23:16];
  assign unscr_data[07:00] = data_out[31:24];
/*

   assign  unscr_data[31:24] = {data_out[0],data_out[1],data_out[2],data_out[3],data_out[4],data_out[5],data_out[6],data_out[7]};
  assign  unscr_data[23:16] = {data_out[8],data_out[9],data_out[10],data_out[11],data_out[12],data_out[13],data_out[14],data_out[15]};
  assign  unscr_data[15:08] = {data_out[16],data_out[17],data_out[18],data_out[19],data_out[20],data_out[21],data_out[22],data_out[23]};
  assign  unscr_data[07:00] = {data_out[24],data_out[25],data_out[26],data_out[27],data_out[28],data_out[29],data_out[30],data_out[31]};   
  */ 
  wire [14:0]        next_seed = (seed_vld & scr_data_vld) ? seed : curr_lfsr;
   
   
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			curr_lfsr <= 15'h0;
		end else begin
			if(scr_data_vld) begin
					curr_lfsr[  0] <= data_in[ 14];
					curr_lfsr[  1] <= data_in[ 13];
					curr_lfsr[  2] <= data_in[ 12];
					curr_lfsr[  3] <= data_in[ 11];
					curr_lfsr[  4] <= data_in[ 10];
					curr_lfsr[  5] <= data_in[  9];
					curr_lfsr[  6] <= data_in[  8];
					curr_lfsr[  7] <= data_in[  7];
					curr_lfsr[  8] <= data_in[  6];
					curr_lfsr[  9] <= data_in[  5];
					curr_lfsr[ 10] <= data_in[  4];
					curr_lfsr[ 11] <= data_in[  3];
					curr_lfsr[ 12] <= data_in[  2];
					curr_lfsr[ 13] <= data_in[  1];
					curr_lfsr[ 14] <= data_in[  0];
			end // if (scr_data_vld)
		end // else: !if(reset)
	end // always @ (posedge clk or posedge reset)


	always @(posedge clk or posedge reset) begin
		if(reset) begin
			unscr_data_vld <= 1'h0;
      data_out <= 32'h0; 
		end else begin
			unscr_data_vld <= scr_data_vld;
       if (bypass_dscr) 
         data_out <= data_in;
			 else if(scr_data_vld) begin
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
					data_out[ 17] <= next_seed[ 14] ^ data_in[ 31] ^ data_in[ 17];
					data_out[ 16] <= data_in[ 31] ^ data_in[ 30] ^ data_in[ 16];
					data_out[ 15] <= data_in[ 30] ^ data_in[ 29] ^ data_in[ 15];
					data_out[ 14] <= data_in[ 29] ^ data_in[ 28] ^ data_in[ 14];
					data_out[ 13] <= data_in[ 28] ^ data_in[ 27] ^ data_in[ 13];
					data_out[ 12] <= data_in[ 27] ^ data_in[ 26] ^ data_in[ 12];
					data_out[ 11] <= data_in[ 26] ^ data_in[ 25] ^ data_in[ 11];
					data_out[ 10] <= data_in[ 25] ^ data_in[ 24] ^ data_in[ 10];
					data_out[  9] <= data_in[ 24] ^ data_in[ 23] ^ data_in[  9];
					data_out[  8] <= data_in[ 23] ^ data_in[ 22] ^ data_in[  8];
					data_out[  7] <= data_in[ 22] ^ data_in[ 21] ^ data_in[  7];
					data_out[  6] <= data_in[ 21] ^ data_in[ 20] ^ data_in[  6];
					data_out[  5] <= data_in[ 20] ^ data_in[ 19] ^ data_in[  5];
					data_out[  4] <= data_in[ 19] ^ data_in[ 18] ^ data_in[  4];
					data_out[  3] <= data_in[ 18] ^ data_in[ 17] ^ data_in[  3];
					data_out[  2] <= data_in[ 17] ^ data_in[ 16] ^ data_in[  2];
					data_out[  1] <= data_in[ 16] ^ data_in[ 15] ^ data_in[  1];
					data_out[  0] <= data_in[ 15] ^ data_in[ 14] ^ data_in[  0];
			 end // if (scr_data_vld)       
    end // else: !if(reset)
	end // always @ (posedge clk or posedge reset)
   
endmodule











//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
