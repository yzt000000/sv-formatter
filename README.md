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
| **实例紧凑布局** | 信号少、例化多的场景可切成「一行一个 instance」，跨 instance 按列对齐 `(` 与 `)` |
| **运算符间距** | `q<=cnt+1'b1;` → `q <= cnt + 1'b1;`；`[W-1:0]`、字符串、`::`、一元运算符不动 |
| **控制语句合并** | `end else begin` / `end else if (...)` / `for (...) begin` 收在同一行 |
| 宏安全 | `` `define `` / `` `ifdef `` / `` `include `` / `` `timescale `` 等**逐字节原样保留** |
| **端口列表内条件编译** | 端口列表 / 实例连接里的 `` `ifdef `` / `` `else `` / `` `endif `` 不再导致整篇跳过，指令原位保留 |
| **端口文档注释** | 独占一行的 `//! …` 归属它下面的端口；只有与端口同行的注释才挂在该端口后面 |
| **跨 `ifdef` 对齐** | 端口列表被 `` `ifdef `` / 注释打断时仍共用一套列（名字、位宽、逗号都对齐） |
| **例化参数表展开** | `#(.A(1), .B(2))` 一行一个并沿 `(` 对齐；单个 `.A(1)` 仍留在头部行 |
| 注释安全 | 块注释内部逐行原样输出，重复格式化不会累积缩进 |
| 语法错误保护 | 解析失败时默认**拒绝格式化**，可选覆盖 |
| 幂等 | `format(format(x)) == format(x)`，有测试保证 |
| **分段格式化** | 选中任意一段代码格式化，只重排选区、选区外逐字节不变，缩进按选区首行推断的基础层级 + 引擎结构推导 |
| **现场切换例化布局** | `Ctrl+Alt+L` 选中一段后当场选 explode / compact / auto，只对本次生效，不改 `settings.json` |

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
    localparam int             PTR_W = $clog2(DEPTH);
    logic          [WIDTH-1:0] r_data;
    logic signed   [15:0]      acc   ;
    assign o_data  = r_data;
    assign valid_a = r_data;
    bus_if #(.WIDTH(WIDTH)) u_bus (
        .clk  (clk   ),
        .rst_n(rst_n ),
        .data (o_data)
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

## 例化的两种排版方向

例化用哪种形态取决于场景，插件通过 `instanceLayout` 分派：

| 值 | 行为 | 适用 |
|----|------|------|
| `explode` | 每个端口连接一行，端口名列表对齐 | 端口多、连接表达式长 |
| `compact` | 一行一个 instance，跨 instance 按列对齐 `.port(expr)` | 端口少（≤4）、例化很多（如按 bit 展开的 `sync_cell`） |
| `auto` | 端口数 ≤ `compactInstanceMaxPorts` 用 compact，否则 explode | 默认 |
| `off` | 例化原文不动 | — |

`auto` 的实际效果（`demo/instances.sv`）：

```systemverilog
    sync_cell u_bit0 (.clk(clk), .d(din[0]), .q(q0));
    sync_cell u_bit1 (.clk(clk), .d(din[1]), .q(q1));
    sync_cell u_bit2 (.clk(clk), .d(din[2]), .q(q2));

    frame_store #(.DEPTH(512)) u_store (
        .clk    (clk          ),
        .rst_n  (rst_n        ),
        .wr_en  (store_wr_en  ),
        .rd_en  (store_rd_en  ),
        .wdata  (store_wdata  ),
        .rdata  (store_rdata  )
    );
```

连接表达式宽度不一致时，`(` 与 `)` 都对齐到同一列：

```systemverilog
    tiny u_x  (.d(data_bus[7:0]), .q(q_x ));
    tiny u_yy (.d(d            ), .q(q_yy));
```

约束与细节：

- compact 的分组要求**同模块 + 同缩进 + 同连接数 + 同连接形状 + 端口名顺序一致**。
  端口顺序不同的两次例化若共用列宽，每项都会被推到错误位置，因此不并组。
- 连接里带注释或 `` `ifdef `` 时强制回退 `explode`，折行会吞掉注释或指令。
- 发射器只产出无 padding 的规范文本，列宽由对齐阶段从行上的 `{prefix, name, items}`
  载荷重建，因此重复格式化不会累积空格（幂等）。
- expr 列过宽时按 `alignTerminatorMaxPad` 放弃该列对齐，避免一个长表达式把整组推飞。

> 上面选的是**文件级**默认形态。只想给**某一段选中**换形态、又不想改设置，
> 用 `Ctrl+Alt+L`（见下一节）。

## `Ctrl+Alt+L`：选中一段，现场决定例化用哪种形态

`instanceLayout` 是**全局设置**——改它要开 `settings.json`，而且下一次保存会立刻影响整篇文件。
但实际写 RTL 时，同一个文件里两种形态经常都要：

- 成批按 bit 展开的 `sync_cell`、`crc_slice` → 压成表最好看，一眼扫完
- 刚接的 `frame_store`、`axi_slave` 这类大端口模块 → 一端口一行，逐个 review 连线

**`Ctrl+Alt+L` 就是把这个选择从「改配置」挪到「按下的那一刻」**：只对本次选区生效，
不写 `settings.json`，不影响 `formatOnSave`，更不会波及文件里其它例化。

### 三步操作

| 步骤 | 做什么 |
|---|---|
| 1 | 选中要整理的代码。**不必精确**——选区会自动扩到包含它的最小完整语法块 |
| 2 | 按 `Ctrl+Alt+L` |
| 3 | 四选一 → 回车。列表里的 `按当前配置` 表示不覆盖，沿用 `instanceLayout` |

### 同一段代码，三种结果

输入（手写的拥挤排版）：

```systemverilog
    frame_store #(.DEPTH(512)) u_store (
        .clk(clk), .rst_n(rst_n), .wr_en(store_wr_en),
        .rd_en(store_rd_en), .wdata(store_wdata), .rdata(store_rdata)
    );
```

选 **Explode** → 一端口一行，`(` 列对齐，适合逐个核对接线：

```systemverilog
    frame_store #(.DEPTH(512)) u_store (
        .clk  (clk        ),
        .rst_n(rst_n      ),
        .wr_en(store_wr_en),
        .rd_en(store_rd_en),
        .wdata(store_wdata),
        .rdata(store_rdata)
    );
```

选 **Compact** → 整个实例回到一行（`compactInstanceMaxPorts` 不参与判定，compact 就是 compact）：

```systemverilog
    frame_store #(.DEPTH(512)) u_store (.clk(clk), .rst_n(rst_n), .wr_en(store_wr_en), .rd_en(store_rd_en), .wdata(store_wdata), .rdata(store_rdata));
```

选 **Auto** → 这里 6 个连接超过 `compactInstanceMaxPorts`（默认 4），落到 explode，结果与 Explode 相同。

Compact 真正的价值在**成批实例**：同模块、相邻行的实例会连成一张表，`(` 与 `)` 跨行对齐。
下面两行的例化名与表达式宽度都不同，仍然对齐：

```systemverilog
    tiny u_x  (.d(data_bus[7:0]), .q(q_x ));
    tiny u_yy (.d(d            ), .q(q_yy));
```

### 行为约定

- **只作用于本次调用**：覆盖值随命令结束丢弃，`settings.json` 一个字节不动。
- **记住上次选择**：上次选过的项会浮到列表首位并预选，重复同一动作就是
  `Ctrl+Alt+L` → `回车` → `回车`。
- **没有选区时不会触发**：该键位的 `when` 条件含 `editorHasSelection`，无选区按下不产生任何编辑，
  不会悄悄退化成全文格式化。
- **`Ctrl+Alt+K` 等价于选「按当前配置」**：两者共用同一套块扩展与缩进推断逻辑，
  区别只在于多不多这一步选择。
- **想绕开弹窗**：`svFormatter.formatSelectionExplode` / `svFormatter.formatSelectionCompact`
  两个直通命令默认不绑键位，自己绑死一个即可：

  ```json
  { "key": "ctrl+alt+e", "command": "svFormatter.formatSelectionExplode",
    "when": "editorTextFocus && editorHasSelection && editorLangId == systemverilog" },
  { "key": "ctrl+alt+c", "command": "svFormatter.formatSelectionCompact",
    "when": "editorTextFocus && editorHasSelection && editorLangId == systemverilog" }
  ```

### 什么时候别用它

- **要整篇统一形态**：改 `instanceLayout` 后按 `Ctrl+Alt+F`，别一段一段选。
- **端口列表里含 `` `ifdef `` 的例化**：`expandToBlock` 会判为语法错误而跳过（已知限制，
  见文末），改用整篇格式化。
- **想连格式之外的语义一起动**（改端口名、重排实例顺序）：格式化器不做这些，它只重排空白。

## 安装

```bash
# 打包并安装
npm install
npx @vscode/vsce package
code --install-extension sv-formatter-0.6.1.vsix

# 或者在 VSCode 里按 F5 启动扩展开发宿主调试
```

> `npx vsce package --no-dependencies` 会**整个丢掉 `node_modules`**（只剩几百 KB 空壳），
> 原生模块和 grammar 都不在里面，装上去无法格式化。必须用不带该参数的 `npx vsce package`。

### ⚠️ 必须设置 defaultFormatter

**仅安装不会生效。** TerosHDL、verilog-hdl 等扩展同样注册了 `systemverilog`
语言 ID，VSCode 不会自动选中本插件，需要显式指定：

`Ctrl+Shift+P` → `Preferences: Configure Language Specific Settings...`
→ 选择 `SystemVerilog` → 在打开的 `settings.json` 里填：

```json
"[systemverilog]": {
  "editor.defaultFormatter": "yzt000000.sv-formatter",
  "editor.formatOnSave": true
}
```

或者直接在项目里建 `.vscode/settings.json`（只影响该项目）：

```json
{
  "[systemverilog]": {
    "editor.defaultFormatter": "yzt000000.sv-formatter",
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

所有配置位于 `systemverilogFormatter.*`。设置界面里每项都带**中文说明**
（`markdownDescription`，含取值含义、单位、与其它项的联动），英文 `description` 保留在
`package.json` 里供 schema 消费者与设置搜索使用。

| 键 | 默认 | 说明 |
|----|------|------|
| `indentSize` | `4` | 每级缩进的空格数（`useTabs` 为 `true` 时忽略） |
| `useTabs` | `false` | 用 Tab 缩进，而不是空格 |
| `explodePortList` | `true` | 模块端口列表一行一个端口 |
| `explodeDeclarations` | `true` | 多信号声明一行一个，每行重复完整类型前缀（`wire a, b;` → 两行 `wire`） |
| `explodeInstancePorts` | `true` | **已废弃**，改用 `instanceLayout: "off"`；为 `false` 时例化原文不动 |
| `instanceLayout` | `explode` | 例化排版：`explode` 一端口一行 / `compact` 一实例一行并跨实例成表 / `auto` 按连接数自适应 / `off` 不动。含注释或 `` `ifdef `` 的连接列表强制 explode |
| `compactInstanceMaxPorts` | `4` | `auto` 的判定阈值：连接数不超过它用 compact |
| `alignPortsInHeader` | `true` | 端口/声明的方向、类型、位宽、名称列对齐 |
| `alignDeclarationTerminators` | `true` | 连续声明行尾的 `;` / `,` 对齐 |
| `alignConsecutiveAssignments` | `true` | 连续赋值的运算符对齐 |
| `alignConsecutiveDeclarations` | `true` | 连续声明的变量名对齐 |
| `spaceAroundBinaryOperators` | `true` | 二元运算符两侧加一个空格 |
| `spaceAfterComma` | `true` | 逗号后加一个空格 |
| `maxConsecutiveBlankLines` | `1` | 最多保留几个连续空行 |
| `ensureTrailingNewline` | `true` | 文件以恰好一个换行结尾 |
| `formatOnParseError` | `false` | 有语法错误时是否仍然格式化（默认关闭，避免重排不完整代码） |
| `caseItemOnSameLine` | `true` | `case` 单语句项与标签同行（`IDLE: state <= RUN;`） |
| `alignTerminatorMaxPad` | `16` | 行尾 `;` 列对齐允许的最大填充，超出则放弃该列；`0` 不限制 |
| `trace.server` | `off` | 输出格式化请求日志（`messages`），排查插件自身问题时用 |

### 关闭展开

如果你的团队规范倾向于把同类型信号写在一行：

```json
{
  "systemverilogFormatter.explodeDeclarations": false,
  "systemverilogFormatter.instanceLayout": "off"
}
```

配合 VSCode 的 `editor.formatOnSave` 使用即可自动格式化。

## 分段格式化（Format Selection Only）

除了整篇格式化，本插件支持**只格式化选中那一段**，选区外的代码逐字节保持不变。

用法：

1. 选中要整理的代码（一段 `always` 块、一组声明、一个 instance 等均可）。
2. 以下任一方式触发：

   | 触发方式 | 说明 |
   |----------|------|
   | `Ctrl+Alt+K` | 插件自带的快捷键，按当前 `instanceLayout` 设置格式化 |
   | `Ctrl+Alt+L` | 弹出选择框，**本次**指定例化布局（explode / compact / auto），不影响设置 —— 详见上文 `Ctrl+Alt+L` 一节 |
   | `Ctrl+K Ctrl+F` | VSCode 内置 `Format Selection`，走同一个 range provider |
   | 右键 → **Format SystemVerilog Selection Only** | 命令面板同名命令 |
   | `Ctrl+Alt+F` | 全文格式化（对比用） |

   要改快捷键，在 `keybindings.json` 里覆盖：

   ```json
   {
     "key": "ctrl+alt+k",
     "command": "svFormatter.formatSelectionOnly",
     "when": "editorLangId == systemverilog && editorHasSelection"
   }
   ```

### 选区格式化时指定例化布局

`Ctrl+Alt+L` 会先弹出四选一，再格式化选区：

| 选项 | 行为 |
|------|------|
| **Explode** | 一端口一行、列对齐。端口多、要逐个确认连线时用 |
| **Compact** | 整实例压成一行，相邻同模块实例的 `.port(expr)` 对齐成表 |
| **Auto** | 连接数 ≤ `compactInstanceMaxPorts` 用 compact，否则 explode |
| **按当前配置** | 不覆盖，沿用 `systemverilogFormatter.instanceLayout` |

上次的选择会浮到列表首位并预选，重复同一操作就是 `Ctrl+Alt+L` → 回车 → 回车。

也可以绕过弹窗，把这两个命令直接绑到你自己的键位上（默认不绑）：

```json
{ "key": "ctrl+alt+e", "command": "svFormatter.formatSelectionExplode",
  "when": "editorTextFocus && editorHasSelection && editorLangId == systemverilog" },
{ "key": "ctrl+alt+c", "command": "svFormatter.formatSelectionCompact",
  "when": "editorTextFocus && editorHasSelection && editorLangId == systemverilog" }
```

行为细节：

- 选区自动**扩展到包含它的最小完整语法块**（`always_construct` / `data_declaration` /
  `module_declaration` / `function_declaration` / `generate` …），整块在**隔离环境**中格式化，
  只替换该块的行范围，**块外逐字节不变**。
- 选区恰好是完整块时，扩展后就是它本身；选区落在块内部（如只选了 `if` 那一行）时，
  会向上扩到包含它的 `always`/`begin-end` 块。
- 位于 module 体内的块（例化、声明、`always`、`generate` …）在隔离格式化时会**临时包进一个
  一次性 `module`** 再解析，否则一条裸的 `tiny u_a (.clk(clk));` 会被语法分析当成函数调用语句，
  实例化布局完全不生效。包裹层在输出前被剥掉，并扣回它引入的那一级缩进。
  顶层 `module` / `interface` / `package` 声明与宏定义**不包裹**（嵌套非法 / 续行会被改缩进）。
- 缩进按块**首行非空行的前导空白**推断基础层级，量化到 `indentSize`（或 tab 站），
  引擎在隔离块上做结构化缩进，最终每行 = 基础前缀 + 引擎缩进。
- 块有语法错误、或选区跨了多个块而无法合成一个合法片段时，**拒绝执行并提示**，
  返回 0 个编辑（宁可不改也不乱改）。此行为受 `formatOnParseError` 影响。
- 三条入口（快捷键 / 内置 Format Selection / 命令）共用同一个 `selectionEdit()`，
  行为完全一致。旧实现「格式化整篇再按行号切片」已废弃——一旦选区上方行数变化就会切错位。

> 已知限制：端口连接列表内含 `` `ifdef `` 时，`expandToBlock` 判定该块带语法错误会返回「跳过」。
> 这类例化目前只能用整篇格式化或手工整理。


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
npm test        # 382 项断言 + 激活/provider 冒烟
```

测试对每个用例校验三条性质：

1. **幂等性** — 格式化两次结果相同
2. **无损性** — 标识符与字面量无丢失、无重复（去空白后比较）
3. **结构平衡** — `begin/end`、`module/endmodule`、`case/endcase` 配平

覆盖的边界情况包括：字符串字面量内含 `begin`/`end` 关键字、块注释跨行、
UVM 类与方法、多声明符、tab 缩进、空输入、语法错误代码、端口列表内的 `` `ifdef ``、
端口文档注释、`else if` 扁平化、例化 compact 列对齐与选区 block 展开。

`test/activate-smoke.js` 不依赖真实 VSCode：拦截 `require('vscode')` 注入桩件跑
`activate()`，断言 provider / 命令 / disposable 的注册数量，再用假 `document`
驱动 provider 跑一份真实 RTL。这类「API 名字写错导致扩展根本没激活」的问题
会在本地就被挡下来。

### 语料回归

`test_rtl/` 里是 80 份真实 JESD204B RTL，可整体跑通并检查幂等与无损：

```bash
node tools/fmt-corpus.js              # 输出到 test_rtl_fm/
node tools/fmt-corpus.js --indent=2   # 换成 2 空格缩进
```

每份文件都会校验：无令牌丢失、`begin/end` 计数不变、格式化后仍可解析、
尾随空白为 0、二次格式化结果一致。

## 命令行

内核不依赖 `vscode` 模块，可直接用于 CI：

```bash
node tools/sv-fmt.js --check src/**/*.sv    # 未格式化则退出码 1
node tools/sv-fmt.js -i file.sv             # 原地格式化
node tools/sv-fmt.js --indent-size 4 f.sv   # 覆盖任意配置项（kebab-case 或 camelCase 均可）
node tools/sv-fmt.js --instanceLayout compact f.sv
```

## 已知限制

- 长表达式的**自动换行**尚未实现，目前只处理用户已有的换行位置（`maxLineLength` 暂未生效）。
- SVA 属性（`(* ... *)`）与 `property` / `sequence` 体按原文保留，未做深度重排。
- `modport` 的条目一行一个、按块缩进，条目内部的列对齐未做。
- `generate` 内的复杂嵌套仅做了基础缩进处理。
- 端口列表 / 实例连接里的预处理指令要求**整行只有指令本身**。像 `` `endif ); `` 这种
  「指令 + 收尾括号」同一行的写法仍会让解析失败，此时按语法错误处理（默认跳过整篇）。

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
  extension.js   VSCode 集成：Document / Range formatting provider、两条命令、快捷键
  fragment.js    选区格式化：扩展到最小 block 级语法节点 → 隔离环境格式化 → 回填缩进
  formatter.js   核心引擎：AST 遍历 → 逻辑行 → 缩进 → 对齐 → 文本
  config.js      配置默认值与归一化
tools/
  sv-fmt.js      CLI，用于 CI 格式检查
  fmt-corpus.js  语料回归：整体格式化 test_rtl/ 并写报告
test/
  run-tests.js   断言测试套件（382 条）
  activate-smoke.js  桩件跑 activate()，校验 provider / 命令注册与选区编辑
test_rtl/        80 份真实 JESD204B RTL，语料回归输入
demo/            手动试用的代表文件（不动 test_rtl 的基线）
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
npm test                     # 382 assertions + activate/provider smoke
npx vsce package             # produces sv-formatter-0.6.0.vsix
npx vsce publish --pat $VSCE_PAT
```

The CI workflow runs the test suite on Linux, Windows and macOS across Node 18
and 20, and packages the extension on every push.

Prebuilt native bindings are bundled for Windows, macOS and Linux on x64 and
arm64, so no compiler is needed at install time on any of those targets.
