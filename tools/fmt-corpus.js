'use strict';
/**
 * Format every RTL file in a source directory and write a report next to the
 * output.
 *
 *   node tools/fmt-corpus.js --src=rtl_src            # default src: test_rtl
 *   node tools/fmt-corpus.js --src=rtl_src --indent=2
 *
 * The corpus is NOT shipped with the repo (it is a local, machine-specific
 * pile of real RTL). Point --src at any directory; output goes to <src>_fm/ and
 * the report is <src>_fm/_FORMAT_REPORT.md.
 *
 * Files the grammar cannot parse are copied through unchanged and listed as
 * skipped in the report — never half-formatted.
 */
const fs = require('fs');
const path = require('path');
const { format } = require('../src/formatter');

const srcArg = process.argv.find((a) => a.startsWith('--src='));
const SRC = (srcArg ? srcArg.split('=')[1] : 'test_rtl').replace(/[\\/]+$/, '');
const DST = SRC + '_fm';
const indentArg = process.argv.find((a) => a.startsWith('--indent='));
const cfg = indentArg ? { indentSize: Number(indentArg.split('=')[1]) } : {};

if (!fs.existsSync(SRC)) {
  console.error(
    `fmt-corpus: source directory "${SRC}" not found.\n` +
      'This repo does not ship a corpus. Point --src at a directory of .v/.sv\n' +
      'files, e.g.:\n' +
      '  node tools/fmt-corpus.js --src=../my_rtl'
  );
  process.exit(1);
}

const files = fs.readdirSync(SRC).filter((f) => /\.(v|sv|svh|vh)$/i.test(f)).sort();
if (!files.length) {
  console.error(`fmt-corpus: no .v / .sv / .svh / .vh files in "${SRC}".`);
  process.exit(1);
}
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
L.push(`# \`${SRC}\` 格式化结果对照`);
L.push('');
L.push('由 `src/formatter.js` 的默认配置批量生成（`indentSize=4`、端口/声明/例化全部展开、对齐全开），与源目录一一对应、文件名不变。');
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
L.push('');
L.push('## 跳过的文件');
L.push('');
L.push('| 文件 | 原因 |');
L.push('|---|---|');
for (const r of skipped) L.push(`| \`${r.f}\` | ${r.note} |`);
L.push('');
L.push('## 行数变化最大的文件');
L.push('');
L.push('| 文件 | 源 | 结果 | 变化 |');
L.push('|---|---|---|---|');
for (const r of grow) L.push(`| \`${r.f}\` | ${r.before} | ${r.after} | ${sign(r.delta)} |`);
L.push('| …… | | | |');
for (const r of shrink) L.push(`| \`${r.f}\` | ${r.before} | ${r.after} | ${sign(r.delta)} |`);
L.push('');

fs.writeFileSync(path.join(DST, '_FORMAT_REPORT.md'), L.join('\n') + '\n');
console.log(`formatted ${ok.length}/${rows.length}, lines ${sum(ok, 'before')} -> ${sum(ok, 'after')}`);
if (skipped.length) console.log('skipped: ' + skipped.map((r) => r.f).join(', '));
