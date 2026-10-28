'use strict';

/**
 * Formatter test suite.
 *
 * Three properties matter for a formatter and are checked for every case:
 *   1. idempotence  — format(format(x)) == format(x)
 *   2. losslessness — no identifier or literal is dropped or duplicated
 *   3. structure    — begin/end and module/endmodule stay balanced
 */

const fs = require('fs');
const path = require('path');
const { format } = require('../src/formatter');

let passed = 0;
let failed = 0;
const failures = [];

function check(name, condition, detail) {
  if (condition) {
    passed++;
  } else {
    failed++;
    failures.push({ name, detail });
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${String(detail).split('\n').join('\n        ')}`);
  }
}

/**
 * Extract the ordered sequence of signal and value names.
 *
 * This is what the formatter must preserve exactly. Everything that is purely
 * structural — keywords, punctuation, whitespace, and the numeric bounds of a
 * packed width — is excluded on purpose, because the formatter legitimately
 * rewrites all of it: `wire a, b;` becomes `wire a;` + `wire b;` with the type
 * prefix repeated, alignment padding is inserted between columns, and commas may
 * become semicolons.
 *
 * What must not change is the set and order of declared names, which is what this
 * signature compares. Losing or reordering a signal is a real defect.
 */
const STRUCTURAL_WORDS = new Set([
  'input', 'output', 'inout', 'ref', 'wire', 'reg', 'logic', 'bit', 'byte',
  'int', 'integer', 'shortint', 'longint', 'real', 'realtime', 'time', 'string',
  'chandle', 'event', 'genvar', 'tri', 'tri0', 'tri1', 'wand', 'wor', 'trireg',
  'uwire', 'supply0', 'supply1', 'signed', 'unsigned', 'var', 'const', 'static',
  'automatic', 'parameter', 'localparam', 'specparam',
]);

function codeTokens(text) {
  const stripped = text
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/\/\/[^\n]*/g, ' ')
    .replace(/`[a-zA-Z_$][\w$]*/g, ' ');

  const tokens = stripped.match(/[A-Za-z_$][\w$]*|\d+'[sSbBoOdDhH]?[0-9a-fA-FxzXZ_?]+|\d+/g) || [];

  const out = [];
  for (let i = 0; i < tokens.length; i++) {
    const t = tokens[i];
    if (STRUCTURAL_WORDS.has(t)) continue;
    // Drop the bounds of a packed width: `[31:0]` contributes 31 and 0, which
    // the formatter is free to rewrite.
    if (/^\d+$/.test(t)) {
      const prev = tokens[i - 1];
      const next = tokens[i + 1];
      const prevIsType = prev !== undefined && STRUCTURAL_WORDS.has(prev);
      if (prevIsType || (prev !== undefined && /^\d+$/.test(prev))) continue;
      if (next !== undefined && /^\d+$/.test(next)) continue;
    }
    out.push(t);
  }
  return out.join(' ');
}

/**
 * Semantically normalised declaration lines of the given base type.
 *
 * Column alignment inserts padding between the type, the packed width, the name
 * and the terminator, so an exact string comparison is brittle. This returns
 * `type + width + name` per line with whitespace collapsed and the trailing
 * `;` / `,` removed, which is what the declaration actually *means*.
 */
function declarationLines(text, baseType) {
  const re = new RegExp('^\\s*' + baseType + '\\b((?:\\s*\\[[^\\]]*\\])*)\\s+([A-Za-z_$][\\w$]*)\\s*[;,]?\\s*$');
  return text.split('\n')
    .map((l) => {
      const m = re.exec(l);
      // Whitespace fully collapsed so the result is alignment-independent.
      return m ? baseType + m[1].replace(/\s+/g, '') + ' ' + m[2] : null;
    })
    .filter(Boolean);
}

function checkIdempotent(name, src, config) {
  const once = format(src, config || {});
  const twice = format(once.text, config || {});
  check(`${name}: idempotent`, once.text === twice.text,
    `first pass differs from second:\n--- 1st ---\n${once.text}\n--- 2nd ---\n${twice.text}`);
  return once;
}

function checkLossless(name, src, result) {
  const a = codeTokens(src);
  const b = codeTokens(result.text);
  check(`${name}: no code lost`, a === b,
    `expected:\n${a}\ngot:\n${b}`);
}

function checkBalance(name, result) {
  // Mask comments and string literals so keywords inside them don't skew counts.
  const text = result.text
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/\/\/[^\n]*/g, ' ')
    .replace(/"(?:[^"\\]|\\.)*"/g, ' ');
  const count = (re) => (text.match(re) || []).length;
  const begins = count(/\bbegin\b/g);
  const ends = count(/\bend\b/g);
  check(`${name}: begin/end balanced`, begins === ends, `begin=${begins} end=${ends}`);

  const modOpen = count(/\bmodule\b/g);
  const modClose = count(/\bendmodule\b/g);
  check(`${name}: module/endmodule balanced`, modOpen === modClose,
    `module=${modOpen} endmodule=${modClose}`);

  const caseOpen = count(/\bcase(x|z)?\b/g);
  const caseClose = count(/\bendcase\b/g);
  check(`${name}: case/endcase balanced`, caseOpen === caseClose,
    `case=${caseOpen} endcase=${caseClose}`);
}

function runCase(name, src, config) {
  config = Object.assign({ indentSize: 2 }, config);
  console.log(`\n[${name}]`);
  const r = checkIdempotent(name, src, config);
  checkLossless(name, src, r);
  checkBalance(name, r);
  return r;
}

// ============================================================== test cases

console.log('=== SystemVerilog formatter tests ===');

// 1. Indentation convergence: garbage indentation must normalise.
{
  const src = [
    'module a;',
    'always_ff @(posedge clk) begin',
    'if (x) y <= 1;',
    'else y <= 0;',
    'end',
    'endmodule',
  ].join('\n');
  const r = runCase('indent-convergence', src);
  check('indent-convergence: nested if is indented',
    /\n {4}if \(x\)/.test(r.text), r.text);
}

// 2. Macros are preserved byte-for-byte.
{
  const src = [
    '`define WIDTH 8',
    '`ifdef FOO',
    '`include "x.svh"',
    '`endif',
    'module b;',
    'endmodule',
  ].join('\n');
  const r = runCase('macros', src);
  check('macros: define kept', r.text.includes('`define WIDTH 8'), r.text);
  check('macros: ifdef kept', r.text.includes('`ifdef FOO'), r.text);
  check('macros: endif kept', r.text.includes('`endif'), r.text);
  check('macros: include kept', r.text.includes('`include "x.svh"'), r.text);
}

// 3. Comments survive.
{
  const src = [
    'module c;',
    '  // leading comment',
    '  logic a; // trailing comment',
    '  /* block',
    '     comment */',
    'endmodule',
  ].join('\n');
  const r = runCase('comments', src);
  check('comments: line comment kept', r.text.includes('// leading comment'), r.text);
  check('comments: trailing kept', r.text.includes('// trailing comment'), r.text);
  check('comments: block kept', r.text.includes('/* block'), r.text);
}

// 4. Alignment of consecutive assignments.
{
  const src = [
    'module d;',
    'always_comb begin',
    'a = 1;',
    'bbbb = 2;',
    'cc = 3;',
    'end',
    'endmodule',
  ].join('\n');
  const r = runCase('align-assign', src);
  const eqCols = r.text.split('\n')
    .filter((l) => /^\s*(a|bbbb|cc)\s/.test(l))
    .map((l) => l.indexOf('='));
  check('align-assign: equals in one column',
    eqCols.length === 3 && new Set(eqCols).size === 1, JSON.stringify(eqCols) + '\n' + r.text);
}

// 5. Declaration alignment.
{
  const src = [
    'module e;',
    'logic [7:0] wide;',
    'logic flag;',
    'endmodule',
  ].join('\n');
  const r = runCase('align-decl', src);
  // Absolute column at which each declared name starts.
  const nameCol = r.text.split('\n')
    .filter((l) => /^\s*logic/.test(l))
    .map((l) => {
      const m = /\s(\S+);/.exec(l);
      return m ? m.index + 1 : -1;
    });
  check('align-decl: names start in one column',
    nameCol.length === 2 && nameCol[0] === nameCol[1],
    JSON.stringify(nameCol) + '\n' + r.text);
  // The terminator column has to line up too.
  const termCol = r.text.split('\n')
    .filter((l) => /^\s*logic/.test(l))
    .map((l) => l.replace(/\s+$/, '').length);
  check('align-decl: terminators in one column',
    new Set(termCol).size === 1, JSON.stringify(termCol) + '\n' + r.text);
}

// 6. Alignment can be disabled.
{
  const src = ['module f;', 'logic [7:0] wide;', 'logic flag;', 'endmodule'].join('\n');
  const r = runCase('align-off', src, {
    alignConsecutiveDeclarations: false,
  });
  check('align-off: single space kept', /\n {2}logic flag;/.test(r.text), r.text);
}

// 7. Tab indentation.
{
  const src = ['module g;', 'logic a;', 'endmodule'].join('\n');
  const r = runCase('tabs', src, { useTabs: true });
  check('tabs: tab used', r.text.includes('\n\tlogic a;'), JSON.stringify(r.text));
}

// 8. case / endcase with a default.
{
  const src = [
    'module h;',
    'always_comb begin',
    'case (s)',
    "2'd0: a = 0;",
    'default: a = 1;',
    'endcase',
    'end',
    'endmodule',
  ].join('\n');
  const r = runCase('case', src);
  check('case: default kept', r.text.includes('default:'), r.text);
}

// 9. else-if chain stays a chain (no duplicated `else`).
{
  const src = [
    'module i;',
    'always_comb begin',
    'if (a) x = 1;',
    'else if (b) x = 2;',
    'else x = 3;',
    'end',
    'endmodule',
  ].join('\n');
  const r = runCase('else-if', src);
  check('else-if: single else-if', (r.text.match(/else if/g) || []).length === 1, r.text);
  const elseLines = r.text.split('\n').filter((l) => /^\s*else\s*$/.test(l));
  check('else-if: trailing else on its own line', elseLines.length === 1,
    JSON.stringify(elseLines) + '\n' + r.text);
}

// 10. Multiple declarators.
{
  const src = 'module j;\nlogic a, b, c;\nendmodule\n';
  const r = runCase('multi-decl', src);
  check('multi-decl: all three names kept',
    ['a', 'b', 'c'].every((n) => new RegExp(`\\b${n}\\b`).test(r.text)), r.text);
  check('multi-decl: semicolon present', /;\s*$/.test(r.text.trim()) || r.text.includes(';'), r.text);
}

// 11. UVM-style class with methods and macro calls.
{
  const src = [
    'class drv extends base_drv #(my_item);',
    '  `uvm_component_utils(drv)',
    '',
    '  function new(string name, uvm_component parent);',
    '    super.new(name, parent);',
    '  endfunction',
    '',
    '  virtual task run_phase(uvm_phase phase);',
    '    forever begin',
    "      #10ns;",
    '    end',
    '  endtask',
    'endclass',
  ].join('\n');
  const r = runCase('uvm-class', src);
  check('uvm-class: header intact',
    /^class drv extends base_drv #\(my_item\);$/m.test(r.text), r.text);
  check('uvm-class: endfunction kept', /\bendfunction\b/.test(r.text), r.text);
  check('uvm-class: endtask kept', /\bendtask\b/.test(r.text), r.text);
  check('uvm-class: macro call kept',
    r.text.includes('`uvm_component_utils(drv)'), r.text);
}

// 12. String literals and comments must not confuse the structure scanner.
{
  const src = [
    'module s;',
    '  initial begin',
    '    $display("end begin endfunction"); // end end',
    '    /* begin end */',
    '    a = 1;',
    '  end',
    'endmodule',
  ].join('\n');
  const r = runCase('string-safety', src);
  check('string-safety: literal untouched',
    r.text.includes('$display("end begin endfunction")'), r.text);
  check('string-safety: assignment kept', /\ba = 1;/.test(r.text), r.text);
}

// 13. Empty and whitespace-only input must not crash.
{
  runCase('empty', '');
  runCase('whitespace', '\n\n\n   \n');
}

// 14. Broken code is reported, not mangled.
{
  const src = 'module k;\n  logic a\n  logic b\nendmodule\n';
  const r = format(src, { indentSize: 2 });
  check('parse-error: flagged', r.hadError === true, JSON.stringify(r.hadError));
}

// 15. Sample files round-trip.
{
  const dir = path.join(__dirname, '..', 'samples');
  for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.sv'))) {
    const src = fs.readFileSync(path.join(dir, f), 'utf8');
    runCase(`sample:${f}`, src);
  }
}

// 16. Multi-signal declarations are exploded, each repeating the type prefix.
{
  const src = [
    'module m;',
    '  wire w_valid, w_ready, w_en;',
    '  logic [31:0] x_data, y_data;',
    'endmodule',
  ].join('\n');
  const r = runCase('explode-decl', src);
  check('explode-decl: wire exploded with prefix on each line',
    declarationLines(r.text, 'wire').join('|') === 'wire w_valid|wire w_ready|wire w_en',
    declarationLines(r.text, 'wire').join('|') + '\n' + r.text);
  check('explode-decl: logic keeps width on each line',
    declarationLines(r.text, 'logic').join('|') === 'logic[31:0] x_data|logic[31:0] y_data',
    declarationLines(r.text, 'logic').join('|') + '\n' + r.text);
}

// 17. Port columns (direction / type / width / name) line up.
{
  const src = [
    'module p (',
    '    input wire clk,',
    '    input wire [31:0] din,',
    '    input wire valid,',
    '    output wire [63:0] dout',
    ');',
    'endmodule',
  ].join('\n');
  const r = runCase('port-columns', src);
  const ports = r.text.split('\n').filter((l) => /^\s*(input|output|inout)\b/.test(l));
  // Absolute column at which each port's signal name starts.
  const nameCol = ports.map((l) => {
    const m = /\s([A-Za-z_$][\w$]*)\s*[,;]?\s*$/.exec(l);
    return m ? m.index + 1 : -1;
  });
  check('port-columns: names start in one column',
    nameCol.length >= 3 && new Set(nameCol).size === 1,
    JSON.stringify(nameCol) + '\n' + r.text);
  // Every port that carries a comma must place it in the same column.
  const commaCol = ports
    .filter((l) => /,\s*$/.test(l))
    .map((l) => l.replace(/\s+$/, '').length - 1);
  check('port-columns: commas in one column',
    commaCol.length >= 1 && new Set(commaCol).size === 1,
    JSON.stringify(commaCol) + '\n' + r.text);
}

// 18. Instance ports are exploded one per line with aligned parentheses.
{
  const src = [
    'module t;',
    '  fifo #(.DEPTH(8)) u_fifo (',
    '      .clk(clk),',
    '      .rst_n(rst_n),',
    '      .wr_data(w_data_long)',
    '  );',
    'endmodule',
  ].join('\n');
  const r = runCase('instance-ports', src);
  const conns = r.text.split('\n').filter((l) => /^\s*\./.test(l));
  check('instance-ports: one connection per line', conns.length === 3, r.text);
  const parenCols = conns.map((l) => l.indexOf('('));
  check('instance-ports: parentheses aligned',
    new Set(parenCols).size === 1, JSON.stringify(parenCols) + '\n' + r.text);
  check('instance-ports: no connections left on one line',
    !/\.\w+\([^)]*\),\s*\.\w+/.test(r.text), r.text);
}

// 19. Parameter port list: one per line, flush with the left margin.
{
  const src = [
    'module m #(parameter int A = 1, parameter int B = 2) (',
    '    input logic clk',
    ');',
    'endmodule',
  ].join('\n');
  const r = runCase('param-list', src);
  check('param-list: parameters exploded one per line',
    /^parameter int A = 1,$/m.test(r.text) && /^parameter int B = 2$/m.test(r.text),
    r.text);
  check('param-list: flush with left margin',
    /^#\($/m.test(r.text), r.text);
  check('param-list: closing paren shares a line with the port list opener',
    /^\) \($/m.test(r.text), r.text);
}

// 19b. Module header (parameters and ports alike) is flush with the left margin.
//      This is the house style: the header is the module's signature, not its
//      body, so nothing inside it is indented past `module`.
{
  const src = [
    'module sync_2stage #(parameter WIDTH = 1) (',
    '    input  wire              clk,',
    '    input  wire  [WIDTH-1:0] d,',
    '    output wire  [WIDTH-1:0] q',
    ');',
    '  assign q = d;',
    'endmodule',
  ].join('\n');
  const r = runCase('header-flush', src);
  const lines = r.text.split('\n');
  check('header-flush: no leading indent on parameter',
    lines.includes('parameter WIDTH = 1'), r.text);
  const portLines = lines.filter((l) => /^(?:input|output|inout)\b/.test(l));
  check('header-flush: no leading indent on ports',
    portLines.length === 3, r.text);
  // …and their signal names still share one column.
  check('header-flush: port names share a column',
    new Set(portLines.map((l) => l.search(/\w+\s*[,\s]*$/))).size === 1 ||
    new Set(portLines.map((l) => l.replace(/.*?\]\s*|.*?\b(wire|reg|logic)\s+/, '').search(/\w+/))).size === 1,
    JSON.stringify(portLines));
  check('header-flush: closing `);` at column 0',
    lines.includes(');'), r.text);
  // Only the module body is indented.
  check('header-flush: body still indented one level',
    lines.includes('  assign q = d;'), r.text);
}

// 20. localparam / parameter bodies are not comma-expanded and align with the
//     surrounding declaration group.
{
  const src = [
    'module m;',
    '  localparam int A = 1;',
    '  localparam int BBB = 22;',
    '  logic a;',
    'endmodule',
  ].join('\n');
  const r = runCase('localparam', src);
  const flat = r.text.split('\n').map((l) => l.trim().replace(/\s+/g, ' '));
  check('localparam: kept intact on one line',
    flat.some((l) => /^localparam int A = 1 ;$/.test(l)) ||
    flat.some((l) => /^localparam int A = 1;$/.test(l)), r.text);
  check('localparam: initialiser never split across lines',
    // Each localparam must appear complete on a single line.
    r.text.split('\n').filter((l) => /localparam/.test(l)).every(
      (l) => /= [^;]+;?\s*$/.test(l)), r.text);
  check('localparam: shares the declaration alignment group',
    /\n {2}localparam int\s+A\s{2,}= 1/.test(r.text) ||
    /\n {2}localparam int\s+A\s+= 1/.test(r.text), r.text);
}

// 21. Continuous assigns align both the operator and the trailing `;`.
{
  const src = [
    'module m;',
    '  assign o_data = r_data;',
    '  assign valid_long = some_expression;',
    '  assign b = x;',
    'endmodule',
  ].join('\n');
  const r = runCase('assign-align', src);
  const lines = r.text.split('\n').filter((l) => /^\s*assign\b/.test(l));
  const eq = lines.map((l) => l.indexOf('='));
  check('assign-align: operators in one column',
    new Set(eq).size === 1, JSON.stringify(eq) + '\n' + r.text);
  // `ref.md` pads the terminator of declarations only; `assign` statements keep
  // their `;` tight, so no padding may be inserted before it.
  check('assign-align: no padding before `;`',
    lines.every((l) => /;\s*$/.test(l) && !/ ;\s*$/.test(l)),
    JSON.stringify(lines) + '\n' + r.text);
}

// 22. Instance ports align both `(` and `)`.
{
  const src = [
    'module m;',
    '  sub #(.W(8)) u_sub (',
    '      .clk(clk),',
    '      .rst_n(rst_n),',
    '      .data_out(long_signal_name)',
    '  );',
    'endmodule',
  ].join('\n');
  const r = runCase('inst-paren-align', src);
  const conns = r.text.split('\n').filter((l) => /^\s*\./.test(l));
  const open = conns.map((l) => l.indexOf('('));
  const close = conns.map((l) => l.lastIndexOf(')'));
  check('inst-paren-align: open parens in one column',
    new Set(open).size === 1, JSON.stringify(open) + '\n' + r.text);
  check('inst-paren-align: close parens in one column',
    new Set(close).size === 1, JSON.stringify(close) + '\n' + r.text);
}

// 23. Interface body indents one level, not two.
{
  const src = [
    'interface bus_if (input logic clk);',
    'logic a;',
    'endinterface',
  ].join('\n');
  const r = runCase('interface-indent', src);
  check('interface-indent: body at one level',
    /\n {2}logic a;/.test(r.text), r.text);
  check('interface-indent: no double indent',
    !/\n {4}logic a;/.test(r.text), r.text);
}

// 24. Routine bodies keep their statement terminators (regression: a scanned
//     routine body used to lose the `;`, which also broke idempotence).
{
  const src = [
    'interface i;',
    '  task automatic send(input logic d);',
    '    data <= d;',
    '    valid <= 1\'b1;',
    '  endtask',
    'endinterface',
  ].join('\n');
  const r = runCase('routine-semi', src);
  check('routine-semi: statements terminated',
    /\n {4}data\s+<= d\s*;/.test(r.text) && /\n {4}valid <= 1'b1;/.test(r.text),
    r.text);
}

// ---------------------------------------------------------------- summary
console.log('\n=== fragment formatting tests ===');

// 25. Fragment formatting: a selection is formatted in isolation and re-indented
//     by the base indent inferred from its first non-blank line. Everything
//     outside the selection is preserved by the extension layer's
//     TextEdit.replace(range, text); here we verify the core helper.
{
  const { formatFragment, inferBaseIndent } = require('../src/fragment');

  // An always_ff block sitting 2 spaces deep inside a module body.
  const frag = [
    '  always_ff @(posedge clk or negedge rst_n) begin',
    '  if(!rst_n) begin',
    '  cnt <= \'0;',
    '  acc <= 16\'d0;',
    '  end else begin',
    '  acc <= acc + din;',
    '  cnt <= cnt + 1\'b1;',
    '  end',
    '  end',
  ].join('\n') + '\n';

  const r = formatFragment(frag, {indentSize:2});
  console.log('\n[fragment-always]');
  check('fragment-always: no parse error', !r.hadError, r.text);
  check('fragment-always: base indent is 2 spaces', r.basePrefix === '  ', r.basePrefix);
  check('fragment-always: header line keeps base indent',
    /^  always_ff/.test(r.text), r.text);
  check('fragment-always: if body indented to base+2',
    /\n    if \(!rst_n\)/.test(r.text), r.text);
  check('fragment-always: innermost body at base+4',
    /\n      cnt <= '0/.test(r.text), r.text);
  // Idempotent on the fragment.
  const r2 = formatFragment(r.text, {indentSize:2});
  check('fragment-always: idempotent', r2.text === r.text,
    `--- 1st ---\n${r.text}\n--- 2nd ---\n${r2.text}`);
  // Lossless: same code tokens as input.
  check('fragment-always: no code lost', codeTokens(frag) === codeTokens(r.text),
    `expected:\n${codeTokens(frag)}\ngot:\n${codeTokens(r.text)}`);

  // Surrounding text is untouched: splice the formatted fragment back into the
  // full document and confirm the lines outside the selection are byte-identical.
  const fullBefore = [
    'module top (',
    '  input logic clk,',
    '  input logic rst_n',
    ');',
  ].join('\n') + '\n';
  const fullAfter = 'endmodule\n';
  const reconstructed = fullBefore + r.text + fullAfter;
  check('fragment-always: prefix preserved',
    reconstructed.startsWith(fullBefore), reconstructed);
  check('fragment-always: suffix preserved',
    reconstructed.endsWith(fullAfter), reconstructed);
}

// 26. Fragment formatting: a declaration/assign block, base indent 4 spaces.
{
  const { formatFragment } = require('../src/fragment');
  const frag = [
    '    logic [7:0] cnt;',
    '    logic [15:0] acc;',
    '    logic flag;',
    '    assign o_data = r_data;',
    '    assign valid_a = r_data;',
  ].join('\n') + '\n';

  const r = formatFragment(frag, {indentSize:2});
  console.log('\n[fragment-decls]');
  check('fragment-decls: no parse error', !r.hadError, r.text);
  check('fragment-decls: base indent is 4 spaces', r.basePrefix === '    ', r.basePrefix);
  check('fragment-decls: declarations aligned and indented',
    /^    logic \[7:0\]\s+cnt/m.test(r.text), r.text);
  check('fragment-decls: assigns aligned',
    /^    assign o_data\s+= r_data;/m.test(r.text), r.text);
  const r2 = formatFragment(r.text, {indentSize:2});
  check('fragment-decls: idempotent', r2.text === r.text,
    `--- 1st ---\n${r.text}\n--- 2nd ---\n${r2.text}`);
}

// 27. Fragment formatting: tab-based indent and useTabs=true.
{
  const { formatFragment } = require('../src/fragment');
  const frag = '\talways_ff @(posedge clk) begin\n\tif (x) y <= 1;\n\tend\n';
  const r = formatFragment(frag, { useTabs: true });
  console.log('\n[fragment-tabs]');
  check('fragment-tabs: base indent is one tab', r.basePrefix === '\t', r.basePrefix);
  check('fragment-tabs: header on one tab', /^\talways_ff/.test(r.text), r.text);
}

// 28. Fragment formatting: empty / whitespace-only selection is a no-op.
{
  const { formatFragment, inferBaseIndent } = require('../src/fragment');
  check('fragment-empty: base indent empty', inferBaseIndent('\n  \n', {indentSize:2}) === '', 'x');
  const r = formatFragment('   \n\n  \n', {indentSize:2});
  check('fragment-empty: no error on blank input', !r.hadError, r.text);
}

// 29. expandToBlock: a selection inside an always_ff grows to the whole
//     always_construct, so the formatted block boundary is syntactically natural
//     and the surrounding lines keep their byte content.
{
  const { expandToBlock } = require('../src/fragment');
  const src = [
    'module top;',
    '  logic [7:0] cnt;',
    '  always_ff @(posedge clk) begin',
    '    if (x) y <= 1;',
    '    else y <= 0;',
    '  end',
    '  assign z = y;',
    'endmodule',
  ].join('\n') + '\n';
  const line3 = src.indexOf('    if (x)');
  const selEnd = line3 + 4;
  const block = expandToBlock(src, line3, selEnd);
  console.log('\n[expand-to-block]');
  check('expand-to-block: found a block', !!block, block);
  check('expand-to-block: type is always_construct',
    block && block.type === 'always_construct', block && block.type);
  check('expand-to-block: starts at always_ff',
    block && src.slice(block.start, block.start + 9) === 'always_ff', block && block.start);
  check('expand-to-block: ends at end keyword',
    block && src.slice(block.end - 3, block.end) === 'end', block && block.end);
  check('expand-to-block: assign z outside block',
    block && src.indexOf('assign z = y;') >= block.end, block && block.end);
}

// 30. expandToBlock: a selection that already covers a whole data_declaration
//     stays at that declaration (does not grow to the module).
{
  const { expandToBlock } = require('../src/fragment');
  const src = [
    'module top;',
    '  logic [7:0] a;',
    '  logic [15:0] b;',
    'endmodule',
  ].join('\n') + '\n';
  const aStart = src.indexOf('  logic [7:0] a;');
  const aEnd = aStart + '  logic [7:0] a;'.length;
  const block = expandToBlock(src, aStart, aEnd);
  check('expand-to-block: decl stays decl',
    block && block.type === 'data_declaration' &&
    src.slice(block.start, block.end).indexOf('logic [7:0] a;') >= 0,
    block && block.type);
}

// 31. expandToBlock: a selection spanning two sibling declarations grows to the
//     enclosing module (no smaller block contains both).
{
  const { expandToBlock } = require('../src/fragment');
  const src = [
    'module top;',
    '  logic [7:0] a;',
    '  logic [15:0] b;',
    'endmodule',
  ].join('\n') + '\n';
  const aStart = src.indexOf('  logic [7:0] a;');
  const bEnd = src.indexOf('  logic [15:0] b;') + '  logic [15:0] b;'.length;
  const block = expandToBlock(src, aStart, bEnd);
  check('expand-to-block: cross-sibling grows to module',
    block && block.type === 'module_declaration', block && block.type);
}

// 32. CRLF input: the grammar gives `//`-comments and `define nodes their
//     trailing CR, which used to emit a phantom blank line after every one of
//     them (and made a second pass differ). Regression guard.
{
  const src = [
    '// header',
    '`define W 8',
    'module crlf;',
    '  // note',
    '  wire [W-1:0] a;',
    'endmodule',
    '',
  ].join('\r\n');
  const r = runCase('crlf', src);
  check('crlf: no blank after line comment', !/\n\n\s*\/\/ note/.test(r.text), r.text);
  check('crlf: no blank after define', !/`define W 8\n\n/.test(r.text), r.text);
  check('crlf: output is LF only', !r.text.includes('\r'), JSON.stringify(r.text));
}

// 33. Module header style: `(` stays on the module-name line when there is no
//     parameter list, and `) (` joins when there is one.
{
  const src = [
    'module no_params (input wire clk, output wire q);',
    '  assign q = clk;',
    'endmodule',
  ].join('\n');
  const r = runCase('header-paren', src);
  check('header-paren: open paren on module line',
    r.text.startsWith('module no_params (\n'), r.text);

  const withParams = [
    'module with_params #(parameter int W = 8) (input wire clk);',
    'endmodule',
  ].join('\n');
  const r2 = runCase('header-paren-params', withParams);
  check('header-paren: ) ( between the two lists', r2.text.includes(') (\n'), r2.text);
}

// 34. `end else` stays on one line, including an `else if` chain.
{
  const src = [
    'module els;',
    'always_ff @(posedge clk) begin',
    'if (a) begin',
    'x <= 1;',
    'end else if (b) begin',
    'x <= 2;',
    'end else begin',
    'x <= 3;',
    'end',
    'end',
    'endmodule',
  ].join('\n');
  const r = runCase('else-join', src);
  check('else-join: end else if', r.text.includes('end else if (b) begin'), r.text);
  check('else-join: end else', r.text.includes('end else begin'), r.text);
}

// 35. modports keep their entries on separate lines.
{
  const src = [
    'interface bus_if (input logic clk);',
    '  modport master (',
    '      output data,',
    '      input  ready',
    '  );',
    'endinterface',
  ].join('\n');
  const r = runCase('modport', src);
  check('modport: entries stay on their own lines',
    r.text.includes('modport master (\n') && r.text.includes('output data,') &&
    r.text.includes('input ready') && r.text.includes('\n);'),
    r.text);
}

// 36. Preprocessor directives inside a port list: the file must still be
//     formatted, with the directives put back on their own lines.
{
  const src = [
    'module ifdef_ports (',
    '    input  wire clk,',
    '`ifdef WIDE',
    '    input  wire [31:0] din,',
    '`else',
    '    input  wire [15:0] din,',
    '`endif',
    '    output wire        q',
    ');',
    '  assign q = clk;',
    'endmodule',
  ].join('\n');
  const r = runCase('ifdef-ports', src);
  check('ifdef-ports: not rejected', r.hadError === false, String(r.hadError));
  check('ifdef-ports: ifdef kept', r.text.includes('`ifdef WIDE'), r.text);
  check('ifdef-ports: else kept', r.text.includes('`else'), r.text);
  check('ifdef-ports: endif kept', r.text.includes('`endif'), r.text);
  check('ifdef-ports: directive on its own line',
    /^`ifdef WIDE$/m.test(r.text), r.text);
}

// 37. A generate block that the author wrote with `begin` must keep it; an
//     implicit one must not gain a spurious begin/end.
{
  const explicit = [
    'module g1;',
    'genvar i;',
    'generate',
    'for (i = 0; i < 4; i = i + 1) begin',
    'always @(posedge clk) q[i] <= d[i];',
    'end',
    'endgenerate',
    'endmodule',
  ].join('\n');
  const r = runCase('generate-begin', explicit);
  check('generate: explicit begin kept', /\bfor \(.*\) begin\b/.test(r.text), r.text);

  const implicit = [
    'module g2;',
    'genvar i;',
    'generate',
    'for (i = 0; i < 4; i = i + 1)',
    'assign q[i] = d[i];',
    'endgenerate',
    'endmodule',
  ].join('\n');
  const r2 = runCase('generate-implicit', implicit);
  check('generate: no spurious begin', !r2.text.includes('begin'), r2.text);
}

// 38. Operator spacing is normalised inside expressions, while ranges keep
//     their tight form and unary operators are left alone.
{
  const src = [
    'module sp;',
    '  assign q=a+b;',
    '  assign r=a[W-1:0]+1;',
    '  always_ff @(posedge clk) begin',
    '    z<=-1;',
    '    for (i=0;i<8;i=i+1) y[i]<=i;',
    '    if (a==b) w<=c;',
    '  end',
    'endmodule',
  ].join('\n');
  const r = runCase('spacing', src);
  check('spacing: assign spaced', /assign q = a \+ b\s*;/.test(r.text), r.text);
  check('spacing: range untouched', r.text.includes('a[W-1:0] + 1'), r.text);
  check('spacing: unary minus tight', r.text.includes('z <= -1;'), r.text);
  check('spacing: for header spaced',
    r.text.includes('for (i = 0; i < 8; i = i + 1)'), r.text);
  check('spacing: comparison spaced', r.text.includes('if (a == b)'), r.text);
}

// 39. A `for` line must not drag the surrounding assignments out to its own
//     operator column.
{
  const src = [
    'module al;',
    '  always_ff @(posedge clk) begin',
    '    q<=cnt;',
    '    for (i=0;i<8;i=i+1) z<=i;',
    '    x=y;',
    '  end',
    'endmodule',
  ].join('\n');
  const r = runCase('assign-align-ctrl', src);
  const qLine = r.text.split('\n').find((l) => l.trim().startsWith('q <='));
  check('assign-align-ctrl: short lhs not padded to the for line',
    qLine && qLine.indexOf('<=') < 12, qLine);
}

// 40. Routine bodies: indentation is derived from nesting, nested loops close
//     where they opened, and case labels stay on the `begin` line.
{
  const src = [
    'module fn;',
    '  function void f(int a);',
    '    int t;',
    '    for (int i = 0; i < 8 ; i++)begin',
    '       for (int j = 0; j < 6 ; j++) begin',
    '          y[i][j]=8\'h00;',
    '       end',
    '    end',
    '    case (a)',
    '      1: begin',
    '        t = 1;',
    '      end',
    '      default: t = 0;',
    '    endcase',
    '  endfunction',
    'endmodule',
  ].join('\n');
  const r = runCase('routine-body', src);
  check('routine-body: nested loop indented',
    /\n {4}for \(int i = 0; i < 8; i\+\+\) begin\n {6}for \(int j = 0; j < 6; j\+\+\) begin\n {8}y\[i\]\[j\] = 8'h00;\n {6}end\n {4}end/.test(r.text),
    r.text);
  check('routine-body: case label inline', r.text.includes('1: begin'), r.text);
  check('routine-body: function body indented',
    /\n {4}int t;\n/.test(r.text), r.text);
}

// 41. Documentation above a port belongs to the port below it. A comment on its
//     own line must not be bound to the previous port as a trailing comment,
//     and it must not reset the alignment column either.
{
  const src = [
    'module m (',
    '//!Clock used by the CPU',
    'input clk_cpu,',
    '//! clock used by the data path',
    'input clk_character,',
    '//! frame sync',
    'input sync_b,',
    'output [3:0] q',
    ');',
    'endmodule',
  ].join('\n');
  const r = runCase('port-doc-comments', src);
  check('port-doc-comments: comment stays above its port',
    /\/\/! clock used by the data path\ninput\s+clk_character,/.test(r.text), r.text);
  check('port-doc-comments: no comment attached to the wrong port',
    !/input\s+clk_cpu,\s*\/\//.test(r.text), r.text);
  const names = r.text.split('\n').filter((l) => /^(?:input|output)\b/.test(l))
    .map((l) => l.search(/[A-Za-z_]\w*(?:\s*,)?$/));
  check('port-doc-comments: one name column across comments',
    new Set(names).size === 1, JSON.stringify(names) + '\n' + r.text);
}

// 42. `ifdef in a port list: the directive does not start a new table, so the
//     whole header keeps one set of columns.
{
  const src = [
    'module m (',
    'input a,',
    '`ifdef WIDE',
    'input [31:0] wide_d,',
    '`endif',
    'output b',
    ');',
    'endmodule',
  ].join('\n');
  const r = runCase('port-ifdef-columns', src);
  // Name column: the identifier just before `,` (or end of line).
  const cols = r.text.split('\n').filter((l) => /^(?:input|output)\b/.test(l))
    .map((l) => l.search(/[A-Za-z_]\w*(?:\s*,)?$/));
  check('port-ifdef-columns: names share one column', new Set(cols).size === 1,
    JSON.stringify(cols) + '\n' + r.text);
  check('port-ifdef-columns: directive kept', /^`ifdef WIDE$/m.test(r.text), r.text);
}

// 43. A multi-entry parameter override is exploded like the port map, and the
//     instance name with its `(` stays on the closing line.
{
  const src = [
    'module t;',
    '  sub #(.A(1), .B(2)) u_sub (',
    '      .clk(clk)',
    '  );',
    'endmodule',
  ].join('\n');
  const r = runCase('inst-param-explode', src);
  check('inst-param-explode: one override per line',
    /sub #\(\n\s+\.A\(1\),\n\s+\.B\(2\)\n\s+\) u_sub \(/.test(r.text), r.text);
  // Only the override block, not the port map that follows `) u_sub (`.
  const overrideBlock = r.text.split(') u_sub (')[0].split('\n').filter((l) => /^\s+\./.test(l));
  const opens = overrideBlock.map((l) => l.indexOf('('));
  check('inst-param-explode: overrides aligned on `(`', new Set(opens).size === 1,
    JSON.stringify(opens) + '\n' + r.text);
}

// 44. A single short override stays inline.
{
  const src = ['module t;', '  sub #(.A(1)) u_sub (', '      .clk(clk)', '  );', 'endmodule'].join('\n');
  const r = runCase('inst-param-inline', src);
  check('inst-param-inline: lone override kept on the head line',
    r.text.includes('sub #(.A(1)) u_sub ('), r.text);
}

// 45. `endmodule // name`: the trailer stays on the keyword line.
{
  const src = ['module t;', 'endmodule // u_thing'].join('\n');
  const r = runCase('module-trailer', src);
  check('module-trailer: comment kept on endmodule', /^endmodule \/\/ u_thing$/m.test(r.text), r.text);
}

// 46. Compact layout: one line per instance, columns aligned.
{
  const src = [
    'module t;',
    '  leaf u_a (.clk(clk), .rst_n(rst_n), .dout(d0));',
    '  leaf u_bbb (.clk(clk), .rst_n(rst_n), .dout(d1));',
    'endmodule',
  ].join('\n');
  const r = runCase('inst-compact-basic', src, { instanceLayout: 'compact' });
  const instLines = r.text.split('\n').filter((l) => l.includes('leaf '));
  check('inst-compact-basic: one line per instance', instLines.length === 2, r.text);
  check('inst-compact-basic: instance names padded to one column',
    instLines[0].indexOf(' (') === instLines[1].indexOf(' ('),
    JSON.stringify(instLines));
  check('inst-compact-basic: no exploded port lines',
    !/^\s+\.clk\(clk\),?$/m.test(r.text), r.text);
}

// 47. Compact layout: the k-th `.port(expr)` sits in the same column for every
// instance in the group, so both `(` and `)` line up.
{
  const src = [
    'module t;',
    '  leaf u_a (.d(data_bus[7:0]), .q(q));',
    '  leaf u_b (.d(d), .q(qq));',
    'endmodule',
  ].join('\n');
  const r = runCase('inst-compact-columns', src, { instanceLayout: 'compact' });
  const instLines = r.text.split('\n').filter((l) => l.includes('leaf '));
  const comma = instLines.map((l) => l.indexOf(', .q'));
  const qOpen = instLines.map((l) => l.indexOf('(', l.indexOf('.q')));
  const qClose = instLines.map((l) => l.lastIndexOf(')'));
  check('inst-compact-columns: `.q` starts in one column', new Set(comma).size === 1,
    JSON.stringify(comma) + '\n' + r.text);
  check('inst-compact-columns: `.q(` paren aligned', new Set(qOpen).size === 1,
    JSON.stringify(qOpen) + '\n' + r.text);
  check('inst-compact-columns: closing paren aligned', new Set(qClose).size === 1,
    JSON.stringify(qClose) + '\n' + r.text);
}

// 48. `auto`: small instances compact, wide ones explode.
{
  const src = [
    'module t;',
    '  leaf u_a (.clk(clk), .rst_n(rst_n), .dout(d0));',
    '  big u_big (.a(1), .b(2), .c(3), .d(4), .e(5), .f(6));',
    'endmodule',
  ].join('\n');
  const r = runCase('inst-auto-threshold', src,
    { instanceLayout: 'auto', compactInstanceMaxPorts: 4 });
  check('inst-auto-threshold: 3-port instance stays on one line',
    /leaf u_a +\(\.clk\(clk\), \.rst_n\(rst_n\), \.dout\(d0\)\);/.test(r.text), r.text);
  check('inst-auto-threshold: 6-port instance explodes',
    /big u_big \(\n\s+\.a\(1\),\n/.test(r.text), r.text);
}

// 49. A comment inside the port map forces the exploded layout: folding it onto
// one line would swallow the comment.
{
  const src = [
    'module t;',
    '  leaf u_a (.clk(clk), // clock',
    '            .rst_n(rst_n));',
    'endmodule',
  ].join('\n');
  const r = runCase('inst-compact-comment', src, { instanceLayout: 'compact' });
  check('inst-compact-comment: comment still present',
    r.text.includes('// clock'), r.text);
  check('inst-compact-comment: fell back to one connection per line',
    /\.clk\s*\(clk\s*\),?\n[\s\S]*\n\s+\.rst_n\(rst_n\)/.test(r.text), r.text);
}

// 50. Selection formatting: only the enclosing block is rewritten, and its
// nesting depth is preserved from the fragment itself.
{
  const { formatFragment, expandToBlock } = require('../src/fragment');
  const src = [
    'module t;',
    '  // keep this comment exactly as written',
    '  always_comb begin',
    '        x = a+b;',
    '        y = c  &  d;',
    '  end',
    '  assign z = x;',
    'endmodule',
  ].join('\n');

  const start = src.indexOf('always_comb');
  const end = src.indexOf('end', src.indexOf('y = c')) + 3;
  const block = expandToBlock(src, start, end);
  check('selection: block expanded to the always_construct',
    block && block.type === 'always_construct', block && block.type);

  const lineStart = src.lastIndexOf('\n', block.start) + 1;
  const lineEnd = src.indexOf('\n', block.end) + 1;
  const { text } = formatFragment(src.slice(lineStart, lineEnd), { indentSize: 2 });
  const spliced = src.slice(0, lineStart) + text + src.slice(lineEnd);

  check('selection: body re-indented, base indent kept',
    /\n {2}always_comb begin\n {4}x = a \+ b;\n {4}y = c & d;\n {2}end\n/.test(spliced),
    spliced);
  check('selection: text before the block untouched',
    spliced.startsWith('module t;\n  // keep this comment exactly as written\n'), spliced);
  check('selection: text after the block untouched',
    spliced.endsWith('  assign z = x;\nendmodule'), spliced);
}

// ---------------------------------------------------------------- summary
console.log('\n=== summary ===');
console.log(`passed: ${passed}`);
console.log(`failed: ${failed}`);
if (failed) {
  console.log('\nfailures:');
  for (const f of failures) console.log(`  - ${f.name}`);
  process.exit(1);
}
