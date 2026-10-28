模块头（parameter 与 port） **齐左缩进** ，只有模块体缩进：

```systemverilog
module sync_2stage
#(
parameter WIDTH = 1
) (
inputwire              clk  ,
inputwire              rst_n,
inputwire  [WIDTH-1:0] d    ,
outputwire  [WIDTH-1:0] q
);
assign q = d;
endmodule
```

模块体内部则是常规对齐：

```systemverilog
module top
#(
parameterint DEPTH = 16,
parameterint WIDTH = 32
) (
inputlogic              clk   ,
inputlogic              rst_n ,
outputlogic  [WIDTH-1:0] o_data
);
localparamint             PTR_W = $clog2(DEPTH)   ;
logic        [WIDTH-1:0]   r_data;
logicsigned [15:0]        acc   ;
assign o_data  = r_data;
assign valid_a = r_data;
  bus_if #(.WIDTH(WIDTH)) u_bus (
    .clk   (clk   ),
    .rst_n (rst_n ),
    .data  (o_data)
  );
endmodule
```

要点：

* **`#(...)` 和端口列表齐左** ，与 `module` 同列 —— 它们属于模块签名而非模块体。
* 只有模块 **体** （`assign`、声明、instance）缩进。
* 头部的 `parameter` 与 `port` 内部仍按方向 / 类型 / 位宽 / 名称 / 分号对齐。

## 实例

输入（缩进混乱、信号挤在一行、instance 全部挤在一行）：

```systemverilog
module align_demo (
inputwire clk,
inputwire [31:0] din,
inputwire valid,
outputwire [63:0] dout
);
wire [31:0] w_data;
wire w_valid, w_ready, w_en;
  fifo #(.DEPTH(1024)) u_fifo (.clk(clk), .wr_en(w_en), .rd_data(dout));
endmodule
```

输出：

```systemverilog
module align_demo (
inputwire         clk  ,
inputwire  [31:0] din  ,
inputwire         valid,
outputwire  [63:0] dout
);
wire  [31:0] w_data ;
wire         w_valid;
wire         w_ready;
wire         w_en   ;
  fifo #(.DEPTH(1024)) u_fifo (
    .clk   (clk),
    .wr_en (w_en),
    .rd_data(dout)
  );
endmodule
```
