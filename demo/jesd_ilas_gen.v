

// This module is responsible for generating the ilas multiframes which are either part of the normal link up sequence 
// or part of linktest operation. The ILAS contains incremental sequence of octets an single counter for increment logic
// would have been sufficient but instead we use 4 separate adders (one per octet of 32 bit data path) to help timing 
// closure in FPGA. The logic for this is implemented as macro MACRO_OCTET_COUNTER so as to keep the code compact

module jesd_ilas_gen
  (
   input             clk_character,             // Primary clock
   input             rst_clk_character,         // Primary reset
   input [10:0]      mframe_length_char,        // Number of octets in multiframe  
   input [8:0]       ilas_length_mframe,        // Number of multi frames in ILAS
   input [6:0]       sample_to_frame_delay,     // Variable delay between start_sample_if and first frame to be transmitted. Value depends on F, S, and clk_ratio
   input [1:0]       txrx_enablelinktest_reg,   // Control signal to trigger test mode of repeating ILAS pattern
   input [3:0]       txrx_bank_id_reg,          // ILAS Parameter to be advertised
   input [4:0]       txrx_cf_reg,               // ILAS Parameter to be advertised
   input [1:0]       txrx_cs_reg,               // ILAS Parameter to be advertised
   input [7:0]       txrx_did_reg,              // ILAS Parameter to be advertised 
   input [7:0]       txrx_f_reg,                // ILAS Parameter to be advertised
   input [0:0]       txrx_hd_reg,               // ILAS Parameter to be advertised  
   input [4:0]       txrx_k_reg,                // ILAS Parameter to be advertised  
   input [4:0]       txrx_l_reg,                // ILAS Parameter to be advertised
   input [4:0]       txrx_lid_reg,              // ILAS Parameter to be advertised 
   input [7:0]       txrx_m_reg,                // ILAS Parameter to be advertised
   input [4:0]       txrx_n_reg,                // ILAS Parameter to be advertised 
   input [4:0]       txrx_ntotal_reg,           // ILAS Parameter to be advertised
   input [4:0]       txrx_s_reg,                // ILAS Parameter to be advertised 
   input [0:0]       txrx_scr_reg,              // ILAS Parameter to be advertised  
   input [2:0]       txrx_subclass_reg,         // ILAS Parameter to be advertised  
   input [3:0]       txrx_adjcnt_reg,           // ILAS Parameter to be advertised 
   input             txrx_adjdir_reg,           // ILAS Parameter to be advertised
   input             txrx_phadj_reg,            // ILAS Parameter to be advertised
   input             disable_ilas_tx,           // Control bit when 1 disable ILAS generation 
   input [7:0]       sum_ilas_com_param,        // Sum of all the parameters that are common across all lanes . (all except LID)
   input             halt_or_reset_non_cgs_stream, // Input when 1 indicates that CGS or JSPAT_CUSTOM data transmission is active 
   input             ilas_data_rdy,        // Handshake signal confirming that information on ilas_data_* output signals has been transferred to next module              
   output reg        start_sample_if,      // Signal to sample interface to start requesting samples
   output [31:0]     ilas_data,            // 4 octets of transmit data stream  carrying the CGS octets                                                                    
   output [3:0]      ilas_data_k,          // 1 bit corresponding to each octet of ilas_data. Indication of whether the chracter is contol character or data              
   output reg [1:0]  ilas_data_bc,         // indcates number of octets on ilas_data that should be packed into Tx data stream . 00 implies all 4 octets should be packed 
   output reg        ilas_data_vld,        // 1 bit control signal indicating valid information on ilas_data_* outputs                                                    
   output reg [15:0] ilas_trail_bits //to initialize the scrambler use this as the scrambler seed 
   );
   reg [10:0]        remaining_char_count;
   reg               start_with_r;// flag to indicate the next op should start with /R/
   reg [8:0]         mf_num;
   wire [8:0]        ilas_data_0 = {txrx_did_reg};
   wire [7:0]        ilas_data_1 = {txrx_adjcnt_reg,txrx_bank_id_reg};
   wire [7:0]        ilas_data_2 = {txrx_adjdir_reg,txrx_phadj_reg,txrx_lid_reg};
   wire [7:0]        ilas_data_3 = {txrx_scr_reg,1'b0,1'b0,txrx_l_reg};
   wire [7:0]        ilas_data_4 = {txrx_f_reg};
   wire [7:0]        ilas_data_5 = {txrx_k_reg};
   wire [7:0]        ilas_data_6 = {txrx_m_reg};
   wire [7:0]        ilas_data_7 = {txrx_cs_reg,1'b0,txrx_n_reg};                            
   wire [7:0]        ilas_data_8 = {txrx_subclass_reg,txrx_ntotal_reg};
   wire [7:0]        ilas_data_9 = {3'b001,txrx_s_reg};// JESD204B
   wire [7:0]        ilas_data_10 = {txrx_hd_reg,2'b00,txrx_cf_reg};                            
   reg [7:0]         fchk_calc;
   reg [8:0]         ilas_data_char_0,ilas_data_char_1,ilas_data_char_2,ilas_data_char_3;
   reg               halt_or_reset_non_cgs_stream_r;

   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) 
        halt_or_reset_non_cgs_stream_r <= 1'b0;
      else
        halt_or_reset_non_cgs_stream_r <= halt_or_reset_non_cgs_stream;           
   end
      
   wire              local_reset = !halt_or_reset_non_cgs_stream_r & halt_or_reset_non_cgs_stream;
   
   

   assign {ilas_data_k[0],ilas_data[07:00]}  = ilas_data_char_0;
   assign {ilas_data_k[1],ilas_data[15:08]}  = ilas_data_char_1;
   assign {ilas_data_k[2],ilas_data[23:16]}  = ilas_data_char_2;
   assign {ilas_data_k[3],ilas_data[31:24]}  = ilas_data_char_3;   
   

   
   wire [7:0]        sum_ilas_uncom_param = txrx_lid_reg;
   
   reg               last_mf;
   wire              last_mf_next = (mf_num-1'b1 == 0);
   
//   wire              end_of_ilas =  (mf_num == (ilas_length_mframe-1)) && (remaining_char_count < 'h5);
   reg               end_of_ilas;
   wire              end_of_ilas_next = ~end_of_ilas && last_mf_next && (remaining_char_count < 'h9);

    always @(posedge clk_character or posedge rst_clk_character) begin
       if (rst_clk_character)
         end_of_ilas <= 1'b0;
       else
         end_of_ilas <= end_of_ilas_next;
    end
       

`define MACRO_OCTET_COUNTER(reg_name,reset_value) \
   reg [7:0]        reg_name; \
   always @(posedge clk_character or posedge rst_clk_character) begin \
       if (rst_clk_character) \
          reg_name <= reset_value; \
      else if (local_reset || disable_ilas_tx) \
          reg_name <= reset_value; \
      else if ((ilas_data_vld & ilas_data_rdy) || (ilas_data_vld == 1'b0)) begin \
         if (end_of_ilas) \
           reg_name <= (3'h4 - remaining_char_count[2:0]); \
         else \
           reg_name <= (reg_name + 3'h4); \
      end \
   end // always @ (posedge clk_character or posedge rst_clk_character)

`MACRO_OCTET_COUNTER (octet_counter_0,8'h0)
`MACRO_OCTET_COUNTER (octet_counter_1,8'h1)
`MACRO_OCTET_COUNTER (octet_counter_2,8'h2)
`MACRO_OCTET_COUNTER (octet_counter_3,8'h3)   
   
   reg [4:0] mframe_2_offset;
   reg       first_mf,second_mf;
   //wire [11:0] start_sample_cnt = {{txrx_f_reg[7:0], 1'b0} + 3'b101 - 14, 2'b00}; // {3+{(txrx_f_reg+1), 1'b0}, 2'b00}; == (3 + 2*F) * 4 is the number of characters delay in he transport layer
   //wire [6:0] start_sample_cnt = (txrx_f_reg >= 3) ? (7'h2C + {txrx_f_reg[7:2], 2'b00}) : txrx_f_reg[1] ? 7'h20 : txrx_f_reg [0] ? 7'h18 : 7'h10; 
   wire [8:0] start_sample_cnt = {sample_to_frame_delay, 2'b00};     // Variable delay between start_sample_if and first frame to be transmitted. Value depends on F, S, and clk_ratio
   wire [12:0] mframe_length_char_array [3:0]; 
   reg [2:0] load_start_sample_mf;
   reg [12:0] load_start_sample_chars;
  
   
   assign mframe_length_char_array[0] = {2'b00, mframe_length_char};
   assign mframe_length_char_array[1] = {1'b0, mframe_length_char, 1'b0};
   assign mframe_length_char_array[2] = mframe_length_char_array[1] + mframe_length_char_array[0];
   assign mframe_length_char_array[3] = {mframe_length_char, 2'b00};
            
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         remaining_char_count <= 11'h0;
         start_with_r <= 1'b0;
         mf_num <= 9'h0;
         ilas_data_bc <= 2'h0;
         ilas_data_vld <= 1'b0;      
         fchk_calc <= 8'h00;
         ilas_trail_bits <= 16'h0;
         ilas_data_char_0 <= 9'h0;
         ilas_data_char_1 <= 9'h0;
         ilas_data_char_2 <= 9'h0;
         ilas_data_char_3 <= 9'h0;
         mframe_2_offset <= 5'h0;  
         first_mf <= 1'b1;
         second_mf <= 1'b0;
         last_mf <= 1'b0;         
         load_start_sample_mf <= 3'b000;
         load_start_sample_chars <= 'h0;
         start_sample_if <= 1'b0;
      end
      else if (disable_ilas_tx == 1'b1 || local_reset) begin
         remaining_char_count <= 'h0;
         start_with_r <= 1'b0;
         mf_num <= ilas_length_mframe;
         // Find out in which multiframe before end of ILAS sample data must
         // be requested
         if ({4'h0, start_sample_cnt} <= mframe_length_char_array[0])
         begin
           load_start_sample_mf <= 3'b001;
           load_start_sample_chars <= {4'h0, start_sample_cnt};
         end
         else if ({4'h0, start_sample_cnt} <= mframe_length_char_array[1])
         begin
           load_start_sample_mf <= 3'b010;
           load_start_sample_chars <= {4'h0, start_sample_cnt}-mframe_length_char_array[0] + 3'h4;
         end
         else if ({4'h0, start_sample_cnt} <= mframe_length_char_array[2])
         begin
           load_start_sample_mf <= 3'b011;
           load_start_sample_chars <= {4'h0, start_sample_cnt}-mframe_length_char_array[1] + 3'h4;
         end
         else if ({4'h0, start_sample_cnt} <= mframe_length_char_array[3])
         begin
           load_start_sample_mf <= 3'b100;
           load_start_sample_chars <= {4'h0, start_sample_cnt}-mframe_length_char_array[2] + 3'h4;
         end
         else
         begin
           load_start_sample_mf <= 3'b101;
           load_start_sample_chars <= {6'h0, start_sample_cnt}-mframe_length_char_array[3] + 3'h4;
         end
         start_sample_if <= 1'b0;

         ilas_data_bc <= 2'h0;
         ilas_data_vld <= 1'b0;      
         fchk_calc <= 8'h00;
         mframe_2_offset <= 5'h0;
         first_mf <= 1'b1;
         second_mf <= 1'b0;
         last_mf <= 1'b0;                  
      end
      else if (last_mf) begin
         ilas_data_vld <= 1'b0;         
      end
      else begin
         if (!ilas_data_vld) begin
            remaining_char_count <= mframe_length_char - 11'h4;
            ilas_data_vld <= 1'b1;
            start_with_r <= 1'b0; 
            fchk_calc <= sum_ilas_com_param; 
            ilas_data_char_0 <= character_mux(octet_counter_0,mframe_2_offset,1'b1,1'b0);
            ilas_data_char_1 <= character_mux(octet_counter_1,mframe_2_offset,1'b0,1'b0);
            ilas_data_char_2 <= character_mux(octet_counter_2,mframe_2_offset,1'b0,1'b0);
            ilas_data_char_3 <= character_mux(octet_counter_3,mframe_2_offset,1'b0,1'b0);                  
         end // if (!ilas_data_vld)
         else if (ilas_data_rdy) begin
            if (mf_num=={6'h0, load_start_sample_mf} && (remaining_char_count[10:0]+0)<=load_start_sample_chars[10:0])
              start_sample_if <= 1'b1;
            start_with_r <= 1'b0;
            if (remaining_char_count > 11'h4) begin
               remaining_char_count <=   remaining_char_count - 11'h4;
               if ((mframe_2_offset < 5'h10)  && second_mf) begin               
                  ilas_data_char_0 <= character_mux(octet_counter_0,mframe_2_offset,start_with_r,1'b0);
                  ilas_data_char_1 <= character_mux(octet_counter_1,mframe_2_offset+2'h1,1'b0,1'b0);
                  ilas_data_char_2 <= character_mux(octet_counter_2,mframe_2_offset+2'h2,1'b0,1'b0);
                  ilas_data_char_3 <= character_mux(octet_counter_3,mframe_2_offset+2'h3,1'b0,1'b0);
                  mframe_2_offset <= mframe_2_offset + 3'h4;
               end
               else begin
                  ilas_data_char_0 <= character_mux(octet_counter_0,mframe_2_offset,start_with_r,1'b0);
                  ilas_data_char_1 <= character_mux(octet_counter_1,mframe_2_offset,1'b0,1'b0);
                  ilas_data_char_2 <= character_mux(octet_counter_2,mframe_2_offset,1'b0,1'b0);
                  ilas_data_char_3 <= character_mux(octet_counter_3,mframe_2_offset,1'b0,1'b0);                  
               end // else: !if((mframe_2_offset < 5'h10)  && (mf_num == 1'b1))
            end // if (remaining_char_count > 3'h4)
            else begin    
               second_mf <= first_mf;
               first_mf <= 1'b0;
               last_mf <= last_mf_next;               
               remaining_char_count <= (mframe_length_char - 11'h4) +  {8'h0, remaining_char_count[2:0]};
               case(remaining_char_count[2:0])
                 3:begin
                    ilas_data_char_0 <= character_mux(octet_counter_0,mframe_2_offset,1'b0,1'b0);
                    ilas_data_char_1 <= character_mux(octet_counter_1,mframe_2_offset,1'b0,1'b0);
                    ilas_data_char_2 <= character_mux(octet_counter_2,mframe_2_offset,1'b0,1'b1);
                    ilas_data_char_3 <= character_mux(octet_counter_3,mframe_2_offset,1'b1,1'b0);                    
                    ilas_trail_bits[15:8] <= (octet_counter_2[7:0]);
                    ilas_trail_bits[7:0] <= (octet_counter_1[7:0]);
                 end
                 2:begin
                    ilas_data_char_0 <= character_mux(octet_counter_0,mframe_2_offset,1'b0,1'b0);
                    ilas_data_char_1 <= character_mux(octet_counter_1,mframe_2_offset,1'b0,1'b1);
                    ilas_data_char_2 <= character_mux(octet_counter_2,mframe_2_offset,1'b1,1'b0);

                    if (first_mf)
                      ilas_data_char_3 <= character_mux(octet_counter_3,5'h1,1'b0,1'b0); //Insert /Q/
                    else if (last_mf)
                      ilas_data_char_3 <= character_mux(8'h01,mframe_2_offset,1'b0,1'b0);
                    else
                      ilas_data_char_3 <= character_mux(octet_counter_3,mframe_2_offset,1'b0,1'b0);
                    
                    ilas_trail_bits[15:8] <= (octet_counter_1[7:0]);
                    ilas_trail_bits[7:0] <= (octet_counter_0[7:0]);
                 end
                 1:begin
                    ilas_data_char_0 <= character_mux(octet_counter_0,mframe_2_offset,1'b0,1'b1);
                    ilas_data_char_1 <= character_mux(octet_counter_1,mframe_2_offset,1'b1,1'b0);

                    if (first_mf) begin
                      ilas_data_char_2 <= character_mux(octet_counter_2,5'h1,1'b0,1'b0); //Insert /Q/
                      ilas_data_char_3 <= character_mux(octet_counter_3,5'h2,1'b0,1'b0); // Insert ILAS details
                    end
                    else if (last_mf) begin
                       ilas_data_char_2 <= character_mux(8'h01,mframe_2_offset,1'b0,1'b0);
                       ilas_data_char_3 <= character_mux(8'h02,mframe_2_offset,1'b0,1'b0);                       
                    end
                    else begin
                       ilas_data_char_2 <= character_mux(octet_counter_2,mframe_2_offset,1'b0,1'b0);
                       ilas_data_char_3 <= character_mux(octet_counter_3,mframe_2_offset,1'b0,1'b0);                       
                    end
                    ilas_trail_bits[15:8] <= (octet_counter_0[7:0]);
                    ilas_trail_bits[7:0] <= (ilas_data_char_3[7:0]);
                 end
                 default:begin
                       ilas_data_char_0 <= character_mux(octet_counter_0,mframe_2_offset,1'b0,1'b0);
                       ilas_data_char_1 <= character_mux(octet_counter_1,mframe_2_offset,1'b0,1'b0);
                       ilas_data_char_2 <= character_mux(octet_counter_2,mframe_2_offset,1'b0,1'b0);
                       ilas_data_char_3 <= character_mux(octet_counter_3,mframe_2_offset,1'b0,1'b1);
                       start_with_r <= 1'b1;
                       ilas_trail_bits[15:8] <= (octet_counter_3[7:0]);
                       ilas_trail_bits[7:0] <= (octet_counter_2[7:0]);
                 end
               endcase // case (remaining_char_count[2:0])
               if (first_mf) begin
                  fchk_calc <= fchk_calc + sum_ilas_uncom_param;
                  mframe_2_offset <= 3'h4 - remaining_char_count[2:0]; // Load the appropriate count to start for selecting ILAS data
               end
               
               
               if (txrx_enablelinktest_reg == 2'b10) begin
                  if (end_of_ilas) begin
                     mf_num <= ilas_length_mframe;
                     fchk_calc <= sum_ilas_com_param;
                     first_mf <= 1'b1;
                     second_mf <= 1'b0;
                     last_mf <= 1'b0;               
                  end
                  else mf_num <= mf_num - 1'b1;
               end
               else begin
                  mf_num <= mf_num - 1'b1;
                  if (end_of_ilas)
                    ilas_data_bc <= remaining_char_count[1:0];
               end
            end // else: !if(remaining_char_count > 'h4)            
         end // if (ilas_data_rdy)         
      end // else: !if(last_mf)
   end // always @ (posedge clk_character or posedge rst_clk_character)
   
   
   function [8:0] character_mux(input [7:0] counter_value,input [4:0] mframe_2_count,input insert_r, input insert_a);
      begin
         character_mux = {1'b0,counter_value[7:0]};         
         if (insert_a) 
            character_mux = {1'b1,8'h7C}; 
         else if (insert_r) 
           character_mux = {1'b1,8'h1C};
         else begin
            case (mframe_2_count)
              1:character_mux = {1'b1,8'h9C}; // Q Insertion
              2:character_mux = {1'b0,ilas_data_0};
              3:character_mux = {1'b0,ilas_data_1};
              4:character_mux = {1'b0,ilas_data_2};
              5:character_mux = {1'b0,ilas_data_3};
              6:character_mux = {1'b0,ilas_data_4};
              7:character_mux = {1'b0,ilas_data_5};
              8:character_mux = {1'b0,ilas_data_6};
              9:character_mux = {1'b0,ilas_data_7};
              10:character_mux = {1'b0,ilas_data_8};
              11:character_mux = {1'b0,ilas_data_9};
              12:character_mux = {1'b0,ilas_data_10};
              13:character_mux = {1'b0,8'h00};                            
              14:character_mux = {1'b0,8'h00};
              15:character_mux = {1'b0,fchk_calc};
              default: character_mux = {1'b0,counter_value[7:0]};         
            endcase // case (mframe_2_count)
         end // else: !if(insert_r)
      end
   endfunction 

   


   
endmodule // jesd_ilas_gen
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
