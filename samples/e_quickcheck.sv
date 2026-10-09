// 故意写乱：缩进错、缺对齐、逗号后无空格
module quick_check (
    input  wire clk,
    input  wire rst_n,
    output logic [7:0]  q
);
      logic [7:0] cnt;
  logic [15:0] acc;
logic flag;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
   cnt <= '0;
        acc <= 16'd0;
    end else begin
      acc <= acc + {q, 8'd0};
        cnt <= cnt + 1'b1;
    end
    flag <= ~flag;
  end
endmodule