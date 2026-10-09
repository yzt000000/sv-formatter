module align_demo (
    input wire clk,
    input wire rst_n,
    input wire [31:0] din,
    input wire [7:0] addr,
    input wire valid,
    output wire [63:0] dout,
    output wire done,
    inout wire sda
);

  wire [31:0] w_data;
  wire [7:0] w_addr;
  wire w_valid, w_ready, w_en;
  logic [15:0] r_data;
  logic [3:0] r_state;
  logic [15:0] r_count;

  logic [31:0] x_data, y_data;
  reg [7:0] r_reg;

  fifo #(.DEPTH(1024), .WIDTH(64)) u_fifo (
      .clk(clk),
      .rst_n(rst_n),
      .wr_en(w_en),
      .wr_data(w_data),
      .rd_en(w_ready),
      .rd_addr(w_addr),
      .rd_data(dout)
  );

  assign dout = r_data;

endmodule