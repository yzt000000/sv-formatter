

// This file has definitions of modules jesd_sync_rst  and jesd_jesd204b_rst_gen. 
// These are shared between TX and RX cores .


// jesd_sync_rst  is used to transfer signals across 2 clock domains . If the source signal is combinational
// then one should set the parameter REG_IP=1 and also connect the src_clk pin to the source clock domain
// else REG_IP=0 and src_clk can be left floating.
module jesd_sync_rst
  #(parameter WIDTH=1,
    parameter REG_IP=1)
  (
   input [WIDTH-1:0]  src_signal,
   input              src_clk,
   input              rst,
   input              dest_clk, 
   output [WIDTH-1:0] dest_signal                     
   );

   reg [WIDTH-1:0] src_signal_r0,dest_signal_r0,dest_signal_r1;
   
   always @(posedge src_clk or posedge rst)
     if (rst)
       src_signal_r0 <= 1'b1;
     else
       src_signal_r0 <= src_signal;

   always @(posedge dest_clk or posedge rst) begin
     if (rst) begin
       dest_signal_r0 <= {WIDTH{1'b1}};
       dest_signal_r1 <= {WIDTH{1'b1}};
     end 
     else begin
       if (REG_IP)
         dest_signal_r0 <= src_signal_r0;
       else
         dest_signal_r0 <= src_signal;
       dest_signal_r1 <= dest_signal_r0;
     end
   end
   
   assign dest_signal = dest_signal_r1;   
endmodule // jesd_sync_rst 

// jesd_jesd204b_rst_gen is responsible for generating the reset to link layer of the design.
// The reset source of the reset is from clk_cpu domain (either reset_core or not of enable_module signal).
// The above 2 signals are used to generate rst_core in clk_cpu domain.
// This reset is then transferred into different clock_domains using
// jesd_sync_rst  module 
// The reset duration is internally stretched by 16 cpu clocks which helps in ensuring that if enable_module is 
// set the values coming from register bits (clk_cpu domain) into clk_character/clk_serdes domain will be stable.
// at the point of reset de-assertion
  `define    TIMEOUT
module jesd_jesd204b_rst_gen
  #(parameter NO_LANES=1
  )
  (
   input [NO_LANES-1:0]  clk_serdes,
   input                 clk_character,
   input                 clk_sample,
   input                 clk_cpu,
   input                 reset_core,
   input                 enable_module,
   input                 test_mode,
   output                rst_clk_character,
   output                [NO_LANES-1:0] rst_clk_serdes,
   output                rst_clk_sample   
);

   reg                   enable_module_delayed;
   wire                  rst_core = reset_core | ((~enable_module | ~enable_module_delayed) & ~test_mode);
   wire                  reset_clk_character;
   wire [NO_LANES-1:0]   reset_clk_serdes;
   wire                  reset_clk_sample;
   
    reg time_is_over;
//  `ifdef    TIMEOUT
    reg [31:0] counter1, counter2;
    
    
    
    always @(posedge clk_character or posedge reset_core)
    begin
      if (reset_core)
      begin
        counter1<=64'h0;
        counter2<=64'h0;
        time_is_over<=1'h0;
      end
      else
      begin
        counter1<= counter1 +1'h1;
        if (counter1==32'hFFFF_FFFF)
        begin
          counter2<= counter2+1'h1;
          counter1<=1'h0;
        end
        if (counter2==31'hF)     
          time_is_over<=1'h1;
        else
          time_is_over<=time_is_over;
      end
    end 
//  `endif
    
/*   `ifndef    TIMEOUT
    always @(posedge clk_character or posedge reset_core)
    begin
      if (reset_core)
      begin
        time_is_over<=1'h0;     
      end
      else 
      begin
        time_is_over<=time_is_over;
      end
    end
  `endif */
   
   
   genvar ln_cnt;
   generate for (ln_cnt = 0; ln_cnt < NO_LANES; ln_cnt = ln_cnt + 1) begin : lane_generate

     jesd_sync_rst  sync_serdes (/*AUTOINST*/
                                  // Outputs
                                  .dest_signal    (reset_clk_serdes[ln_cnt]),
                                  // Inputs
                                  .src_signal     (1'b0),
                                  .src_clk        (clk_cpu),
                                  .rst            (rst_core),
                                  .dest_clk       (clk_serdes[ln_cnt]));

      assign  rst_clk_serdes[ln_cnt]  = (reset_clk_serdes[ln_cnt] & ~test_mode) | (reset_core & test_mode) | time_is_over;

   end endgenerate
                                
   jesd_sync_rst  sync_character (/*AUTOINST*/
                                   // Outputs
                                   .dest_signal         (reset_clk_character),
                                   // Inputs
                                   .src_signal          (1'b0),
                                   .src_clk             (clk_cpu),
                                   .rst                 (rst_core),
                                   .dest_clk            (clk_character));
   jesd_sync_rst  sync_sample (/*AUTOINST*/
                                // Outputs
                                .dest_signal    (reset_clk_sample),
                                // Inputs
                                .src_signal     (1'b0),
                                .src_clk        (clk_cpu),
                                .rst            (rst_core),
                                .dest_clk       (clk_sample));   
   reg [3:0] delay_counter;

   always @ (posedge clk_cpu or posedge reset_core) begin
      if (reset_core ) begin
         delay_counter <= 'h0;
         enable_module_delayed <= 1'b0;
      end
	  else if (~enable_module & ~test_mode) begin 
		delay_counter <= 'h0;
        enable_module_delayed <= 1'b0;
	  end
	  
      else if (enable_module_delayed == 1'b0) begin
         delay_counter <= delay_counter + 1'b1;
         enable_module_delayed <= (delay_counter == 'hF);         
      end
   end
    
   assign  rst_clk_character = (reset_clk_character & ~test_mode) | (reset_core & test_mode)| time_is_over;
   assign  rst_clk_sample    = (reset_clk_sample    & ~test_mode) | (reset_core & test_mode)| time_is_over;
   
endmodule // jesd_jesd204b_rst_gen
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
