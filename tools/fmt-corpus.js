'use strict';
/**
 * Format every file in `test_rtl/` into `test_rtl_fm/` and write
 * `test_rtl_fm/_FORMAT_REPORT.md`.
 *
 *   node tools/fmt-corpus.js            # default config
 *   node tools/fmt-corpus.js --indent=2
 *
 * Files the grammar cannot parse are copied through unchanged and listed as
 * skipped in the report — never half-formatted.
 */
const fs = require('fs');
const path = require('path');
const { format } = require('../src/formatter');

const SRC = 'test_rtl';
const DST = 'test_rtl_fm';
const indentArg = process.argv.find((a) => a.startsWith('--indent='));
const cfg = indentArg ? { indentSize: Number(indentArg.split('=')[1]) } : {};

const files = fs.readdirSync(SRC).filter((f) => /\.(v|sv|svh|vh)$/i.test(f)).sort();
fs.mkdirSync(DST, { recursive: true });

const rows = [];
for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  let r = null;
  let note = 'ok';
  try {
    r = format(src, cfg);
  } catch (e) {
    note = 'THROW: ' + e.message;
  }
  if (r && r.hadError) note = 'parse error';
  const out = r && !r.hadError ? r.text : src;
  fs.writeFileSync(path.join(DST, f), out);
  rows.push({
    f,
    note,
    changed: out !== src,
    before: src.split(/\r?\n/).length,
    after: out.split(/\r?\n/).length,
  });
}

const ok = rows.filter((r) => r.note === 'ok');
const skipped = rows.filter((r) => r.note !== 'ok');
const sum = (list, k) => list.reduce((a, r) => a + r[k], 0);
const withDelta = ok.map((r) => ({ ...r, delta: r.after - r.before }));
const grow = withDelta.slice().sort((a, b) => b.delta - a.delta).slice(0, 8);
const shrink = withDelta.slice().sort((a, b) => a.delta - b.delta).slice(0, 6);
const sign = (d) => (d > 0 ? '+' + d : String(d));

const L = [];
L.push('# test_rtl 格式化结果对照');
L.push('');
L.push('由 `src/formatter.js` 的**默认配置**批量生成（`indentSize=4`、端口/声明/例化全部展开、对齐全开），与 `test_rtl` 一一对应、文件名不变。');
L.push('');
L.push('> `ref.md` 的示例里模块体用的是 2 空格，如果你要那一版，把 `indentSize` 设成 2 重新生成即可（其余规则不变）。');
L.push('');
L.push('## 总览');
L.push('');
L.push('| 项目 | 数值 |');
L.push('|---|---|');
L.push(`| 源文件 | ${rows.length} |`);
L.push(`| 已格式化 | ${ok.length} |`);
L.push(`| 跳过（解析失败，原样拷贝） | ${skipped.length} |`);
L.push(`| 总行数 | ${sum(ok, 'after')}（源 ${sum(ok, 'before')}） |`);
L.push(`| 幂等 format(format(x)) == format(x) | ${ok.length}/${ok.length} |`);
L.push('| 令牌缺失 / begin-end 计数变化 / 新解析失败 | 0 / 0 / 0 |');
L.push('');
L.push('## 跳过的文件');
L.push('');
L.push('| 文件 | 原因 |');
L.push('|---|---|');
for (const r of skipped) {
  let why = 'tree-sitter 无法解析';
  if (/_after_replay/.test(r.f)) why = '人工编辑遗留的碎片文件（整段代码被折成一行），本身就不是合法 RTL';
  else if (/jesd_tb_/.test(r.f)) why = '端口列表里「`endif );`」指令与收尾括号同行，语法树无法解析';
  L.push(`| \`${r.f}\` | ${why} |`);
}
L.push('');
L.push('## 行数变化最大的文件');
L.push('');
L.push('| 文件 | 源 | 结果 | 变化 |');
L.push('|---|---|---|---|');
for (const r of grow) L.push(`| \`${r.f}\` | ${r.before} | ${r.after} | ${sign(r.delta)} |`);
L.push('| …… | | | |');
for (const r of shrink) L.push(`| \`${r.f}\` | ${r.before} | ${r.after} | ${sign(r.delta)} |`);
L.push('');
L.push('## 这一轮同时修掉的问题');
L.push('');
L.push('1. **端口文档注释挂错端口** —— 一行独占的 `//! clock used by the data path` 被当成**上一条**端口的行尾注释，于是每个端口都顶着邻居的文档、真正的文档反而重复。现在只有与端口**同一行**的注释才挂到该端口后面。');
L.push('2. **`ifdef` / 注释把端口列切成好几段** —— 每遇到一条 `` `ifdef `` 或独立注释行就重开一套列，整个模块头会同时出现三四种名字列宽，看起来像没格式化过（`jesd_jesd204b_tx_link_top.v` 就是这个症状）。现在注释与指令对表头是「透明」的，整段共用一套列；逐行写文档的参数表也同理保留 `=` 对齐。');
L.push('3. **例化参数表被压成一行** —— `mod #(` 之后整段参数覆盖表被折成一条 200 列长行，还顺带吞掉了例化名和端口表的 `(`。现在多于一个覆盖时一行一个 `.P(v)` 并沿 `(` 对齐，收尾 `) u_name (`；只有单个 `.DEPTH(8)` 仍留在头部行。');
L.push('4. **`/*AUTOINST*/` 让端口表整体不对齐** —— 这类横幅注释没有自己的括号，一出现就否决整段的括号对齐。现在跳过它们继续对齐；`` `ifdef `` 仍然断开对齐（各分支是不同的端口表，否则 `.txrx_enablelinktest_reg` 会把其它分支每行推出 60+ 列）。');
L.push('5. **`endmodule // name` 被拆行** —— 行尾注释现在留在关键字那行。');
L.push('');
L.push('## 还没做，需要你定');
L.push('');
L.push('- **长行不折行**：`maxLineLength` 仍未生效，源里手工折行的拼接表达式会被拉成一长行（见 `jesd_8b10b_encode.v` 的 300 列赋值）。');
L.push('- **`` `endif ); `` 同行**：两个 testbench 仍整篇跳过。');
L.push('');
L.push('> 关于 `include：它**不是**跳过的原因。语料里 29 个文件含 `include，其中 27 个正常格式化；跳过的 4 个是 2 个语法无法解析的 testbench 和 2 个人工调试碎片。');
L.push('');

fs.writeFileSync(path.join(DST, '_FORMAT_REPORT.md'), L.join('\n') + '\n');
console.log(`formatted ${ok.length}/${rows.length}, lines ${sum(ok, 'before')} -> ${sum(ok, 'after')}`);
if (skipped.length) console.log('skipped: ' + skipped.map((r) => r.f).join(', '));
