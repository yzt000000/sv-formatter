

module jesd_tx_frame_detector
  #(parameter NO_LANES=1,
  parameter RDY_TO_DATA_LATENCY = 0
   )
   (input                      clk_character,
   input                      rst_clk_character,
   input                      tframe_data_vld,
   input                      tframe_data_rdy,
   input [4:0]      num_k,                 // Used to align de-assertion of internal request to CGS state machine with multi frame boundary
   input [7:0]      txrx_f_reg,            // may need to cut latency of sysref(lh) detection when clk_frame is faster than clk_character

   output [3:0] start_of_frame,
   output [3:0] end_of_frame,
   output [3:0] start_of_multiframe
);
reg [3:0] lmfc_boundary;
reg [4:0] fcnt, kcnt_2;
reg [3:0] frame_boundary;
//wire [3:0] end_of_frame;
reg [3:0] start_of_frame_r;//,start_of_multiframe_r;
reg [3:0] next_start_of_frame_r;
reg [3:0] next_frame_boundary;
wire start_detected;
reg next_start_of_multiframe;
reg tframe_data_rdy_change_detector;
reg [3:0] latency;
reg tframe_data_vld_delayed;
wire[4:0] add_fb;// add_fb is the amount of frame boundaries that will happen in this clk_character clock.
wire [4:0] subs_fb; // subs_fb is the substraction of the number of frames left in the multiframe and the number of frames that are going to be substracted in this clk_character cycle
wire multiend_of_frame;
wire [3:0] end_of_multiframe;
wire [3:0] frame_counter_variable;



assign start_of_multiframe = (end_of_multiframe == 'h8)? 'h0: (end_of_multiframe != 'h0)? end_of_multiframe<<1:(next_start_of_multiframe || start_detected) ? 4'h1:4'h0; 
assign start_detected = RDY_TO_DATA_LATENCY==1? tframe_data_rdy ^ tframe_data_rdy_change_detector : latency=='h1;
assign start_of_frame = tframe_data_rdy? RDY_TO_DATA_LATENCY==2? start_of_frame_r: next_start_of_frame_r : 'h0;
assign end_of_frame = tframe_data_rdy? RDY_TO_DATA_LATENCY==2? frame_boundary : next_frame_boundary : 'h0;



wire tframe_data_vld_detected = tframe_data_vld_delayed ^ tframe_data_vld;
wire control_sign;
assign control_sign = tframe_data_vld_detected || tframe_data_rdy;



always @(posedge clk_character or posedge rst_clk_character)
begin
 if (rst_clk_character)
 begin
  tframe_data_vld_delayed<='h0;
 end
 else
 begin
  tframe_data_vld_delayed <= tframe_data_vld;
 end
end

always @(posedge clk_character or posedge rst_clk_character)
begin
 if (rst_clk_character)
 begin
  start_of_frame_r<='h0;
  frame_boundary <='h0;

 end
 else
 begin
  if (tframe_data_rdy)
  begin
   start_of_frame_r<=next_start_of_frame_r;
   frame_boundary<=next_frame_boundary;

  end
 end
end

always @(posedge clk_character or posedge rst_clk_character)
begin
 if(rst_clk_character)
 begin
  fcnt <= 'h0;
  next_start_of_frame_r<='h0;
  next_frame_boundary<='h0;
 end
 else 
 begin
  if (control_sign)
  begin
   if ((txrx_f_reg+1)>=3)// when F<4, we can know that there can be more than a frame boundary in every clk_character clock cycle.    
   begin
    case (fcnt)
     'h0:begin
        if ((txrx_f_reg+1)==3)
        begin
         next_frame_boundary<='h9;
         next_start_of_frame_r<= 'h2;//start_of_frame_r <='h9;
         fcnt <=  'h3;
        end
        else
        begin
         next_frame_boundary<='h0;
         next_start_of_frame_r<='h1;
         fcnt <= txrx_f_reg+1;
        end
      end  
     'h1:begin
      next_frame_boundary <= 'h1;
      next_start_of_frame_r <='h2;
      fcnt <= txrx_f_reg+1-'h3;
     end
     'h2:begin
      next_frame_boundary<='h2;
      next_start_of_frame_r <='h4;
      if ((txrx_f_reg+1)==3)
       fcnt <= 'h0 ;
      else
       fcnt <=  txrx_f_reg+1-'h2 ;
     end
     'h3:begin
      next_frame_boundary <='h4;
      if ((txrx_f_reg+1)==3)
       next_start_of_frame_r<='h9;
      else
       next_start_of_frame_r<='h8;
      fcnt <= txrx_f_reg+1-'h1 ;
     end
     'h4:begin
      next_frame_boundary <='h8;
      if ((txrx_f_reg+1)==4)
       next_start_of_frame_r<='h1;
      else
       next_start_of_frame_r<='h0;
      fcnt <=  txrx_f_reg+1 ;
     end   
     default:begin
      next_frame_boundary <='h0;
      next_start_of_frame_r<= (fcnt == (txrx_f_reg+1))? 'h1 :'h0;
      fcnt <=  fcnt - 4 ;
     end
    endcase
   end
   else
   begin
    if ((txrx_f_reg+1)==1)
    begin
     next_frame_boundary<='hF;
     next_start_of_frame_r<='hf;
     fcnt <=  0 ;
    end
    else if ((txrx_f_reg+1)==2)
    begin
     next_frame_boundary<='ha;
     next_start_of_frame_r<='h5;
     fcnt <= 0 ;
    end
   end
  end
  else
    fcnt <= txrx_f_reg+1;
 end
end


assign add_fb = (end_of_frame[0]?1'h1:1'h0) + (end_of_frame[1]?1'h1:1'h0) + (end_of_frame[2]?1'h1:1'h0) + (end_of_frame[3]?1'h1:1'h0);
assign frame_counter_variable = (kcnt_2== 4'h1)? end_of_frame[0]?4'h1:(end_of_frame[1]? 4'h2: 4'h0) : (kcnt_2== 4'h2 ? 4'h2: (kcnt_2==4'h3 ? 4'h4 : 4'h1));
assign subs_fb = kcnt_2 - add_fb;
assign multiend_of_frame = (add_fb<=1)? 1'h1:1'h0;
assign end_of_multiframe = (end_of_frame[0] || end_of_frame[1]||end_of_frame[2] || end_of_frame[3])?  kcnt_2>=add_fb?  subs_fb==0? multiend_of_frame? end_of_frame: end_of_frame[3] ? 'h8 : end_of_frame[2] ? 'h4 : 'h0 :'h0: multiend_of_frame?end_of_frame:frame_counter_variable:'h0;
//assign end_of_multiframe = (end_of_frame? ((kcnt_2<=add_fb)?  (subs_fb==0? (multiend_of_frame? end_of_frame: (end_of_frame[3]? 'h8 :(end_of_frame[2] ? 'h4:'h0) :'h0):'h0): (multiend_of_frame?end_of_frame:frame_counter_variable)): 'h0) :'h0);


always @(posedge clk_character or posedge rst_clk_character)// in every frame boundary it detects if there has been a lmfc_boundary depending on how many frame boundaries there are in a clock cycle. 
begin
 if(rst_clk_character)
 begin
  kcnt_2 <= 'h0;
  lmfc_boundary<='h0;
 end
 else
 begin
  if (control_sign)
   if(end_of_frame[0] || end_of_frame[1]||end_of_frame[2] || end_of_frame[3]) 
   begin
     if (kcnt_2>=add_fb)
     begin
      kcnt_2 <= (subs_fb==0 || (~tframe_data_rdy))? num_k+1: subs_fb ;
     if (subs_fb==0)
     begin
      if (add_fb<=1)
        lmfc_boundary <= end_of_frame;
      else 
      begin
       if (end_of_frame[3]==1'b1)
        lmfc_boundary <='h8;
       else if (end_of_frame[2]==1'b1)
        lmfc_boundary <='h4;
       end
      end
     else 
      lmfc_boundary<='h0;
     end
     else  
     begin
      kcnt_2<= num_k + 1 - add_fb + kcnt_2;
     if (add_fb<=1)
       lmfc_boundary<=end_of_frame;
     else
      case(kcnt_2)
       'h1:begin
        if (end_of_frame[0]==1'b1)
         lmfc_boundary<='h1;
        else if (end_of_frame[1]==1'b1)
         lmfc_boundary<='h2;
       end
       'h2:begin
        lmfc_boundary<='h2;
       end
       'h3:begin
        lmfc_boundary<='h4;
       end
       default:begin
        lmfc_boundary<=1'h1;   
       end
      endcase
     end  
   end
   else 
   begin
    lmfc_boundary <='h0;
   end
  else
   kcnt_2 <= num_k+1;
 end
end

always @(posedge clk_character or posedge rst_clk_character)
begin
 if (rst_clk_character)
 begin
  latency <='h0;
 end
 else if(tframe_data_rdy)
 begin
  if (latency < RDY_TO_DATA_LATENCY )
  begin
   latency<=latency + 'h1;
  end
 end
 else
 begin
  latency<='h0;
 end 
end

//assign tframe_data_rdy_change_detector = tframe_data_rdy ? 1:0;
 
always @(posedge clk_character or posedge rst_clk_character)
begin
 if (rst_clk_character)
 begin
  tframe_data_rdy_change_detector <= 'h0;
 end
 else
 begin
  if(tframe_data_rdy)
   tframe_data_rdy_change_detector <= 'h1;
  else
   tframe_data_rdy_change_detector <= 'h0;

  
 end
end 

always @(posedge clk_character or posedge rst_clk_character)
begin
 if (rst_clk_character)
 begin

  next_start_of_multiframe<='h0;
 end
 else
 begin
 
  if (next_start_of_multiframe=='h1)
  begin
    next_start_of_multiframe<='h0;
  end
  else if (end_of_multiframe=='h8)// || (tframe_data_rdy==1 && tframe_data_rdy_change_detector=='h0))
    next_start_of_multiframe<='h1;
 end 
end   
   
endmodule // jesd_tx_conv_to_lane_mapper
//pragma protect rights =(scheme = "simple", default = "deny",  synthesis = (output_annotation =(method = "none"), output_netlist = (method= "none"),  cmd_options = (method = "False"), viewers = "none"), simulate = (viewers = "none"))
