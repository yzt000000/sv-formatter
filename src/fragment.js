'use strict';

/**
 * Selection-only (fragment) formatting.
 *
 * The core engine in formatter.js always formats a complete translation unit:
 * its indentation and alignment decisions depend on enclosing blocks, so
 * running it on an arbitrary slice would lose the surrounding nesting and, when
 * the fragment's line count changes, leave the neighbouring code visually
 * inconsistent. This module implements two things:
 *
 *   1. `expandToBlock(source, s, e)` — parse the whole document and grow the
 *      requested range to the smallest *block-level* syntax node that contains
 *      it (a node the engine's `topLevel` switch knows how to format, e.g. an
 *      `always_construct`, a `data_declaration`, a `module_declaration` …). The
 *      block boundary is syntactically natural, so re-formatting it never
 *      dangles indentation into the surrounding text, and line-count changes
 *      inside the block do not realign anything outside it.
 *
 *   2. `formatFragment(text, config)` — run the engine on the (already expanded)
 *      fragment in isolation, then re-prepend the base indent inferred from the
 *      fragment's first non-blank line so the result keeps its nesting depth.
 *
 * Everything outside the expanded block is preserved byte-for-byte by the
 * caller's TextEdit.replace(range, text).
 */

const Parser = require('tree-sitter');
const SV = require('tree-sitter-systemverilog');

const { format } = require('./formatter');
const { resolveConfig } = require('./config');

let _parser = null;
function getParser() {
  if (!_parser) {
    _parser = new Parser();
    _parser.setLanguage(SV);
  }
  return _parser;
}

/**
 * Node types the engine's `topLevel` switch handles with a dedicated emitter
 * (i.e. not the `default` verbatim fallback). Only these can be formatted in
 * isolation and produce a canonical result; formatting a bare `statement` or
 * `expression` would collapse it to one line via the default branch.
 */
const BLOCK_TYPES = new Set([
  'module_declaration', 'interface_declaration', 'program_declaration',
  'package_declaration', 'primitive_declaration', 'config_declaration',
  'class_declaration',
  'data_declaration', 'net_declaration', 'parameter_declaration',
  'local_parameter_declaration', 'specparam_declaration',
  'continuous_assign',
  'always_construct', 'initial_construct', 'final_construct',
  'generate_region', 'generate_construct', 'loop_generate_construct',
  'conditional_generate_construct',
  'module_instantiation', 'udp_instantiation',
  'function_declaration', 'task_declaration', 'property_declaration',
  'sequence_declaration', 'covergroup_declaration', 'modport_declaration',
  'clocking_declaration', 'constraint_declaration', 'interface_declaration_body',
  'checker_declaration', 'genvar_declaration',
  // Preprocessor / macro roots are emitted verbatim, which is also a safe
  // standalone format.
  'text_macro_definition', 'conditional_compilation_directive',
  'include_compiler_directive', 'timescale_compiler_directive',
  'default_nettype_compiler_directive', 'resetall_compiler_directive',
  'undef_compiler_directive', 'unconnected_drive_compiler_directive',
  'nounconnected_drive_compiler_directive', 'celldefine_compiler_directive',
  'endcelldefine_compiler_directive', 'undefineall_compiler_directive',
  'line_compiler_directive', 'pragma_compiler_directive',
  'begin_keywords_compiler_directive', 'end_keywords_compiler_directive',
]);

/**
 * Smallest block-level node that contains the byte range [start, end].
 *
 * Returns { start, end, type } or null when no such node exists (e.g. the range
 * spans the whole file, or sits in an unparseable region). The walk descends
 * only into children that still contain the range, so it finds the lowest
 * covering node first; if that node is not itself a block, the recursion
 * unwinds to its nearest block-typed ancestor.
 */
function findSmallestBlock(node, s, e) {
  if (node.startIndex > s || node.endIndex < e) return null;
  for (const child of node.namedChildren) {
    if (child.startIndex <= s && child.endIndex >= e) {
      const deeper = findSmallestBlock(child, s, e);
      if (deeper) return deeper;
    }
  }
  if (BLOCK_TYPES.has(node.type)) {
    return { start: node.startIndex, end: node.endIndex, type: node.type };
  }
  return null;
}

/** Find the AST node whose span is exactly [start, end]. */
function findNodeAt(node, start, end) {
  if (node.startIndex === start && node.endIndex === end) return node;
  for (const child of node.namedChildren) {
    if (child.startIndex <= start && child.endIndex >= end) {
      const found = findNodeAt(child, start, end);
      if (found) return found;
    }
  }
  return null;
}

/** Whether a node or any descendant is an ERROR or MISSING node. */
function nodeHasError(node) {
  if (node.type === 'ERROR' || node.type === 'MISSING') return true;
  for (let i = 0; i < node.namedChildCount; i++) {
    if (nodeHasError(node.namedChild(i))) return true;
  }
  return false;
}

/**
 * Grow the selection range to the smallest block-level syntax node containing
 * it. `source` is the full document text; `start`/`end` are byte offsets of the
 * line-expanded selection. Returns null on parse failure or when the range is
 * not inside any block (caller then falls back to the raw line range).
 *
 * The selection is first collapsed to its non-whitespace content so that a
 * line range which includes leading indentation or a trailing newline still
 * matches the token-anchored node boundaries tree-sitter reports.
 */
function expandToBlock(source, start, end) {
  let s = start;
  while (s < end && /\s/.test(source[s])) s++;
  let e = end;
  while (e > s && /\s/.test(source[e - 1])) e--;

  let root;
  try {
    root = getParser().parse(source).rootNode;
  } catch (_) {
    return null;
  }
  if (root.hasError) {
    // Even with parse errors (e.g. `ifdef in port lists), tree-sitter still
    // produces valid sub-trees for many nodes.  Try findSmallestBlock; if it
    // finds a block that does not itself contain an ERROR, use it.
    const block = findSmallestBlock(root, s, e);
    if (block) {
      // Reject blocks that contain ERROR nodes — formatting them could lose
      // content.  Check the source range for ERROR sub-nodes.
      const blockNode = findNodeAt(root, block.start, block.end);
      if (blockNode && !nodeHasError(blockNode)) return block;
    }
    return null;
  }
  return findSmallestBlock(root, s, e);
}

/**
 * Infer the base indentation prefix from the first non-blank line of `text`.
 *
 * The level is quantised to `indentSize` (spaces) or tab stops so that a
 * slightly off-canonical selection (e.g. 3 spaces when indentSize is 2) is
 * snapped to the nearest canonical level instead of being propagated verbatim.
 */
function inferBaseIndent(text, config) {
  const cfg = resolveConfig(config);
  const lines = String(text).split('\n');
  for (const line of lines) {
    if (!line.trim()) continue;
    const lead = line.match(/^[ \t]*/)[0];
    if (cfg.useTabs) {
      const tabs = lead.replace(/ /g, '').length;
      return '\t'.repeat(tabs);
    }
    const spaces = lead.replace(/\t/g, '').length;
    const level = Math.round(spaces / cfg.indentSize);
    return ' '.repeat(level * cfg.indentSize);
  }
  return '';
}

/**
 * Block types that are only legal *inside* a module body.
 *
 * A bare `tiny u_a (.clk(clk));` sliced out of a module and parsed on its own
 * is ambiguous — tree-sitter reads `ident ident (...)` as a `statement` (a task
 * or function call), so the slice never reaches the instantiation emitter and
 * the port map keeps whatever layout the author wrote (or gets collapsed to one
 * line by the `default` branch). The same happens to `always_construct` bodies
 * and to declarations. Wrapping these slices in a throwaway module makes the
 * parse context correct so the real emitters run.
 *
 * Deliberately excluded:
 *   - module/interface/package/... declarations: nesting one inside a wrapper
 *     is not legal SystemVerilog, the parse breaks and the whole thing
 *     collapses to a single line;
 *   - class declarations: already a legal top-level construct, formats fine
 *     unwrapped;
 *   - macros and compiler directives: emitted verbatim, and a wrapped
 *     multi-line `define would have its continuation lines re-indented, which
 *     changes their meaning.
 */
const WRAP_IN_MODULE = new Set([
  'data_declaration', 'net_declaration', 'parameter_declaration',
  'local_parameter_declaration', 'specparam_declaration',
  'continuous_assign',
  'always_construct', 'initial_construct', 'final_construct',
  'generate_region', 'generate_construct', 'loop_generate_construct',
  'conditional_generate_construct', 'if_generate_construct', 'generate_block',
  'module_instantiation', 'udp_instantiation',
  'function_declaration', 'task_declaration',
  'property_declaration', 'sequence_declaration', 'covergroup_declaration',
  'modport_declaration', 'clocking_declaration', 'constraint_declaration',
  'checker_declaration', 'genvar_declaration',
  'module_item', 'module_or_generate_item', 'block_item_declaration',
  'interface_declaration_body',
]);

const WRAP_HEAD = 'module __svfmt_wrap__;\n';
const WRAP_TAIL = '\nendmodule\n';

/**
 * Remove the wrapper module and the one extra indentation level it introduced.
 *
 * Only a leading indent unit is stripped, never a partial one: a `define
 * continuation line that the engine left verbatim must not be touched, and it
 * is excluded from WRAP_IN_MODULE anyway.
 */
function stripWrapper(text, cfg) {
  const lines = text.split('\n');
  let start = lines.length && /^\s*module\s+__svfmt_wrap__\s*;\s*$/.test(lines[0]) ? 1 : 0;
  let end = lines.length;
  while (end > start && lines[end - 1].trim() === '') end--;
  if (end > start && /^\s*endmodule\s*$/.test(lines[end - 1])) end--;

  const unit = cfg.useTabs ? '\t' : ' '.repeat(cfg.indentSize);
  const body = lines.slice(start, end);
  if (!unit) return body.join('\n');
  return body
    .map((line) => (line.startsWith(unit) ? line.slice(unit.length) : line))
    .join('\n');
}

/**
 * Format a standalone fragment without touching anything outside it.
 *
 * `blockType` is the syntax node type the caller grew the selection to (as
 * returned by `expandToBlock`). Pass it whenever it is known: it decides
 * whether the slice needs a temporary module wrapper to parse in the right
 * context (see WRAP_IN_MODULE). Omitting it keeps the old behaviour of
 * formatting the slice exactly as given.
 *
 * Returns { text, hadError, basePrefix, wrapped } where `text` is the formatted
 * fragment already re-indented by `basePrefix` and terminated by a single
 * trailing newline (matching the line span the caller extracted). The caller
 * splices `text` into the document over the expanded line range.
 */
function formatFragment(text, config, blockType) {
  const cfg = resolveConfig(config);
  const basePrefix = inferBaseIndent(text, cfg);
  const wantsWrap = Boolean(blockType) && WRAP_IN_MODULE.has(blockType);

  let result;
  let wrapped = false;
  if (wantsWrap) {
    const prepared = WRAP_HEAD + text.replace(/\s+$/, '') + WRAP_TAIL;
    result = format(prepared, cfg);
    // A wrapper that fails to parse is worse than no wrapper at all: fall back
    // to formatting the slice bare, i.e. exactly what this function used to do.
    if (result.hadError && !cfg.formatOnParseError) {
      const bare = format(text, cfg);
      if (!bare.hadError) result = bare;
      else result = { text: stripWrapper(result.text, cfg), hadError: true };
    } else {
      wrapped = true;
      result = { text: stripWrapper(result.text, cfg), hadError: result.hadError };
    }
  } else {
    result = format(text, cfg);
  }

  const outLines = result.text.split('\n');
  const indented = outLines
    .map((line) => (line.trim() === '' ? '' : basePrefix + line))
    .join('\n');

  return { text: indented, hadError: result.hadError, basePrefix, wrapped };
}

module.exports = { expandToBlock, inferBaseIndent, formatFragment, BLOCK_TYPES };