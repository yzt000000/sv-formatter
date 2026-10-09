interface bus_if #(parameter int WIDTH = 32) (input logic clk);

  logic [WIDTH-1:0] data;
  logic valid;
  logic ready;

  modport master (
      output data,
      output valid,
      input  ready
  );

  task automatic send(input logic [WIDTH-1:0] d);
    data <= d;
    valid <= 1'b1;
  endtask

endinterface


module top #(
    parameter int DEPTH = 16,
    parameter int WIDTH = 32
) (
    input  logic clk,
    input  logic rst_n,
    output logic [WIDTH-1:0] o_data
);

  localparam int PTR_W = $clog2(DEPTH);
  localparam int MASK = (1 << DEPTH) - 1;

  logic [WIDTH-1:0] r_data;
  logic [WIDTH-1:0] w_data;
  logic signed [15:0] acc;
  logic [7:0] cnt;

  assign o_data = r_data;
  assign valid_a = r_data;
  assign ready_b = w_data;

  bus_if #(.WIDTH(WIDTH)) u_bus (
      .clk   (clk),
      .rst_n (rst_n),
      .data  (o_data)
  );

  assign ack = cnt;

endmodule