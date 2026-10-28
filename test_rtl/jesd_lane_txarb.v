

// This module forms the final arbitration or muxing stage of following 4 Transmits streams jspot_or_custom_data, comma_data, ilas_data, user_frame_data.
// At any given clock only one of the following outputs will be high  jspat_or_custom_data_rdy,comma_data_rdy,ilas_data_rdy,unscr_data_rdy
// Since the point of switching over from one stream to other stream may not always align with  datapath (dword) boundary we  need to hold partial data and
// merge it with the next stream . This  operation  requires wait state insertion at input side. To avoid the wait state on input side from propogating to the output side
// we have a synchronous fifo as the ouput stage of the module . Post reset we fill this fifo and do not read anything until it reaches the almost full level.
// Once it reaches this threshold we start the read operation and the data initially buffered in the fifo prevents the input wait state (while switching streams)
// from propogating to output.


module jesd_lane_txarb
(
 input         clk_character,            //Primary clock
 input         rst_clk_character,        //Primary reset
 input         test_mode,                // test mode pin for bypassing generated resets in scan mode


 input [31:0]  jspat_or_custom_data,     // 4 octets of transmit data stream  carrying the jspat_or_custom_data test octets
 input [3:0]   jspat_or_custom_data_k,   // 1 bit corresponding to each octet of jspat_or_custom_data. Indication of whether the chracter is contol character or data
 input         jspat_or_custom_data_vld, // 1 bit control signal indicating valid information on jspat_or_custom_data_* inputs

 input [31:0]  comma_data,               // 4 octets of transmit data stream  carrying the CGS octets
 input [3:0]   comma_data_k,             // 1 bit corresponding to each octet of comma_data. Indication of whether the chracter is contol character or data
 input [1:0]   comma_data_bc,            // indcates number of octets on comma_data that should be packed into Tx data stream . 00 implies all 4 octets should be packed
 input         comma_data_vld,           // 1 bit control signal indicating valid information on comma_data_* inputs


 input [31:0]  ilas_data,               // 4 octets of transmit data stream  carrying the ILAS octets
 input [3:0]   ilas_data_k,             // 1 bit corresponding to each octet of ilas_data. Indication of whether the chracter is contol character or data
 input [1:0]   ilas_data_bc,            // indcates number of octets on ilas_data that should be packed into Tx data stream . 00 implies all 4 octets should be packed
 input         ilas_data_vld,           // 1 bit control signal indicating valid information on ilas_data_* inputs

 input [31:0]  process_data,            // 4 octets of transmit data stream  carrying the user_data test octets
 input [3:0]   process_data_k,          // 1 bit corresponding to each octet of user_data. Indication of whether the chracter is contol character or data
 input         process_data_vld,        // 1 bit control signal indicating valid information on user_data_* inputs

 output reg [31:0] txdata,             // Combined txdata stream
 output reg [3:0]  txdata_k,           // 1 bit corresponding to each octet of txdata. Indication of whether the chracter is contol character or data
 output reg    txdata_vld,             // 1 bit control signal indicating valid information on txdata_* outputs

 output        jspat_or_custom_data_rdy, // Handshake signal confirming that information on jspat_or_custom_data_*  signals has been consumed
 output        comma_data_rdy,           // Handshake signal confirming that information on comma_data_*  signals has been consumed
 output        ilas_data_rdy,            // Handshake signal confirming that information on ilas_data_*  signals has been consumed
 output reg    unscr_data_rdy            // Handshake signal that goes directly to transport layer input and is used to initally throttle the transport data
 );
   reg [31:0]      residue_data;
   reg [3:0]       residue_data_k;
   reg [1:0]       residue_bc;

   reg [31:0]      wrdata;
   reg [3:0]       wrdata_k;
   reg             wrdata_vld;
   reg             comma_data_vld_r;
   reg             always_vld;
   wire            rempty,afull;

   wire txdata_vld_next = txdata_vld  ? !rempty | always_vld : afull;
   wire [35:0] rdata;
   wire            fifo_flush = comma_data_vld & !comma_data_vld_r;
   wire            wfull;


   assign jspat_or_custom_data_rdy = jspat_or_custom_data_vld;
   assign comma_data_rdy = comma_data_vld & !jspat_or_custom_data_rdy;
   assign ilas_data_rdy  = ilas_data_vld & !comma_data_rdy;




always @(posedge clk_character or posedge rst_clk_character) begin
   if (rst_clk_character)
     comma_data_vld_r <= 1'b0;
   else
     comma_data_vld_r <= comma_data_vld;
end



always @(posedge clk_character or posedge rst_clk_character) begin
   if (rst_clk_character)
      unscr_data_rdy <= 1'b0;
   else if (jspat_or_custom_data_vld || comma_data_vld || ilas_data_vld)
     unscr_data_rdy <= 1'b0;
   else
     unscr_data_rdy <= txdata_vld_next;
end


wire [2:0] bc_add =  {1'b0, ilas_data_bc} + {1'b0, residue_bc};

always @(posedge clk_character or posedge rst_clk_character) begin
   if (rst_clk_character) begin
      residue_data <= 32'h0;
      residue_data_k <= 4'h0;
      residue_bc <= 2'b00;
      wrdata <= 32'h0;
      wrdata_k <= 4'h0;
      wrdata_vld <= 1'b0;
      always_vld <= 1'b0;
   end
   else begin
      if (!(process_data_vld | ilas_data_vld | comma_data_vld | jspat_or_custom_data_vld))
         always_vld <= 1'b1;
      wrdata_vld <= 1'b0;
      if (jspat_or_custom_data_vld) begin
         wrdata <= jspat_or_custom_data;
         wrdata_k <= jspat_or_custom_data_k;
         wrdata_vld <= 1'b1;
         residue_data <= 32'h0;
         residue_data_k <= 4'h0;
         residue_bc <= 'h0;
      end
      else if (comma_data_vld) begin
         always_vld <= 1'b0;
         residue_bc <= comma_data_bc;
         residue_data <= comma_data;
         residue_data_k <= comma_data_k;
         case (comma_data_bc)
           1,2,3:begin
               wrdata_vld <= 1'b0;
            end
            default:begin
               wrdata <= comma_data;
               wrdata_k <= comma_data_k;
               wrdata_vld <= 1'b1;
            end
         endcase // case (comma_data_bc)
      end
      else if (ilas_data_vld) begin
//         residue_bc <= (ilas_data_bc + residue_bc > 2'h3) ? ((ilas_data_bc + residue_bc) - 3'h4)
//                       : (ilas_data_bc + residue_bc);
         residue_bc <= bc_add[1:0];   // Equivalent to above
         case (ilas_data_bc)
           1:begin
              case (residue_bc)
                 1:begin
                    wrdata_vld <= 1'b0;
                    residue_data <= {ilas_data[7:0],residue_data[7:0]};
                    residue_data_k <= {ilas_data_k[0],residue_data_k[0]};
                 end
                 2:begin
                    wrdata_vld <= 1'b0;
                    residue_data <= {ilas_data[7:0],residue_data[15:0]};
                    residue_data_k <= {ilas_data_k[0],residue_data_k[1:0]};
                 end
                 3:begin
                    wrdata_vld <= 1'b1;
                    wrdata <= {ilas_data[7:0],residue_data[23:0]};
                    wrdata_k <= {ilas_data_k[0],residue_data_k[2:0]};
                 end
                 default:begin
                   wrdata_vld <= 1'b0;
                   residue_data <= ilas_data;
                   residue_data_k <= ilas_data_k;
                 end
               endcase // case (residue_bc)
           end
           2:begin
              case (residue_bc)
                 1:begin
                    wrdata_vld <= 1'b0;
                    residue_data <= {ilas_data[15:0],residue_data[7:0]};
                    residue_data_k <= {ilas_data_k[1:0],residue_data_k[0]};
                 end
                 2:begin
                    wrdata <= {ilas_data[15:0],residue_data[15:0]};
                    wrdata_k <= {ilas_data_k[1:0],residue_data_k[1:0]};
                    wrdata_vld <= 1'b1;
                 end
                 3:begin
                    wrdata <= {ilas_data[7:0],residue_data[23:0]};
                    wrdata_k <= {ilas_data_k[0],residue_data_k[2:0]};
                    wrdata_vld <= 1'b1;
                    residue_data <= ilas_data[15:08];
                    residue_data_k <= ilas_data_k[1];
                 end
                 default:begin
                   wrdata_vld <= 1'b0;
                   residue_data <= ilas_data;
                   residue_data_k <= ilas_data_k;
                 end
               endcase // case (residue_bc)
           end
           3:begin
              case (residue_bc)
                 1:begin
                    wrdata <= {ilas_data[23:0],residue_data[7:0]};
                    wrdata_k <= {ilas_data_k[2:0],residue_data_k[0]};
                    wrdata_vld <= 1'b1;
                 end
                 2:begin
                    wrdata <= {ilas_data[15:0],residue_data[15:0]};
                    wrdata_k <= {ilas_data_k[1:0],residue_data_k[1:0]};
                    wrdata_vld <= 1'b1;
                    residue_data <= ilas_data[23:16];
                    residue_data_k <= ilas_data_k[2];
                 end
                 3:begin
                    wrdata <= {ilas_data[7:0],residue_data[23:0]};
                    wrdata_k <= {ilas_data_k[0],residue_data_k[2:0]};
                    wrdata_vld <= 1'b1;
                    residue_data <= ilas_data[23:08];
                    residue_data_k <= ilas_data_k[2:1];
                 end
                 default:begin
                   wrdata_vld <= 1'b0;
                   residue_data <= ilas_data;
                   residue_data_k <= ilas_data_k;
                 end
               endcase // case (residue_bc)
           end // case: 3
           default:begin
              case (residue_bc)
                1:begin
                   wrdata <= {ilas_data[23:0],residue_data[7:0]};
                   wrdata_k <= {ilas_data_k[2:0],residue_data_k[0]};
                   wrdata_vld <= 1'b1;
                   residue_data <= ilas_data[31:24];
                   residue_data_k <= ilas_data_k[3];
                end
                2:begin
                   wrdata <= {ilas_data[15:0],residue_data[15:0]};
                   wrdata_k <= {ilas_data_k[1:0],residue_data_k[1:0]};
                   wrdata_vld <= 1'b1;
                   residue_data <= ilas_data[31:16];
                   residue_data_k <= ilas_data_k[3:2];
                end
                3:begin
                   wrdata <= {ilas_data[7:0],residue_data[23:0]};
                   wrdata_k <= {ilas_data_k[0],residue_data_k[2:0]};
                   wrdata_vld <= 1'b1;
                   residue_data <= ilas_data[31:08];
                   residue_data_k <= ilas_data_k[3:1];
                end
                default:begin
                   wrdata <= ilas_data;
                   wrdata_k <= ilas_data_k;
                   wrdata_vld <= 1'b1;
                end
              endcase // case (residue_bc)
           end // case: begin...
         endcase // case (ilas_data_bc)
      end
      else if (process_data_vld) begin
         always_vld <= 1'b1;
         case (residue_bc)
           1:begin
              wrdata <= {process_data[23:0],residue_data[7:0]};
              wrdata_k <= {process_data_k[2:0],residue_data_k[0]};
              wrdata_vld <= 1'b1;
              residue_data <= process_data[31:24];
              residue_data_k <= process_data_k[3];
           end
           2:begin
              wrdata <= {process_data[15:0],residue_data[15:0]};
              wrdata_k <= {process_data_k[1:0],residue_data_k[1:0]};
              wrdata_vld <= 1'b1;
              residue_data <= process_data[31:16];
              residue_data_k <= process_data_k[3:2];
           end
           3:begin
              wrdata <= {process_data[7:0],residue_data[23:0]};
              wrdata_k <= {process_data_k[0],residue_data_k[2:0]};
              wrdata_vld <= 1'b1;
              residue_data <= process_data[31:08];
              residue_data_k <= process_data_k[3:1];
           end
           default:begin
              wrdata <= process_data;
              wrdata_k <= process_data_k;
              wrdata_vld <= 1'b1;
           end
         endcase // case (residue_bc)
      end
   end // else: !if(rst_clk_character)
end // always @ (posedge clk_character or posedge rst_clk_character)


   always @(posedge clk_character or posedge rst_clk_character) begin
      if (rst_clk_character) begin
         txdata_vld <= 1'b0;
         txdata <= 'h0;
         txdata_k <= 'h0;
      end
      else begin
         txdata_vld <=  txdata_vld_next;
         {txdata_k,txdata} <= rdata;
      end
   end




   jesd_sync_fifo #(
                   // Parameters
                   .DSIZE               (36),
                   .ASIZE               (3),
                   .AFULL_TH (2'h2))
   jesd_sync_fifo (/*AUTOINST*/
                  // Outputs
                  .rdata                (rdata),
                  .wfull                (wfull),
                  .rempty               (rempty),
                  .afull          (afull),
                  // Inputs
                  .wdata                ({wrdata_k,wrdata}),
                  .winc                 (wrdata_vld),
                  .rinc                 (txdata_vld_next),
                  .flush                (fifo_flush),
                  .clk                  (clk_character),
                  .rst                  (rst_clk_character));




endmodule // jesd_lane_txarb

//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
