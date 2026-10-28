

module jesd_rx_align_mon_char_rep(
   input             clk_character,
   input             rst_clk_character,
   input [31:0]      dskew_frame_data,
   input [03:0]      dskew_frame_data_k,
   input             dskew_frame_data_vld,
   input [8:0]       frame_length_char,
   input [10:0]      mframe_length_char, 
   input [1:0]       ilas_length_mframe, // prefereably multiple of 4 . Default is 4
   input [3:0]       ilas_data_valid,    // ILAS monitor would provide details
   input             align_a_char_replace_en,         // 1: Lane alignment character replacement enable, 0: disabled
   input             align_a_char_error_reporting_en, // 1: Error reporting is enabled, 0: Error reporting is disabled
   input             scr_dis,                         // 1: Scrambler is disabled, 0: Enabled
   input             ilas_en,                         // 1: ILAS is enabled, 0: disabled
   output reg        ilas_restart,
   output reg        mframe_alignment_err,
   output reg        frame_alignment_err, 
   output reg [3:0]  decode_err,
   output reg [3:0]  unexpected_k_err,
   output reg [3:0]  user_data_valid_n, // De-scrambler can use this
   output     [31:0] scr_data,
   output reg [03:0] scr_data_eof,
   output reg [03:0] scr_data_eomf, 
   output reg [03:0] scr_data_sof,
   output reg [03:0] scr_data_somf,
   output reg [03:0] scr_byte_en, 
   output reg        scr_data_vld
                                    
                                 );
   //wire char_replace_en = 1'b1;              // 1: Frame / Lane alignment character replacement enable, 0: disabled
   //wire align_a_char_replace_en = 1'b1;              // 1: Frame / Lane alignment character replacement enable, 0: disabled
   //wire align_f_char_replace_en = 1'b1;              // 1: Frame / Lane alignment character replacement enable, 0: disabled
   //wire alignment_error_reporting_en = 1'b1; // 1: Error reporting is enabled, 0: Error reporting is disabled
   //wire align_a_char_error_reporting_en = 1'b1; // 1: Error reporting is enabled, 0: Error reporting is disabled
   //wire alignment_f_char_error_reporting_en = 1'b1; // 1: Error reporting is enabled, 0: Error reporting is disabled
   //wire ilas_en = 1;                         // 1: ILAS is enabled, 0: disabled

   wire [08:0]       TXRX_F_REG = frame_length_char;
    
   // Algorithm
   // keep prev_frame_last_octet as single byte instead of DW
   // keep prev_frame_align_char_exist, 1 means yes, 0 means no
   // when current frame receives last octet, and if it is not alignment character, directly store it in prev_frame_last_octet, also update prev_frame_align_char_exist
   // when current frame receives last octet, and if it is alignment character, do not update prev_frame_last_octet, rather load that value in current location, 
   //                                             also update prev_frame_align_char_exist
   //
   // checking of alignment character at right location, error need to differentiate between frame (/F/) and multi-frame (/A/)
   // Need to know frame boundary
   // a. check every byte and if alignment character receives other than frame boundary, it is error (alignment_received_before_frame_ends),
   // b. if alignment character receives on frame boundary, check it is received on last octet (use last_octet_location)
   // c. if alignment character receives on last octet of frame boundary, check value of prev_frame_align_char_exist
   //       if prev_frame_align_char_exist == 0 and current frame is end of multi frame boundary (last_multi_frame_octet_in_curr_dw), alignment character must be /A/
   //       if prev_frame_align_char_exist == 0 and current frame is not end of multi frame boundary, alignment character must be /F/
   //       if prev_frame_align_char_exist == 1 and current frame is end of multi frame boundary, alignment character must be /A/
   //       if prev_frame_align_char_exist == 1 and current frame is not end of multi frame boundary, it is an error
   // 
   // For F=1, prev_frame_last_octet need to use only when alignment character is received in current frame, 0th byte
   //          else it can get details from current frame only
   // For F=2, prev_frame_last_octet need to use only when alignment character is received in current frame, 2nd byte
   //          else it can get details from current frame only
   // For F=3, prev_frame_last_octet need to use only when alignment character is received in current frame, other than 4th byte
   //          else it can get details from current frame only
   // For F=4, prev_frame_last_octet need to use since alignment character would always be received on 4th byte in DW
   // For F=5, prev_frame_last_octet need to use and current frame would not carry previous frame last octet
   // For F>5 same as above
   // 

   // case, F=3, two /F/ are not possible in single DW

   `define ALIGNMENT_CHARCTER_F   8'hFC
   `define ALIGNMENT_CHARCTER_A   8'h7C
   `define ALIGNMENT_DECODE_ERR   8'h5C
   `define FRAME_ERROR_THRESHOLD  4'hF  //Number of Frame Alignment error received at unexpected position will be tolerated till count FRAME_ERROR_THRESHOLD
   
   reg               single_frame_received;
   reg [03:00]       single_frame_received_lesser_F;
   reg               last_octet_in_curr_dw;
   reg               last_multi_frame_octet_in_curr_dw;
   reg               start_multi_frame_octet_in_curr_dw;
   reg [31:0]        curr_frame_last_dw;
   reg [07:0]        prev_frame_last_octet;
   reg [03:0]        last_octet_location, last_multi_frame_octet_location;
   reg [03:0]        last_octet_location_lesser_F;
   reg [03:0]        start_octet_location, start_multi_frame_octet_location;
   (*keep = "true",max_fanout = 4*)reg [08:0]        F_local;
   reg [10:0]        MULT_F_local;
   reg [10:0]        multi_frame_octets;
   //reg [03:0]        expected_A, expected_F;

   reg               prev_frame_align_char_exist;
   reg [3:0]         prev_frame_align_char_exist_lesser_F;
   
   // assign scrambler output
   assign scr_data = curr_frame_last_dw;
              
   //reg [3:0] alignment_err[4]; //bit 0, alignment F error, bit 1, alignment A, bit 2 decode error, bit 3 unexpected error
   reg [3:0] alignment_err_0, alignment_err_1, alignment_err_2, alignment_err_3; //bit 0, alignment F error, bit 1, alignment A, bit 2 decode error, bit 3 unexpected error
   reg       initial_prediction;

   wire [3:0] length_lsb = (mframe_length_char[1:0]*ilas_length_mframe[1:0]);
   
   wire [3:0] ilas_data_valid_local_tmp = (ilas_en) ? (((length_lsb[1:0]) == 2'b00) ? 4'b0000 :
                                                       ((length_lsb[1:0]) == 2'b01) ? 4'b0001 :
                                                       ((length_lsb[1:0]) == 2'b10) ? 4'b0011 :
                                                       ((length_lsb[1:0]) == 2'b11) ? 4'b0111 :
                                                       4'b0000) : 4'b0000;
   
   wire       dskew_frame_data_vld_local = (dskew_frame_data_vld) & (ilas_data_valid != 4'b1111);

   //reg        one_time_pulse, ilas_restart;
   reg        one_time_pulse;
   reg [0:0]  ilas_restart_fsm;
   reg [3:0]  ilas_data_valid_local;

   // Detect ILAS is going to start again from User Data phase
   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         ilas_restart <= 0;
         ilas_restart_fsm <= 1'b0;
      end else begin
         if (ilas_restart_fsm == 0) begin
            ilas_restart <= 0;
            if (dskew_frame_data_vld) begin
               ilas_restart_fsm <= 1'b1;
            end else begin
               ilas_restart_fsm <= 1'b0;
            end
         //end else if (ilas_restart_fsm == 1'b1) begin
         end else begin
            if (dskew_frame_data_vld == 0) begin
               ilas_restart_fsm <= 1'b0; // I think ilast_start_fsm <= 2'b00 also ok
               ilas_restart <= 1;
            end else begin
               ilas_restart_fsm <= 1'b1;
               ilas_restart <= 0;
            end
         end
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)

   // drive sof and eof for frame and multi-frame
   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         scr_data_eof  <= 4'h0;
         scr_data_eomf <= 4'h0;
         scr_data_sof  <= 4'h0;
         scr_data_somf <= 4'h0;
         scr_data_vld  <= 1'b0;
         scr_byte_en   <= 4'h0;
         user_data_valid_n  <= 4'h0;
      end else begin
         scr_data_vld <= dskew_frame_data_vld;
         //scr_byte_en  <= ~dskew_frame_data_k;
         //scr_byte_en  <= ~(decode_err & unexpected_k_err);
         scr_byte_en  <= ~(decode_err | unexpected_k_err);
         user_data_valid_n  <= ilas_data_valid;
         //scr_data_sof <= 4'h0;
         if (dskew_frame_data_vld_local) begin
              
            scr_data_sof <= start_octet_location;

            if (start_multi_frame_octet_in_curr_dw) begin
               if (TXRX_F_REG > 3) begin
                  scr_data_somf <= start_octet_location;
               end else begin
                  scr_data_somf <= start_multi_frame_octet_location;
               end
            end else begin
               scr_data_somf <= 4'b0;
            end

            if (last_octet_in_curr_dw) begin
               if (TXRX_F_REG > 3) begin
                  scr_data_eof <= last_octet_location;
               end else begin
                  scr_data_eof <= last_octet_location_lesser_F;
               end
            end else begin
              scr_data_eof <= 4'h0;
            end
  
            if (last_multi_frame_octet_in_curr_dw) begin
               if (TXRX_F_REG > 3) begin
                  scr_data_eomf <= last_octet_location;//ToDo for F less than 4
               end else begin
                  scr_data_eomf <= last_multi_frame_octet_location;
               end
            end else begin
              scr_data_eomf <= 4'h0;
            end
              
        end // if (dskew_frame_data_vld_local)
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)

   // Need to have some intelligent logic which will predict 
   // whether current cycle has last octet of frame and respective location
   // Other always block would use these details and take required action
   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         one_time_pulse               <= 1;
         F_local                      <= 'h1;
         MULT_F_local                 <= 'h11;
         last_octet_in_curr_dw        <= 0;
         multi_frame_octets           <= 0;
         last_octet_location          <= 4'h0;
         last_octet_location_lesser_F <= 4'h0;
         initial_prediction           <= 0;
         ilas_data_valid_local        <= 4'b0000;
         start_multi_frame_octet_location <= 4'b0000;
         start_octet_location         <= 4'b0001;
         last_multi_frame_octet_in_curr_dw  <= 0;
         last_multi_frame_octet_location    <= 4'b0000;
         start_multi_frame_octet_in_curr_dw <= 0;
      end else begin
         if (initial_prediction) begin
            initial_prediction    <= 0;
            ilas_data_valid_local <= 4'b0000;
         end
         
         if ((one_time_pulse) || (ilas_restart))begin
            one_time_pulse     <= 0;
            F_local            <= TXRX_F_REG;
            MULT_F_local       <= mframe_length_char;
            multi_frame_octets <= mframe_length_char;
            initial_prediction <= 1;
            ilas_data_valid_local <= ilas_data_valid_local_tmp;
         //end
         end else if ((initial_prediction) || (dskew_frame_data_vld_local)) begin
         // Use one time pulse which will use to start prediction
         // then onwards, use dskew_frame_data_vld for further update
         //if ((initial_prediction) || (dskew_frame_data_vld_local)) begin
            if (TXRX_F_REG > 3) begin
               case (F_local)
                 0: begin
                    F_local <= TXRX_F_REG;
                 end
                 4: begin
                    if (initial_prediction == 0) begin
                       last_octet_in_curr_dw <= 1;
                       // last_octet_location would be coming from F_local
                       last_octet_location <= 4'b1000;
                       // Reload the original value
                       F_local <= TXRX_F_REG;
                       if (TXRX_F_REG == 4) begin
                          start_octet_location <= 4'b0001;
                       end else begin
                          start_octet_location <= 4'b0000;
                       end
                    end else begin
                       case (ilas_data_valid_local)
                         4'b1111: F_local <= TXRX_F_REG;     //Invalid case
                         4'b0111: begin
                            F_local <= F_local - 8'h1;
                            start_octet_location <= 4'b1000;
                            last_octet_location  <= 4'b0000;
                         end
                         4'b0011: begin 
                            F_local <= F_local - 8'h2;
                            start_octet_location <= 4'b0100;
                            last_octet_location  <= 4'b0000;
                         end
                         4'b0001: begin 
                            F_local <= F_local - 8'h1;
                            start_octet_location <= 4'b0010;
                            last_octet_location  <= 4'b0000;
                         end
                         4'b0000: begin
                            F_local <= TXRX_F_REG;
                            last_octet_in_curr_dw <= 1;
                            // last_octet_location would be coming from F_local
                            last_octet_location  <= 4'b1000;
                            start_octet_location <= 4'b0001;
                         end
                         default: F_local <= TXRX_F_REG;
                       endcase // case (ilas_data_valid_local)
                    end
                 end // case: 4
                 1: begin
                    last_octet_in_curr_dw <= 1;
                    last_octet_location  <= 4'b0001;
                    start_octet_location <= 4'b0010;
                    // Reload original value but adjust balance F_local
                    F_local <= TXRX_F_REG - (8'h4-F_local);
                 end
                 2: begin
                    last_octet_in_curr_dw <= 1;
                    last_octet_location  <= 4'b0010;
                    start_octet_location <= 4'b0100;
                    // Reload original value but adjust balance F_local
                    F_local <= TXRX_F_REG - (8'h4-F_local);
                 end
                 3: begin
                    last_octet_in_curr_dw <= 1;
                    last_octet_location  <= 4'b0100;
                    start_octet_location <= 4'b1000;
                    // Reload original value but adjust balance F_local
                    F_local <= TXRX_F_REG - (8'h4-F_local);
                 end
                 default: begin
                    last_octet_in_curr_dw <= 0;
                    last_octet_location   <= 4'b0000;
                    
                    case (ilas_data_valid_local)
                      4'b1111: F_local <= F_local;     //invalid case
                      4'b0111: F_local <= F_local - 8'h1;
                      4'b0011: F_local <= F_local - 8'h2;
                      4'b0001: F_local <= F_local - 8'h3;
                      4'b0000: F_local <= F_local - 8'h4;
                      default: F_local <= F_local - 8'h4;
                    endcase // case (ilas_data_valid_local)
                    
                    if (F_local == TXRX_F_REG) begin
                       case(ilas_data_valid_local)
                         4'b1111: start_octet_location <= 4'b0000;     //invalid case
                         4'b0111: start_octet_location <= 4'b1000;
                         4'b0011: start_octet_location <= 4'b0100;
                         4'b0001: start_octet_location <= 4'b0010;
                         4'b0000: start_octet_location <= 4'b0001;
                         default: start_octet_location <= 4'b0000;
                       endcase // case (ilas_data_valid_local)
                    end else begin
                       start_octet_location <= 4'b0000;
                    end
                    //F_local = F_local - 4;
                 end
               endcase // case (F_local)
            
            end else begin // if (TXRX_F_REG > 3)
               //For F between 1 to 4 is TBD
               //last_octet_in_curr_dw <= 1;
               
               // For F=1: prev_frame_last_octet need to use only when alignment character is received in current frame, 0th byte
               //          else it can get details from current frame only
               //          prev_frame_last_octet need to store from 4th byte of current DW
               // For F=2: prev_frame_last_octet need to use only when alignment character is received in current frame, 2nd byte
               //          else it can get details from current frame only
               //          prev_frame_last_octet need to store from 4th byte of current DW
               // For F=3, prev_frame_last_octet need to use only when alignment character is received in current frame, other than 4th byte
               //          else it can get details from current frame only

               // Keep seperate logic for initial prediction and for rest of the window
               //if (initial_prediction) begin
        //        
        //       end else begin
        //       end
               if (initial_prediction) begin
                  case (F_local[1:0])
                    1: begin // if (F_local == 1) begin
                       // irrespective value of ilas_data_valid_local, we expect last_octet_location is 4'b1000
                       last_octet_location  <= 4'b1000; //As such it should be 4'b1111 but this is used for storing prev_char, so MSB is 1 and rest bits are 0
                       // start_octet_location would indicate valid octets
                       case (ilas_data_valid_local)
                         4'b0111: begin
                            start_octet_location <= 4'b1000;
                            last_octet_location_lesser_F <= 4'b1000;
                         end
                         4'b0011: begin
                            start_octet_location <= 4'b1100;
                            last_octet_location_lesser_F <= 4'b1100;
                         end
                         4'b0001: begin
                            start_octet_location <= 4'b1110;
                            last_octet_location_lesser_F <= 4'b1110;
                         end
                         default: begin
                            start_octet_location <= 4'b1111;
                            last_octet_location_lesser_F <= 4'b1111;
                         end
                       endcase // case (ilas_data_valid_local)
                       
                       last_octet_in_curr_dw <= 1;
                    end // case: 1
                    2: begin // end else if (F_local == 2) begin
                       case (ilas_data_valid_local)
                         4'b0111: begin
                            // last octet location would change and do not mark last_octet_in_curr_dw as 1
                            // It will get set to 1 in next cycle
                            //last_octet_location  <= 4'b0100; // I think it should be 0 and need to assign in next cycle i.e. else part of initial_prediction
                            last_octet_location  <= 4'b0000; // I think it should be 0 and need to assign in next cycle i.e. else part of initial_prediction
                            start_octet_location <= 4'b1000;
                            last_octet_location_lesser_F <= 4'b0000;
                         end
                         4'b0011: begin
                            last_octet_location  <= 4'b1000;
                            start_octet_location <= 4'b0100;
                            last_octet_location_lesser_F <= 4'b1000;
                            last_octet_in_curr_dw <= 1;
                         end
                         4'b0001: begin
                            last_octet_location  <= 4'b0100;
                            start_octet_location <= 4'b1010;
                            last_octet_location_lesser_F <= 4'b0100;
                            last_octet_in_curr_dw <= 1;
                         end
                         default: begin
                            last_octet_location  <= 4'b1000;
                            start_octet_location <= 4'b0101;
                            last_octet_location_lesser_F <= 4'b1010;
                            last_octet_in_curr_dw <= 1;
                         end
                       endcase // case (ilas_data_valid_local)
                    end // case: 2
                    default: begin // F_local == 3
                       // F_local == 3
                       // need to rotate last_octet_location from 3, 6(i.e. 2nd byte), 9(i.e. 1st byte), 12 (i.e. 4th byte)
                       case (ilas_data_valid_local)
                         4'b0111: begin
                            // last octet location would change and do not mark last_octet_in_curr_dw as 1
                            // It will get set to 1 in next cycle
                            last_octet_location  <= 4'b0000;
                            start_octet_location <= 4'b1000;
                            last_octet_location_lesser_F <= 4'b0000;
                            last_octet_in_curr_dw <= 0;
                         end
                         4'b0011: begin
                            last_octet_location  <= 4'b0000;
                            start_octet_location <= 4'b0100;
                            last_octet_location_lesser_F <= 4'b0000;
                            last_octet_in_curr_dw <= 0;
                         end
                         4'b0001: begin
                            last_octet_location  <= 4'b1000;
                            start_octet_location <= 4'b0010;
                            last_octet_location_lesser_F <= 4'b1000;
                            last_octet_in_curr_dw <= 1;
                         end
                         default: begin
                            last_octet_location  <= 4'b0100;
                            start_octet_location <= 4'b1001;
                            last_octet_location_lesser_F <= 4'b0100;
                            last_octet_in_curr_dw <= 1;
                         end
                       endcase // case (ilas_data_valid_local)
                    end // case: default
                  endcase // case (F_local[1:0])
               end else begin // if (initial_prediction)
                  last_octet_in_curr_dw <= 1;
                  case (F_local[1:0])
                    2: begin // if (F_local == 2) begin
                       // Instead of using ilas_data_valid_local_tmp, 
                       // another option is to use start_octet_location to decide next value of last_octet_location, start_octet_location
                       if (ilas_data_valid_local_tmp == 4'b0111) begin
                          last_octet_location <= 4'b0100;
                       end else begin
                          last_octet_location <= last_octet_location;
                       end

                       case (ilas_data_valid_local_tmp)
                         4'b0111: begin
                            start_octet_location <= 4'b1010;
                         end
                         4'b0011: begin
                            start_octet_location <= 4'b0101;
                         end
                         default: begin
                            start_octet_location <= start_octet_location;
                         end
                       endcase // case (ilas_data_valid_local_tmp)

                       case (ilas_data_valid_local_tmp)
                         4'b0111: begin
                            last_octet_location_lesser_F <= 4'b0101;
                         end
                         4'b0011: begin
                            last_octet_location_lesser_F <= 4'b1010;
                         end
                         4'b0001: begin
                            last_octet_location_lesser_F <= 4'b0101;
                         end
                         default: begin
                            last_octet_location_lesser_F <= last_octet_location_lesser_F; 
                         end
                       endcase // case (ilas_data_valid_local_tmp)
                    end // case: 2
                    3: begin // end else if (F_local == 3) begin
                       // depending on start_octet_locatino, last_octet_location is decided
                       //
                       case (start_octet_location)
                         4'b1001: begin
                            last_octet_location <= 4'b0010;
                            start_octet_location <= 4'b0100;
                            last_octet_location_lesser_F <= 4'b0010;
                         end
                         4'b0010: begin
                            last_octet_location <= 4'b0100;
                            start_octet_location <= 4'b1001;
                            last_octet_location_lesser_F <= 4'b0100;
                         end
                         4'b0100: begin
                            last_octet_location <= 4'b1001; //I think we need to mark 4'b1000 so next machine would use MSB location for storing history
                            start_octet_location <= 4'b0010;
                            last_octet_location_lesser_F <= 4'b1001;
                         end
                         4'b1000: begin
                            last_octet_location <= 4'b0010;
                            start_octet_location <= 4'b0100;
                            last_octet_location_lesser_F <= 4'b0010;
                         end
                         default: begin // This is invalid case
                            last_octet_location  <= last_octet_location;
                            start_octet_location <= start_octet_location;
                            last_octet_location_lesser_F <= last_octet_location_lesser_F;
                         end
                       endcase // case (start_octet_location)
                       // if (start_octet_location == 4'b1001) begin
                       // end else if (start_octet_location == 4'b0010) begin
                       // end else if (start_octet_location == 4'b0100) begin
                       // end else if (start_octet_location == 4'b1000) begin
                       // end else begin  // This is invalid case
                       // end
                    end // case: 3
                    default: begin // end else begin
                       last_octet_location  <= 4'b1000;
                       last_octet_location_lesser_F <= 4'b1111;
                       start_octet_location <= 4'b1111;
                    end
                  endcase // case (F_local[1:0])
               end // else: !if(initial_prediction)
            end // else: !if(TXRX_F_REG > 3)
            
            // Detection of multi-frame is ending
            // Commenting below line with assumption that MULT_F_local = 0 will never happen
            // if (MULT_F_local == 0) begin
            //    MULT_F_local <= multi_frame_octets;
            // end else if (MULT_F_local == 4) begin
            case (MULT_F_local)
              4: begin
                  last_multi_frame_octet_in_curr_dw <= 1;
                  last_multi_frame_octet_location <= 4'b1000;
              end
               3: begin
                 last_multi_frame_octet_in_curr_dw <= 1;
                 last_multi_frame_octet_location  <= 4'b0100;
               end
              2: begin
                 last_multi_frame_octet_in_curr_dw <= 1;
                 last_multi_frame_octet_location  <= 4'b0010;
              end
              1: begin
                 last_multi_frame_octet_in_curr_dw <= 1;
                 last_multi_frame_octet_location  <= 4'b0001;
              end
              default: begin //Need to check ilas_data_valid, use initial_prediction
                 last_multi_frame_octet_in_curr_dw <= 0;
                 last_multi_frame_octet_location   <= 4'b0000;
              end
            endcase // case (MULT_F_local)

            case (MULT_F_local)
              4: begin
                  // Reload the original value
                  MULT_F_local <= multi_frame_octets;
              end
              3: begin
                 MULT_F_local <= multi_frame_octets - (11'h4-MULT_F_local);
              end
              2: begin
                 MULT_F_local <= multi_frame_octets - (11'h4-MULT_F_local);
              end
              1: begin
                 MULT_F_local <= multi_frame_octets - (11'h4-MULT_F_local);
              end
              default: begin
               if (initial_prediction) begin
                  case (ilas_data_valid_local)
                    //4'b1111: MULT_F_local <= multi_frame_octets;     //Invalid case
                    4'b0111: begin
                                MULT_F_local <= MULT_F_local - 11'h1;
                             end
                    4'b0011: begin 
                                MULT_F_local <= MULT_F_local - 11'h2;
                             end
                    4'b0001: begin 
                                MULT_F_local <= MULT_F_local - 11'h3;
                             end
                    4'b0000: begin
                                MULT_F_local <= MULT_F_local - 11'h4;
                             end
                    default: MULT_F_local <= multi_frame_octets;
                  endcase // case (ilas_data_valid_local)
               end else begin // if (initial_prediction)
                  MULT_F_local <= MULT_F_local - 11'h4;
               end // else: !if(initial_prediction)
              end
            endcase // case (MULT_F_local)

            case (MULT_F_local)
              4: begin
                 if (MULT_F_local == multi_frame_octets) begin
                    //This case is not legal case
                    start_multi_frame_octet_location <= 4'b0001;
                    start_multi_frame_octet_in_curr_dw <= 1;
                 end else begin
                    start_multi_frame_octet_location <= 4'b0000;
                    start_multi_frame_octet_in_curr_dw <= 0;
                 end
              end
              3: begin
                 start_multi_frame_octet_in_curr_dw <= 1;
                 start_multi_frame_octet_location <= 4'b1000;
              end
              2: begin
                 start_multi_frame_octet_in_curr_dw <= 1;
                 start_multi_frame_octet_location <= 4'b0100;
              end
              1: begin
                 start_multi_frame_octet_in_curr_dw <= 1;
                 start_multi_frame_octet_location <= 4'b0010;
              end
              default: begin
               if (initial_prediction) begin
                  start_multi_frame_octet_in_curr_dw <= 1;
                  
                  //seperating in two case statment for synthesize
                  case (ilas_data_valid_local)
                    4'b0111: begin
                                start_multi_frame_octet_location <= 4'b1000;
                             end
                    4'b0011: begin 
                                start_multi_frame_octet_location <= 4'b0100;
                             end
                    4'b0001: begin 
                                start_multi_frame_octet_location <= 4'b0010;
                             end
                    4'b0000: begin
                                start_multi_frame_octet_location <= 4'b0001;
                             end
                    default: start_multi_frame_octet_location <= 4'b0000;
                  endcase // case (ilas_data_valid_local)
                  
               end else begin
                  if (MULT_F_local == multi_frame_octets) begin
                     start_multi_frame_octet_in_curr_dw <= 1;
                     start_multi_frame_octet_location <= 4'b0001;
                  end else begin
                     start_multi_frame_octet_location <= 4'b0000;
                     start_multi_frame_octet_in_curr_dw <= 0;
                  end
               end
              end
            endcase // case (MULT_F_local)
            
            // if (MULT_F_local == 4) begin
            //       last_multi_frame_octet_in_curr_dw <= 1;
            //       last_multi_frame_octet_location <= 4'b1000;

            //       // last_octet_location would be coming from F_local
            //       //last_octet_location <= 4'b1000;
            //       // Reload the original value
            //       MULT_F_local <= multi_frame_octets;

            //       if (MULT_F_local == multi_frame_octets) begin
            //          //This case is not legal case
            //          start_multi_frame_octet_location <= 4'b0001;
            //          start_multi_frame_octet_in_curr_dw <= 1;
            //       end else begin
            //          start_multi_frame_octet_location <= 4'b0000;
            //          start_multi_frame_octet_in_curr_dw <= 0;
            //       end
            // end else if (MULT_F_local > 4) begin
            //    // Need to check ilas_data_valid, use initial_prediction

            //    if (initial_prediction) begin
            //       start_multi_frame_octet_in_curr_dw <= 1;
                  
            //       case (ilas_data_valid_local)
            //         //4'b1111: MULT_F_local <= multi_frame_octets;     //Invalid case
            //         4'b0111: begin
            //                     MULT_F_local <= MULT_F_local - 11'h1;
            //                  end
            //         4'b0011: begin 
            //                     MULT_F_local <= MULT_F_local - 11'h2;
            //                  end
            //         4'b0001: begin 
            //                     MULT_F_local <= MULT_F_local - 11'h3;
            //                  end
            //         4'b0000: begin
            //                     MULT_F_local <= MULT_F_local - 11'h4;
            //                  end
            //         default: MULT_F_local <= multi_frame_octets;
            //       endcase // case (ilas_data_valid_local)

            //       //seperating in two case statment for synthesize
            //       case (ilas_data_valid_local)
            //         4'b0111: begin
            //                     start_multi_frame_octet_location <= 4'b1000;
            //                  end
            //         4'b0011: begin 
            //                     start_multi_frame_octet_location <= 4'b0100;
            //                  end
            //         4'b0001: begin 
            //                     start_multi_frame_octet_location <= 4'b0010;
            //                  end
            //         4'b0000: begin
            //                     start_multi_frame_octet_location <= 4'b0001;
            //                  end
            //         default: start_multi_frame_octet_location <= 4'b0000;
            //       endcase // case (ilas_data_valid_local)
                  
            //    end else begin
            //       MULT_F_local <= MULT_F_local - 12'h4;
            //       if (MULT_F_local == multi_frame_octets) begin
            //          start_multi_frame_octet_in_curr_dw <= 1;
            //          start_multi_frame_octet_location <= 4'b0001;
            //       end else begin
            //          start_multi_frame_octet_location <= 4'b0000;
            //          start_multi_frame_octet_in_curr_dw <= 0;
            //       end
            //    end
               
            //    last_multi_frame_octet_in_curr_dw <= 0;
            //    last_multi_frame_octet_location   <= 4'b0000;
               
            // end else if (MULT_F_local < 4) begin
            //    last_multi_frame_octet_in_curr_dw <= 1;

            //    if (MULT_F_local == 3) begin
            //       start_multi_frame_octet_location <= 4'b1000;
            //       last_multi_frame_octet_location  <= 4'b0100;
            //    end else if (MULT_F_local == 2) begin
            //       start_multi_frame_octet_location <= 4'b0100;
            //       last_multi_frame_octet_location  <= 4'b0010;
            //    end else begin
            //       start_multi_frame_octet_location <= 4'b0010;
            //       last_multi_frame_octet_location  <= 4'b0001;
            //    end

            //    MULT_F_local <= multi_frame_octets - (11'h4-MULT_F_local);
            //    start_multi_frame_octet_in_curr_dw <= 1;
            // end
         end // if ((initial_prediction) || (dskew_frame_data_vld))
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)

   reg [1:0] frame_bits_require;
   reg       frame_count;

/// combination logic start

   always @* begin
         if (last_octet_in_curr_dw == 1 & dskew_frame_data_vld_local) begin
            if (dskew_frame_data_k[0] & !ilas_data_valid[0]) begin
               // For F less than 4, need special checking since single DW itself holds more than one frame
               if ((TXRX_F_REG == 1) || (TXRX_F_REG == 2) || (TXRX_F_REG == 3)) begin
                  //alignment_err_0 = chk_alignment_correctness_special(0, dskew_frame_data[7:0], prev_frame_align_char_exist_lesser_F[4-TXRX_F_REG], prev_frame_last_octet);
                  alignment_err_0 = chk_alignment_correctness_special(0, last_octet_location_lesser_F, last_multi_frame_octet_location, align_a_char_replace_en, single_frame_received_lesser_F, dskew_frame_data[7:0], prev_frame_align_char_exist_lesser_F[4-TXRX_F_REG], prev_frame_last_octet, scr_dis);
               end else begin // if ((TXRX_F_REG == 1) || (TXRX_F_REG == 2) || (TXRX_F_REG == 3))
                  //alignment_err_0 = chk_alignment_correctness(1, dskew_frame_data[07:0]);
                  alignment_err_0 = chk_alignment_correctness(4'd1, last_octet_location, last_multi_frame_octet_in_curr_dw, align_a_char_replace_en, prev_frame_align_char_exist, dskew_frame_data[07:0], single_frame_received, scr_dis);
               end
            end else begin
               alignment_err_0 = 0;
            end
            
            if (dskew_frame_data_k[1] & !ilas_data_valid[1]) begin
               case (TXRX_F_REG)
                 1: begin // if (TXRX_F_REG == 1) begin
                  //alignment_err_1 = chk_alignment_correctness_special(1, dskew_frame_data[15:8], dskew_frame_data_k[0], dskew_frame_data[07:00]); //ToDo, need to check for _k[0] == 1?
                  alignment_err_1 = chk_alignment_correctness_special(1, last_octet_location_lesser_F, last_multi_frame_octet_location, align_a_char_replace_en, single_frame_received_lesser_F, dskew_frame_data[15:8], dskew_frame_data_k[0], dskew_frame_data[07:00], scr_dis); //ToDo, need to check for _k[0] == 1?
                 end
                 2: begin // end else if ((TXRX_F_REG == 2) || (TXRX_F_REG == 3)) begin // if (TXRX_F_REG == 1)
                  //if (TXRX_F_REG == 2) begin
                     // For F==2
                     //alignment_err_1 = chk_alignment_correctness_special(1, dskew_frame_data[15:8], prev_frame_align_char_exist_lesser_F[3], prev_frame_last_octet);
                     alignment_err_1 = chk_alignment_correctness_special(1, last_octet_location_lesser_F, last_multi_frame_octet_location, align_a_char_replace_en, single_frame_received_lesser_F, dskew_frame_data[15:8], prev_frame_align_char_exist_lesser_F[3], prev_frame_last_octet, scr_dis);
                 end
                 3: begin 
                     // For F==3
                     //alignment_err_1 = chk_alignment_correctness_special(1, dskew_frame_data[15:8], prev_frame_align_char_exist_lesser_F[2], prev_frame_last_octet);
                     alignment_err_1 = chk_alignment_correctness_special(1, last_octet_location_lesser_F, last_multi_frame_octet_location, align_a_char_replace_en, single_frame_received_lesser_F, dskew_frame_data[15:8], prev_frame_align_char_exist_lesser_F[2], prev_frame_last_octet, scr_dis);
                 end
                 default: begin //end else begin // if ((TXRX_F_REG == 2) || (TXRX_F_REG == 3))
                  //alignment_err_1 = chk_alignment_correctness(2, dskew_frame_data[15:8]);
                  alignment_err_1 = chk_alignment_correctness(4'd2, last_octet_location, last_multi_frame_octet_in_curr_dw, align_a_char_replace_en, prev_frame_align_char_exist, dskew_frame_data[15:08], single_frame_received, scr_dis);
                 end
               endcase // case (TXRX_F_REG)
            end else begin // if (dskew_frame_data_k[1])
               alignment_err_1 = 0;
            end // else: !if(dskew_frame_data_k[1])

            if (dskew_frame_data_k[2] & !ilas_data_valid[2]) begin
               //ToDo: For F=2, need to check location [7:0] whether it contains alignment character
               //               and if current location has alignment character then it is issue
               case (TXRX_F_REG)
                 1: begin
                    //alignment_err_2 = chk_alignment_correctness_special(2, dskew_frame_data[23:16], dskew_frame_data_k[1], dskew_frame_data[15:08]);
                    alignment_err_2 = chk_alignment_correctness_special(2, last_octet_location_lesser_F, last_multi_frame_octet_location, align_a_char_replace_en, single_frame_received_lesser_F, dskew_frame_data[23:16], dskew_frame_data_k[1], dskew_frame_data[15:08], scr_dis);
                 end
                 2: begin
                     //alignment_err_2 = chk_alignment_correctness_special(2, dskew_frame_data[23:16], dskew_frame_data_k[0], dskew_frame_data[07:00]);
                     alignment_err_2 = chk_alignment_correctness_special(2, last_octet_location_lesser_F, last_multi_frame_octet_location, align_a_char_replace_en, single_frame_received_lesser_F, dskew_frame_data[23:16], dskew_frame_data_k[0], dskew_frame_data[07:00], scr_dis);
                 end
                 3: begin
                     //alignment_err_2 = chk_alignment_correctness_special(2, dskew_frame_data[23:16], prev_frame_align_char_exist_lesser_F[3], prev_frame_last_octet);
                     alignment_err_2 = chk_alignment_correctness_special(2, last_octet_location_lesser_F, last_multi_frame_octet_location, align_a_char_replace_en, single_frame_received_lesser_F, dskew_frame_data[23:16], prev_frame_align_char_exist_lesser_F[3], prev_frame_last_octet, scr_dis);
                 end
                 default: begin
                    //alignment_err_2 = chk_alignment_correctness(4, dskew_frame_data[23:16]);
                    alignment_err_2 = chk_alignment_correctness(4'd4, last_octet_location, last_multi_frame_octet_in_curr_dw, align_a_char_replace_en, prev_frame_align_char_exist, dskew_frame_data[23:16], single_frame_received, scr_dis);
                 end
               endcase // case (TXRX_F_REG)
                    
               // if ((TXRX_F_REG == 1) || (TXRX_F_REG == 2) || (TXRX_F_REG == 3))begin
               //    if (TXRX_F_REG == 1) begin
               //       alignment_err_2 = chk_alignment_correctness_special(2, dskew_frame_data[23:16], dskew_frame_data_k[1], dskew_frame_data[15:08]);
               //    end else if (TXRX_F_REG == 2) begin
               //       alignment_err_2 = chk_alignment_correctness_special(2, dskew_frame_data[23:16], dskew_frame_data_k[0], dskew_frame_data[07:00]);
               //    end else begin
               //       // F==3
               //       alignment_err_2 = chk_alignment_correctness_special(2, dskew_frame_data[23:16], prev_frame_align_char_exist_lesser_F[3], prev_frame_last_octet);
               //    end
                  
               // end else begin // if ((TXRX_F_REG == 1) || (TXRX_F_REG == 2) || (TXRX_F_REG == 3))
               //    alignment_err_2 = chk_alignment_correctness(4, dskew_frame_data[23:16]);
                  
               // end // else: !if((TXRX_F_REG == 1) || (TXRX_F_REG == 2) || (TXRX_F_REG == 3))
               
            end else begin // if (dskew_frame_data_k[2])
                  alignment_err_2 = 0;
            end // else: !if(dskew_frame_data_k[2])
            
            if (dskew_frame_data_k[3] & !ilas_data_valid[3]) begin
               //check whether alignment character is expected at this location
               //ToDo: For F=2, need to check location [15:8] whether it contains alignment character
               //               and if current location has alignment character then it is issue
               //ToDo: For F=3, need to check location [23:16] whether it contains alignment character
               //               and if current location has alignment character then it is issue
               case (TXRX_F_REG)
                 1: begin
                    //alignment_err_3 = chk_alignment_correctness_special(3, dskew_frame_data[31:24], dskew_frame_data_k[2], dskew_frame_data[23:16]);
                    alignment_err_3 = chk_alignment_correctness_special(3, last_octet_location_lesser_F, last_multi_frame_octet_location, align_a_char_replace_en,  single_frame_received_lesser_F, dskew_frame_data[31:24], dskew_frame_data_k[2], dskew_frame_data[23:16], scr_dis);
                 end
                 2: begin
                    //alignment_err_3 = chk_alignment_correctness_special(3, dskew_frame_data[31:24], dskew_frame_data_k[1], dskew_frame_data[15:08]);, 
                    alignment_err_3 = chk_alignment_correctness_special(3, last_octet_location_lesser_F, last_multi_frame_octet_location, align_a_char_replace_en, single_frame_received_lesser_F, dskew_frame_data[31:24], dskew_frame_data_k[1], dskew_frame_data[15:08], scr_dis);
                 end
                 3: begin
                    //alignment_err_3 = chk_alignment_correctness_special(3, dskew_frame_data[31:24], dskew_frame_data_k[0], dskew_frame_data[07:00]);
                    alignment_err_3 = chk_alignment_correctness_special(3, last_octet_location_lesser_F, last_multi_frame_octet_location, align_a_char_replace_en, single_frame_received_lesser_F, dskew_frame_data[31:24], dskew_frame_data_k[0], dskew_frame_data[07:00], scr_dis);
                 end
                 default: begin
                    //alignment_err_3 = chk_alignment_correctness(8, dskew_frame_data[31:24]);
                    alignment_err_3 = chk_alignment_correctness(4'd8, last_octet_location, last_multi_frame_octet_in_curr_dw, align_a_char_replace_en, prev_frame_align_char_exist, dskew_frame_data[31:24], single_frame_received, scr_dis);
                 end
               endcase // case (TXRX_F_REG)
                 
               // if (TXRX_F_REG == 1) begin
               //    alignment_err_3 = chk_alignment_correctness_special(3, dskew_frame_data[31:24], dskew_frame_data_k[2], dskew_frame_data[23:16]);
               // end else if (TXRX_F_REG == 2) begin
               //    alignment_err_3 = chk_alignment_correctness_special(3, dskew_frame_data[31:24], dskew_frame_data_k[1], dskew_frame_data[15:08]);
               // end else if (TXRX_F_REG == 3) begin
               //    alignment_err_3 = chk_alignment_correctness_special(3, dskew_frame_data[31:24], dskew_frame_data_k[0], dskew_frame_data[07:00]);
               // end else begin                  
               //    alignment_err_3 = chk_alignment_correctness(8, dskew_frame_data[31:24]);
               // end
            end else begin // if (dskew_frame_data_k[3])
               alignment_err_3 = 0;
            end // else: !if(dskew_frame_data_k[3])
            
         end else begin // if (last_octet_in_curr_dw == 1 & dskew_frame_data_vld_local)
            alignment_err_0 = 4'b0;
            alignment_err_1 = 4'b0;
            alignment_err_2 = 4'b0;
            alignment_err_3 = 4'b0;
         end // else: !if(last_octet_in_curr_dw == 1 & dskew_frame_data_vld_local)
         
   end

/// combination logic end
   
   
   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         single_frame_received      <= 0;
      end else begin // if (rst_clk_character)
         // single_frame_received = 0 only during reset and mark it as 1 
         // once single frame reception is completed (when last_octet_in_curr_DW = 1 is detected)
         if (ilas_restart) begin
            single_frame_received <= 0;
         end else if (last_octet_in_curr_dw & dskew_frame_data_vld_local) begin
            single_frame_received <= 1;
         end else begin
            single_frame_received <= single_frame_received;
         end
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)

   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         single_frame_received_lesser_F <= 4'h0;
         frame_count <= 1'b0;
         frame_bits_require <= 2'b00;
      end else begin
         //ToDo: If below cause any issue in sync, need to use initial_prediction to get it 1 clock early
         if (ilas_restart) begin
            single_frame_received_lesser_F <= 4'h0;
            frame_count <= 1'b0;
            frame_bits_require <= 2'b00;
         end else if (dskew_frame_data_vld_local) begin//block1
            case (ilas_data_valid)
              4'b0000: begin //if (ilas_data_valid == 4'b0000) begin
                 // all octets belongs to user data
                 case (TXRX_F_REG)
                   1: begin // if (TXRX_F_REG == 1) begin
                      if (frame_count == 1) begin
                         single_frame_received_lesser_F <= 4'b1111;
                      end else begin
                         single_frame_received_lesser_F <= 4'b1110;
                         frame_count <= 1;
                      end
                      frame_bits_require <= 2'b00;
                   end
                   2: begin //end else if (TXRX_F_REG == 2) begin
                      if (frame_count == 1) begin
                         if (frame_bits_require == 1) begin
                            single_frame_received_lesser_F <= 4'b1110;
                         end else begin
                            single_frame_received_lesser_F <= 4'b1111;
                         end
                      end else begin
                         single_frame_received_lesser_F <= 4'b1100;
                         frame_count <= 1;
                      end
                      frame_bits_require <= 2'b00;
                   end // case: 2
                   default: begin       // equivalent to end else if (TXRX_F_REG == 3) begin
                      if (frame_count == 1) begin
                         // if (frame_bits_require == 1) begin
                         //    single_frame_received_lesser_F <= 4'b1110;
                         // end else if (frame_bits_require == 2) begin
                         //    single_frame_received_lesser_F <= 4'b1100;
                         // end else begin
                         //    single_frame_received_lesser_F <= 4'b1111;
                         // end
                         case (frame_bits_require)
                           1: single_frame_received_lesser_F <= 4'b1110;
                           2: single_frame_received_lesser_F <= 4'b1100;
                           default: single_frame_received_lesser_F <= 4'b1111;
                         endcase // case (frame_bits_require)
                         
                      end else begin
                         single_frame_received_lesser_F <= 4'b1000;
                         frame_bits_require <= 3'h0;
                         frame_count <= 1;
                      end // else: !if(frame_count == 1)
                      frame_bits_require <= 2'b00;
                   end // case: default
                 endcase // case (TXRX_F_REG)
              end // case: 4'b0000
              4'b0001: begin //end else if (ilas_data_valid == 4'b0001) begin // if (ilas_data_valid == 4'b0000)
                 // 3 MSBs are user data
                 case (TXRX_F_REG)
                   1: begin //               if (TXRX_F_REG == 1) begin
                      single_frame_received_lesser_F <= 4'b1000;
                      frame_count <= 1;
                      // if (frame_count == 1) begin
                      //    single_frame_received_lesser_F <= 4'b1100;
                      // end else begin
                      //    single_frame_received_lesser_F <= 4'b1000;
                      //    frame_count = 1;
                      // end
                      frame_bits_require <= 2'b00;
                   end // case: 1
                   2: begin // end else if (TXRX_F_REG == 2) begin
                      // frame_bits_required is not required to check
                      single_frame_received_lesser_F <= 4'b1000;
                      frame_count <= 1;
                      frame_bits_require <= 2'b00;
                   end
                   3: begin //end else begin //F==3
                      single_frame_received_lesser_F <= 4'b0000;
                      frame_count <= 1;
                      frame_bits_require <= 2'b00;
                   end
                 endcase // case (TXRX_F_REG)
              end // case: 4'b0001
              4'b0011: begin // end else if (ilas_data_valid == 4'b0011) begin // if (ilas_data_valid == 4'b0001)
                 case (TXRX_F_REG)
                   1: begin // if (TXRX_F_REG == 1) begin
                      single_frame_received_lesser_F <= 4'b1000;
                      frame_count <= 1;
                      frame_bits_require <= 2'b00;
                   end
                   2: begin // end else if (TXRX_F_REG == 2) begin
                      single_frame_received_lesser_F <= 4'b0000;
                      frame_count <= 1;
                      frame_bits_require <= 2'b00;
                      //end else if (TXRX_F_REG == 3) begin
                   end
                   default: begin //end else begin //F==3
                      frame_bits_require <= 2'b01;
                      single_frame_received_lesser_F <= 4'b0000;
                      frame_count <= 1;
                   end // else: !if(TXRX_F_REG == 2)
                 endcase // case (TXRX_F_REG)
              end // case: 4'b0011
              4'b0111: begin //end else if (ilas_data_valid == 4'b0111) begin // if (ilas_data_valid == 4'b0011)
                 case (TXRX_F_REG)
                   1: begin // if (TXRX_F_REG == 1) begin
                      single_frame_received_lesser_F <= 4'b0000;
                      frame_count <= 1;
                      frame_bits_require <= 2'b00;
                   end
                   2: begin // end else if (TXRX_F_REG == 2) begin
                      single_frame_received_lesser_F <= 4'b0000;
                      frame_count <= 1;
                      frame_bits_require <= 2'b01;
                      //end else if (TXRX_F_REG == 3) begin
                   end
                   default: begin // end else begin //F==3
                      single_frame_received_lesser_F <= 4'b0000;
                      frame_count <= 1;
                      frame_bits_require <= 2'b10;
                   end // else: !if(TXRX_F_REG == 2)
                 endcase // case (TXRX_F_REG)
              end // case: 4'b0111
              default: begin //end else begin
                 single_frame_received_lesser_F <= 4'b0000;
                 frame_count <= 0;
              end // else: !if(ilas_data_valid == 4'b0111)
            endcase // case (ilas_data_valid)
         end else begin // if (dskew_frame_data_vld_local)
            single_frame_received_lesser_F <= single_frame_received_lesser_F;
            frame_count <= 0;
         end // else: !if(dskew_frame_data_vld_local)
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)
         
   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         prev_frame_last_octet      <=  8'h0;
      end else begin
         // Update prev_frame_last_octet when single_frame_received = 1 and last_octet_in_curr_DW = 1,
         //if (single_frame_received == 1 & last_octet_in_curr_dw == 1 & dskew_frame_data_vld) begin
         // Do we care for single_frame_received?
         //if (single_frame_received == 1 & last_octet_in_curr_dw == 1 & dskew_frame_data_vld_local) begin
         if (last_octet_in_curr_dw == 1 & dskew_frame_data_vld_local) begin
            if (TXRX_F_REG > 3) begin
               case (last_octet_location)
                 4'b0001: begin //if (last_octet_location == 4'b0001) begin
                    if (((dskew_frame_data[07:0] == `ALIGNMENT_CHARCTER_F) || (dskew_frame_data[7:0] == `ALIGNMENT_CHARCTER_A)) && (dskew_frame_data_k[0])) begin
                       prev_frame_last_octet <= prev_frame_last_octet;
                    end else begin
                       prev_frame_last_octet <= dskew_frame_data[07:0];
                    end
                 end
                 4'b0010: begin // end else if (last_octet_location == 4'b0010) begin
                    if (((dskew_frame_data[15:8] == `ALIGNMENT_CHARCTER_F) || (dskew_frame_data[15:8] == `ALIGNMENT_CHARCTER_A)) && (dskew_frame_data_k[1])) begin
                       prev_frame_last_octet <= prev_frame_last_octet;
                    end else begin
                       prev_frame_last_octet <= dskew_frame_data[15:8];
                    end
                 end
                 4'b0100: begin // end else if (last_octet_location == 4'b0100) begin
                    if (((dskew_frame_data[23:16] == `ALIGNMENT_CHARCTER_F) || (dskew_frame_data[23:16] == `ALIGNMENT_CHARCTER_A)) && (dskew_frame_data_k[2])) begin
                       prev_frame_last_octet <= prev_frame_last_octet;
                    end else begin
                       prev_frame_last_octet <= dskew_frame_data[23:16];
                    end
                 end
                 4'b1000: begin //end else if (last_octet_location == 4'b1000) begin
                    if (((dskew_frame_data[31:24] == `ALIGNMENT_CHARCTER_F) || (dskew_frame_data[31:24] == `ALIGNMENT_CHARCTER_A)) && (dskew_frame_data_k[3])) begin
                       prev_frame_last_octet <= prev_frame_last_octet;
                    end else begin
                       prev_frame_last_octet <= dskew_frame_data[31:24];
                    end
                 end
                 default: begin // end else begin
                    prev_frame_last_octet <= prev_frame_last_octet;
                 end
               endcase // case (last_octet_location)
            end else begin // if (TXRX_F_REG > 3)
               if (last_octet_location_lesser_F[3] == 1) begin
                  if (((dskew_frame_data[31:24] == `ALIGNMENT_CHARCTER_F) || (dskew_frame_data[31:24] == `ALIGNMENT_CHARCTER_A)) && (dskew_frame_data_k[3])) begin
                     //prev_frame_last_octet <= prev_frame_last_octet;// dont we need to check TXRX_F_REG, currently prev_frame_last_octet getting value 0
                     case (TXRX_F_REG)
                       1: begin // if (TXRX_F_REG == 1) begin
                          if (dskew_frame_data[23:16]==`ALIGNMENT_CHARCTER_F && (dskew_frame_data_k[2]) && dskew_frame_data[31:24]==`ALIGNMENT_CHARCTER_A )
                            prev_frame_last_octet <= prev_frame_last_octet;
                          else
                            prev_frame_last_octet <= dskew_frame_data[23:16];
                       end
                       2: begin // end else if (TXRX_F_REG == 2) begin
                          if (last_octet_location_lesser_F[1] == 1) begin
                            if (dskew_frame_data[15:08]==`ALIGNMENT_CHARCTER_F && (dskew_frame_data_k[1]) && dskew_frame_data[31:24]==`ALIGNMENT_CHARCTER_A)
                              prev_frame_last_octet <= prev_frame_last_octet;
                            else
                              prev_frame_last_octet <= dskew_frame_data[15:08];
                          end else begin
                            prev_frame_last_octet <= prev_frame_last_octet;
                             
                          end
                       end
                       default: begin // end else begin
                          if (last_octet_location_lesser_F[0] == 1) begin
                            if (dskew_frame_data[07:00]==`ALIGNMENT_CHARCTER_F && (dskew_frame_data_k[0]) && dskew_frame_data[31:24]==`ALIGNMENT_CHARCTER_A)
                              prev_frame_last_octet <= prev_frame_last_octet;
                            else
                              prev_frame_last_octet <= dskew_frame_data[07:00];
                             //prev_frame_last_octet <= dskew_frame_data[15:08];
                          end else begin
                             prev_frame_last_octet <= prev_frame_last_octet;
                          end
                       end
                     endcase // case (TXRX_F_REG)
                  end else begin
                     //prev_frame_last_octet <= dskew_frame_data[31:24];
                     prev_frame_last_octet <= dskew_frame_data[31:24];
                  end
               end else if (last_octet_location_lesser_F[2] == 1) begin
                  if (((dskew_frame_data[23:16] == `ALIGNMENT_CHARCTER_F) || (dskew_frame_data[23:16] == `ALIGNMENT_CHARCTER_A)) && (dskew_frame_data_k[2])) begin
                     case (TXRX_F_REG)
                     
                       1: begin // if (TXRX_F_REG == 1) begin
                          // As such this is illegal case except at the begining but that is also illegal to reecive alignment character at the begining
                          if (dskew_frame_data[15:08]==`ALIGNMENT_CHARCTER_F && (dskew_frame_data_k[1]) && dskew_frame_data[23:16]==`ALIGNMENT_CHARCTER_A)
                            prev_frame_last_octet <= prev_frame_last_octet;
                          else                           
                            prev_frame_last_octet <= dskew_frame_data[15:08];
                       end
                       2: begin // end else if (TXRX_F_REG == 2) begin
                          if (dskew_frame_data[07:00]==`ALIGNMENT_CHARCTER_F && (dskew_frame_data_k[0]) && dskew_frame_data[23:16]==`ALIGNMENT_CHARCTER_A)
                            prev_frame_last_octet <= prev_frame_last_octet;
                          else                                             
                            prev_frame_last_octet <= dskew_frame_data[07:00];
                       end
                       default: begin // end else begin
                          //prev_frame_last_octet <= dskew_frame_data[07:00];
                          prev_frame_last_octet <= curr_frame_last_dw[31:24];
                       end
                     endcase // case (TXRX_F_REG)
                  end else begin
                     //prev_frame_last_octet <= prev_frame_last_octet;
                     prev_frame_last_octet <= dskew_frame_data[23:16];
                  end
               end else if (last_octet_location_lesser_F[1] == 1) begin
                  if (((dskew_frame_data[15:08] == `ALIGNMENT_CHARCTER_F) || (dskew_frame_data[15:08] == `ALIGNMENT_CHARCTER_A)) && (dskew_frame_data_k[1])) begin
                     case (TXRX_F_REG)
                       1: begin // if (TXRX_F_REG == 1) begin
                       // As such this is illegal case except at the begining but that is also illegal to reecive alignment character at the begining
                          if (dskew_frame_data[07:00]==`ALIGNMENT_CHARCTER_F && (dskew_frame_data_k[0]) && dskew_frame_data[15:08]==`ALIGNMENT_CHARCTER_A)
                            prev_frame_last_octet <= prev_frame_last_octet;
                          else                                                      
                            prev_frame_last_octet <= dskew_frame_data[07:00];
                       end
                       2: begin // end else if (TXRX_F_REG == 2) begin
                          //prev_frame_last_octet <= dskew_frame_data[07:00];
                          prev_frame_last_octet <= curr_frame_last_dw[31:24];
                       end
                       default: begin // end else begin
                          //prev_frame_last_octet <= dskew_frame_data[07:00];
                          prev_frame_last_octet <= curr_frame_last_dw[23:16];
                       end
                     endcase // case (TXRX_F_REG)
                  end else begin
                     //prev_frame_last_octet <= prev_frame_last_octet;
                     prev_frame_last_octet <= dskew_frame_data[15:08];
                  end
               end else if (last_octet_location_lesser_F[0] == 1) begin
                  if (((dskew_frame_data[07:00] == `ALIGNMENT_CHARCTER_F) || (dskew_frame_data[07:00] == `ALIGNMENT_CHARCTER_A)) && (dskew_frame_data_k[0])) begin
                     case (TXRX_F_REG)
                       1: begin // if (TXRX_F_REG == 1) begin
                          // As such this is illegal case except at the begining but that is also illegal to reecive alignment character at the begining
                          prev_frame_last_octet <= curr_frame_last_dw[31:24];
                       end
                       2: begin // end else if (TXRX_F_REG == 2) begin
                          prev_frame_last_octet <= curr_frame_last_dw[23:16];
                       end
                       default: begin //end else begin
                          prev_frame_last_octet <= curr_frame_last_dw[15:08];
                       end
                     endcase // case (TXRX_F_REG)
                  end else begin
                     //prev_frame_last_octet <= prev_frame_last_octet;
                     prev_frame_last_octet <= dskew_frame_data[07:00];
                  end
               end else begin
                  prev_frame_last_octet <= prev_frame_last_octet;
               end // else: !if(last_octet_location_lesser_F[0] == 1)
            end // else: !if(TXRX_F_REG > 3)
         end else begin // if (single_frame_received == 1 & last_octet_in_curr_dw == 1 & dskew_frame_data_vld_local)
            prev_frame_last_octet <= prev_frame_last_octet;
         end // else: !if(last_octet_in_curr_dw == 1 & dskew_frame_data_vld_local)
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)
   
   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         curr_frame_last_dw         <= 32'h0;
         prev_frame_align_char_exist <= 1'b0;
         prev_frame_align_char_exist_lesser_F <= 4'h0;
      end else begin
         curr_frame_last_dw <= dskew_frame_data;
         // when last_octet_in_curr_dw = 1, 
         // curr_frame_last_dw also gets updated as per prev_frame_last_octet if /F/ or /A/ characer present
         // Frame/Lane Alignment monitor, look for last octet in current frame
         if (last_octet_in_curr_dw == 1 & dskew_frame_data_vld_local) begin
            //curr_frame_last_dw <= dskew_frame_data;
            //REVIST: below variable gets assigned to 1 if alignment character exist in current frame
            prev_frame_align_char_exist <= 1'b0;
            prev_frame_align_char_exist_lesser_F <= 4'h0;

            // Character Replacement, need to add enable/disable
            // Revisit: Please confirm below logic
            //if (((dskew_frame_data[07:00] == `ALIGNMENT_CHARCTER_F) || (dskew_frame_data[07:00] == `ALIGNMENT_CHARCTER_A)) && (dskew_frame_data_k[0])) begin
            if ((dskew_frame_data_k[0]) & (alignment_err_0 == 4'h0)) begin
               // 
               // For F less than 4, need special checking since single DW itself holds more than one frame
               if ((TXRX_F_REG == 1) || (TXRX_F_REG == 2) || (TXRX_F_REG == 3)) begin
                  //If no alignment error, then need to replace alignment character as per last octet
                  //if (alignment_err_0 == 4'h0) begin
                     // If align_a_char_replace_en is disabled, we will not get /A/ character, else it will treat as error
                     // If scrambler is disabled, need to replace character with prev_frame_last_octer
                     if (scr_dis) begin
                        curr_frame_last_dw[7:0] <= prev_frame_last_octet;
                     end else begin
                        // If scrambler is enabled, need to replace alignment character with constant value
                        if (dskew_frame_data[7:0] == `ALIGNMENT_CHARCTER_F) begin
                           curr_frame_last_dw[7:0] <= `ALIGNMENT_CHARCTER_F;
                        end else begin
                           curr_frame_last_dw[7:0] <= `ALIGNMENT_CHARCTER_A;
                        end
                     end
                     prev_frame_align_char_exist_lesser_F[0] <= 1;
                  //end // if (alignment_err_0 == 4'h0)
               end else begin // if ((TXRX_F_REG == 1) || (TXRX_F_REG == 2) || (TXRX_F_REG == 3))
                  //if (alignment_err_0 == 4'h0) begin
                     if (scr_dis) begin
                        curr_frame_last_dw[7:0] <= prev_frame_last_octet;
                     end else begin
                        if (dskew_frame_data[7:0] == `ALIGNMENT_CHARCTER_F) begin
                           curr_frame_last_dw[7:0] <= `ALIGNMENT_CHARCTER_F;
                        end else begin
                           curr_frame_last_dw[7:0] <= `ALIGNMENT_CHARCTER_A;
                        end
                     end
                     prev_frame_align_char_exist <= 1'b1;
                  //end // if (alignment_err_0 == 4'h0)
               end // else: !if((TXRX_F_REG == 1) || (TXRX_F_REG == 2) || (TXRX_F_REG == 3))
            end // if (dskew_frame_data_k[0])
            
            //if (((dskew_frame_data[15:8] == `ALIGNMENT_CHARCTER_F) || (dskew_frame_data[15:8] == `ALIGNMENT_CHARCTER_A)) && (dskew_frame_data_k[1])) begin
            if ((dskew_frame_data_k[1]) & (alignment_err_1 == 4'h0)) begin
               //check whether alignment character is expected at this location
               //if (TXRX_F_REG == 1) begin
               case (TXRX_F_REG)
                 1: begin // if (TXRX_F_REG == 1) begin
                  //if (alignment_err_1 == 0) begin
                     if (scr_dis) begin
                        if (dskew_frame_data[07:00]==`ALIGNMENT_CHARCTER_F && dskew_frame_data_k[0] && dskew_frame_data[15:08]==`ALIGNMENT_CHARCTER_A)
                          curr_frame_last_dw[15:08] <= prev_frame_last_octet;
                        else
                          curr_frame_last_dw[15:08] <= dskew_frame_data[07:00];
                     end else begin
                        if (dskew_frame_data[15:08] == `ALIGNMENT_CHARCTER_F) begin
                           curr_frame_last_dw[15:08] <= `ALIGNMENT_CHARCTER_F;
                        end else begin
                           curr_frame_last_dw[15:08] <= `ALIGNMENT_CHARCTER_A;
                        end
                     end
                     prev_frame_align_char_exist_lesser_F[1] <= 1;
                  //end // if (alignment_err_1 == 0)
                 end // case: 1
                 2, 3: begin // end else if ((TXRX_F_REG == 2) || (TXRX_F_REG == 3)) begin // if (TXRX_F_REG == 1)
                  //if (alignment_err_1 == 0) begin
                     if (scr_dis) begin
                        curr_frame_last_dw[15:08] <= prev_frame_last_octet;
                     end else begin
                        if (dskew_frame_data[15:08] == `ALIGNMENT_CHARCTER_F) begin
                           curr_frame_last_dw[15:08] <= `ALIGNMENT_CHARCTER_F;
                        end else begin
                           curr_frame_last_dw[15:08] <= `ALIGNMENT_CHARCTER_A;
                        end
                     end
                     prev_frame_align_char_exist_lesser_F[1] <= 1;
                  //end // if (alignment_err_1 == 0)
                 end // case: 2, 3
                 default: begin // end else begin // if ((TXRX_F_REG == 2) || (TXRX_F_REG == 3))
                  
                  //if (alignment_err_1 == 0) begin
                     if (scr_dis) begin
                        curr_frame_last_dw[15:8] <= prev_frame_last_octet;
                     end else begin
                        if (dskew_frame_data[15:08] == `ALIGNMENT_CHARCTER_F) begin
                           curr_frame_last_dw[15:08] <= `ALIGNMENT_CHARCTER_F;
                        end else begin
                           curr_frame_last_dw[15:08] <= `ALIGNMENT_CHARCTER_A;
                        end
                     end
                     prev_frame_align_char_exist <= 1'b1;
                  //end // if (alignment_err_1 == 0)
                 end // case: default
               endcase // case (TXRX_F_REG)
            end // if ((dskew_frame_data_k[1]) & (alignment_err_1 == 0))
            

            if ((dskew_frame_data_k[2]) & (alignment_err_2 == 4'h0)) begin
               //check whether alignment character is expected at this location
               //ToDo: For F=2, need to check location [7:0] whether it contains alignment character
               //               and if current location has alignment character then it is issue
               if ((TXRX_F_REG == 1) || (TXRX_F_REG == 2) || (TXRX_F_REG == 3))begin
                  //if (alignment_err_2 == 0) begin
                     if (scr_dis) begin
                        if (TXRX_F_REG == 1) begin
                          if (dskew_frame_data[15:08]==`ALIGNMENT_CHARCTER_F && dskew_frame_data_k[1] && dskew_frame_data[23:16]==`ALIGNMENT_CHARCTER_A)
                            curr_frame_last_dw[23:16] <= dskew_frame_data[07:00];
                          else
                            curr_frame_last_dw[23:16] <= dskew_frame_data[15:08];
                        end else if (TXRX_F_REG == 2) begin
                          if (dskew_frame_data[07:00]==`ALIGNMENT_CHARCTER_F && dskew_frame_data_k[0] && dskew_frame_data[23:16]==`ALIGNMENT_CHARCTER_A)
                            curr_frame_last_dw[23:16] <= prev_frame_last_octet;
                          else                        
                            curr_frame_last_dw[23:16] <= dskew_frame_data[07:00];
                        end else begin
                           curr_frame_last_dw[23:16] <= prev_frame_last_octet;
                        end
                     end else begin
                        if (dskew_frame_data[23:16] == `ALIGNMENT_CHARCTER_F) begin
                           curr_frame_last_dw[23:16] <= `ALIGNMENT_CHARCTER_F;
                        end else begin
                           curr_frame_last_dw[23:16] <= `ALIGNMENT_CHARCTER_A;
                        end
                     end // else: !if(scr_dis)
                     prev_frame_align_char_exist_lesser_F[2] <= 1;
                  //end // if (alignment_err_2 == 0)
                  
               end else begin // if ((TXRX_F_REG == 1) || (TXRX_F_REG == 2) || (TXRX_F_REG == 3))
                  //if (alignment_err_2 == 0) begin
                     if (scr_dis) begin
                        curr_frame_last_dw[23:16] <= prev_frame_last_octet;
                     end else begin
                        if (dskew_frame_data[23:16] == `ALIGNMENT_CHARCTER_F) begin
                           curr_frame_last_dw[23:16] <= `ALIGNMENT_CHARCTER_F;
                        end else begin
                           curr_frame_last_dw[23:16] <= `ALIGNMENT_CHARCTER_A;
                        end
                     end
                     prev_frame_align_char_exist <= 1'b1;
                  //end // if (alignment_err_2 == 0)
               end // else: !if((TXRX_F_REG == 1) || (TXRX_F_REG == 2) || (TXRX_F_REG == 3))
            end // if (dskew_frame_data_k[2])
            
            //if (dskew_frame_data_k[3]) begin
            if ((dskew_frame_data_k[3]) & (alignment_err_3 == 4'h0)) begin
               //check whether alignment character is expected at this location
               //ToDo: For F=2, need to check location [15:8] whether it contains alignment character
               //               and if current location has alignment character then it is issue
               //ToDo: For F=3, need to check location [23:16] whether it contains alignment character
               //               and if current location has alignment character then it is issue
               
               //if (alignment_err_3 == 0) begin
                  if (scr_dis) begin
                     case (TXRX_F_REG)
                       1: begin // if (TXRX_F_REG == 1) begin
                        // For F=1, last octet present incurrent DW
                          if (dskew_frame_data[23:16]==`ALIGNMENT_CHARCTER_F && dskew_frame_data_k[2] && dskew_frame_data[31:24]==`ALIGNMENT_CHARCTER_A)
                            curr_frame_last_dw[31:24] <= dskew_frame_data[15:08];
                          else                        
                            curr_frame_last_dw[31:24] <= dskew_frame_data[23:16];
                       end
                       2: begin // end else if (TXRX_F_REG == 2) begin
                          if (dskew_frame_data[15:08]==`ALIGNMENT_CHARCTER_F && dskew_frame_data_k[1] && dskew_frame_data[31:24]==`ALIGNMENT_CHARCTER_A)
                            curr_frame_last_dw[31:24] <= prev_frame_last_octet;
                          else                        
                            curr_frame_last_dw[31:24] <= dskew_frame_data[15:8];
                       end
                       3: begin // end else if (TXRX_F_REG == 3) begin
                          if (dskew_frame_data[07:00]==`ALIGNMENT_CHARCTER_F && dskew_frame_data_k[0] && dskew_frame_data[31:24]==`ALIGNMENT_CHARCTER_A)
                            curr_frame_last_dw[31:24] <= prev_frame_last_octet;
                          else                                               
                        curr_frame_last_dw[31:24] <= dskew_frame_data[7:0];
                       end
                       default : begin // end else begin
                        curr_frame_last_dw[31:24] <= prev_frame_last_octet;
                       end
                     endcase // case (TXRX_F_REG)
                  end else begin // if (scr_dis)
                     if (dskew_frame_data[31:24] == `ALIGNMENT_CHARCTER_F) begin
                        curr_frame_last_dw[31:24] <= `ALIGNMENT_CHARCTER_F;
                     end else begin
                        curr_frame_last_dw[31:24] <= `ALIGNMENT_CHARCTER_A;
                     end
                  end
                  prev_frame_align_char_exist_lesser_F[3] <= 1;
                  prev_frame_align_char_exist <= 1'b1;
                  
               //end // if (alignment_err_3 == 0)
            end // if (dskew_frame_data_k[3])
         end // if (last_octet_in_curr_dw == 1 & dskew_frame_data_vld_local)
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)
   

   // b. if alignment character receives on frame boundary, check it is received on last octet (use last_octet_location)
   // c. if alignment character receives on last octet of frame boundary, check value of prev_frame_align_char_exist
   //       if prev_frame_align_char_exist == 0 and current frame is end of multi frame boundary (last_multi_frame_octet_in_curr_dw), alignment character must be /A/
   //       if prev_frame_align_char_exist == 0 and current frame is not end of multi frame boundary, alignment character must be /F/
   //       if prev_frame_align_char_exist == 1 and current frame is end of multi frame boundary, alignment character must be /A/
   //       if prev_frame_align_char_exist == 1 and current frame is not end of multi frame boundary, it is an error unless the scrambler is enabled
   //function automatic [3:0] chk_alignment_correctness(input reg[3:0] location, input reg [7:0] dskew_frame_data);
   // Taken global variable as input due to modelsim issue, not able to detect global vairable correctly
   function automatic [3:0] chk_alignment_correctness(input reg[3:0] location, input reg[3:0] last_octet_location, input last_multi_frame_octet_in_curr_dw, input align_a_char_replace_en, input prev_frame_align_char_exist, input reg [7:0] dskew_frame_data, input reg single_frame_received,  input scr_dis);
        if (dskew_frame_data == `ALIGNMENT_CHARCTER_F) begin
           //if ((location == last_octet_location) && (last_multi_frame_octet_in_curr_dw == 0) && (prev_frame_align_char_exist == 0) && (single_frame_received == 1))
           if ((location == last_octet_location) && (!(last_multi_frame_octet_in_curr_dw & align_a_char_replace_en)) && ((prev_frame_align_char_exist == 0) || (scr_dis==0)) && (single_frame_received == 1))
             chk_alignment_correctness = 4'h0;
           else
             chk_alignment_correctness = 4'b0001;//alignment_f_error
        end else if (dskew_frame_data == `ALIGNMENT_CHARCTER_A) begin
           //if (align_a_char_error_reporting_en) begin
           if (align_a_char_replace_en) begin
              // It means alignment character A is received
              if ((location == last_octet_location) && (last_multi_frame_octet_in_curr_dw == 1) && (single_frame_received == 1))
                chk_alignment_correctness = 4'h0;
              else
                chk_alignment_correctness = 4'b0010; //alignment_a_error
           end else begin
              chk_alignment_correctness = 4'b0010;
           end
        end else if (dskew_frame_data == `ALIGNMENT_DECODE_ERR) begin
             chk_alignment_correctness = 4'b0100; // Decode Error
        end else begin
             chk_alignment_correctness = 4'b1000; //Unexpected K character Error
        end
   endfunction // chk_alignment_correctness

   //function automatic [3:0] chk_alignment_correctness_special(input reg[3:0] location, input reg [7:0] dskew_frame_data, input reg dskew_prev_k, input reg [7:0] dskew_last_frame_octet_data);
   // Taken global variable as input due to modelsim issue, not able to detect global vairable correctly
   function [3:0] chk_alignment_correctness_special(input reg[3:0] location, input reg[3:0] last_octet_location_lesser_F, input reg[3:0] last_multi_frame_octet_location, input align_a_char_replace_en, input reg [3:0] single_frame_received_lesser_F, input reg [7:0] dskew_frame_data, input reg dskew_prev_k, input reg [7:0] dskew_last_frame_octet_data, input scr_dis);
        if (dskew_frame_data == `ALIGNMENT_CHARCTER_F) begin
           if (dskew_prev_k) begin
              if ((last_octet_location_lesser_F[location]) && (!(last_multi_frame_octet_location[location] & align_a_char_replace_en)) && (dskew_last_frame_octet_data != `ALIGNMENT_CHARCTER_F || (scr_dis==0)) && (dskew_last_frame_octet_data != `ALIGNMENT_CHARCTER_A) && (single_frame_received_lesser_F[location])) begin
                 chk_alignment_correctness_special = 4'h0;
              end else begin
                 chk_alignment_correctness_special = 4'b0001;//alignment_f_error
              end
           end else begin
              if ((last_octet_location_lesser_F[location]) && (!(last_multi_frame_octet_location[location] & align_a_char_replace_en))) begin
                 chk_alignment_correctness_special = 4'h0;
              end else begin
                 chk_alignment_correctness_special = 4'b0001;//alignment_f_error
              end
           end // else: !if(dskew_prev_k)
        end else if (dskew_frame_data == `ALIGNMENT_CHARCTER_A) begin // if (dskew_frame_data == `ALIGNMENT_CHARCTER_F)
           if (align_a_char_replace_en) begin
              // It means alignment character A is received
              if ((last_multi_frame_octet_location[location]) && (single_frame_received_lesser_F[location]))
                chk_alignment_correctness_special = 4'h0;
              else
                chk_alignment_correctness_special = 4'b0010; //alignment_a_error
           end else begin
              chk_alignment_correctness_special = 4'b0010;
           end
        end else if (dskew_frame_data == `ALIGNMENT_DECODE_ERR) begin
             chk_alignment_correctness_special = 4'b0100; // Decode Error
        end else begin
             chk_alignment_correctness_special = 4'b1000; //Unexpected K character Error
        end
   endfunction // chk_alignment_correctness_special

   // We can have single bit instead of per Octet
   reg [3:0] alignment_f_received_before_frame_ends, alignment_a_received_before_frame_ends;
   reg [3:0] alignment_decode_err_received_before_frame_ends, alignment_unexp_k_char_received_before_frame_ends;

  //always @(posedge clk_character or posedge rst_clk_character)
   always @* begin
       //if (dskew_frame_data_vld_local & (last_octet_in_curr_dw == 0)) begin
          //ToDo: For F less than 3, last_octet_in_curr_dw is always 1, so below cases would not get checked
          //      Need to have seperate logic
       alignment_f_received_before_frame_ends = 4'h0;
       alignment_a_received_before_frame_ends = 4'h0;
       alignment_decode_err_received_before_frame_ends   = 4'h0;
       alignment_unexp_k_char_received_before_frame_ends = 4'h0;
       
       if (dskew_frame_data_vld_local) begin
          if (TXRX_F_REG > 3) begin
             if (last_octet_in_curr_dw == 0) begin
                if (dskew_frame_data_k[0] & !(ilas_data_valid[0])) begin
                    if (dskew_frame_data[07:00] == `ALIGNMENT_CHARCTER_F) begin
                       alignment_f_received_before_frame_ends[0] = 1;
                    end else if (dskew_frame_data[07:00] == `ALIGNMENT_CHARCTER_A) begin
                       alignment_a_received_before_frame_ends[0] = 1;
                    end else if (dskew_frame_data[07:00] == `ALIGNMENT_DECODE_ERR) begin
                       alignment_decode_err_received_before_frame_ends[0] = 1;
                    end else begin
                       alignment_unexp_k_char_received_before_frame_ends[0] = 1;
                    end
                end // if (dskew_frame_data_k[0])
                
                if (dskew_frame_data_k[1] & !(ilas_data_valid[1])) begin
                    if (dskew_frame_data[15:08] == `ALIGNMENT_CHARCTER_F) begin
                       alignment_f_received_before_frame_ends[1] = 1;
                    end else if (dskew_frame_data[15:08] == `ALIGNMENT_CHARCTER_A) begin
                       alignment_a_received_before_frame_ends[1] = 1;
                    end else if (dskew_frame_data[15:08] == `ALIGNMENT_DECODE_ERR) begin
                       alignment_decode_err_received_before_frame_ends[1] = 1;
                    end else begin
                       alignment_unexp_k_char_received_before_frame_ends[1] = 1;
                    end
                end // if (dskew_frame_data_k[1])
                
                if (dskew_frame_data_k[2] & !(ilas_data_valid[2])) begin
                    if (dskew_frame_data[23:16] == `ALIGNMENT_CHARCTER_F) begin
                       alignment_f_received_before_frame_ends[2] = 1;
                    end else if (dskew_frame_data[23:16] == `ALIGNMENT_CHARCTER_A) begin
                       alignment_a_received_before_frame_ends[2] = 1;
                    end else if (dskew_frame_data[23:16] == `ALIGNMENT_DECODE_ERR) begin
                       alignment_decode_err_received_before_frame_ends[2] = 1;
                    end else begin
                       alignment_unexp_k_char_received_before_frame_ends[2] = 1;
                    end
                end // if (dskew_frame_data_k[2])
                
                if (dskew_frame_data_k[3] & !(ilas_data_valid[3])) begin
                    if (dskew_frame_data[31:24] == `ALIGNMENT_CHARCTER_F) begin
                       alignment_f_received_before_frame_ends[3] = 1;
                    end else if (dskew_frame_data[31:24] == `ALIGNMENT_CHARCTER_A) begin
                       alignment_a_received_before_frame_ends[3] = 1;
                    end else if (dskew_frame_data[31:24] == `ALIGNMENT_DECODE_ERR) begin
                       alignment_decode_err_received_before_frame_ends[3] = 1;
                    end else begin
                       alignment_unexp_k_char_received_before_frame_ends[3] = 1;
                    end
                end // if (dskew_frame_data_k[3])

             end // if (last_octet_in_curr_dw == 0)
             
          end else begin // if (TXRX_F_REG > 3)
             if (last_octet_location_lesser_F[0] == 0) begin
                if (dskew_frame_data_k[0] & !ilas_data_valid[0]) begin
                    if (dskew_frame_data[07:00] == `ALIGNMENT_CHARCTER_F) begin
                       alignment_f_received_before_frame_ends[0] = 1;
                    end else if (dskew_frame_data[07:00] == `ALIGNMENT_CHARCTER_A) begin
                       alignment_a_received_before_frame_ends[0] = 1;
                    end else if (dskew_frame_data[07:00] == `ALIGNMENT_DECODE_ERR) begin
                       alignment_decode_err_received_before_frame_ends[0] = 1;
                    end else begin
                       alignment_unexp_k_char_received_before_frame_ends[0] = 0;
                    end
                end // if (dskew_frame_data_k[0])
             end // if (last_octet_location_lesser_F[0] == 0)

             if (last_octet_location_lesser_F[1] == 0) begin
                if (dskew_frame_data_k[1] & !ilas_data_valid[1]) begin
                    if (dskew_frame_data[15:08] == `ALIGNMENT_CHARCTER_F) begin
                       alignment_f_received_before_frame_ends[1] = 1;
                    end else if (dskew_frame_data[15:08] == `ALIGNMENT_CHARCTER_A) begin
                       alignment_a_received_before_frame_ends[1] = 1;
                    end else if (dskew_frame_data[15:08] == `ALIGNMENT_DECODE_ERR) begin
                       alignment_decode_err_received_before_frame_ends[1] = 1;
                    end else begin
                       alignment_unexp_k_char_received_before_frame_ends[1] = 0;
                    end
                end // if (dskew_frame_data_k[1])
                
             end // if (last_octet_location_lesser_F[1] == 0)

             if (last_octet_location_lesser_F[2] == 0) begin
                if (dskew_frame_data_k[2] & !ilas_data_valid[2]) begin
                    if (dskew_frame_data[23:16] == `ALIGNMENT_CHARCTER_F) begin
                       alignment_f_received_before_frame_ends[2] = 1;
                    end else if (dskew_frame_data[23:16] == `ALIGNMENT_CHARCTER_A) begin
                       alignment_a_received_before_frame_ends[2] = 1;
                    end else if (dskew_frame_data[23:16] == `ALIGNMENT_DECODE_ERR) begin
                       alignment_decode_err_received_before_frame_ends[2] = 1;
                    end else begin
                       alignment_unexp_k_char_received_before_frame_ends[2] = 0;
                    end
                end // if (dskew_frame_data_k[2])
             end // if (last_octet_location_lesser_F[2] == 0)

             if (last_octet_location_lesser_F[3] == 0) begin
                if (dskew_frame_data_k[3] & !ilas_data_valid[3]) begin
                    if (dskew_frame_data[31:24] == `ALIGNMENT_CHARCTER_F) begin
                       alignment_f_received_before_frame_ends[3] = 1;
                    end else if (dskew_frame_data[31:24] == `ALIGNMENT_CHARCTER_A) begin
                       alignment_a_received_before_frame_ends[3] = 1;
                    end else if (dskew_frame_data[31:24] == `ALIGNMENT_DECODE_ERR) begin
                       alignment_decode_err_received_before_frame_ends[3] = 1;
                    end else begin
                       alignment_unexp_k_char_received_before_frame_ends[3] = 0;
                    end
                end // if (dskew_frame_data_k[3])
             end // if (last_octet_location_lesser_F[3] == 0)
          end // else: !if(TXRX_F_REG > 3)
       end // if (dskew_frame_data_vld_local)
       
   end // always @ *
   
   
   //Error Reporting logic
   // Increment counter if frame error is received at the unexpected position
   reg [3:0] frame_error_count_at_unexpected_position;
   
   // wire frame_alignment_err_0 = alignment_err_0[0] | alignment_f_received_before_frame_ends[0];
   // wire frame_alignment_err_1 = alignment_err_1[0] | alignment_f_received_before_frame_ends[1];
   // wire frame_alignment_err_2 = alignment_err_2[0] | alignment_f_received_before_frame_ends[2];
   // wire frame_alignment_err_3 = alignment_err_3[0] | alignment_f_received_before_frame_ends[3];

   wire frame_alignment_err_0 = alignment_err_0[0];
   wire frame_alignment_err_1 = alignment_err_1[0];
   wire frame_alignment_err_2 = alignment_err_2[0];
   wire frame_alignment_err_3 = alignment_err_3[0];

   wire frame_alignment_received_at_unexpected_position = (alignment_f_received_before_frame_ends[0] | alignment_f_received_before_frame_ends[1] | alignment_f_received_before_frame_ends[2] | alignment_f_received_before_frame_ends[3]);
   wire frame_alignment_repeated_received_at_unexpected_position = (frame_error_count_at_unexpected_position == `FRAME_ERROR_THRESHOLD) ? 1'b1: 1'b0;

   wire frame_alignment_err_all = frame_alignment_err_0 | frame_alignment_err_1 | frame_alignment_err_2 | frame_alignment_err_3 | frame_alignment_repeated_received_at_unexpected_position;

   wire mframe_alignment_err_0 = alignment_err_0[1] | alignment_a_received_before_frame_ends[0];
   wire mframe_alignment_err_1 = alignment_err_1[1] | alignment_a_received_before_frame_ends[1];
   wire mframe_alignment_err_2 = alignment_err_2[1] | alignment_a_received_before_frame_ends[2];
   wire mframe_alignment_err_3 = alignment_err_3[1] | alignment_a_received_before_frame_ends[3];

   wire mframe_alignment_err_chk = mframe_alignment_err_0 | mframe_alignment_err_1 | mframe_alignment_err_2 | mframe_alignment_err_3;
   wire mframe_alignment_err_all = align_a_char_error_reporting_en ? mframe_alignment_err_chk : 1'b0;


   wire decode_err_0 = alignment_err_0[2] | alignment_decode_err_received_before_frame_ends[0];
   wire decode_err_1 = alignment_err_1[2] | alignment_decode_err_received_before_frame_ends[1];
   wire decode_err_2 = alignment_err_2[2] | alignment_decode_err_received_before_frame_ends[2];
   wire decode_err_3 = alignment_err_3[2] | alignment_decode_err_received_before_frame_ends[3];

   wire unexp_k_err_0 = alignment_err_0[3] | alignment_unexp_k_char_received_before_frame_ends[0];
   wire unexp_k_err_1 = alignment_err_1[3] | alignment_unexp_k_char_received_before_frame_ends[1];
   wire unexp_k_err_2 = alignment_err_2[3] | alignment_unexp_k_char_received_before_frame_ends[2];
   wire unexp_k_err_3 = alignment_err_3[3] | alignment_unexp_k_char_received_before_frame_ends[3];

   
   always @ (posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         frame_alignment_err  <= 1'b0;
         mframe_alignment_err <= 1'b0;
         decode_err           <= 4'h0;
         unexpected_k_err     <= 4'h0;
         frame_error_count_at_unexpected_position  <= 4'h0;
      end else begin
         frame_alignment_err  <= frame_alignment_err_all;
         mframe_alignment_err <= mframe_alignment_err_all;
         decode_err[0]        <= decode_err_0;
         decode_err[1]        <= decode_err_1;
         decode_err[2]        <= decode_err_2;
         decode_err[3]        <= decode_err_3;

         unexpected_k_err[0]  <= unexp_k_err_0;
         unexpected_k_err[1]  <= unexp_k_err_1;
         unexpected_k_err[2]  <= unexp_k_err_2;
         unexpected_k_err[3]  <= unexp_k_err_3;

         if (frame_error_count_at_unexpected_position >= `FRAME_ERROR_THRESHOLD) begin
            frame_error_count_at_unexpected_position <= 4'h0;
         end else begin
            if (frame_alignment_received_at_unexpected_position) begin
                  frame_error_count_at_unexpected_position <= frame_error_count_at_unexpected_position + 1'b1;
            end
         end
      end // else: !if(rst_clk_character)
   end // always @ (posedge clk_character or posedge rst_clk_character)
   
   
endmodule // jesd_rx_align_mon_char_rep
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
