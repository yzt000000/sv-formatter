


module jesd_ilas_monitor
   (
   input              clk_character,
   input              rst_clk_character,
   input [31:0]       dskew_frame_data,
   input [03:0]       dskew_frame_data_k,
   input              dskew_frame_data_vld,
//   input [7:0]        frame_length_char,
   input [10:0]       mframe_length_char, 
   input [8:0]        ilas_length_mframe, // prefereably multiple of 4 . Default is 4
   input              ilas_en, // 1: ILAS is enabled, 0: disabled
   input              ilas_restart, // It is pulse
   input              ilas_error_reporting_en, // 1: Enable, 0: disable (If Enabled, ilas_mismatch would indicate error)
   input [03:00]      txrx_bank_id_reg,
   input [07:00]      txrx_did_reg,
   input [04:00]      txrx_lid_reg,
   input [02:00]      txrx_subclass_reg,
   input [04:0]       txrx_cf_reg,
   input [01:0]       txrx_cs_reg,
   input [07:0]       txrx_f_reg,
   input [04:0]       txrx_k_reg,
   input [04:0]       txrx_l_reg,
   input [04:0]       txrx_n_reg,
   input [07:0]       txrx_m_reg,
   input [04:0]       txrx_ntotal_reg,
   input [04:0]       txrx_s_reg,
   input [00:0]       txrx_hd_reg,
   input [00:0]       txrx_scr_reg,
   input [01:0]       txrx_enablelinktest_reg,
   input [7:0]        sum_ilas_com_param, 
   output reg         ilas_mismatch,
   //output reg [03:00] ilas_end
   output reg [03:00] ilas_data_valid
    );
   //wire ilas_en = 1'b1; // 1: Enable, 0: disabled
   //wire ilas_error_reporting_en = 1'b1; // 1: Enable, 0: disable
                                        // If Enabled, ilas_mismatch would indicate error
   wire [8:0]        num_of_multi_frame_reg = ilas_length_mframe;

   reg [4:0]         num_of_second_multi_frame_octets_consumed;
   

   `define FIRST_OCTET_IN_MULT_FRAME             5'd0
   `define SECOND_OCTET_IN_SECOND_MULT_FRAME     5'd1
   `define THIRD_OCTET_IN_SECOND_MULT_FRAME      5'd2 
   `define FOURTH_OCTET_IN_SECOND_MULT_FRAME     5'd3 
   `define FIFTH_OCTET_IN_SECOND_MULT_FRAME      5'd4 
   `define SIXTH_OCTET_IN_SECOND_MULT_FRAME      5'd5 
   `define SEVENTH_OCTET_IN_SECOND_MULT_FRAME    5'd6 
   `define EIGTH_OCTET_IN_SECOND_MULT_FRAME      5'd7 
   `define NINETH_OCTET_IN_SECOND_MULT_FRAME     5'd8 
   `define TENTH_OCTET_IN_SECOND_MULT_FRAME      5'd9 
   `define ELEVENTH_OCTET_IN_SECOND_MULT_FRAME   5'd10
   `define TWLETH_OCTET_IN_SECOND_MULT_FRAME     5'd11
   `define THIRTEEN_OCTET_IN_SECOND_MULT_FRAME   5'd12
   `define FOURTEEN_OCTET_IN_SECOND_MULT_FRAME   5'd13
   `define FIFTEEN_OCTET_IN_SECOND_MULT_FRAME    5'd14
   `define SIXTEEN_OCTET_IN_SECOND_MULT_FRAME    5'd15
   `define REG_0_OCTET_IN_MULT_FRAME             5'd16
   `define REG_1_OCTET_IN_MULT_FRAME             5'd17
   `define REG_2_OCTET_IN_MULT_FRAME             5'd18
   `define REG_3_OCTET_IN_MULT_FRAME             5'd19
   `define LAST_OCTET_IN_MULT_FRAME              5'd20
   `define LINK_CONFIG_OCTETS                    5'd14

   reg [03:00]       txrx_bank_id_reg_int;
   reg [07:00]       txrx_did_reg_int;
   reg [04:00]       txrx_lid_reg_int;
   reg [02:00]       txrx_subclass_reg_int;
   reg [04:0]        txrx_cf_reg_int;
   reg [01:0]        txrx_cs_reg_int;
   reg [07:0]        txrx_f_reg_int;
   reg [04:0]        txrx_k_reg_int;
   reg [04:0]        txrx_l_reg_int;
   reg [04:0]        txrx_n_reg_int;
   reg [07:0]        txrx_m_reg_int;
   reg [04:0]        txrx_ntotal_reg_int;
   reg [04:0]        txrx_s_reg_int;
   reg [00:0]        txrx_hd_reg_int;
   reg [00:0]        txrx_scr_reg_int;
   reg [01:0]        txrx_enablelinktest_reg_int;

   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         txrx_bank_id_reg_int <= 4'h0;
         txrx_did_reg_int <= 8'h0;
         txrx_lid_reg_int <= 5'h0;
         txrx_subclass_reg_int <= 3'b000;
         txrx_cf_reg_int <= 5'h0;
         txrx_cs_reg_int <= 2'b00;
         txrx_f_reg_int <= 8'h0;
         txrx_k_reg_int <= 5'h0;
         txrx_l_reg_int <= 5'h0;
         txrx_n_reg_int <= 5'h0;
         txrx_m_reg_int <= 8'h0;
         txrx_ntotal_reg_int <= 5'h0;
         txrx_s_reg_int <= 5'h0;
         txrx_hd_reg_int <= 0;
         txrx_scr_reg_int <= 4'h0;
         txrx_enablelinktest_reg_int <= 2'b00;
      end else begin // if (rst_clk_character)
         txrx_bank_id_reg_int  <= txrx_bank_id_reg;
         txrx_did_reg_int      <= txrx_did_reg   ;
         txrx_lid_reg_int      <= txrx_lid_reg   ;
         txrx_subclass_reg_int <= txrx_subclass_reg;
         txrx_cf_reg_int       <= txrx_cf_reg     ;
         txrx_cs_reg_int       <= txrx_cs_reg     ;
         txrx_f_reg_int        <= txrx_f_reg      ;
         txrx_k_reg_int        <= txrx_k_reg      ;
         txrx_l_reg_int        <= txrx_l_reg      ;
         txrx_n_reg_int        <= txrx_n_reg      ;
         txrx_m_reg_int        <= txrx_m_reg      ;
         txrx_ntotal_reg_int   <= txrx_ntotal_reg ;
         txrx_s_reg_int        <= txrx_s_reg       ;
         txrx_hd_reg_int       <= txrx_hd_reg;
         txrx_scr_reg_int      <= txrx_scr_reg    ;
         txrx_enablelinktest_reg_int <= txrx_enablelinktest_reg;
      end
   end

   // wire [7:0] link_config_did              = txrx_did_reg;
   // wire [7:0] link_config_adjcnt_bid       = {4'b0, txrx_bank_id_reg};
   // //wire [7:0] link_config_adjdir_phadj_lid = {1'b0, adjdir_reg, phadj_reg, txrx_lid_reg}; //adjdir_reg, phadj_reg need to define
   // wire [7:0] link_config_adjdir_phadj_lid = {1'b0, 1'b0, 1'b0, txrx_lid_reg[4:0]}; //adjdir_reg, phadj_reg need to define
   // wire [7:0] link_config_scr_l            = {txrx_scr_reg, 2'b0, txrx_l_reg};
   // wire [7:0] link_config_f                = txrx_f_reg;
   // wire [7:0] link_config_k                = {3'b0, txrx_k_reg};
   // wire [7:0] link_config_m                = txrx_m_reg;  
   // wire [7:0] link_config_cs_N             = {txrx_cs_reg, 1'b0, txrx_n_reg};
   // wire [7:0] link_config_subclass_ntotal  = {txrx_subclass_reg, txrx_ntotal_reg};
   // wire [7:0] link_config_jesdv_s          = {3'b1, txrx_s_reg};
   // wire [7:0] link_config_hd_cf            = {txrx_hd_reg, 2'b0, txrx_cf_reg};
   // wire [7:0] link_config_res1             = 0;
   // wire [7:0] link_config_res2             = 0;
   // wire [7:0] link_config_fchk             = 0;

   wire [7:0] link_config_did              = txrx_did_reg_int;
   wire [7:0] link_config_adjcnt_bid       = {4'b0, txrx_bank_id_reg_int};
   //wire [7:0] link_config_adjdir_phadj_lid = {1'b0, adjdir_reg, phadj_reg, txrx_lid_reg}; //adjdir_reg, phadj_reg need to define
   wire [7:0] link_config_adjdir_phadj_lid = {1'b0, 1'b0, 1'b0, txrx_lid_reg_int[4:0]}; //adjdir_reg, phadj_reg need to define
   wire [7:0] link_config_scr_l            = {txrx_scr_reg_int, 2'b0, txrx_l_reg_int};
   wire [7:0] link_config_f                = txrx_f_reg_int;
   wire [7:0] link_config_k                = {3'b0, txrx_k_reg_int};
   wire [7:0] link_config_m                = txrx_m_reg_int;  
   wire [7:0] link_config_cs_N             = {txrx_cs_reg_int, 1'b0, txrx_n_reg_int};
   wire [7:0] link_config_subclass_ntotal  = {txrx_subclass_reg_int, txrx_ntotal_reg_int};
   wire [7:0] link_config_jesdv_s          = {3'b1, txrx_s_reg_int};
   wire [7:0] link_config_hd_cf            = {txrx_hd_reg_int, 2'b0, txrx_cf_reg_int};
   wire [7:0] link_config_res1             = 0;
   wire [7:0] link_config_res2             = 0;
   wire [7:0] link_config_fchk             = sum_ilas_com_param + {3'b000, txrx_lid_reg_int};


// K28.0 --> 1C // R
// K28.2 --> 5C // Decode Error . Implementation specific and not part of JESD204B spec
// K28.3 --> 7C // A
// K28.4 --> 9C // Q
// K28.5 --> BC // K
// K28.7 --> FC // F


   // K*F define as multi-frame
   // e.g. F=16, K=5
   // P.N. 102, 1st octet of 1st multi-frame is 0x1C, it is K character, therefore dskew_frame_data_k[0] must be 1
   // then D0 would have dskew_frame_data_k[0] = 0 and value would be 1, D1 would be 2 and so on till last octect of multi-frame
   // 80 octets would continue
   // 1st octet of 2nd multi-frmae must be 0x1C,
   // 2nd octet of 2nd multi-frame must be 0x9C
   // 3rd octet of 2nd multi-frame is link configuration data, need to compare with register value, till 14th more octet
   // 1st octet of 3rd multi-frame must be 0x1C
   // 2nd octet of 3rd multi-frame must be increment data
   // last octet of 3rd multi-frame must be 0x7C (K)
   // So in general, 1st and last octect of multi-frame must be 0x1C and 0x7C respectively
   // continue pattern till end of all multi-frame
   // then start user data and enable frame alignment character and replacement monitor
   // while giving user data or end of ilas, need to assert scr_usr_data[3:0]
   // 
   // P.N. 75, waveform
   // Keep one big decoder, input is either 0x1C. 0x9C. 0x7C. 14octets of config parameter and 
   // keep select line to select one of the input and compare it with incoming octets
   // like wise need four decoder since incoming data width is 32-bits
   //


   reg [7:0] octet_counter;
   reg [4:0] octet_select_0, octet_select_1, octet_select_2, octet_select_3;   
   
   // Free running counter
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         octet_counter <= 8'h0;
      end else begin
         if (dskew_frame_data_vld) begin
            octet_counter <= octet_counter+8'h4;
         end else begin
            octet_counter <= 8'h0;
         end
      end
   end // always @ (posedge clk_character or posedge rst_clk_character)

   reg [10:0] multi_frame_octet;
   (*keep = "true",max_fanout = 2*)reg [8:0] num_of_multi_frame;
   reg       one_time_pulse;

   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         ilas_data_valid    <= 0;
      end else begin
         if ((one_time_pulse) || (ilas_restart))begin
            //ilas_data_valid <= 4'hF; //Initially all data belongs to ILAS
            if (ilas_en) begin
              ilas_data_valid <= 4'hF; //Initially all data belongs to ILAS
            end else begin
              ilas_data_valid <= 4'h0; //all data belongs to User data
            end
         end else begin
            if (ilas_en) begin
               case (num_of_multi_frame)
                 0: begin //
                    ilas_data_valid <= 4'h0;
                 end
                 1: begin
                    case (multi_frame_octet)
                      3: ilas_data_valid <= 4'b0111;
                      2: ilas_data_valid <= 4'b0011;
                      1: ilas_data_valid <= 4'b0001;
                      0: ilas_data_valid <= 4'b0000;
                      default: ilas_data_valid <= 4'b1111;
                    endcase // case (multi_frame_octet)
                 end
                 default: begin
                    ilas_data_valid <= 4'hF;
                 end
               endcase // case (num_of_multi_frame)
            end else begin // if (ilas_en)
               ilas_data_valid <= 4'h0; //all data belongs to user data 
            end // else: !if(ilas_en)
         end // else: !if((one_time_pulse) || (ilas_restart))
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)

   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         multi_frame_octet  <= 0;
         num_of_multi_frame <= 0;
         one_time_pulse     <= 1;
         octet_select_0     <= 0;
         octet_select_1     <= 0;
         octet_select_2     <= 0;
         octet_select_3     <= 0;
         num_of_second_multi_frame_octets_consumed <= 0;
              
      end else begin
         //if (one_time_pulse) begin
         if ((one_time_pulse) || (ilas_restart))begin
            one_time_pulse <= 0;
            multi_frame_octet  <= mframe_length_char-11'h4;
            num_of_multi_frame <= num_of_multi_frame_reg;  // REVISIT
            octet_select_0  <= `FIRST_OCTET_IN_MULT_FRAME; //start of a multi-frame
            octet_select_1  <= `REG_1_OCTET_IN_MULT_FRAME; // Data_1
            octet_select_2  <= `REG_2_OCTET_IN_MULT_FRAME;
            octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME;
            num_of_second_multi_frame_octets_consumed <= 0;            
         end else begin
            if ((dskew_frame_data_vld) && (num_of_multi_frame>0)) begin
               // It means frame is other than 2nd multi-frame
               if (num_of_multi_frame != num_of_multi_frame_reg-1) begin

                  if(multi_frame_octet == mframe_length_char) begin
                     // This is the case of rollover
                     multi_frame_octet <= multi_frame_octet-8'h4;
                    
                     octet_select_0  <= `FIRST_OCTET_IN_MULT_FRAME; 
                     octet_select_1  <= `REG_1_OCTET_IN_MULT_FRAME; // Data_1
                     octet_select_2  <= `REG_2_OCTET_IN_MULT_FRAME;
                     octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME;
                  end else begin // if (multi_frame_octet == mframe_length_char)
                     case (multi_frame_octet)
                       4: begin
                          multi_frame_octet <= mframe_length_char;
                          num_of_multi_frame <= num_of_multi_frame-8'h1;
                          
                          octet_select_0  <= `REG_0_OCTET_IN_MULT_FRAME;
                          octet_select_1  <= `REG_1_OCTET_IN_MULT_FRAME;
                          octet_select_2  <= `REG_2_OCTET_IN_MULT_FRAME;
                          octet_select_3  <= `LAST_OCTET_IN_MULT_FRAME;
                       end
                       3: begin
                               multi_frame_octet <= mframe_length_char - (11'h4-multi_frame_octet);
                               num_of_multi_frame <= num_of_multi_frame-9'h1;
                          
                               if (num_of_multi_frame ==  num_of_multi_frame_reg) begin
                                  // It means next frame is second multi-frame and need to take extra care
                             num_of_second_multi_frame_octets_consumed <= 3'h4-multi_frame_octet[2:0];
                             octet_select_0  <= `REG_0_OCTET_IN_MULT_FRAME;
                             octet_select_1  <= `REG_1_OCTET_IN_MULT_FRAME;
                             octet_select_2  <= `LAST_OCTET_IN_MULT_FRAME;
                             octet_select_3  <= `FIRST_OCTET_IN_MULT_FRAME;
                          end else begin
                             octet_select_0  <= `REG_0_OCTET_IN_MULT_FRAME;
                             octet_select_1  <= `REG_1_OCTET_IN_MULT_FRAME;
                             octet_select_2  <= `LAST_OCTET_IN_MULT_FRAME;
                             octet_select_3  <= `FIRST_OCTET_IN_MULT_FRAME;
                          end
                          
                       end
                       2: begin
                               multi_frame_octet <= mframe_length_char - (11'h4-multi_frame_octet);
                               num_of_multi_frame <= num_of_multi_frame-9'h1;
                          
                               if (num_of_multi_frame ==  num_of_multi_frame_reg) begin
                                  // It means next frame is second multi-frame and need to take extra care
                             num_of_second_multi_frame_octets_consumed <= 3'h4-multi_frame_octet[2:0];
                             octet_select_0  <= `REG_0_OCTET_IN_MULT_FRAME;
                             octet_select_1  <= `LAST_OCTET_IN_MULT_FRAME;
                             octet_select_2  <= `FIRST_OCTET_IN_MULT_FRAME;
                           // Changed by MGH, chetan to review
                           //  octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME;
                           octet_select_3  <= `SECOND_OCTET_IN_SECOND_MULT_FRAME;
                          end else begin
                             octet_select_0  <= `REG_0_OCTET_IN_MULT_FRAME;
                             octet_select_1  <= `LAST_OCTET_IN_MULT_FRAME;
                             octet_select_2  <= `FIRST_OCTET_IN_MULT_FRAME;
                             octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME;
                          end
                       end
                       1: begin
                               multi_frame_octet <= mframe_length_char - (11'h4-multi_frame_octet);
                               num_of_multi_frame <= num_of_multi_frame-9'h1;
                               if (num_of_multi_frame ==  num_of_multi_frame_reg) begin
                                  // It means next frame is second multi-frame and need to take extra care
                             num_of_second_multi_frame_octets_consumed <= 3'h4-multi_frame_octet[2:0];
                             octet_select_0  <= `LAST_OCTET_IN_MULT_FRAME;
                             octet_select_1  <= `FIRST_OCTET_IN_MULT_FRAME;
                             octet_select_2  <= `SECOND_OCTET_IN_SECOND_MULT_FRAME;
                             octet_select_3  <= `THIRD_OCTET_IN_SECOND_MULT_FRAME;
                          end else begin
                             octet_select_0  <= `LAST_OCTET_IN_MULT_FRAME;
                             octet_select_1  <= `FIRST_OCTET_IN_MULT_FRAME;
                             octet_select_2  <= `REG_2_OCTET_IN_MULT_FRAME;
                             octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME;
                          end
                       end
                       default: begin // more than 4
                          multi_frame_octet <= multi_frame_octet-11'h4;
                          
                          octet_select_0  <= `REG_0_OCTET_IN_MULT_FRAME;
                          octet_select_1  <= `REG_1_OCTET_IN_MULT_FRAME;
                          octet_select_2  <= `REG_2_OCTET_IN_MULT_FRAME;
                          octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME;
                       end
                     endcase // case (multi_frame_octet)
                  end // else: !if(multi_frame_octet == mframe_length_char)
               end else begin // if (num_of_multi_frame != num_of_multi_frame_reg-1)
                  // 
                  // multi_frame_octet   20 16 12   8  4 20
                  // num_of_2nd_consumed  0  4  8  12 16 20

                  // ilas_length_frame = 17
                  // multi_frame_octet   14 10  6   2
                  // num_of_2nd_consumed  3  7 11  15 19 23

                  // ilas_length_frame = 20
                  // multi_frame_octet    4 20 16 12  8  4 20 
                  // num_of_2nd_consumed  0  0  4  8 12 16 16
                  
                  // Need to find octet_counter value for 4th cycle
                  if (num_of_second_multi_frame_octets_consumed >= `LINK_CONFIG_OCTETS+5'd2) begin
                  // +2 for 1st & 2nd octet
                     case (multi_frame_octet)
                       4: begin // if (multi_frame_octet == 4) begin
                          multi_frame_octet <= mframe_length_char;
                          num_of_multi_frame <= num_of_multi_frame-8'h1;
                          
                          octet_select_0  <= `REG_0_OCTET_IN_MULT_FRAME;
                          octet_select_1  <= `REG_1_OCTET_IN_MULT_FRAME;
                          octet_select_2  <= `REG_2_OCTET_IN_MULT_FRAME;
                          octet_select_3  <= `LAST_OCTET_IN_MULT_FRAME;
                       end
                       1: begin
                          multi_frame_octet <= mframe_length_char - (11'h4-multi_frame_octet);
                          num_of_multi_frame <= num_of_multi_frame-8'h1;
                          
                          octet_select_0  <= `LAST_OCTET_IN_MULT_FRAME;
                          octet_select_1  <= `FIRST_OCTET_IN_MULT_FRAME;
                          octet_select_2  <= `REG_2_OCTET_IN_MULT_FRAME;
                          octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME;
                       end
                       2: begin
                          multi_frame_octet <= mframe_length_char - (11'h4-multi_frame_octet);
                          num_of_multi_frame <= num_of_multi_frame-8'h1;
                          octet_select_0  <= `REG_0_OCTET_IN_MULT_FRAME;
                          octet_select_1  <= `LAST_OCTET_IN_MULT_FRAME;
                          octet_select_2  <= `FIRST_OCTET_IN_MULT_FRAME;
                          octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME;
                       end
                       3: begin
                          multi_frame_octet <= mframe_length_char - (11'h4-multi_frame_octet);
                          num_of_multi_frame <= num_of_multi_frame-8'h1;
                          octet_select_0  <= `REG_0_OCTET_IN_MULT_FRAME;
                          octet_select_1  <= `REG_1_OCTET_IN_MULT_FRAME;
                          octet_select_2  <= `LAST_OCTET_IN_MULT_FRAME;
                          octet_select_3  <= `FIRST_OCTET_IN_MULT_FRAME;
                       end
                       default: begin //end else if (multi_frame_octet > 4) begin
                          multi_frame_octet <= multi_frame_octet-11'h4;
                          num_of_multi_frame <= num_of_multi_frame;
                          
                          octet_select_0  <= `REG_0_OCTET_IN_MULT_FRAME;
                          octet_select_1  <= `REG_1_OCTET_IN_MULT_FRAME;
                          octet_select_2  <= `REG_2_OCTET_IN_MULT_FRAME;
                          octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME;
                       end
                     endcase // case (multi_frame_octet)
                  end else begin // if (num_of_second_multi_frame_octets_consumed >= `LINK_CONFIG_OCTETS+2)
                     // Expect configuration Link data
                     num_of_second_multi_frame_octets_consumed <= num_of_second_multi_frame_octets_consumed + 5'h4;
                     case (multi_frame_octet)
                       4: begin
                          multi_frame_octet <= mframe_length_char;
                          num_of_multi_frame <= num_of_multi_frame-8'h1;
                          
                          octet_select_0  <= num_of_second_multi_frame_octets_consumed;
                          octet_select_1  <= num_of_second_multi_frame_octets_consumed+5'h1;
                          octet_select_2  <= `REG_2_OCTET_IN_MULT_FRAME;
                          octet_select_3  <= `LAST_OCTET_IN_MULT_FRAME;
                       end
                       3: begin
                          // Two multi-frames are overlapping
                          multi_frame_octet <= mframe_length_char - (11'h4-multi_frame_octet);
                          num_of_multi_frame <= num_of_multi_frame-8'h1;
                          octet_select_0  <= num_of_second_multi_frame_octets_consumed;
                          octet_select_1  <= `REG_1_OCTET_IN_MULT_FRAME;
                          octet_select_2  <= `LAST_OCTET_IN_MULT_FRAME;
                          octet_select_3  <= `FIRST_OCTET_IN_MULT_FRAME;
                       end
                       2: begin
                          // Two multi-frames are overlapping
                          multi_frame_octet <= mframe_length_char - (11'h4-multi_frame_octet);
                          num_of_multi_frame <= num_of_multi_frame-8'h1;
                          octet_select_0  <= num_of_second_multi_frame_octets_consumed;
                          octet_select_1  <= `LAST_OCTET_IN_MULT_FRAME;
                          octet_select_2  <= `FIRST_OCTET_IN_MULT_FRAME;
                          octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME;

                       end
                       1: begin
                          // Two multi-frames are overlapping
                          multi_frame_octet <= mframe_length_char - (11'h4-multi_frame_octet);
                          num_of_multi_frame <= num_of_multi_frame-8'h1;
                          octet_select_0  <= `LAST_OCTET_IN_MULT_FRAME;
                          octet_select_1  <= `FIRST_OCTET_IN_MULT_FRAME;
                          octet_select_2  <= `REG_2_OCTET_IN_MULT_FRAME;
                          octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME;
                       end
                       default: begin
                          multi_frame_octet <= multi_frame_octet-11'h4;
                          if (num_of_second_multi_frame_octets_consumed > 11) begin
                             case (`LINK_CONFIG_OCTETS+5'd2 - num_of_second_multi_frame_octets_consumed)
                               4: begin
                                  octet_select_0  <= num_of_second_multi_frame_octets_consumed;   //12
                                  octet_select_1  <= num_of_second_multi_frame_octets_consumed+5'h1; //13
                                  octet_select_2  <= num_of_second_multi_frame_octets_consumed+5'h2; //14
                                  octet_select_3  <= num_of_second_multi_frame_octets_consumed+5'h3; //15
                               end
                               3: begin
                                  octet_select_0  <= num_of_second_multi_frame_octets_consumed;   //13
                                  octet_select_1  <= num_of_second_multi_frame_octets_consumed+5'h1; //14
                                  octet_select_2  <= num_of_second_multi_frame_octets_consumed+5'h2; //15
                                  octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME; //19 (Config parameter are finished so sending regular octet
                               end
                               2: begin 
                                  octet_select_0  <= num_of_second_multi_frame_octets_consumed;   //14
                                  octet_select_1  <= num_of_second_multi_frame_octets_consumed+5'h1; //15
                                  octet_select_2  <= `REG_2_OCTET_IN_MULT_FRAME; //18
                                  octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME; //19
                               end
                               1: begin
                                  octet_select_0  <= num_of_second_multi_frame_octets_consumed;   //15
                                  octet_select_1  <= `REG_1_OCTET_IN_MULT_FRAME; //17
                                  octet_select_2  <= `REG_2_OCTET_IN_MULT_FRAME; //18
                                  octet_select_3  <= `REG_3_OCTET_IN_MULT_FRAME; //19
                               end
                             endcase // case (`LINK_CONFIG_OCTETS+2 - num_of_second_multi_frame_octets_consumed)
                          end else begin // if (num_of_second_multi_frame_octets_consumed > 11)
                             octet_select_0  <= num_of_second_multi_frame_octets_consumed;   
                             octet_select_1  <= num_of_second_multi_frame_octets_consumed+5'h1; 
                             octet_select_2  <= num_of_second_multi_frame_octets_consumed+5'h2; 
                             octet_select_3  <= num_of_second_multi_frame_octets_consumed+5'h3; 
                          end // else: !if(num_of_second_multi_frame_octets_consumed > 11)
                       end
                     endcase // case (multi_frame_octet)
                  end // else: !if(num_of_second_multi_frame_octets_consumed >= `LINK_CONFIG_OCTETS+5'd2)
               end // else: !if(num_of_multi_frame != num_of_multi_frame_reg-1)
            end // if ((dskew_frame_data_vld) && (num_of_multi_frame>0))
         end // else: !if((one_time_pulse) || (ilas_restart))
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)
   
   // cases 
   // a. where partial 2nd multi-frame already cosnumed in previous cycle
   // b. none of the octets of 2nd multi-frame consumed in previous cycle
   // c. 2nd multi-frame completing on dword boundary
   // d. 2nd and 3rd multi-frame are overlapping in same cycle
   // 

   reg ilas_mismatch_a, ilas_mismatch_b, ilas_mismatch_c, ilas_mismatch_d;
   reg ilas_mismatch_e, ilas_mismatch_f, ilas_mismatch_g, ilas_mismatch_h;
   reg ilas_mismatch_y1, ilas_mismatch_y2, ilas_mismatch_y3, ilas_mismatch_y4;
   reg ilas_mismatch_x;
   
   
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
        ilas_mismatch <= 0;
        ilas_mismatch_x <= 0;
        ilas_mismatch_y1 <= 0;
        ilas_mismatch_y2 <= 0;
        ilas_mismatch_y3 <= 0;
        ilas_mismatch_y4 <= 0;
      end else begin
         ilas_mismatch_x <= ilas_mismatch_a | ilas_mismatch_b | ilas_mismatch_c | ilas_mismatch_d;
         ilas_mismatch_y1 <= ilas_mismatch_e;
         ilas_mismatch_y2 <= ilas_mismatch_f;
         ilas_mismatch_y3 <= ilas_mismatch_g;
         ilas_mismatch_y4 <= ilas_mismatch_h;
         ilas_mismatch   <=  ilas_mismatch_x | ilas_mismatch_y1 | ilas_mismatch_y2 | ilas_mismatch_y3 | ilas_mismatch_y4;
      end
   end


   //always @* begin
   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         ilas_mismatch_a <= 1'b0;
         ilas_mismatch_b <= 1'b0;
         ilas_mismatch_c <= 1'b0;
         ilas_mismatch_d <= 1'b0;
         ilas_mismatch_e <= 1'b0;
         ilas_mismatch_f <= 1'b0;
         ilas_mismatch_g <= 1'b0;
         ilas_mismatch_h <= 1'b0;
      end else begin
         ilas_mismatch_a <= 1'b0;
         ilas_mismatch_b <= 1'b0;
         ilas_mismatch_c <= 1'b0;
         ilas_mismatch_d <= 1'b0;
         ilas_mismatch_e <= 1'b0;
         ilas_mismatch_f <= 1'b0;
         ilas_mismatch_g <= 1'b0;
         ilas_mismatch_h <= 1'b0;
      
         if ((ilas_error_reporting_en) & (dskew_frame_data_vld) & ((num_of_multi_frame>0))) begin
               // Add checking logic for incoming dword
               // get ilas octet expection from function ilas_octet_exp passing
               // also for last octet after all multi-frame need to pass details whether it holds any user data
               // ToDo: Last octet of all multi-frame
               if ((octet_select_0 == `FIRST_OCTET_IN_MULT_FRAME) ||
                   (octet_select_0 == `SECOND_OCTET_IN_SECOND_MULT_FRAME) ||
                   (octet_select_0 == `LAST_OCTET_IN_MULT_FRAME)) begin
                  if (dskew_frame_data_k[0] != 1) begin
                     ilas_mismatch_a <= 1'b1;
                  end
               end
               if ((octet_select_1 == `FIRST_OCTET_IN_MULT_FRAME) ||
                   (octet_select_1 == `SECOND_OCTET_IN_SECOND_MULT_FRAME) ||
                   (octet_select_1 == `LAST_OCTET_IN_MULT_FRAME)) begin
                  if (dskew_frame_data_k[1] != 1) begin
                     ilas_mismatch_b <= 1'b1;
                  end
               end
               if ((octet_select_2 == `FIRST_OCTET_IN_MULT_FRAME) ||
                   (octet_select_2 == `SECOND_OCTET_IN_SECOND_MULT_FRAME) ||
                   (octet_select_2 == `LAST_OCTET_IN_MULT_FRAME)) begin
                  if (dskew_frame_data_k[2] != 1) begin
                     ilas_mismatch_c <= 1'b1;
                  end
               end
               if ((octet_select_3 == `FIRST_OCTET_IN_MULT_FRAME) ||
                   (octet_select_3 == `SECOND_OCTET_IN_SECOND_MULT_FRAME) ||
                   (octet_select_3 == `LAST_OCTET_IN_MULT_FRAME)) begin
                  if (dskew_frame_data_k[3] != 1) begin
                     ilas_mismatch_d <= 1'b1;
                  end
               end

              //if ((dskew_frame_data[7:0] != ilas_octet_exp(octet_select_0)) && ilas_data_valid[0]) begin
              if (((dskew_frame_data[7:0] & ilas_octet_exp_mask(octet_select_0)) != ilas_octet_exp(octet_select_0)) && ilas_data_valid[0]) begin
                     ilas_mismatch_e <= 1'b1;
              end
                  
              if (((dskew_frame_data[15:8] & ilas_octet_exp_mask(octet_select_1)) != ilas_octet_exp(octet_select_1)) && ilas_data_valid[1]) begin
                     ilas_mismatch_f <= 1'b1;
              end
                  
              if (((dskew_frame_data[23:16] & ilas_octet_exp_mask(octet_select_2)) != ilas_octet_exp(octet_select_2)) && ilas_data_valid[2]) begin
                     ilas_mismatch_g <= 1'b1;
              end
                  
              if (((dskew_frame_data[31:24] & ilas_octet_exp_mask(octet_select_3)) != ilas_octet_exp(octet_select_3)) && ilas_data_valid[3]) begin
                     ilas_mismatch_h <= 1'b1;
              end
            //end // if (dskew_frame_data_vld)
         end // if ((ilas_error_reporting_en) & (dskew_frame_data_vld) & ((num_of_multi_frame>0)))
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)
   
   function [7:0] ilas_octet_exp(input reg [4:0] select_input);
      case (select_input)
        `FIRST_OCTET_IN_MULT_FRAME           : ilas_octet_exp = 8'h1c; // 1st octet in a multi-frame
        `LAST_OCTET_IN_MULT_FRAME            : ilas_octet_exp = 8'h7c; // last octet in a multi-frame
        `SECOND_OCTET_IN_SECOND_MULT_FRAME   : ilas_octet_exp = 8'h9c; // 2nd octet in 2nd multi-frame
        `THIRD_OCTET_IN_SECOND_MULT_FRAME    : ilas_octet_exp = link_config_did             ; //  3rd octet in 2nd multi-frame
        `FOURTH_OCTET_IN_SECOND_MULT_FRAME   : ilas_octet_exp = link_config_adjcnt_bid      ; //  4th octet in 2nd multi-frame
        `FIFTH_OCTET_IN_SECOND_MULT_FRAME    : ilas_octet_exp = link_config_adjdir_phadj_lid; //  5th octet in 2nd multi-frame
        `SIXTH_OCTET_IN_SECOND_MULT_FRAME    : ilas_octet_exp = link_config_scr_l           ; //  6th octet in 2nd multi-frame
        `SEVENTH_OCTET_IN_SECOND_MULT_FRAME  : ilas_octet_exp = link_config_f               ; //  7th octet in 2nd multi-frame
        `EIGTH_OCTET_IN_SECOND_MULT_FRAME    : ilas_octet_exp = link_config_k               ; //  8th octet in 2nd multi-frame
        `NINETH_OCTET_IN_SECOND_MULT_FRAME   : ilas_octet_exp = link_config_m               ; //  9th octet in 2nd multi-frame
        `TENTH_OCTET_IN_SECOND_MULT_FRAME    : ilas_octet_exp = link_config_cs_N            ; // 10th octet in 2nd multi-frame
        `ELEVENTH_OCTET_IN_SECOND_MULT_FRAME : ilas_octet_exp = link_config_subclass_ntotal ; // 11th octet in 2nd multi-frame
        `TWLETH_OCTET_IN_SECOND_MULT_FRAME   : ilas_octet_exp = link_config_jesdv_s         ; // 12th octet in 2nd multi-frame
        `THIRTEEN_OCTET_IN_SECOND_MULT_FRAME : ilas_octet_exp = link_config_hd_cf           ; // 13th octet in 2nd multi-frame
        `FOURTEEN_OCTET_IN_SECOND_MULT_FRAME : ilas_octet_exp = link_config_res1            ; // 14th octet in 2nd multi-frame
        `FIFTEEN_OCTET_IN_SECOND_MULT_FRAME  : ilas_octet_exp = link_config_res2            ; // 15th octet in 2nd multi-frame
        `SIXTEEN_OCTET_IN_SECOND_MULT_FRAME  : ilas_octet_exp = link_config_fchk            ; // 16th octet in 2nd multi-frame
        `REG_0_OCTET_IN_MULT_FRAME           : ilas_octet_exp = octet_counter            ;
        `REG_1_OCTET_IN_MULT_FRAME           : ilas_octet_exp = octet_counter+8'h1       ;
        `REG_2_OCTET_IN_MULT_FRAME           : ilas_octet_exp = octet_counter+8'h2       ;
        `REG_3_OCTET_IN_MULT_FRAME           : ilas_octet_exp = octet_counter+8'h3       ;
        default                              : ilas_octet_exp = octet_counter            ;
      endcase // case (select_input)
         
   endfunction // ilas_octet_exp
   
   function [7:0] ilas_octet_exp_mask(input reg [4:0] select_input);
      case (select_input)
        `FIRST_OCTET_IN_MULT_FRAME           : ilas_octet_exp_mask = 8'hFF; // 1st octet in a multi-frame
        `LAST_OCTET_IN_MULT_FRAME            : ilas_octet_exp_mask = 8'hFF; // last octet in a multi-frame
        `SECOND_OCTET_IN_SECOND_MULT_FRAME   : ilas_octet_exp_mask = 8'hFF; // 2nd octet in 2nd multi-frame
        `THIRD_OCTET_IN_SECOND_MULT_FRAME    : ilas_octet_exp_mask = 8'hFF          ; //  3rd octet in 2nd multi-frame
        `FOURTH_OCTET_IN_SECOND_MULT_FRAME   : ilas_octet_exp_mask = 8'b0000_1111   ; //  4th octet in 2nd multi-frame
        `FIFTH_OCTET_IN_SECOND_MULT_FRAME    : ilas_octet_exp_mask = 8'b000_11111   ; //  5th octet in 2nd multi-frame
        `SIXTH_OCTET_IN_SECOND_MULT_FRAME    : ilas_octet_exp_mask = 8'b1_00_11111  ; //  6th octet in 2nd multi-frame
        `SEVENTH_OCTET_IN_SECOND_MULT_FRAME  : ilas_octet_exp_mask = 8'hFF          ; //  7th octet in 2nd multi-frame
        `EIGTH_OCTET_IN_SECOND_MULT_FRAME    : ilas_octet_exp_mask = 8'b000_11111   ; //  8th octet in 2nd multi-frame
        `NINETH_OCTET_IN_SECOND_MULT_FRAME   : ilas_octet_exp_mask = 8'hFF          ; //  9th octet in 2nd multi-frame
        `TENTH_OCTET_IN_SECOND_MULT_FRAME    : ilas_octet_exp_mask = 8'b11_0_11111  ; // 10th octet in 2nd multi-frame
        `ELEVENTH_OCTET_IN_SECOND_MULT_FRAME : ilas_octet_exp_mask = 8'b111_11111   ; // 11th octet in 2nd multi-frame
        `TWLETH_OCTET_IN_SECOND_MULT_FRAME   : ilas_octet_exp_mask = 8'b111_11111   ; // 12th octet in 2nd multi-frame
        `THIRTEEN_OCTET_IN_SECOND_MULT_FRAME : ilas_octet_exp_mask = 8'b1_00_11111  ; // 13th octet in 2nd multi-frame
        `FOURTEEN_OCTET_IN_SECOND_MULT_FRAME : ilas_octet_exp_mask = 8'hFF          ; // 14th octet in 2nd multi-frame
        `FIFTEEN_OCTET_IN_SECOND_MULT_FRAME  : ilas_octet_exp_mask = 8'hFF          ; // 15th octet in 2nd multi-frame
        `SIXTEEN_OCTET_IN_SECOND_MULT_FRAME  : ilas_octet_exp_mask = 8'hFF          ; // 16th octet in 2nd multi-frame
        `REG_0_OCTET_IN_MULT_FRAME           : ilas_octet_exp_mask = 8'hFF          ;
        `REG_1_OCTET_IN_MULT_FRAME           : ilas_octet_exp_mask = 8'hFF          ;
        `REG_2_OCTET_IN_MULT_FRAME           : ilas_octet_exp_mask = 8'hFF          ;
        `REG_3_OCTET_IN_MULT_FRAME           : ilas_octet_exp_mask = 8'hFF          ;
        default                              : ilas_octet_exp_mask = 8'hFF          ;
      endcase // case (select_input)
         
   endfunction // ilas_octet_exp_mask

endmodule // jesd_ilas_monitor
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
