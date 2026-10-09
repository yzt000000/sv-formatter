# SystemVerilog Formatter for VSCode

基于 [tree-sitter-systemverilog](https://github.com/gmlarumbe/tree-sitter-systemverilog)（IEEE 1800-2023 完整语法）实现的 SystemVerilog 格式化插件。

设计原则：**缩进由语法结构推导，而非从原文猜测**。任意缩进混乱的输入都会收敛到同一规范形式，因此格式化结果稳定且幂等。

---

## 功能

| 能力 | 说明 |
|------|------|
| 结构化缩进 | `begin/end`、`case/endcase`、`module/endmodule`、`generate` 层级全部按 AST 推导 |
| **五列对齐** | 声明与端口按**方向 / 类型 / 位宽 / 名称 / 分号**对齐 |
| **语句对齐** | 连续 `assign` 的运算符与行尾 `;` 都对齐 |
| **实例对齐** | instance 端口连接的 `(` 与 `)` 都对齐 |
| **参数齐左** | `#(...)` 列表一行一个参数，缩进与 `module` 齐平 |
| **多信号展开** | `wire a, b, c;` 自动展开为一行一个，每行重复完整类型前缀 |
| **实例展开** | instance 端口连接一行一个，不会塌成一行 |
| 宏安全 | `` `define `` / `` `ifdef `` / `` `include `` / `` `timescale `` 等**逐字节原样保留** |
| 注释安全 | 块注释内部逐行原样输出，重复格式化不会累积缩进 |
| 语法错误保护 | 解析失败时默认**拒绝格式化**，可选覆盖 |
| 幂等 | `format(format(x)) == format(x)`，有测试保证 |

## 样式示例

模块头（parameter 与 port）**齐左缩进**，只有模块体缩进：

```systemverilog
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
```

模块体内部则是常规对齐：

```systemverilog
module top
#(
parameter int DEPTH = 16,
parameter int WIDTH = 32
) (
input  logic              clk   ,
input  logic              rst_n ,
output logic  [WIDTH-1:0] o_data
);
  localparam int             PTR_W = $clog2(DEPTH)   ;
  logic        [WIDTH-1:0]   r_data;
  logic signed [15:0]        acc   ;
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
- **`#(...)` 和端口列表齐左**，与 `module` 同列 —— 它们属于模块签名而非模块体。
- 只有模块**体**（`assign`、声明、instance）缩进。
- 头部的 `parameter` 与 `port` 内部仍按方向 / 类型 / 位宽 / 名称 / 分号对齐。

## 实例

输入（缩进混乱、信号挤在一行、instance 全部挤在一行）：

```systemverilog
module align_demo (
    input wire clk,
    input wire [31:0] din,
    input wire valid,
    output wire [63:0] dout
);
  wire [31:0] w_data;
  wire w_valid, w_ready, w_en;
  fifo #(.DEPTH(1024)) u_fifo (.clk(clk), .wr_en(w_en), .rd_data(dout));
endmodule
```

输出：

```systemverilog
module align_demo (
    input  wire         clk  ,
    input  wire  [31:0] din  ,
    input  wire         valid,
    output wire  [63:0] dout
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

## 安装

```bash
# 打包并安装
npx @vscode/vsce package --allow-missing-repository
code --install-extension sv-formatter-0.1.0.vsix

# 或者在 VSCode 里按 F5 启动扩展开发宿主调试
```

首次安装后需要 `npm install` 拉取 tree-sitter 原生模块。

### ⚠️ 必须设置 defaultFormatter

**仅安装不会生效。** TerosHDL、verilog-hdl 等扩展同样注册了 `systemverilog`
语言 ID，VSCode 不会自动选中本插件，需要显式指定：

`Ctrl+Shift+P` → `Preferences: Configure Language Specific Settings...`
→ 选择 `SystemVerilog` → 在打开的 `settings.json` 里填：

```json
"[systemverilog]": {
  "editor.defaultFormatter": "local.sv-formatter",
  "editor.formatOnSave": true
}
```

或者直接在项目里建 `.vscode/settings.json`（只影响该项目）：

```json
{
  "[systemverilog]": {
    "editor.defaultFormatter": "local.sv-formatter",
    "editor.formatOnSave": true
  }
}
```

也可以用命令面板 `Format Document With...` 手动选择
`SystemVerilog Formatter` —— 输出的选择项名称即为该插件。

> 语言 ID 是多个扩展共享的，语法高亮会叠加；但 **defaultFormatter 是单选的**，
> 所以必须显式指定，否则走的是其他扩展的 formatter。

### 验证是否生效

打开仓库中的 `samples/e_quickcheck.sv`（故意写乱的样例），
按 `Shift+Alt+F`，应看到缩进归位、端口与声明对齐。

如果没变化，检查：
1. 右键 → `Format Document With...` 看当前选中的是不是本插件
2. 右下角状态栏 → `{}` 括号图标 → 选择 formatter
3. 文件类型是否被识别为 `SystemVerilog`（状态栏右下角会显示）

## 配置项

所有配置位于 `systemverilogFormatter.*`：

| 键 | 默认 | 说明 |
|----|------|------|
| `indentSize` | `2` | 每级缩进空格数 |
| `useTabs` | `false` | 用 Tab 缩进 |
| `explodePortList` | `true` | 模块端口列表一行一个 |
| `explodeDeclarations` | `true` | 多信号声明一行一个，每行重复类型前缀 |
| `explodeInstancePorts` | `true` | instance 端口连接一行一个 |
| `alignPortsInHeader` | `true` | 端口/声明的方向、类型、位宽、名称列对齐 |
| `alignDeclarationTerminators` | `true` | 连续声明的 `;` / `,` 对齐 |
| `alignConsecutiveAssignments` | `true` | 连续赋值的运算符对齐 |
| `alignConsecutiveDeclarations` | `true` | 连续声明的变量名对齐 |
| `spaceAroundBinaryOperators` | `true` | 二元运算符两侧加空格 |
| `spaceAfterComma` | `true` | 逗号后加空格 |
| `maxConsecutiveBlankLines` | `1` | 最多保留几个连续空行 |
| `ensureTrailingNewline` | `true` | 文件末尾保留一个换行 |
| `formatOnParseError` | `false` | 有语法错误时是否仍然格式化 |

### 关闭展开

如果你的团队规范倾向于把同类型信号写在一行：

```json
{
  "systemverilogFormatter.explodeDeclarations": false,
  "systemverilogFormatter.explodeInstancePorts": false
}
```

配合 VSCode 的 `editor.formatOnSave` 使用即可自动格式化。

## 示例

输入：

```systemverilog
module align_demo (
    input  wire clk,
    output logic [7:0]  data_out,
    input  logic [31:0] din
);
  logic [7:0] cnt;
  logic [15:0] acc;
  logic flag;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= '0;
      acc <= 16'd0;
    end else begin
      acc <= acc + din;
      cnt <= cnt + 1'b1;
    end
  end
endmodule
```

输出：

```systemverilog
module align_demo (
  input  wire         clk,
  output logic [7:0]  data_out,
  input  logic [31:0] din
);
  logic [7:0]  cnt;
  logic [15:0] acc;
  logic        flag;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= '0;
      acc <= 16'd0;
    end else begin
      acc <= acc + din;
      cnt <= cnt + 1'b1;
    end
  end
endmodule
```

## 测试

```bash
npm test        # 114 项断言
```

测试对每个用例校验三条性质：

1. **幂等性** — 格式化两次结果相同
2. **无损性** — 标识符与字面量无丢失、无重复（去空白后比较）
3. **结构平衡** — `begin/end`、`module/endmodule`、`case/endcase` 配平

覆盖的边界情况包括：字符串字面量内含 `begin`/`end` 关键字、块注释跨行、
UVM 类与方法、多声明符、tab 缩进、空输入、以及语法错误代码。

## 命令行

内核不依赖 `vscode` 模块，可直接用于 CI：

```bash
node tools/sv-fmt.js --check src/**/*.sv    # 未格式化则退出码 1
node tools/sv-fmt.js -i file.sv             # 原地格式化
node tools/sv-fmt.js --indent-size 4 f.sv   # 覆盖任意配置项
```

## 已知限制

- 长表达式的**自动换行**尚未实现，目前只处理用户已有的换行位置。
- SVA 属性（`(* ... *)`）与 `property` / `sequence` 体按原文保留，未做深度重排。
- 接口的 `modport` 内容按原文保留。
- `generate` 内的复杂嵌套仅做了基础缩进处理。

## 语法依据

格式化规则基于对 `tree-sitter-systemverilog`（v0.4.x）实际 AST 的探测确定，
几个反直觉但关键的事实：

| 构造 | 实际结构 |
|------|---------|
| `always_ff @(...) begin` | event control 位于 `statement` 内的 `procedural_timing_control_statement`，body 是 `statement_or_null` |
| `initial` / `final` | **没有** keyword 子节点；关键字是匿名的，需从源码前缀取 |
| `if / else if / else` | **被完全展平**为 `[pred, stmt, pred, stmt, stmt]`，树中无 `else` 关键字 |
| 赋值语句 | 分号**不在** assignment 节点内，而在其后的 `statement_item` 内 |
| `function` / `task` 体 | grammar **不生成**结构节点，体内容是扁平 token，只能扫描源码 |
| 宏与条件编译 | 有专门节点类型（`text_macro_definition` 等），可逐字节透传 |

这些事实直接决定了实现方式：结构能靠 AST 的用 AST，靠不到的（如例程体）
才退回源码扫描，且扫描时会屏蔽字符串字面量与注释，避免关键字误匹配。

## 架构

```
src/
  extension.js   VSCode 集成：注册 DocumentFormatting / RangeFormatting provider
  formatter.js   核心引擎：AST 遍历 → 逻辑行 → 缩进 → 对齐 → 文本
  config.js      配置默认值与归一化
tools/
  sv-fmt.js      CLI，用于 CI 格式检查
  run.js         开发用：格式化单个文件并检查幂等性
test/
  run-tests.js   测试套件
samples/         覆盖基础语法、宏、对齐、UVM 的样例
```

核心引擎不依赖 `vscode` 模块，可在 Node 中独立调用。

## License

MIT © 2026 Fan Wenjie

This extension bundles:

| Dependency | License | Project |
|------------|---------|---------|
| [tree-sitter](https://github.com/tree-sitter/tree-sitter) | MIT | parsing runtime |
| [tree-sitter-systemverilog](https://github.com/gmlarumbe/tree-sitter-systemverilog) | MIT | IEEE 1800-2023 grammar |

Both are redistributed unmodified under their own MIT licenses. See
[LICENSE](LICENSE) for the full text.

## Privacy

No telemetry, no network access, no data collection. Formatting happens entirely
in the extension host process; no file content ever leaves your machine.

## Publishing

```bash
npm install
npm test                     # 209 assertions
npx vsce package             # produces sv-formatter-0.1.0.vsix
npx vsce publish             # requires a Marketplace publisher + Azure DevOps PAT
```

Prebuilt native bindings are bundled for Windows, macOS and Linux on x64 and
arm64, so no compiler is needed at install time on any of those targets.
