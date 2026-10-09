'use strict';

/**
 * Core formatting engine.
 *
 * Design notes
 * ------------
 * The engine walks the tree-sitter CST and emits one logical line at a time.
 * Indentation is derived purely from block structure (begin/end, case/endcase,
 * module/endmodule), never from the input text, so arbitrarily mis-indented
 * input converges to a canonical shape.
 *
 * Node text is obtained via a token cursor rather than by slicing the source
 * with regexes, because SystemVerilog's conditional-compilation constructs and
 * attribute instances make text slicing unreliable.
 *
 * Preprocessor directives and text macros are copied out verbatim.
 */

const Parser = require('tree-sitter');
const SV = require('tree-sitter-systemverilog');

const { resolveConfig } = require('./config');

let _parser = null;
function getParser() {
  if (!_parser) {
    _parser = new Parser();
    _parser.setLanguage(SV);
  }
  return _parser;
}

const VERBATIM_ROOTS = new Set([
  'text_macro_definition', 'conditional_compilation_directive',
  'include_compiler_directive', 'timescale_compiler_directive',
  'default_nettype_compiler_directive', 'resetall_compiler_directive',
  'undef_compiler_directive', 'unconnected_drive_compiler_directive',
  'nounconnected_drive_compiler_directive', 'celldefine_compiler_directive',
  'endcelldefine_compiler_directive', 'undefineall_compiler_directive',
  'line_compiler_directive', 'pragma_compiler_directive',
  'begin_keywords_compiler_directive', 'end_keywords_compiler_directive',
  'default_decay_time_compiler_directive',
  'delay_mode_distributed_compiler_directive',
  'delay_mode_path_compiler_directive', 'delay_mode_unit_compiler_directive',
  'delay_mode_zero_compiler_directive', 'protect_compiler_directive',
  'endprotect_compiler_directive', 'protected_compiler_directive',
  'endprotected_compiler_directive',
]);

// Nodes that introduce a block body terminated by a dedented keyword.
const CASE_LIKE = new Set(['case_statement', 'randcase_statement']);

class Formatter {
  constructor(source, config) {
    this.src = source;
    this.cfg = resolveConfig(config);
    this.lines = [];
    this.indent = 0;
    this.hadError = false;
    // End index of the previously emitted top-level node, used to reproduce
    // blank lines around verbatim (macro) regions.
    this.prevEndIndex = null;
    // Set by callers whose header line already ended (e.g. `always_ff @(..)`),
    // telling the next block to hang its `begin` on that header.
    this.hangBlock = false;
  }

  format() {
    const root = getParser().parse(this.src).rootNode;
    if (root.hasError && !this.cfg.formatOnParseError) this.hadError = true;

    for (const child of namedChildren(root)) {
      this.emitLeadingBlanks(child);
      this.topLevel(child);
      this.prevEndIndex = child.endIndex;
    }
    return { text: this.render(), hadError: this.hadError };
  }

  /** Blank lines between the previous top-level node and `node`. */
  emitLeadingBlanks(node) {
    if (this.prevEndIndex === null) return;
    const blanks = countBlankLines(this.src.slice(this.prevEndIndex, node.startIndex));
    for (let i = 0; i < blanks; i++) {
      this.lines.push({ text: '', indent: 0, kind: 'blank', group: null, joinPrev: false });
    }
  }

  // ------------------------------------------------------------- top level

  topLevel(node) {
    if (VERBATIM_ROOTS.has(node.type)) return this.verbatim(node);
    if (isCommentNode(node)) return this.commentBlock(node);

    switch (node.type) {
      case 'module_declaration':
      case 'interface_declaration':
      case 'program_declaration':
      case 'package_declaration':
      case 'primitive_declaration':
      case 'config_declaration':
        return this.moduleLike(node);

      // Class headers carry a superclass list, parameterised base types and
      // mixins; splitting them across lines would misstate the code, so the
      // header stays intact and only the body is re-indented.
      case 'class_declaration':
        return this.classDeclaration(node);

      case 'data_declaration':
      case 'net_declaration':
      case 'parameter_declaration':
      case 'local_parameter_declaration':
      case 'specparam_declaration':
        return this.declaration(node);

      case 'continuous_assign':
        return this.continuousAssign(node);

      case 'always_construct':
      case 'initial_construct':
      case 'final_construct':
        return this.procedural(node);

      case 'generate_region':
      case 'generate_construct':
      case 'loop_generate_construct':
      case 'conditional_generate_construct':
        return this.generate(node);

      case 'module_instantiation':
      case 'udp_instantiation':
        return this.instantiation(node);

      case 'function_declaration':
      case 'task_declaration':
      case 'property_declaration':
      case 'sequence_declaration':
      case 'covergroup_declaration':
      case 'modport_declaration':
      case 'clocking_declaration':
      case 'constraint_declaration':
      case 'interface_declaration_body':
        return this.blockDecl(node);

      case 'checker_declaration':
      case 'genvar_declaration':
        return this.line(this.text(node));

      default:
        return this.line(this.text(node));
    }
  }

  // ------------------------------------------------------- module-like body

  moduleLike(node) {
    const kids = allChildren(node);
    const header = kids.find((k) => /header$/.test(k.type));
    const items = kids.filter((k) => k !== header && !isClosingKeyword(k));

    this.indent++;
    if (header) {
      this.moduleHeader(header);
      for (const item of items) this.moduleItem(item);
    } else if (items.length) {
      this.emit(this.text(items[0]), { indent: 0, group: 'header' });
      for (const item of items.slice(1)) this.moduleItem(item);
    }
    this.indent--;

    const closing = closingKeywordOf(node);
    if (closing) this.emit(closing, { indent: 0, group: 'footer' });
  }

  /**
   * `module name #(params) (ports);`
   *
   * Both lists are exploded one entry per line and kept **flush with the left
   * margin** — they are part of the module's signature, not its body, so they
   * read at the same column as `module` itself:
   *
   *     module sync_2stage
   *     #(
   *     parameter WIDTH = 1
   *     ) (
   *     input  wire              clk,
   *     output wire  [WIDTH-1:0] q
   *     );
   *
   * Entries keep their internal column alignment, so direction, type, width and
   * name still line up.
   */
  moduleHeader(header) {
    const portList = firstChildOfType(header, [
      'list_of_port_declarations', 'list_of_ports', 'port_declaration',
    ]);
    const paramList = firstChildOfType(header, ['parameter_port_list']);

    if (!portList || !this.cfg.explodePortList) {
      this.emit(this.text(header), { indent: 0, group: 'header' });
      return;
    }

    const ports = portDeclarations(portList, this.src);
    if (!ports.length) {
      this.emit(this.text(header), { indent: 0, group: 'header' });
      return;
    }

    // `module foo` — everything before whichever list comes first.
    const firstList = paramList && paramList.startIndex < portList.startIndex
      ? paramList
      : portList;
    this.emit(collapse(this.src.slice(header.startIndex, firstList.startIndex)),
      { indent: 0, group: 'header' });

    if (paramList && paramList.startIndex < portList.startIndex) {
      this.emit('#(', { indent: 0, group: 'param-open' });
      for (const p of parameterDeclarations(paramList, this.src)) {
        this.emit(p, { indent: 0, group: 'param' });
      }
      this.emit(') (', { indent: 0, group: 'param-close' });
    } else {
      // No parameter list: the port list opens right after the module name.
      this.emit('(', { indent: 0, group: 'header-open' });
    }

    ports.forEach((p, i) => {
      const text = collapse(p.text);
      const comma = p.isText ? '' : (i === ports.length - 1 ? '' : ',');
      this.emit(text + comma, { indent: 0, group: 'port' });
    });
    this.emit(');', { indent: 0, group: 'header-end' });
  }

  moduleItem(node) {
    if (VERBATIM_ROOTS.has(node.type)) return this.verbatim(node);
    if (isCommentNode(node)) return this.commentBlock(node);

    switch (node.type) {
      case 'data_declaration':
      case 'net_declaration':
      case 'parameter_declaration':
      case 'local_parameter_declaration':
        return this.declaration(node);

      case 'continuous_assign':
        return this.continuousAssign(node);

      case 'always_construct':
      case 'initial_construct':
      case 'final_construct':
        return this.procedural(node);

      case 'generate_region':
      case 'generate_construct':
      case 'loop_generate_construct':
      case 'conditional_generate_construct':
        return this.generate(node);

      case 'module_instantiation':
      case 'udp_instantiation':
        return this.instantiation(node);

      case 'function_declaration':
      case 'task_declaration':
      case 'property_declaration':
      case 'sequence_declaration':
      case 'covergroup_declaration':
      case 'modport_declaration':
      case 'clocking_declaration':
      case 'constraint_declaration':
        return this.blockDecl(node);

      case 'class_declaration':
        return this.classDeclaration(node);

      default:
        return this.line(this.text(node));
    }
  }

  generate(node) {
    const kids = namedChildren(node);
    const first = kids[0];
    if (first) {
      this.emit(this.text(first), { indent: this.indent, group: 'gen-head' });
      this.indent++;
      for (const k of kids.slice(1)) this.moduleItem(k);
      this.indent--;
      return;
    }
    this.line(this.text(node));
  }

  /**
   * Module instantiation.
   *
   * The port connection list is exploded one connection per line and kept
   * aligned; collapsing a whole instance onto one line destroys the port map
   * readability that matters most in RTL.
   */
  instantiation(node) {
    const inst = firstChildOfType(node, ['hierarchical_instance', 'udp_instance']);
    if (!inst || !this.cfg.explodeInstancePorts) {
      this.emit(this.text(node), { indent: this.indent, group: 'inst' });
      return;
    }

    // `fifo #(...) u_fifo (` — everything up to the port list's `(`.
    const ports = portConnections(inst);
    if (!ports.length) {
      this.emit(this.text(node), { indent: this.indent, group: 'inst' });
      return;
    }

    const openParen = this.src.indexOf('(', inst.startIndex);
    const head = collapse(this.src.slice(node.startIndex, openParen + 1));
    this.emit(head, { indent: this.indent, group: 'inst-head' });

    this.indent++;
    ports.forEach((p, i) => {
      const last = i === ports.length - 1;
      const body = collapse(p.text).replace(/\s*$/, '');
      const text = body.endsWith(',') ? body : body + (last ? '' : ',');
      this.emit(text, { indent: this.indent, group: 'inst-port' });
    });
    this.indent--;
    this.emit(');', { indent: this.indent, group: 'inst-tail' });
  }

  /**
   * class ... extends base #(params); items... endclass
   *
   * The header holds the class name, an optional parameterised base type and a
   * mixin list; it is emitted as one line to keep the inheritance statement
   * readable. Class items are then processed as module-level items so methods,
   * properties and macro calls keep their own indentation.
   */
  classDeclaration(node) {
    const kids = namedChildren(node);
    const items = [];
    let nameNode = null;
    let baseNode = null;

    for (const k of kids) {
      if (k.type === 'class_item') { items.push(k); continue; }
      if (!nameNode && k.type === 'simple_identifier') { nameNode = k; continue; }
      if (!baseNode) baseNode = k;
    }

    let head = 'class';
    if (nameNode) head += ' ' + nameNode.text;
    if (baseNode) {
      const base = collapse(baseNode.text);
      head += /^(extends|implements)\b/.test(base) ? ' ' + base : ' extends ' + base;
    }
    this.emit(head + ';', { indent: this.indent, group: 'class-head' });

    this.indent++;
    for (const it of items) {
      if (VERBATIM_ROOTS.has(it.type)) { this.verbatim(it); continue; }
      if (isCommentNode(it)) { this.commentBlock(it); continue; }
      this.blockDecl(it);
    }
    this.indent--;

    this.emit('endclass', { indent: this.indent, group: 'class-tail' });
  }

  /**
   * function / task / property / sequence / class item ...
   *
   * The grammar does not build structural nodes for routine bodies: the tokens
   * between the header `;` and the closing keyword are flat. Layout therefore
   * falls back to scanning the source text, using token-boundary positions from
   * the CST so string literals and comments cannot confuse the brace/keyword
   * matching.
   */
  blockDecl(node) {
    const target = node.type === 'class_item'
      ? (namedChildren(node)[0] || node)
      : node;

    const text = this.src.slice(target.startIndex, target.endIndex);
    const split = splitRoutine(text);
    if (!split) return this.line(collapse(text));

    this.emit(split.head, { indent: this.indent, group: 'block-head' });
    if (split.body.trim()) {
      this.indent++;
      this.bodyStatements(split.body);
      this.indent--;
    }
    if (split.tail) this.emit(split.tail, { indent: this.indent, group: 'block-tail' });
  }

  // ------------------------------------------------------- declarations

  /**
   * wire / reg / logic / input / output / inout declarations.
   *
   * A declaration may name several signals (`wire a, b, c;`). When
   * `explodeDeclarations` is on, each signal goes on its own line and repeats
   * the full type prefix, so the result can be reordered or commented
   * independently and still reads as valid SystemVerilog.
   */
  declaration(node) {
    const text = this.text(node);

    // Parameters keep their own shape: `parameter int A = 1` is a single
    // declaration whose initialiser is part of the statement, so it must not be
    // split at commas. It still joins the surrounding alignment group, because a
    // run of declarations that mixes parameters and signals reads as one table.
    if (/^\s*(?:localparam|parameter|specparam)\b/.test(text)) {
      this.emit(collapse(text), { indent: this.indent, group: 'decl' });
      return;
    }

    const semi = text.trimEnd().endsWith(';') ? ';' : '';
    const core = semi ? text.trimEnd().slice(0, -1) : text;

    const prefixLen = declarationPrefixLength(core);
    const prefixRaw = core.slice(0, prefixLen);
    const prefix = prefixRaw ? collapse(prefixRaw) + ' ' : '';
    const names = splitTopLevel(core.slice(prefixLen), ',')
      .map((s) => collapse(s.replace(/\s*=[\s\S]*$/, (m) => m).trim()))
      .filter(Boolean);

    if (!names.length) {
      this.emit(core + semi, { indent: this.indent, group: 'decl' });
      return;
    }

    const explode = this.cfg.explodeDeclarations && names.length > 1;

    if (!explode) {
      this.emit(collapse(core) + semi, { indent: this.indent, group: 'decl' });
      return;
    }

    // One signal per line, each repeating the type prefix.
    names.forEach((name, i) => {
      const last = i === names.length - 1;
      const body = prefix ? prefix + name : name;
      this.emit(body + (last ? semi : ';'), {
        indent: this.indent,
        group: 'decl',
      });
    });
  }

  continuousAssign(node) {
    this.emit(this.text(node), { indent: this.indent, group: 'assign' });
  }

  // ------------------------------------------------------- procedural

  /**
   * always_ff / always_comb / initial / final ...
   *
   * These four constructs have different child shapes:
   *   always_construct  -> [always_keyword, statement]
   *   initial_construct -> [statement_or_null]           (keyword is anonymous)
   *   final_construct   -> [function_statement]
   * so the keyword is recovered from the source prefix and the body is located
   * by type rather than by position.
   *
   * The event control (`@(posedge clk)`) lives inside the body statement, under
   * procedural_timing_control_statement, and must stay on the header line.
   */
  procedural(node) {
    const kids = namedChildren(node);
    const bodyNode = kids.find((k) =>
      k.type === 'statement' || k.type === 'statement_or_null' || k.type === 'function_statement');
    if (!bodyNode) return this.line(this.text(node));

    const headKeyword = collapse(
      this.src.slice(node.startIndex, bodyNode.startIndex)
    ).replace(/\s*$/, '');

    let timingText = '';
    let body = bodyNode;

    const inner = unwrapOne(bodyNode);
    if (inner && inner.type === 'procedural_timing_control_statement') {
      const sub = namedChildren(inner);
      body = sub.find((k) => k.type === 'statement_or_null' || k.type === 'statement') || null;
      if (body) timingText = collapse(this.src.slice(inner.startIndex, body.startIndex));
    }

    const head = collapse(headKeyword + (timingText ? ' ' + timingText : ''));
    this.emit(head, { indent: this.indent, group: 'always-head' });

    if (!body) return;
    this.hangBlock = true;
    this.statement(body);
    this.hangBlock = false;
  }

  statement(stmt) {
    if (!stmt || stmt.type === '__empty__') return;
    const inner = unwrapOne(stmt);
    if (!inner) {
      const t = this.text(stmt).trim();
      if (t) this.line(t);
      return;
    }
    this.statementItem(inner);
  }

  statementItem(node) {
    if (VERBATIM_ROOTS.has(node.type)) return this.verbatim(node);
    if (isCommentNode(node)) return this.commentBlock(node);

    switch (node.type) {
      case 'seq_block':
        return this.seqBlock(node, this.hangBlock);

      case 'conditional_statement':
        return this.conditional(node);

      case 'case_statement':
      case 'randcase_statement':
        return this.caseStatement(node);

      case 'loop_statement':
        return this.loop(node);

      case 'blocking_assignment':
      case 'nonblocking_assignment':
      case 'operator_assignment':
      case 'expression_statement':
      case 'procedural_timing_control_statement':
      case 'clocking_skew':
      case 'disable_statement':
      case 'event_trigger':
      case 'wait_statement':
      case 'jump_statement':
      case 'procedural_continuous_assignment':
      case 'assertion_item':
      case 'constr_assignment':
      case 'randsequence_statement':
      case 'randcase_statement_item':
      case 'let_declaration':
        return this.statementLine(node);
      default:
        return this.statementLine(node);
    }
  }

  /**
   * begin ... end
   *
   * `hang` means the `begin` is a dangling block that belongs on the previous
   * line (`if (x) begin`, `always_ff @(..) begin`). Either way the block body
   * sits one level in and `end` returns to the block's own level.
   */
  seqBlock(node, hang) {
    let label = null;
    const body = [];
    for (const k of namedChildren(node)) {
      if ((k.type === 'simple_identifier' || k.type === 'block_identifier') && !label) {
        label = k.text;
        continue;
      }
      body.push(...unwrapStatements(k));
    }

    this.emit('begin' + (label ? ' : ' + label : ''), {
      indent: this.indent,
      group: 'begin',
      joinPrev: !!hang,
    });
    this.indent++;
    for (const k of body) this.statementItem(k);
    this.indent--;
    this.emit('end', { indent: this.indent, group: 'end' });
  }

  conditional(node) {
    const kids = namedChildren(node);
    const branches = collectConditional(kids);
    for (const br of branches) {
      if (br.elseIf) {
        this.emit('else if' + (br.cond ? ' ' + br.cond : ''), { indent: this.indent, group: 'cond' });
      } else if (br.else) {
        this.emit('else', { indent: this.indent, group: 'else' });
      } else {
        this.emit('if' + (br.cond ? ' ' + br.cond : ''), { indent: this.indent, group: 'cond' });
      }
      this.hangBlock = true;
      this.emitBody(br.stmt);
      this.hangBlock = false;
    }
  }

  caseStatement(node) {
    const kids = namedChildren(node);
    const items = kids.filter((k) => k.type === 'case_item' || k.type === 'default_case_item');

    // Header = everything before the first case item, collapsed.
    const firstItem = items[0];
    const headEnd = firstItem ? firstItem.startIndex : node.endIndex;
    const rawHead = this.src.slice(node.startIndex, headEnd);
    const head = collapse(rawHead).replace(/\s*$/, '');

    this.emit(head || 'case', { indent: this.indent, group: 'case-head' });
    this.indent++;
    for (const it of items) this.caseItem(it);
    this.indent--;
    this.emit('endcase', { indent: this.indent, group: 'end' });
  }

  caseItem(node) {
    const kids = namedChildren(node);
    if (!kids.length) return this.line(this.text(node));

    const last = kids[kids.length - 1];
    const isDefault = node.type === 'default_case_item' ||
      (kids.length === 1 && /default/.test(this.text(node)));

    if (isDefault) {
      this.emit('default:', { indent: this.indent, group: 'case-label' });
    } else {
      const labels = kids.slice(0, -1).map((k) => this.text(k)).join(', ');
      this.emit(labels + ':', { indent: this.indent, group: 'case-label' });
    }

    // Body: last named child is the statement.
    this.hangBlock = true;
    this.emitBody(last);
    this.hangBlock = false;
  }

  loop(node) {
    const text = this.text(node);
    const split = splitBlockText(text);
    if (!split) return this.statementLine(node);

    this.emit(split.head, { indent: this.indent, group: 'loop-head' });
    this.indent++;
    if (split.body.trim()) this.bodyStatements(split.body);
    this.indent--;
    if (split.tail) this.emit(split.tail, { indent: this.indent, group: 'end' });
  }

  /** Emit a statement; blocks hang at the current indent, others nest one level. */
  emitBody(stmt) {
    if (!stmt) return;
    const inner = unwrapOne(stmt);
    if (!inner) {
      const t = this.text(stmt).trim();
      if (t) this.line(t);
      return;
    }
    if (BLOCK_NODE_TYPES.has(inner.type)) {
      // `else begin` / `if (x) begin` — begin sits on the same line as its
      // header in conventional style, so no extra indent here.
      return this.statementItem(inner);
    }
    this.indent++;
    this.statementItem(inner);
    this.indent--;
  }

  /**
   * Parse a fragment of statement text and emit it structurally.
   *
   * The fragment comes from a scanned routine body, so its nodes index into the
   * fragment rather than into `this.src`. `trailingSemicolon` therefore has to
   * resolve against the fragment — hence the temporary source swap.
   */
  bodyStatements(text) {
    if (!text || !text.trim()) return;

    const outerSrc = this.src;
    this.src = text;
    try {
      const root = getParser().parse(text).rootNode;
      const items = unwrapStatements(root);
      if (!items.length) {
        this.line(collapse(text));
        return;
      }
      for (const it of items) this.statementItem(it);
    } finally {
      this.src = outerSrc;
    }
  }

  // ---------------------------------------------------------- comments etc

  /**
   * Copy a preprocessor directive or text macro out byte-for-byte.
   * Any blank lines that separated this node from its neighbour in the source
   * are reproduced as well, so macro regions keep their spacing.
   */
  verbatim(node) {
    for (const ln of node.text.split(/\r\n|\r|\n/)) {
      this.push(ln.replace(/\s+$/, ''), this.indent, 'raw', null);
    }
  }

  /**
   * Emit a comment.
   *
   * The first line gets the current indent; continuation lines of a block
   * comment are emitted verbatim so that reformatting never ratchets their
   * indentation (which would make formatting non-idempotent).
   */
  commentBlock(node) {
    const lines = node.text.split(/\r\n|\r|\n/);
    lines.forEach((ln, i) => {
      const text = ln.replace(/\s+$/, '');
      if (i === 0) {
        this.push(text, this.indent, 'comment', null);
      } else {
        // Absolute column 0: block comment bodies are never re-indented.
        this.push(text, 0, 'comment-raw', null);
      }
    });
  }

  // ------------------------------------------------------------- emitting

  emit(text, opts = {}) {
    const t = collapse(text);
    if (!t) return;
    this.push(t, opts.indent !== undefined ? opts.indent : this.indent,
      opts.kind || 'code', opts);
  }

  line(text, opts = {}) {
    return this.emit(text, opts);
  }

  statementLine(node) {
    const text = this.text(node);
    // The node text never includes the terminating `;` for assignment-like
    // statements (the semicolon belongs to the enclosing statement_item), and a
    // RHS ending in `}` defeats a suffix test. Read the source instead.
    const semi = this.trailingSemicolon(node);
    this.emit(semi ? text + semi : text, { indent: this.indent, group: 'stmt' });
  }

  /**
   * The `;` terminating this statement, located in the source.
   *
   * Assignment nodes exclude the semicolon from their span; it sits between the
   * node and its enclosing statement_item. Walk up until an ancestor whose span
   * reaches the semicolon is found, stopping at the enclosing block.
   */
  trailingSemicolon(node) {
    let owner = node;
    let parent = node.parent;
    let guard = 0;
    while (parent && guard++ < 8) {
      if (/^\s*;/.test(this.src.slice(node.endIndex, parent.endIndex))) {
        owner = parent;
        break;
      }
      if (parent.type === 'seq_block' || parent.type === 'source_file') break;
      parent = parent.parent;
    }
    // `owner` ends at (or just past) the semicolon when one was found.
    return /^\s*;/.test(this.src.slice(node.endIndex, owner.endIndex)) ? ';' : '';
  }

  push(text, indent, kind, opts) {
    const o = opts || {};
    this.lines.push({
      text,
      indent,
      kind,
      group: o.group || null,
      // `joinPrev` glues this line onto the preceding one.
      joinPrev: !!o.joinPrev,
    });
  }

  // -------------------------------------------------------------- output

  render() {
    // A line marked `joinPrev` merges into the line before it. This lets a
    // dangling `begin` attach to its header (`if (x) begin`) without the
    // header having to know about the block in advance.
    const merged = [];
    for (const ln of this.lines) {
      if (ln.joinPrev && merged.length) {
        const prev = merged[merged.length - 1];
        prev.text = prev.text + ' ' + ln.text;
        // Keep the header's indent: a dangling `begin` belongs to that line.
        continue;
      }
      merged.push(ln);
    }

    const aligner = new AlignPass(this.cfg);
    const items = aligner.run(merged);

    const rendered = [];
    let blankRun = 0;
    for (const ln of items) {
      if (ln.text === '') {
        blankRun++;
        if (blankRun > this.cfg.maxConsecutiveBlankLines) continue;
        rendered.push('');
        continue;
      }
      blankRun = 0;
      rendered.push(this.indentString(ln.indent) + (ln.padBefore || '') + ln.text);
    }

    while (rendered.length && rendered[0] === '') rendered.shift();
    while (rendered.length && rendered[rendered.length - 1] === '') rendered.pop();

    if (!rendered.length) return '';
    let out = rendered.join('\n').replace(/[ \t]+$/gm, '');
    if (this.cfg.ensureTrailingNewline) out += '\n';
    return out;
  }

  indentString(level) {
    if (level <= 0) return '';
    return this.cfg.useTabs ? '\t'.repeat(level) : ' '.repeat(this.cfg.indentSize * level);
  }

  text(node) {
    return node.text;
  }
}

const BLOCK_NODE_TYPES = new Set([
  'seq_block', 'conditional_statement', 'case_statement', 'randcase_statement',
  'loop_statement', 'function_declaration', 'task_declaration',
  'generate_construct', 'loop_generate_construct', 'conditional_generate_construct',
]);

/** Statements whose `;` is a required terminator checked in the source. */
const NEEDS_TERMINATOR = new Set([
  'blocking_assignment', 'nonblocking_assignment', 'operator_assignment',
  'expression_statement', 'assign_declaration', 'event_trigger',
  'wait_statement', 'jump_statement', 'procedural_continuous_assignment',
]);

// ==================================================================== utils

function collapse(s) {
  if (!s) return '';
  let out = '', inStr = false, i = 0;
  while (i < s.length) {
    const c = s[i];
    if (inStr) {
      out += c;
      if (c === '\\' && i + 1 < s.length) { out += s[i + 1]; i += 2; continue; }
      if (c === '"') inStr = false;
      i++; continue;
    }
    if (c === '"') { inStr = true; out += c; i++; continue; }
    if (/\s/.test(c)) {
      while (i < s.length && /\s/.test(s[i])) i++;
      if (out.length && !out.endsWith(' ')) out += ' ';
      continue;
    }
    out += c; i++;
  }
  return out.trim();
}

/**
 * Number of blank lines between two nodes.
 *
 * The gap between two nodes starts right after the previous node's last
 * character and ends right before the next node's first character, so it always
 * begins and ends with a line remainder. Blank lines are the entries strictly
 * between the first and last, which is `newlines - 1` for an all-whitespace gap.
 */
function countBlankLines(gap) {
  if (!gap) return 0;
  const newlines = (gap.match(/\r\n|\r|\n/g) || []).length;
  if (newlines === 0) return 0;
  const parts = gap.split(/\r\n|\r|\n/);
  let blanks = 0;
  for (let i = 1; i < parts.length - 1; i++) {
    if (parts[i].trim() === '') blanks++;
  }
  // A gap that is only newlines: 2 newlines => 1 blank line.
  if (parts.length === 2 && parts[0].trim() === '' && parts[1].trim() === '') {
    return newlines - 1;
  }
  return blanks;
}

/** End of the region available after `node` (next sibling, else enclosing node). */
function nextBoundary(node) {
  if (node.nextNamedSibling) return node.nextNamedSibling.startIndex;
  let p = node.parent;
  while (p) {
    if (p.nextNamedSibling) return p.nextNamedSibling.startIndex;
    p = p.parent;
  }
  return node.endIndex;
}

function namedChildren(node) {
  const res = [];
  const c = node.walk();
  if (c.gotoFirstChild()) {
    do { if (c.currentNode.isNamed) res.push(c.currentNode); } while (c.gotoNextSibling());
  }
  return res;
}

function allChildren(node) {
  const res = [];
  const c = node.walk();
  if (c.gotoFirstChild()) {
    do { res.push(c.currentNode); } while (c.gotoNextSibling());
  }
  return res;
}

function isClosingKeyword(node) {
  return !node.isNamed &&
    /^(end[a-z]*|join(_any|_none)?|endmodule|endinterface|endpackage|endprogram|endclass|endfunction|endtask|endgenerate|endclocking|endgroup|endinterface|endprogram)$/.test(node.type);
}

/** First direct named child whose type is in `types`. */
function firstChildOfType(node, types) {
  const set = new Set(types);
  for (let i = 0; i < node.namedChildCount; i++) {
    const k = node.namedChild(i);
    if (set.has(k.type)) return k;
  }
  return null;
}

/**
 * Individual port declarations in source order.
 *
 * ANSI ports are their own nodes. Grouped non-ANSI declarations
 * (`input wire [7:0] a, b`) share one node, so they are split further.
 */
function portDeclarations(portList, src) {
  const found = [];
  const walk = (n, depth) => {
    if (depth > 4) return;
    for (let i = 0; i < n.namedChildCount; i++) {
      const c = n.namedChild(i);
      if (c.type === 'ansi_port_declaration' || c.type === 'port_declaration') {
        found.push({ startIndex: c.startIndex, endIndex: c.endIndex, text: c.text });
        continue;
      }
      if (c.namedChildCount > 0) walk(c, depth + 1);
    }
  };
  walk(portList, 0);
  if (found.length) return found.sort((a, b) => a.startIndex - b.startIndex);

  // Fallback: split the raw text at top-level commas.
  const text = src.slice(portList.startIndex, portList.endIndex)
    .replace(/^\s*\(/, '').replace(/\)\s*$/, '');
  return splitTopLevel(text, ',')
    .map((p) => p.trim())
    .filter(Boolean)
    .map((p, i, arr) => ({
      text: p + (i < arr.length - 1 ? ',' : ''),
      isText: true,
    }));
}

function closingKeywordOf(node) {
  const kids = allChildren(node);
  for (let i = kids.length - 1; i >= 0; i--) {
    const k = kids[i];
    if (!k.isNamed && /^(end[a-z]+|join(_any|_none)?)$/.test(k.type)) return k.text;
  }
  return null;
}

function isCommentNode(node) {
  if (node.type === 'comment') return true;
  if (!node.isNamed && (node.type === '//' || node.type === '/*')) return true;
  return /^\s*(\/\/|\/\*)/.test(node.text || '');
}

/**
 * Statement wrappers are three levels deep in this grammar
 * (statement -> statement_item -> <actual>), and bodies can also sit under
 * statement_or_null. Peel them off so callers always see real statements.
 */
const STATEMENT_WRAPPERS = new Set([
  'statement', 'statement_item', 'statement_or_null', 'source_file',
]);

function unwrapStatements(node) {
  const out = [];
  for (const k of namedChildren(node)) {
    if (STATEMENT_WRAPPERS.has(k.type)) out.push(...unwrapStatements(k));
    else out.push(k);
  }
  return out;
}

/** Real statement node inside a `statement` wrapper, or the node itself. */
function unwrapOne(node) {
  if (!node) return null;
  let cur = node;
  let guard = 0;
  while (STATEMENT_WRAPPERS.has(cur.type) && guard++ < 8) {
    const next = namedChildren(cur)[0];
    if (!next) return null;
    cur = next;
  }
  return cur;
}

/** Split text into `head` / `body` / `tail` around the first block keyword. */
function splitBlockText(text) {
  const openers = ['begin', 'case', 'casex', 'casez', 'randcase', 'fork'];
  const closers = ['end', 'endcase', 'join', 'join_any', 'join_none'];
  let i = 0, depth = 0, inStr = false;
  let headEnd = -1;
  while (i < text.length) {
    const c = text[i];
    if (inStr) { if (c === '\\') i++; else if (c === '"') inStr = false; i++; continue; }
    if (c === '"') { inStr = true; i++; continue; }
    if (c === '(' || c === '[' || c === '{') { depth++; i++; continue; }
    if (c === ')' || c === ']' || c === '}') { depth--; i++; continue; }
    if (depth === 0) {
      const rest = text.slice(i);
      const om = openers.map((o) => new RegExp('^' + o + '\\b').exec(rest)).find(Boolean);
      if (om && headEnd < 0) { headEnd = i + om[0].length; i += om[0].length; continue; }
      const cm = closers.map((o) => new RegExp('^' + o + '\\b').exec(rest)).find(Boolean);
      if (cm) {
        return {
          head: collapse(text.slice(0, headEnd)),
          body: text.slice(headEnd, i),
          tail: collapse(text.slice(i)),
        };
      }
    }
    i++;
  }
  return null;
}

/**
 * Reconstruct the if / else-if / else chain from a conditional_statement.
 *
 * This grammar **flattens** the chain: `if (a) x; else if (b) y; else z;`
 * yields children [cond_predicate(a), statement, cond_predicate(b),
 * statement, statement]. The `else` keyword is not represented in the tree at
 * all, so branch roles must be inferred from position: every
 * cond_predicate after the first belongs to an `else if`, and a trailing
 * statement with no pending predicate belongs to `else`.
 */
function collectConditional(kids) {
  const out = [];
  let seenPred = 0;

  for (const k of kids) {
    if (k.type === 'cond_predicate') {
      const inner = namedChildren(k)[0];
      out.push({
        elseIf: seenPred > 0,
        else: false,
        cond: predicateText(k),
        stmt: null,
      });
      seenPred++;
      continue;
    }
    if (k.type !== 'statement' && k.type !== 'statement_or_null') continue;

    if (out.length && out[out.length - 1].stmt === null) {
      out[out.length - 1].stmt = unwrapOne(k);
    } else {
      // No predicate pending: this is the `else` branch.
      out.push({ else: true, elseIf: false, cond: null, stmt: unwrapOne(k) });
    }
  }

  return out;
}

function isElseIfChain(stmtNode) {
  if (!stmtNode) return false;
  if (!/^\s*else\s+if\b/.test(stmtNode.text)) return false;
  const inner = unwrapOne(stmtNode);
  return !!inner && inner.type === 'conditional_statement';
}

function predicateText(pred) {
  const inner = namedChildren(pred)[0];
  if (!inner) {
    const t = collapse(pred.text).replace(/^\(/, '').replace(/\)$/, '');
    return '(' + t + ')';
  }
  return '(' + collapse(inner.text) + ')';
}

function splitTopLevel(s, sep) {
  const res = [];
  let depth = 0, inStr = false, cur = '';
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (inStr) {
      cur += c;
      if (c === '\\') { cur += s[i + 1] || ''; i++; continue; }
      if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') { inStr = true; cur += c; continue; }
    if (c === '(' || c === '[' || c === '{') { depth++; cur += c; continue; }
    if (c === ')' || c === ']' || c === '}') { depth--; cur += c; continue; }
    if (c === sep && depth === 0) { res.push(cur); cur = ''; continue; }
    cur += c;
  }
  res.push(cur);
  return res;
}

// ---------------------------------------------------------- alignment pass

/**
 * Second pass: pad groups of structurally similar lines into columns.
 *
 * Works on the already-laid-out line list, so it only has to decide *where*
 * the padding goes, not what the tokens are.
 */
class AlignPass {
  constructor(cfg) { this.cfg = cfg; }

  run(lines) {
    const out = lines.map((l) => Object.assign({}, l, { padBefore: '' }));
    // Both passes share alignDeclGroup, so each must only see its own kind of
    // group — otherwise the same lines would be aligned twice and the padding
    // would accumulate on every run, breaking idempotence.
    this.alignPorts(out);
    this.alignDeclarations(out);
    this.alignInstancePorts(out);
    this.alignAssignments(out);
    this.alignCaseLabels(out);
    return out;
  }

  /**
   * Align module ports and declarations across four columns:
   *
   *   input  wire [31:0] din;      <- direction
   *   output wire [63:0] dout;     <- base type
   *          wire        done;     <- packed dimension
   *                       valid;   <- name
   *                       w_en;    <- terminator
   *
   * Only lines emitted by the port list and declaration paths participate;
   * anything else (`module ...(`, `assign x = y`, an instantiation header) must
   * be left alone or the alignment would corrupt it.
   */
  alignPorts(lines) {
    if (!this.cfg.alignPortsInHeader) return;
    for (let i = 0; i < lines.length;) {
      if (!isAlignableDecl(lines[i], 'port')) { i++; continue; }
      const group = this.collectGroup(lines, i, (l) => isAlignableDecl(l, 'port'));
      if (group.length > 1) this.alignDeclGroup(group);
      i = group.length ? i + group.length : i + 1;
    }
  }

  /** Align instance port connections: `.port(expr)` names in one column. */
  /**
   * Align instance port connections on both delimiters.
   *
   *   .clk    (clk),
   *   .wr_data(w_data),
   *          ^ open    ^ close
   *
   * The opening paren is padded so the expressions start in one column, and the
   * closing paren is then padded so the column of `)` also matches — a port map
   * that opens aligned but closes ragged still reads as misaligned.
   */
  alignInstancePorts(lines) {
    let i = 0;
    while (i < lines.length) {
      if (lines[i].group !== 'inst-port') { i++; continue; }
      let j = i;
      while (j < lines.length && lines[j].group === 'inst-port') j++;
      const group = lines.slice(i, j);

      if (group.length > 1) {
        // Step 1: open paren.
        const openCols = group.map((l) => l.text.indexOf('('));
        if (openCols.every((c) => c > 0)) {
          const target = Math.max(...openCols);
          for (const ln of group) {
            const c = ln.text.indexOf('(');
            if (c > 0 && c < target) {
              ln.text = ln.text.slice(0, c) + ' '.repeat(target - c) + ln.text.slice(c);
            }
          }
        }

        // Step 2: close paren, measured after the open-paren padding is applied.
        const closeCols = group.map((l) => {
          const open = l.text.indexOf('(');
          const close = l.text.lastIndexOf(')');
          return open >= 0 && close > open ? close : -1;
        });
        if (closeCols.every((c) => c > 0)) {
          const target = Math.max(...closeCols);
          for (const ln of group) {
            const close = ln.text.lastIndexOf(')');
            if (close > 0 && close < target) {
              ln.text = ln.text.slice(0, close) + ' '.repeat(target - close) +
                ln.text.slice(close);
            }
          }
        }
      }
      i = j;
    }
  }

  alignDeclarations(lines) {
    if (!this.cfg.alignConsecutiveDeclarations) return;
    for (let i = 0; i < lines.length;) {
      if (!isAlignableDecl(lines[i], 'decl')) { i++; continue; }
      const group = this.collectGroup(lines, i, (l) => isAlignableDecl(l, 'decl'));
      if (group.length > 1) this.alignDeclGroup(group);
      i = group.length ? i + group.length : i + 1;
    }
  }

/**
   * Pad consecutive declaration lines so their semantic columns line up.
   *
   *   input  wire [31:0] din;
   *   output wire        done;
   *          ^ type    ^ dimension
   *
   * The columns are laid out from a single target table, and each line is then
   * rebuilt left to right: at every boundary the gap between where the boundary
   * currently sits and where the table says it belongs is inserted. Padding a
   * line shifts everything to its right, so the running offset has to be carried
   * forward — computing the columns independently and applying them afterwards
   * does not compose.
   */
  alignDeclGroup(group) {
    const parsed = group.map((l) => declarationColumns(l.text));
    if (parsed.some((p) => p === null)) return;

    const hasDir = parsed.some((p) => p.dirEnd > 0);
    const hasDim = parsed.some((p) => p.dimEnd > 0);

    // Widest form of each column. The type column starts one space after the
    // widest direction, the dimension column one space after the widest type, and
    // the signal name one space after the widest dimension.
    const colDir = hasDir ? Math.max(...parsed.map((p) => p.dirEnd)) : 0;
    const colType = Math.max(...parsed.map((p) => p.typeEnd)) + (hasDir ? 1 : 0);
    const dimWidth = hasDim
      ? Math.max(...parsed.map((p) => (p.dimEnd > 0 ? p.dimEnd - p.dimStart : 0)))
      : 0;
    const colDim = hasDim ? colType + dimWidth : colType;
    const colName = colDim + 1;
    const longestName = Math.max(...parsed.map((p) => p.nameEnd - p.nameStart));
    const colEnd = this.cfg.alignDeclarationTerminators ? colName + longestName : 0;

    for (let k = 0; k < group.length; k++) {
      const c = parsed[k];
      // Boundaries as [sourceOffset, targetOffset]. A line without a packed
      // width has no dimension boundary, so its type boundary is pushed all the
      // way to the name column instead.
      const b = [];
      if (hasDir && c.dirEnd > 0) b.push([c.dirEnd, colDir]);
      b.push(hasDim && c.dimEnd === 0
        ? [c.typeEnd, colName - 1]
        : [c.typeEnd, colType]);
      if (hasDim && c.dimEnd > 0) b.push([c.dimEnd, colDim]);
      b.push([c.nameStart, colName]);
      if (colEnd) b.push([c.nameEnd, colEnd]);

      let out = group[k].text;
      let shift = 0;
      for (const [at, want] of b) {
        const pad = want - (at + shift);
        if (pad > 0) {
          out = out.slice(0, at + shift) + ' '.repeat(pad) + out.slice(at + shift);
          shift += pad;
        }
      }
      group[k].text = out;
    }
  }
  /**
   * Collect a run of consecutive lines matching `predicate`.
   *
   * `predicate` receives the whole line object, not just its text, because
   * callers also need the `group` tag to decide what kind of line this is.
   * A blank line, a comment or a non-matching line ends the run.
   */
  collectGroup(lines, from, predicate) {
    const group = [];
    let i = from;
    while (i < lines.length) {
      const ln = lines[i];
      if (ln.kind !== 'code') break;
      if (!predicate(ln)) break;
      group.push(ln);
      i++;
    }
    return group;
  }

  /** Pad the `=` (or `<=` / `+=`) of consecutive assignments to one column. */
  /**
   * Align consecutive assignments on the operator and on the terminator.
   *
   *   assign o_data  = r_data;
   *   assign valid_a = r_data  ;
   *          ^ operator    ^ `;`
   *
   * The operator column comes first; the `;` column is then computed from where
   * each line's terminator actually lands once the operator padding is applied.
   */
  alignAssignments(lines) {
    if (!this.cfg.alignConsecutiveAssignments) return;
    let i = 0;
    while (i < lines.length) {
      if (!this.isAssignable(lines[i])) { i++; continue; }
      let j = i;
      while (j < lines.length && this.isAssignable(lines[j])) j++;
      if (j - i > 1) this.alignAssignGroup(lines.slice(i, j));
      i = j;
    }
  }

  alignAssignGroup(group) {
    // Step 1: align the assignment operator. The operator column is an absolute
    // offset in the finished text, so each line is padded by the difference
    // between that target and its own operator position — independently, since
    // the lines are separate strings and do not shift each other.
    const ops = group.map((l) => assignmentColumn(l.text));
    const opTarget = Math.max(...ops);
    for (let k = 0; k < group.length; k++) {
      const pad = opTarget - ops[k];
      if (pad > 0) {
        const ln = group[k];
        const at = ops[k];
        ln.text = ln.text.slice(0, at) + ' '.repeat(pad) + ln.text.slice(at);
      }
    }

    // Step 2: align the trailing `;` (or `,` where the statement continues).
    if (!this.cfg.alignDeclarationTerminators) return;
    const ends = group.map((l) => {
      const t = l.text.replace(/\s+$/, '');
      return /[;,]$/.test(t) ? t.length - 1 : -1;
    });
    if (!ends.every((e) => e >= 0)) return;
    const endTarget = Math.max(...ends);
    for (let k = 0; k < group.length; k++) {
      const pad = endTarget - ends[k];
      if (pad > 0) {
        const ln = group[k];
        ln.text = ln.text.slice(0, ends[k]) + ' '.repeat(pad) + ln.text.slice(ends[k]);
      }
    }
  }

  isAssignable(ln) {
    if (ln.kind !== 'code') return false;
    if (/^(begin|end|else|endcase|case)\b/.test(ln.text)) return false;
    return assignmentColumn(ln.text) > 0;
  }

  /** Align `case` item labels and their colons. */
  alignCaseLabels(lines) {
    let i = 0;
    while (i < lines.length) {
      if (!/^\s*[\w'\"$].*:\s*$/.test(lines[i].text)) { i++; continue; }
      let j = i;
      while (j < lines.length && /^[\w'\"$].*:\s*$/.test(lines[j].text)) j++;
      if (j - i > 1) {
        const target = Math.max(...lines.slice(i, j).map((l) => l.text.length));
        for (let k = i; k < j; k++) {
          const need = target - lines[k].text.length;
          if (need > 0) lines[k].text = lines[k].text + ' '.repeat(need);
        }
      }
      i = j;
    }
  }

  /**
   * Insert padding immediately before the column reported by `columnOf`,
   * so every line in the group shares one alignment column.
   */
  padAt(lines, from, to, columnOf) {
    const cols = [];
    for (let i = from; i < to; i++) {
      const c = columnOf(lines[i].text);
      if (c > 0) cols.push(c);
    }
    if (!cols.length) return;
    const target = Math.max(...cols);
    for (let i = from; i < to; i++) {
      const c = columnOf(lines[i].text);
      if (c <= 0 || c >= target) continue;
      // Column points at the name (declarations) or the operator (assignment);
      // step back over the single space that precedes it.
      const at = c;
      lines[i].text = lines[i].text.slice(0, at) + ' '.repeat(target - c) + lines[i].text.slice(at);
    }
  }
}

/** Column of the assignment operator, ignoring `==`, `<=` in comparisons. */
function assignmentColumn(text) {
  let depth = 0, inStr = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inStr) { if (c === '\\') i++; else if (c === '"') inStr = false; continue; }
    if (c === '"') { inStr = true; continue; }
    if (c === '(' || c === '[' || c === '{') { depth++; continue; }
    if (c === ')' || c === ']' || c === '}') { depth--; continue; }
    if (depth !== 0) continue;

    if (c === '<' && text[i + 1] === '=' && isAssignCtx(text, i)) return i;
    if (c === '+' || c === '-' || c === '*' || c === '/' || c === '%' ||
        c === '&' || c === '|' || c === '^') {
      if (text[i + 1] === '=' && isAssignCtx(text, i)) return i;
      continue;
    }
    if (c === '=') {
      const prev = text[i - 1];
      if (text[i + 1] === '=' ) continue;
      if (prev === '=' || prev === '!' || prev === '<' || prev === '>' ||
          prev === '+' || prev === '-' || prev === '*' || prev === '/' ||
          prev === '%' || prev === '&' || prev === '|' || prev === '^') continue;
      return i;
    }
  }
  return -1;
}

/** `<=` is an assignment unless it is the tail of a relational compare. */
function isAssignCtx(text, i) {
  const prev = text[i - 1];
  return !(prev === '<' || prev === '>' || prev === '=' || prev === '!');
}

function format(source, config) {
  return new Formatter(source, config).format();
}

/**
 * Split a routine into header / body / closing keyword.
 *
 *   function f(...);  <body>  endfunction
 *
 * The header ends at the first `;` that is not inside parentheses, a string or
 * a comment. The closing keyword is the last `end...` token at depth 0.
 * Returns null when the text has no such structure (e.g. an extern prototype),
 * in which case the caller emits it verbatim.
 */
function splitRoutine(text) {
  const masked = maskLiteralsAndComments(text);

  // Header: up to the first top-level `;`.
  let depth = 0;
  let headEnd = -1;
  for (let i = 0; i < masked.length; i++) {
    const c = masked[i];
    if (c === '(' || c === '[' || c === '{') depth++;
    else if (c === ')' || c === ']' || c === '}') depth--;
    else if (c === ';' && depth === 0) { headEnd = i + 1; break; }
  }
  if (headEnd < 0) return null;

  // Closing keyword: last `end<word>` at depth 0.
  let tailStart = -1;
  depth = 0;
  for (let i = masked.length - 1; i >= 0; i--) {
    const c = masked[i];
    if (c === ')' || c === ']' || c === '}') depth++;
    else if (c === '(' || c === '[' || c === '{') depth--;
    else if (depth === 0 && masked.startsWith('end', i)) {
      const m = /^end[a-z_]*/.exec(masked.slice(i));
      if (m) { tailStart = i; break; }
    }
  }
  if (tailStart < 0 || tailStart <= headEnd) return null;

  return {
    head: collapse(text.slice(0, headEnd)),
    body: text.slice(headEnd, tailStart),
    tail: collapse(text.slice(tailStart)),
  };
}

/**
 * Replace string literals and comments with spaces, preserving length and
 * newlines, so structural scanning cannot be confused by their contents.
 */
function maskLiteralsAndComments(text) {
  let out = '';
  let i = 0;
  const n = text.length;
  while (i < n) {
    const c = text[i];
    const next2 = text.slice(i, i + 2);

    if (next2 === '//') {
      while (i < n && text[i] !== '\n') { out += ' '; i++; }
      continue;
    }
    if (next2 === '/*') {
      while (i < n && text.slice(i, i + 2) !== '*/') {
        out += text[i] === '\n' ? '\n' : ' ';
        i++;
      }
      out += '  '; i += 2;
      continue;
    }
    if (c === '"') {
      out += ' '; i++;
      while (i < n) {
        if (text[i] === '\\') { out += '  '; i += 2; continue; }
        if (text[i] === '"') { out += ' '; i++; break; }
        out += text[i] === '\n' ? '\n' : ' ';
        i++;
      }
      continue;
    }
    out += c;
    i++;
  }
  return out;
}

/**
 * Length of the type prefix in a declaration, i.e. everything before the first
 * declared signal name.
 *
 *   `input wire [31:0] din`  ->  `input wire [31:0] `
 *   `wire signed [7:0] a`    ->  `wire signed [7:0] `
 *   `logic [3:0] state`      ->  `logic [3:0] `
 *   `parameter int W = 8`    ->  `parameter int `  (initialiser not a name)
 *
 * Returns 0 when no name can be located, in which case the caller emits the
 * declaration unchanged.
 */
function declarationPrefixLength(text) {
  const DIRECTIONS = '(?:input|output|inout|ref)';
  const TYPES = [
    'wire', 'reg', 'logic', 'bit', 'byte', 'shortint', 'int', 'integer',
    'longint', 'time', 'real', 'shortreal', 'realtime', 'string', 'chandle',
    'event', 'genvar', 'wand', 'wor', 'tri', 'tri0', 'tri1', 'triand',
    'trior', 'trireg', 'uwire', 'supply0', 'supply1', 'signed', 'unsigned',
  ];
  const TYPEDEF_TYPES = [
    'shortint', 'int', 'longint', 'byte', 'integer', 'time', 'real', 'realtime',
  ];

  // Typedef'd types: `my_type_t foo;`
  if (/^\s*[A-Za-z_$][\w$]*\s+[A-Za-z_$][\w$]*\s*(?:=|$)/.test(text) &&
      !new RegExp('^\\s*(?:' + [DIRECTIONS, ...TYPES].join('|') + ')\\b').test(text)) {
    const m = /^\s*[A-Za-z_$][\w$]*\s+/.exec(text);
    if (m) return m[0].length;
  }

  const pattern = new RegExp(
    '^\\s*(?:' + DIRECTIONS + '\\s+)?' +          // optional direction
    '(?:' + TYPES.join('|') + ')\\b' +            // a base type keyword
    '\\s*(?:signed\\b|unsigned\\b)?' +            // optional sign
    '\\s*(?:\\[\\s*[^\\]]*\\]\\s*)*' +            // packed dimensions
    '\\s+'
  );
  const m = pattern.exec(text);
  if (m) return m[0].length;

  // `input foo;` — a direction with an implicit type.
  const dirOnly = new RegExp('^\\s*' + DIRECTIONS + '\\b\\s+').exec(text);
  if (dirOnly) return dirOnly[0].length;

  return 0;
}

/**
 * Individual port connections of an instantiation, in source order.
 *
 * `fifo u (.a(x), .b(y))` -> ['.a(x)', '.b(y)']
 * Falls back to splitting the raw text when no connection nodes are present
 * (e.g. an empty list).
 */
function portConnections(inst) {
  const found = [];
  const walk = (n, depth) => {
    if (depth > 5) return;
    for (let i = 0; i < n.namedChildCount; i++) {
      const c = n.namedChild(i);
      if (c.type === 'port_connection' || c.type === 'named_port_connection' ||
          c.type === 'ordered_port_connection' || c.type === 'wildcard_port_connection') {
        found.push({ startIndex: c.startIndex, endIndex: c.endIndex, text: c.text });
        continue;
      }
      if (c.namedChildCount > 0) walk(c, depth + 1);
    }
  };
  walk(inst, 0);
  if (found.length) return found.sort((a, b) => a.startIndex - b.startIndex);
  return [];
}

/**
 * Whether a line is a declaration of the given kind (`port` or `decl`) and
 * therefore safe to column-align.
 *
 * The check is deliberately strict: alignment rewrites whitespace, so applying
 * it to a line that merely *looks* declarative (an instantiation header, a
 * continuous assign, a module header) would corrupt it.
 */
function isAlignableDecl(ln, kind) {
  if (!ln || ln.kind !== 'code') return false;
  if (ln.group !== kind) return false;
  return declarationColumns(ln.text) !== null;
}

/**
 * Column positions inside a declaration line, or null if it is not a
 * declaration.
 *
 *   `input  wire [31:0] din;`
 *    ^dirEnd ^typeEnd ^dimEnd     ^nameEnd
 *
 * Each field is the offset just past that token, so padding inserted there pushes
 * everything to its right into alignment.
 */
function declarationColumns(text) {
  const t = text.replace(/\s+$/, '');
  if (!t) return null;

  const DIRECTIONS = ['input', 'output', 'inout', 'ref'];
  const QUALIFIERS = [
    'const', 'static', 'automatic', 'var', 'rand', 'randc',
    'parameter', 'localparam', 'specparam',
  ];

  let i = 0;
  const ws = () => { while (i < t.length && /[ \t]/.test(t[i])) i++; };
  const word = () => {
    const s = i;
    while (i < t.length && /[A-Za-z0-9_$]/.test(t[i])) i++;
    return t.slice(s, i);
  };

  const out = { dirEnd: 0, typeEnd: 0, dimStart: -1, dimEnd: 0, nameEnd: 0 };
  const words = [];

  // Phase 1: consume any run of direction / qualifier / type words.
  // The last word consumed is the signal name, so at least one word must follow.
  let guard = 0;
  while (guard++ < 8) {
    ws();
    if (i >= t.length) return null;
    const before = i;
    const w = word();
    if (!w) return null;

    if (DIRECTIONS.includes(w) && out.dirEnd === 0) {
      out.dir = w;
      words.push(w);
      out.dirEnd = i;
      continue;
    }
    if (QUALIFIERS.includes(w) || TYPE_KEYWORDS.has(w) || w === 'signed' || w === 'unsigned') {
      words.push(w);
      out.type = w;
      out.typeEnd = i;
      // Consume packed dimensions that follow the base type.
      ws();
      out.dimStart = i;
      let dimEnd = 0;
      while (i < t.length && t[i] === '[') {
        let depth = 0;
        while (i < t.length) {
          const c = t[i];
          if (c === '[') {
            depth++;
            i++;
          } else if (c === ']') {
            depth--;
            i++;
            if (depth === 0) break;
          } else {
            i++;
          }
          // Unterminated `[` would otherwise spin here forever.
          if (depth > 64) break;
        }
        if (depth !== 0) return null;
        ws();
        dimEnd = i;
      }
      out.dimEnd = dimEnd;
      continue;
    }

    // First word that is neither qualifier nor type: this is the signal name.
    out.name = w;
    out.nameStart = before;
    out.nameEnd = i;
    return out;
  }
  return null;
}

const TYPE_KEYWORDS = new Set([
  'logic', 'bit', 'reg', 'wire', 'int', 'integer', 'byte', 'shortint',
  'longint', 'real', 'shortreal', 'realtime', 'time', 'string', 'genvar',
  'chandle', 'event', 'wand', 'wor', 'tri', 'tri0', 'tri1', 'triand',
  'trior', 'trireg', 'uwire', 'supply0', 'supply1',
]);

/**
 * Individual parameters of a `#(...)` list, one per line.
 *
 *   #(parameter int A = 1, parameter int B = 2)
 *     -> ['parameter int A = 1,', 'parameter int B = 2']
 *
 * Each entry keeps the `parameter` / `localparam` keyword so the expanded list
 * is still valid SystemVerilog on its own.
 */
function parameterDeclarations(paramList, src) {
  const found = [];
  const walk = (n, depth) => {
    if (depth > 4) return;
    for (let i = 0; i < n.namedChildCount; i++) {
      const c = n.namedChild(i);
      if (/^(?:parameter|localparam)_declaration$/.test(c.type) ||
          c.type === 'parameter_declaration' || c.type === 'localparam_declaration') {
        found.push({ startIndex: c.startIndex, endIndex: c.endIndex });
        continue;
      }
      if (c.namedChildCount > 0) walk(c, depth + 1);
    }
  };
  walk(paramList, 0);

  let items;
  if (found.length) {
    items = found
      .sort((a, b) => a.startIndex - b.startIndex)
      .map((n) => collapse(src.slice(n.startIndex, n.endIndex)));
  } else {
    // Fallback: split the raw text at top-level commas.
    const text = src.slice(paramList.startIndex, paramList.endIndex)
      .replace(/^\s*#?\s*\(/, '')
      .replace(/\)\s*$/, '');
    items = splitTopLevel(text, ',').map((s) => collapse(s)).filter(Boolean);
  }

  return items.map((text, i) => text + (i === items.length - 1 ? '' : ','));
}

/** First statement-like descendant of a declaration node, in source order. */
function findFirstStatement(node) {
  let best = null;
  const walk = (n, depth) => {
    if (depth > 6) return;
    for (let i = 0; i < n.namedChildCount; i++) {
      const c = n.namedChild(i);
      if (c.type === 'statement_or_null' || c.type === 'statement_item') {
        if (!best || c.startIndex < best.startIndex) best = c;
      }
      if (c.namedChildCount > 0) walk(c, depth + 1);
    }
  };
  walk(node, 0);
  return best;
}

/** The closing keyword node (`end`, `endfunction`, ...) if present. */
function closingTail(node) {
  let best = null;
  const walk = (n, depth) => {
    if (depth > 6) return;
    for (let i = 0; i < n.namedChildCount; i++) {
      const c = n.namedChild(i);
      if (!c.isNamed && /^(end[a-z_]*|join(_any|_none)?|endclass|endfunction|endtask)$/.test(c.type)) {
        best = c;
      } else if (c.namedChildCount > 0) walk(c, depth + 1);
    }
  };
  walk(node, 0);
  return best;
}

function emptyNode(src, index) {
  return { type: '__empty__', text: '', startIndex: index, endIndex: index, namedChildCount: 0 };
}

module.exports = {
  format, Formatter, collapse, AlignPass,
  declarationColumns, splitTopLevel,
};
