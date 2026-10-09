module sync_2stage
#(
parameter WIDTH = 1
) (
input  wire              clk  ,
input  wire              rst_n,
input  wire  [WIDTH-1:0] d    ,
output wire  [WIDTH-1:0] q
);
  assign q = d;
endmodule