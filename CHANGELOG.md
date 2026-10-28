# Changelog

All notable changes to this extension are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.1] - 2026-10-29

### Added

- **选区格式化时选择例化布局。** `Ctrl+Alt+L`
  (`svFormatter.formatSelectionWithLayout`) 先弹出 explode / compact / auto /
  按当前配置 四选一，再格式化选区，不改动 `settings.json`。上次的选择会浮到列表
  首位并预选。另提供 `svFormatter.formatSelectionExplode` 与
  `svFormatter.formatSelectionCompact` 两个直通命令（不绑默认键位，便于自行绑键）。

### Changed

- **全部 19 个配置项补上中文说明。** `package.json` 的 `contributes.configuration`
  为每个属性增加中文 `markdownDescription`（写清取值含义、单位、与其它项的联动关系），
  `instanceLayout` 的 `enumDescriptions` 也改为中文。英文 `description` 保留不变，
  继续供 schema 消费者与设置界面搜索使用；VSCode 优先渲染 `markdownDescription`，
  因此设置面板与 `settings.json` 的悬浮提示现在都是中文。
- README 新增整节 **「`Ctrl+Alt+L`：选中一段，现场决定例化用哪种形态」**：
  三步操作、同一段代码在 Explode / Compact / Auto 下的真实输出对照、compact 跨实例成表的效果、
  行为约定（只对本次生效、记住上次选择、无选区不触发、与 `Ctrl+Alt+K` 的关系、
  两个直通命令的绑键写法）以及三种不适用场景。
- README 配置表补全 `trace.server`，各项说明与 `package.json` 中文描述对齐；
  「关闭展开」示例改用 `instanceLayout: "off"`（`explodeInstancePorts` 已废弃）。

### Fixed

- **选区格式化的例化布局对「无参数覆盖」的实例完全不生效。** 一条裸的
  `tiny u_a (.clk(clk), .d(q0));` 被切片后会脱离 module 上下文，语法分析把它判为
  `statement`（task/function call），实例化发射器根本不会被调用：无论
  `instanceLayout` 设成 explode 还是 compact，输出都只是把原有排版压成一行。
  现在把这类块临时包进一个一次性 `module` 再解析，包裹层在输出前剥掉并扣回它引入的
  一级缩进。顶层 `module`/`interface`/`package` 声明与宏定义不在包裹范围内（前者嵌套
  非法、后者续行缩进会被破坏）。受影响的还有 `always_construct`、声明与 `generate`
  片段——它们此前同样依赖「裸切片恰好能解析成正确节点类型」这一巧合。
- 幂等性保持：同一片段连续格式化结果不变（explode / compact / auto 均验证）。

## [0.6.0] - 2026-10-28

### Added

- **`instanceLayout` — a second way to lay out module instantiations.**
  `explode` (default) keeps the existing one-connection-per-line port map.
  `compact` puts the whole instance on one line and aligns the `.port(expr)`
  columns of neighbouring instances of the same module into a table — the shape
  that suits eight three-connection instances, where exploding costs
  twenty-four lines to say nothing. `auto` picks compact up to
  `compactInstanceMaxPorts` connections and explodes above that.
  Alignment is per connection position, so both the `(` and the `)` of every
  reference line up down the block. A group only forms across consecutive
  instances that share the module, the indent, the connection count *and* the
  connection names — the same module does not imply the same port order, and
  aligning across a reordered port map would pad every entry to the wrong
  column. A connection list carrying a comment or a `` `ifdef `` always
  explodes: folding it onto one line would drop what is written there.
- **Selection-only formatting now applies to the enclosing block.** The range
  formatting provider used to format the whole document and then slice the
  result by line index — wrong as soon as the formatter changed the number of
  lines above the selection. It now grows the range to the smallest block-level
  syntax node containing it, formats that block in isolation, and splices it
  back, so nothing outside the block moves. Bound to `Ctrl+Alt+K`; `Ctrl+K
  Ctrl+F` and the context menu use the same path. `Ctrl+Alt+F` formats the
  whole document.

### Fixed

- **`vsce package --no-dependencies` silently dropped `node_modules`.** The
  resulting 388 KB package had no grammar and no native binding.
- **Enum settings were coerced to numbers by the CLI.** `--instanceLayout
  compact` became `NaN` and every layout override was ignored.

## [0.5.0] - 2026-10-28

### Fixed

- **Documentation comments were attached to the wrong port.** In a list written
  one comment per line above the entry — the style used throughout the JESD204B
  RTL (`//! clock used by the data path` / `input clk_character,`) — every
  comment was bound to the *previous* port as its trailing comment, so each port
  carried its neighbour's documentation and the real ones were duplicated. A
  comment now binds to the item only when it starts on the same source line.
- **A port list lost its columns wherever a directive or a comment appeared.**
  `` `ifdef `` lines and standalone comments ended the alignment run, so an
  `` `ifdef ``-heavy header came out with three different name columns and looked
  untouched (this is what `jesd_jesd204b_tx_link_top.v` showed). Comments and
  directives are now transparent for the header: the whole list shares one set
  of columns. Parameter lists documented per line keep their `=` aligned for the
  same reason.
- **A parameter override list was folded into the instance head.** `mod #(…)` was
  collapsed to one ~200-column line that also swallowed the instance name and
  the opening paren of the port map, so a four-parameter instance came out as a
  single unreadable line while its ports stayed exploded. A multi-entry override
  is now one `.P(v)` per line, aligned on `(`, with `) u_name (` closing it; a
  lone `.DEPTH(8)` stays inline.
- **A banner comment disabled instance-paren alignment.** `/*AUTOINST*/` and
  `// Outputs` lines have no paren of their own, and their presence vetoed the
  padding for the whole port map. They are skipped now. An `` `ifdef `` does end
  the run — the branches are alternative maps, and letting
  `.txrx_enablelinktest_reg` in one branch set the column padded every short
  entry in the others by 60+ columns.
- **`endmodule // name` was split over two lines.** The trailer is emitted on the
  keyword line again.

### Notes

- `test_rtl` corpus: 76/80 files formatted, 0 non-idempotent, 0 token loss,
  0 `begin`/`end` count change, 0 new parse failures, 0 trailing whitespace.
  `` `include `` is not involved in any skip — 27 of the 29 files that use it
  format normally; the 4 skipped files fail because the grammar cannot parse
  their port lists (`` `endif ); `` on one line) or because they are fragments.

## [0.4.0] - 2026-10-28

### Fixed

- **`;` alignment was dragged out by long lines.** A 300-column concatenation in
  a group pushed every neighbouring `;` to column 190, filling the file with
  trailing whitespace. Terminator alignment now applies to declaration lines
  only (`ref.md` pads `wire` / `logic` / `localparam`, not `assign`), and is
  abandoned when the widest line in the group is more than
  `alignTerminatorMaxPad` (16) columns away.
- **A single-statement `case` item was split over two lines.** A 100-entry
  encode table went from 283 to 435 lines. Items whose body is one simple
  statement now stay on the label line (`caseItemOnSameLine`), while blocks
  still break.
- **`else if` at generate scope became `else begin if … end`.** An `else`
  written without `begin` arrives as a block holding one nested conditional
  generate; it is now unwrapped so the chain stays flat, and an implicit
  generate block no longer grows a `begin`/`end` pair it never had.
- **`else` was appended to the previous line's comment.** `end // if (…)`
  followed by `else` produced `end // if (…) else begin`, silently commenting
  out the keyword. A line with a trailing `//` is never joined.
- **Port names did not share a column.** `input clk` beside `input [7:0] d`
  left the names ragged, because padding was only inserted at fields the line
  actually had. Declaration lines are now rebuilt from four slots — direction,
  type, packed width, name — with missing slots left blank.
- **`input a, b, c` lost the direction when exploded.** The grammar returns
  `b` and `c` as direction-less declarations, which would have printed as
  `inout`. They now inherit the preceding declaration's prefix.
- **Colon spacing.** `9'h003 :` had a stray space before the colon; labels
  (`2'd0:`, `default:`, `begin : name`) are tight now while a ternary
  `? :` keeps its spaces.

### Added

- `caseItemOnSameLine` (default `true`) and `alignTerminatorMaxPad` (default
  `16`) configuration keys.
- `node tools/fmt-corpus.js [--indent=2]` — formats `test_rtl/` into
  `test_rtl_fm/` and writes `test_rtl_fm/_FORMAT_REPORT.md`, for eyeballing a
  style change across the whole corpus.

## [0.3.0] - 2026-10-28

### Added

- **Conditional compilation inside port and connection lists.** `ifdef` /
  `else` / `endif` between ports no longer makes the whole file unparsable.
  Such directives are masked to marker comments for parsing, then spliced back
  onto their own lines; the rest of the file is formatted normally. On the RTL
  corpus used for testing this lifts the number of formattable files from 64/80
  to 76/80, the remaining four being files that do not parse for other reasons.
- `end else` / `end else if` are joined onto the closing `end` line.
- The port list opening paren stays on the module-name line (`module foo (`)
  when the module has no parameter list.
- `modport` entries are kept one per line and indented as a block instead of
  being collapsed onto a single line.
- `generate` blocks that the author wrote with `begin`/`end` keep them; only
  genuinely implicit generate blocks are inlined.
- **Expression spacing is normalised.** `spaceAroundBinaryOperators`,
  `spaceAfterComma` and `spaceBeforeSemicolon` were declared but had no effect;
  `q<=cnt+1'b1;` came out exactly as written. Now: one space around a binary
  operator, one space after `,` and `;`, none before `;` — while index/range
  contents (`[W-1:0]`), string literals, directives, `::`, `++`, `--` and unary
  operators keep their tight form.

### Fixed

- **CRLF input produced a phantom blank line after every line comment and every
  macro.** The grammar attaches the trailing `\r` to `one_line_comment` and
  `` `define `` nodes; splitting that text yielded a trailing empty line, and
  because output is LF-only the second format pass differed from the first.
  Files formatted with `editor.formatOnSave` were rewritten twice — once per
  save. Affected 66 of the 80 corpus files; now zero.
- A comment following a node whose text includes its own line terminator was
  glued onto that node's line (`end\n// block: foo` became `end // block: foo`,
  merged in the wrong place). Line sharing is now decided from the source gap,
  not from row numbers.
- Comments attached to `end` inside `generate` constructs were dropped.
- A trailing blank line inside a multi-line `` `define `` produced an extra
  blank line in the output.
- **A nested block inside a loop body truncated the loop.** The header/body
  scanner matched the first `end` it saw instead of the one closing the loop, so
  `for (...) begin … for (...) begin … end end` lost an `end`, and everything
  after it was re-parsed as broken statements. `if`/`for` inside function and
  task bodies came out as bare conditions with no keyword, and the routine body
  lost its indentation. The scan is now nesting-aware and only recognises
  keywords at a word boundary outside parentheses and string literals.
- Control constructs no longer join the assignment-alignment group: a
  `for (i = 0; …) z <= i;` line used to pull every neighbouring assignment out
  to its own operator column.

### Changed

- Default `indentSize` is 4 (was 2).
- Test suite: 313 assertions (was 234), covering CRLF idempotence, header paren
  placement, `end else` joining, modport layout, `ifdef` in port lists,
  generate-block `begin` preservation, operator spacing, control-line alignment
  and routine-body nesting.

## [0.2.0] - 2026-10-27

### Added

- **Selection-only formatting** (`svFormatter.formatSelectionOnly` command,
  "Format SystemVerilog Selection Only"): format just the highlighted region and
  leave everything outside it byte-for-byte intact. The fragment is formatted in
  isolation by the engine and re-indented by the base indent inferred from its
  first non-blank line, so a deeply nested `always_ff` block keeps its surrounding
  nesting level. Bound to the right-click menu when a selection is active; can be
  assigned a keyboard shortcut in `keybindings.json`.
- 18 new assertions (227 total) covering fragment formatting: base-indent
  inference, re-indentation, idempotence, losslessness, tab mode, and blank
  selections.

## [0.1.0] - 2026-10-09

### Added

- Structure-driven formatting for SystemVerilog: indentation is derived from
  the parse tree rather than guessed from the input, so any mixture of
  indentation converges to one canonical form.
- Five-column alignment of module ports and declarations: direction, base type,
  packed width, signal name, terminator.
- Multi-signal declarations are exploded one signal per line, each repeating
  the full type prefix (`wire a, b;` becomes two `wire` declarations).
- Instance port connections are exploded one per line with `(` and `)` aligned.
- Module header (`#(...)` parameters and the port list) is kept flush with the
  left margin; only the module body is indented.
- Continuous assignments align both the operator and the trailing `;`.
- Compiler directives and text macros (`` `define ``, `` `ifdef ``,
  `` `include ``, `` `timescale ``, `` `default_nettype `` …) are copied
  byte-for-byte.
- Block comments are reproduced verbatim, including their interior indentation.
- Files that fail to parse are left untouched by default, so incomplete code is
  never rewritten by a formatter that could not fully understand it.
- Command line entry point (`tools/sv-fmt.js`) with a `--check` mode for CI.
- 209 assertions covering idempotence, losslessness and structural balance,
  including literals that contain `begin` / `end`, multi-line block comments,
  UVM classes, tab indentation, empty input and syntax-error input.
- Prebuilt native bindings for Windows, macOS and Linux on both x64 and arm64.

[0.1.0]: https://github.com/yzt000000/sv-formatter/releases/tag/v0.1.0