

// This module is responsible for continous transmission of the 50 octet JSPAT test pattern or custom link test data
// The assumption is that using jspat_addr_offset as the select line, on every clock 4 characters can be read from common
// storage holding the 50 octet JSPAT pattern. 
// Latency from jspat_addr_offset to jspat_data is assumed to be 1 clock and starting address offset for the stored pattern is 
// assumed to be 'h0.

module jesd_ctp_gen #(
   parameter CTP_BUF_ASIZE=4,
   parameter CTP_BUF_DSIZE=36   
)
  (
   input                          clk_character,          // Primary clock
   input                          rst_clk_character,      // Primary reset 
   input                          custom_test_enable,     // enable link test to transmit custom data
   input [15:0]                   custom_test_data,       // custom link data from regiter module
   input [CTP_BUF_DSIZE-1:0]      jspat_data,             // data read from the rom
   output reg [CTP_BUF_ASIZE-1:0] jspat_addr_offset,      // pointer to pick a particular dword from the 50 octet JSPAT rom
   input [6:0]                    jspat_length_char,      // Min value 4 , Max 64 . 
   input                          jspat_enable,           // enable jspat pattern transmission 
   input                          prbs_test_enable_reg,   // enable prbs-15 pattern transmission
   input                          jspat_or_custom_data_rdy, // Handshake signal confirming that information on jspat_or_custom_data_* output signals has been transferred to next module
   output reg [31:0]              jspat_or_custom_data,    // 4 octets of transmit data stream  carrying the test pattern octets
   output reg [3:0]               jspat_or_custom_data_k,  // 1 bit corresponding to each octet of jspat_or_custom_data. Indication of whether the chracter is contol character or data 
   output [1:0]                   jspat_or_custom_data_bc, // indcates number of octets on jspat_or_custom_data that should be packed into Tx data stream . 00 implies all 4 octets should be packed
   output reg                     jspat_or_custom_data_vld // 1 bit control signal indicating valid information on jspat_or_custom_data_* outputs
   );
   reg                            addr_val,addr_val_r1,addr_val_r2;
   reg [3:0]                      residue_data_k;
   reg [31:0]                     residue_data;
   
   wire [31:0]                    prbs_data;
   wire [3:0]                     prbs_k;
   wire                           prbs_vld;
   
   assign jspat_or_custom_data_bc = 2'b00;
   wire [CTP_BUF_ASIZE-1:0] max_address_offset = (jspat_length_char[1:0] == 2'b00) ? jspat_length_char[6:2] - 1'b1 
                            : jspat_length_char[6:2];
   
   always @(posedge clk_character or posedge rst_clk_character)begin
      if (rst_clk_character) begin
         addr_val_r2 <= 1'b0;
         addr_val_r1 <= 1'b0;
         addr_val <= 1'b0;  
         jspat_addr_offset <= {CTP_BUF_ASIZE{1'b0}};  
      end
      else if (jspat_enable) begin
         addr_val_r2  <= addr_val_r1;         
         addr_val_r1  <= addr_val;
         addr_val <= 1'b1;
         if (addr_val == 1'b0) 
           jspat_addr_offset <= {CTP_BUF_ASIZE{1'b0}};
         else if ((jspat_or_custom_data_rdy & jspat_or_custom_data_vld) || (addr_val_r1))
           jspat_addr_offset <= (jspat_addr_offset == max_address_offset) ? {CTP_BUF_ASIZE{1'b0}} : jspat_addr_offset + 1'b1;
      end
      else begin
         addr_val_r1 <= 1'b0;
         addr_val <= 1'b0;
         jspat_addr_offset <= 'h0;  
      end
   end // always @ (posedge clk_character or posedge rst_clk_character)

   reg [6:0] remaining_length;
   reg [2:0] residue_bc;
   wire [2:0] residue_bc_next = (remaining_length > 4) ? residue_bc : remaining_length[2:0];
   
   always @(posedge clk_character or posedge rst_clk_character)begin
      if (rst_clk_character) begin
         jspat_or_custom_data <= 32'h0;
         jspat_or_custom_data_k <= 4'h0;
         jspat_or_custom_data_vld <= 1'b0;
         remaining_length <= 'h0;
         residue_bc <= 'h0;
         residue_data_k <= 'h0;
         residue_data <= 'h0;
      end
      else if (prbs_test_enable_reg) begin
         jspat_or_custom_data <= prbs_data;
         jspat_or_custom_data_k <= prbs_k;
         jspat_or_custom_data_vld <= 1'b1;  
       end
      else if (custom_test_enable) begin
         jspat_or_custom_data <= {custom_test_data,custom_test_data};
         jspat_or_custom_data_k <= 4'h0;
         jspat_or_custom_data_vld <= 1'b1;   
      end
      else if (addr_val_r1 & !addr_val_r2) begin
        {residue_data_k,residue_data} <= jspat_data;
         remaining_length <= jspat_length_char;
         residue_bc <= 'h4;// Assumption is test pattern length is atleast 4 octets
      end
      else if (addr_val_r2) begin
         if ((!jspat_or_custom_data_vld) || (jspat_or_custom_data_vld & jspat_or_custom_data_rdy)) begin
            residue_bc <= residue_bc_next;
            jspat_or_custom_data_vld <= 1'b1;            
            
            if (remaining_length > 3'h4) 
               remaining_length <= remaining_length - 7'h4;
            else
               remaining_length <=  (jspat_length_char - 7'h4) + {4'h0, remaining_length[2:0]};
            
            case (residue_bc_next[2:0])
              'h1:begin
                 jspat_or_custom_data <= {jspat_data[23:0],residue_data[7:0]};
                 jspat_or_custom_data_k <= {jspat_data[34:32],residue_data_k[0]};
                 residue_data[7:0] <= jspat_data[31:24];
                 residue_data_k[0] <= jspat_data[35];                 
              end
              'h2:begin
                 jspat_or_custom_data <= {jspat_data[15:0],residue_data[15:0]};
                 jspat_or_custom_data_k <= {jspat_data[33:32],residue_data_k[1:0]};
                 residue_data[15:0] <= jspat_data[31:16];
                 residue_data_k[1:0] <= jspat_data[35:34];   
              end
              'h3:begin
                 jspat_or_custom_data <= {jspat_data[7:0],residue_data[23:0]};
                 jspat_or_custom_data_k <= {jspat_data[32],residue_data_k[2:0]};
                 residue_data[23:0] <= jspat_data[31:08];
                 residue_data_k[2:0] <= jspat_data[35:33];   
              end
              4:begin
                 jspat_or_custom_data <= residue_data[31:0];
                 jspat_or_custom_data_k <= residue_data_k[3:0];
                 residue_data[31:0] <= jspat_data[31:0];
                 residue_data_k[3:0] <= jspat_data[35:32]; 
              end                
            endcase // case (residue_bc[2:0])
         end // if ((!jspat_or_custom_data_vld) || (jspat_or_custom_data_vld & jspat_or_custom_data_rdy))
      end // if (addr_val_r2)
      else begin
         jspat_or_custom_data <= 32'h0;
         jspat_or_custom_data_k <= 4'h0;
         jspat_or_custom_data_vld <= 1'b0;  
      end
   end // always @ (posedge clk_character or posedge rst_clk_character)
   
      jesd_prbs15_generator generator( 
                  .rst_clk_character    (rst_clk_character),
                  .prbs_test_enable_reg (prbs_test_enable_reg),
                  .clk_character        (clk_character),
 
                  .prbs_data            (prbs_data),
                  .prbs_k               (prbs_k),
                  .prbs_vld             (prbs_vld)
 );
      
   
endmodule // jesd_ctp_gen
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
