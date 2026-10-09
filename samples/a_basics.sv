module m #(parameter int W = 8) (input logic clk, output logic [W-1:0] d);
  logic a, b;
  logic [7:0] q;
  always_ff @(posedge clk or negedge rst_n) begin : blk
    if (!rst_n) begin
      d <= '0;
    end else begin
      q <= din;
      d <= {q[7:0], 1'b0};
    end
    case (sel)
      2'd0: a = 1'b1;
      2'd1, 2'd2: a = 1'b0;
      default: begin a = 1'bx; b = 1'b0; end
    endcase
    d = rdy ? q[7:4] : 8'hFF;
  end
endmodule
