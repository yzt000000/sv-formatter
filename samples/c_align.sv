module align_demo (
    input  wire clk,
    input  wire rst_n,
    output logic [7:0]  data_out,
    output logic         valid_o,
    input  logic [31:0] din
);

  logic [7:0] cnt;
  logic [15:0] acc;
  logic flag;
  logic [3:0] nib;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= '0;
      acc <= 16'd0;
      flag <= 1'b0;
    end else begin
      cnt <= cnt + 1'b1;
      acc <= acc + din;
      flag <= ~flag;
    end
  end

  assign data_out = cnt;
  assign valid_o = flag;
  assign nib = acc[3:0];

endmodule
