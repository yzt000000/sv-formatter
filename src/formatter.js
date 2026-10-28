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
    // Same for generate blocks: `if (g) begin` / `else begin`.
    this.hangGenerate = false;
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
    if (isCommentNode(node)) {
      // `endmodule // u_foo` / `endpackage // pkg` — the trailer documents the
      // keyword it sits on, so it stays there instead of becoming a stray line
      // that later reads as a comment on whatever follows.
      if (this.prevEndIndex !== null &&
          !/[\r\n]/.test(this.src.slice(this.prevEndIndex, node.startIndex))) {
        return this.appendTrailingComment(node);
      }
      return this.commentBlock(node);
    }

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
      case 'if_generate_construct':
      case 'generate_block':
        return this.generate(node);

      case 'module_instantiation':
      case 'udp_instantiation':
        return this.instantiation(node);

      case 'function_declaration':
      case 'task_declaration':
      case 'property_declaration':
      case 'sequence_declaration':
      case 'covergroup_declaration':
      case 'clocking_declaration':
      case 'constraint_declaration':
      case 'interface_declaration_body':
        return this.blockDecl(node);

      case 'modport_declaration':
        return this.modportDeclaration(node);

      case 'checker_declaration':
      case 'genvar_declaration':
        return this.line(this.text(node));

      case 'module_item':
      case 'module_or_generate_item':
      case 'block_item_declaration': {
        const inner = namedChildren(node).find((k) => !isCommentNode(k));
        if (inner) {
          if (inner.type === 'port_declaration') return this.declaration(node);
          return this.moduleItem(inner);
        }
        return this.line(this.text(node));
      }

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
      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        if (i > 0 && isCommentNode(item) && this.sameSourceLine(items[i - 1], item)) {
          this.appendTrailingComment(item);
          continue;
        }
        this.moduleItem(item);
      }
    } else if (items.length) {
      this.emit(this.text(items[0]), { indent: 0, group: 'header' });
      for (let i = 1; i < items.length; i++) {
        const item = items[i];
        if (i > 0 && isCommentNode(item) && this.sameSourceLine(items[i - 1], item)) {
          this.appendTrailingComment(item);
          continue;
        }
        this.moduleItem(item);
      }
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
    if (!ports.length && !paramList) {
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
        if (p.isComment) { this.emit(p.comment, { indent: 0, group: 'param' }); continue; }
        this.emit(p.text, { indent: 0, group: 'param' });
      }
      // Capture trailing comments between the parameter list `)` and the port list `(`.
      const between = this.src.slice(paramList.endIndex, portList.startIndex);
      const trailingCmt = between.replace(/[)\s]+/, '').trim();
      if (trailingCmt.startsWith('//')) {
        this.emit(')', { indent: 0, group: 'param-close' });
        this.emit(trailingCmt, { indent: 0, group: 'param' });
        this.emit('(', { indent: 0, group: 'param-close' });
      } else {
        this.emit(') (', { indent: 0, group: 'param-close' });
      }
    } else {
      // No parameter list: the port list opens on the module-name line
      // (`module align_demo (`), which is how the header reads in the style
      // guide — the `(` is part of the signature, not a block opener.
      this.emit('(', { indent: 0, group: 'header-open', joinPrev: true });
    }

    const realPorts = ports.filter((p) => !p.isComment && !p.isRaw);
    // In an ANSI header `input a, b, c` is one declaration spread over several
    // grammar nodes; the second and third arrive without a direction. Emitting
    // them bare would change their meaning (a direction-less port is `inout`),
    // so the previous declaration's prefix is carried over.
    const ansi = portList.type === 'list_of_port_declarations';
    let inherit = '';
    ports.forEach((p) => {
      if (p.isComment) {
        this.emit(p.comment, { indent: 0, group: 'port', kind: itemKind(p.comment) });
        return;
      }
      if (p.isRaw) {
        for (const seg of p.text.split(/\r\n|\r|\n/)) {
          const t = seg.trim();
          if (t) this.emit(t, { indent: 0, group: 'port', kind: 'raw' });
        }
        return;
      }
      const idx = realPorts.indexOf(p);
      let text = collapse(p.text);
      if (ansi && /^[A-Za-z_$][\w$]*\s*$/.test(text.replace(/,$/, ''))) {
        if (inherit) text = inherit + text;
      } else if (ansi) {
        const cols = declarationColumns(text);
        if (cols && cols.dirEnd > 0) inherit = text.slice(0, cols.nameStart);
      }
      const comma = p.isText ? '' : (idx === realPorts.length - 1 ? '' : ',');
      const cmt = p.comment ? ' ' + p.comment : '';
      this.emit(text + comma + cmt, { indent: 0, group: 'port' });
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
      case 'if_generate_construct':
      case 'generate_block':
        return this.generate(node);

      case 'module_instantiation':
      case 'udp_instantiation':
        return this.instantiation(node);

      case 'function_declaration':
      case 'task_declaration':
      case 'property_declaration':
      case 'sequence_declaration':
      case 'covergroup_declaration':
      case 'clocking_declaration':
      case 'constraint_declaration':
        return this.blockDecl(node);

      case 'modport_declaration':
        return this.modportDeclaration(node);

      case 'class_declaration':
        return this.classDeclaration(node);

      case 'module_item':
      case 'module_or_generate_item':
      case 'block_item_declaration': {
        const inner = namedChildren(node).find((k) => !isCommentNode(k));
        if (inner) {
          if (inner.type === 'port_declaration') return this.declaration(node);
          return this.moduleItem(inner);
        }
        return this.line(this.text(node));
      }

      default:
        return this.line(this.text(node));
    }
  }

  /**
   * `if (...) begin … end [else …]` at generate scope.
   *
   * Children appear in source order: condition, then-block, else-block or a
   * nested if_generate_construct (else-if), interleaved with comments.
   * Everything is walked in order so a comment between the branches —
   * `end // block: foo` — is never dropped.
   *
   * `joinHead` requests that the `if (...)` head continue the previous line,
   * which is how `else if (...)` stays on one line.
   */
  generateIf(node, joinHead) {
    const kids = namedChildren(node);
    let branch = 0;
    let prev = null;
    for (const k of kids) {
      if (isCommentNode(k)) { this.commentInSequence(k, prev); continue; }
      if (k.type === 'generate_block') {
        const isElse = branch++ > 0;
        // An `else` written as `else if (...)` arrives as an implicit block
        // holding the nested if; unwrap it so the chain stays flat instead of
        // turning into `else begin if … end`.
        const chained = isElse ? implicitGenerateIf(k, this.src) : null;
        if (chained) {
          this.emit('else', { indent: this.indent, group: 'gen-head', joinPrev: this.prevLineIsEnd() });
          this.generateIf(chained, true);
          return;
        }
        if (isElse) {
          this.emit('else', { indent: this.indent, group: 'gen-head', joinPrev: this.prevLineIsEnd() });
        }
        this.hangGenerate = true;
        this.generate(k);
      } else if (k.type === 'if_generate_construct') {
        this.emit('else', { indent: this.indent, group: 'gen-head', joinPrev: this.prevLineIsEnd() });
        this.generateIf(k, true);
        return;
      } else if (k.type === 'constant_expression' || k.type === 'expression') {
        this.emit('if (' + collapse(this.text(k)) + ')',
          { indent: this.indent, group: 'gen-head', joinPrev: !!joinHead });
      } else {
        this.generate(k);
      }
      prev = k;
    }
  }

  generate(node) {
    switch (node.type) {
      case 'generate_region': {
        // `generate <items...> endgenerate` — emit the keyword, recurse, close.
        this.emit('generate', { indent: this.indent, group: 'gen-head' });
        this.indent++;
        for (const k of namedChildren(node)) {
          if (isCommentNode(k)) { this.commentBlock(k); continue; }
          this.generate(k);
        }
        this.indent--;
        this.emit('endgenerate', { indent: this.indent, group: 'gen-head' });
        return;
      }
      case 'generate_construct': {
        for (const k of namedChildren(node)) this.generate(k);
        return;
      }
      case 'conditional_generate_construct': {
        // Wraps if_generate_construct / case_generate_construct.
        for (const k of namedChildren(node)) this.generate(k);
        return;
      }
      case 'if_generate_construct': {
        this.generateIf(node, false);
        return;
      }
      case 'loop_generate_construct': {
        // children: genvar_initialization, constant_expression, genvar_iteration, generate_block
        const kids = namedChildren(node);
        const init = kids.find((k) => k.type === 'genvar_initialization');
        const cond = kids.find((k) => k.type === 'constant_expression');
        const iter = kids.find((k) => k.type === 'genvar_iteration');
        const block = kids.find((k) => k.type === 'generate_block');
        const parts = [];
        if (init) parts.push(collapse(this.text(init)));
        if (cond) parts.push(collapse(this.text(cond)));
        if (iter) parts.push(collapse(this.text(iter)));
        this.emit('for (' + parts.join('; ') + ')', { indent: this.indent, group: 'gen-head' });
        if (block) { this.hangGenerate = true; this.generate(block); }
        return;
      }
      case 'generate_block': {
        // `begin : name <items...> end` (name optional).
        const kids = namedChildren(node);
        const nameNode = kids.find((k) => k.type === 'simple_identifier');
        const items = kids.filter((k) => k.type !== 'simple_identifier');
        const hang = this.hangGenerate;
        this.hangGenerate = false;
        // A block the author did not open with `begin` is a container only —
        // walking into it must not invent a scope, otherwise `else if (...)` and
        // a bare `generate if (...)` grow phantom `begin`/`end` pairs.
        const implicit = !/^\s*begin\b/.test(this.src.slice(node.startIndex, node.endIndex));
        if (implicit) {
          for (const it of items) {
            if (isCommentNode(it)) { this.commentInSequence(it, null); continue; }
            this.moduleItem(it);
          }
          return;
        }
        if (nameNode) {
          this.emit('begin : ' + nameNode.text, { indent: this.indent, group: 'gen-block', joinPrev: hang });
        } else {
          this.emit('begin', { indent: this.indent, group: 'gen-block', joinPrev: hang });
        }
        this.indent++;
        let prev = null;
        for (const it of items) {
          if (isCommentNode(it)) { this.commentInSequence(it, prev); continue; }
          this.moduleItem(it);
          prev = it;
        }
        this.indent--;
        this.emit('end', { indent: this.indent, group: 'gen-block' });
        return;
      }
      default: {
        // Unknown generate-shaped node: peel named children like the original.
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
    }
  }

  /**
   * Module instantiation.
   *
   * Two layouts are available, chosen by `instanceLayout`:
   *
   *   explode — one connection per line, columns aligned. The right choice for
   *             a port map of any size, and the default.
   *   compact — the whole instance on one line, with the `.port(expr)` columns
   *             of neighbouring instances of the same module aligned into a
   *             table. Built for the "ten tiny three-port instances" case,
   *             where exploding costs forty lines to say nothing.
   *
   * 'auto' picks compact up to `compactInstanceMaxPorts` connections. Any list
   * carrying a comment or a preprocessor directive always explodes: folding it
   * onto one line would drop or reorder what is written there.
   */
  instantiation(node) {
    const inst = firstChildOfType(node, ['hierarchical_instance', 'udp_instance']);
    if (!inst) {
      this.emit(this.text(node), { indent: this.indent, group: 'inst' });
      return;
    }

    const ports = portConnections(inst);
    const layout = this.instanceLayout(ports);
    if (layout === 'off' || !ports.length) {
      this.emit(this.text(node), { indent: this.indent, group: 'inst' });
      return;
    }

    // `fifo #(...) u_fifo (` — first `(` at or after the instance name; the
    // parameter list, if any, sits before it and is already behind us.
    const openParen = this.src.indexOf('(', inst.startIndex);
    if (layout === 'compact' && this.compactInstance(node, inst, ports, openParen)) return;

    const params = firstChildOfType(node, ['parameter_value_assignment']);
    const paramItems = params ? paramAssignments(params) : [];
    // A lone `.DEPTH(8)` reads better inline; anything longer (or documented
    // with comments) gets one override per line, like the port map below it.
    const explodeParams = params &&
      (paramItems.filter((p) => !p.isComment).length > 1 || paramItems.some((p) => p.isComment));

    if (explodeParams) {
      // `mod #(.A(1), .B(2)) u_mod (`: explode the override list exactly like
      // the port map. Folding it into the head turned a four-line override into
      // one ~200-column line that also swallowed the instance name and the
      // opening paren of the port list.
      const head = collapse(this.src.slice(node.startIndex, params.startIndex)).replace(/\s+$/, '');
      this.emit(head + ' #(', { indent: this.indent, group: 'inst-head' });
      this.indent++;
      paramItems.forEach((p, i) => {
        const last = i === paramItems.length - 1;
        let text = p.isComment ? p.text : collapse(p.text).replace(/\s+$/, '');
        if (!p.isComment && !last) text += ',';
        this.emit(text, {
          indent: this.indent,
          group: 'inst-port',
          kind: p.isComment ? itemKind(p.text) : 'code',
        });
      });
      this.indent--;
      const tail = collapse(this.src.slice(params.endIndex, openParen + 1)).replace(/\s+$/, '');
      this.emit(') ' + tail, { indent: this.indent, group: 'inst-tail' });
    } else {
      const headRaw = this.src.slice(node.startIndex, openParen + 1);
      for (const seg of collapseHeadSegments(headRaw)) {
        this.emit(seg, { indent: this.indent, group: 'inst-head' });
      }
    }

    this.indent++;
    ports.forEach((p, i) => {
      if (p.comment && !p.text) {
        this.emit(p.comment, { indent: this.indent, group: 'inst-port', kind: itemKind(p.comment) });
        return;
      }
      if (p.isRaw) {
        for (const seg of p.text.split(/\r\n|\r|\n/)) {
          const t = seg.trim();
          if (t) this.emit(t, { indent: this.indent, group: 'inst-port', kind: 'raw' });
        }
        return;
      }
      const last = i === ports.length - 1;
      const body = collapse(p.text).replace(/\s*$/, '');
      const text = body.endsWith(',') ? body : body + (last ? '' : ',');
      this.emit(text, { indent: this.indent, group: 'inst-port' });
    });
    this.indent--;
    this.emit(');', { indent: this.indent, group: 'inst-tail' });
  }

  /**
   * Which layout to use for this instance's port map.
   *
   * Kept as a method rather than inline so the rule lives in one place: the
   * `compact` decision depends on the connection list, not on the node.
   */
  instanceLayout(ports) {
    if (!this.cfg.explodeInstancePorts) return 'off';
    const mode = this.cfg.instanceLayout;
    if (mode === 'off') return 'off';
    if (mode === 'explode') return 'explode';
    // A comment or a directive between connections cannot survive being folded
    // onto one line, so those lists always explode regardless of the setting.
    if (ports.some((p) => p.comment || p.isRaw)) return 'explode';
    if (mode === 'compact') return 'compact';
    return ports.length <= this.cfg.compactInstanceMaxPorts ? 'compact' : 'explode';
  }

  /**
   * Emit one instance on a single line and hand the pieces to the align pass.
   *
   * The canonical text written here has single spaces everywhere; `AlignPass`
   * rebuilds it from the `compact` payload with the columns padded. Keeping the
   * two steps apart is what makes the result idempotent — the emitter always
   * starts from an unpadded form, so re-running cannot accumulate padding.
   *
   * Returns false when a connection does not fit the `.name(expr)` shape, so
   * the caller can fall back to the exploded layout instead of guessing.
   */
  compactInstance(node, inst, ports, openParen) {
    const items = [];
    for (const p of ports) {
      const part = splitPortConnection(collapse(p.text));
      if (!part) return false;
      items.push(part);
    }

    // Everything before the instance name: `mod`, or `mod #(...)`.
    const prefix = collapse(this.src.slice(node.startIndex, inst.startIndex)).trim();
    const name = collapse(this.src.slice(inst.startIndex, openParen)).trim();
    if (!prefix || !name) return false;

    const body = items
      .map((it) => {
        if (it.expr === null) return it.name;
        return it.name + (it.paren ? '(' + it.expr + ')' : it.expr);
      })
      .join(', ');
    this.emit(prefix + ' ' + name + ' (' + body + ');', {
      indent: this.indent,
      group: 'inst-compact',
      compact: {
        mod: prefix,
        prefix,
        name,
        items,
        // Which entries are `.name(...)` and which are positional. A group only
        // mixes them safely if the shapes match, so it doubles as a group key.
        sig: items.map((it) => (it.name ? 'n' : 'p')).join(''),
        // Same module does not imply same port order; without this, two
        // instances that list their ports differently would be aligned column
        // by column and land on the wrong x position for every entry.
        names: items.map((it) => it.name).join('|'),
      },
    });
    return true;
  }

  /**
   * modport master ( ... );
   *
   * The grammar exposes the port directions only as loose tokens, so the layout
   * is preserved line for line: a one-line modport stays one line, a multi-line
   * one keeps one entry per line and is re-indented as a block.
   */
  modportDeclaration(node) {
    const lines = nodeLines(this.src.slice(node.startIndex, node.endIndex))
      .map((ln) => ln.trim())
      .filter(Boolean);
    if (lines.length <= 1) return this.line(collapse(lines[0] || ''));
    this.emit(collapse(lines[0]), { indent: this.indent, group: 'modport' });
    for (const ln of lines.slice(1, -1)) {
      this.emit(ln, { indent: this.indent + 1, group: 'modport' });
    }
    this.emit(collapse(lines[lines.length - 1]), { indent: this.indent, group: 'modport' });
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

    const headRaw = headKeyword + (timingText ? ' ' + timingText : '');
    const { text: headClean, comments: headComments } = stripLineComments(headRaw);
    let head = collapse(headClean);
    for (const c of headComments) head += ' ' + c;
    this.emit(head, { indent: this.indent, group: 'always-head' });

    if (!body) return;
    this.hangBlock = !headComments.length;
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
      // Comments and other leaf nodes are not statement wrappers — push them
      // directly so unwrapStatements does not drop them (it returns [] for
      // childless nodes).
      if (STATEMENT_WRAPPERS.has(k.type)) body.push(...unwrapStatements(k));
      else body.push(k);
    }

    this.emit('begin' + (label ? ' : ' + label : ''), {
      indent: this.indent,
      group: 'begin',
      joinPrev: !!hang,
    });
    this.indent++;
    for (let i = 0; i < body.length; i++) {
      const k = body[i];
      if (i > 0 && isCommentNode(k) && this.sameSourceLine(body[i - 1], k)) {
        this.appendTrailingComment(k);
        continue;
      }
      this.statementItem(k);
    }
    this.indent--;
    this.emit('end', { indent: this.indent, group: 'end' });
  }

  conditional(node) {
    const kids = namedChildren(node);
    const branches = collectConditional(kids);
    for (const br of branches) {
      if (br.comment && br.stmt === undefined) { this.commentBlock(br.comment); continue; }
      if (br.condComments) {
        for (const c of br.condComments) this.emit(c, { indent: this.indent, group: 'comment' });
      }
      let head;
      if (br.elseIf) {
        head = 'else if' + (br.cond ? ' ' + br.cond : '');
      } else if (br.else) {
        head = 'else';
      } else {
        head = 'if' + (br.cond ? ' ' + br.cond : '');
      }
      if (br.comment) head += ' ' + br.comment.text.trim();
      // `end else begin` — the `else` of a completed block belongs on the
      // `end` line; a dangling `begin` then hangs onto it as usual.
      this.emit(head, {
        indent: this.indent,
        group: br.else ? 'else' : 'cond',
        joinPrev: !!(br.else || br.elseIf) && this.prevLineIsEnd(),
      });
      this.hangBlock = !br.comment;
      this.emitBody(br.stmt);
      this.hangBlock = false;
    }
  }

  caseStatement(node) {
    const kids = namedChildren(node);
    const items = kids.filter((k) => k.type === 'case_item' || k.type === 'default_case_item' || isCommentNode(k));

    // Header = everything before the first case item, collapsed.
    const firstItem = items[0];
    const headEnd = firstItem ? firstItem.startIndex : node.endIndex;
    const rawHead = this.src.slice(node.startIndex, headEnd);
    const head = collapse(rawHead).replace(/\s*$/, '');

    this.emit(head || 'case', { indent: this.indent, group: 'case-head' });
    this.indent++;
    for (const it of items) {
      if (isCommentNode(it)) { this.commentBlock(it); continue; }
      this.caseItem(it);
    }
    this.indent--;
    this.emit('endcase', { indent: this.indent, group: 'end' });
  }

  caseItem(node) {
    const kids = namedChildren(node);
    if (!kids.length) return this.line(this.text(node));

    const last = kids[kids.length - 1];
    const isDefault = node.type === 'default_case_item' ||
      (kids.length === 1 && /default/.test(this.text(node)));
    const label = isDefault
      ? 'default:'
      : kids.slice(0, -1).map((k) => this.text(k)).join(', ') + ':';

    // A case item whose body is one simple statement stays on the label line —
    // an encoding table is unreadable when every entry costs two lines.
    const inline = this.inlineCaseBody(last, label);
    if (inline !== null) {
      this.emit(label + ' ' + inline, { indent: this.indent, group: 'case-item' });
      return;
    }

    this.emit(label, { indent: this.indent, group: 'case-label' });

    // Body: last named child is the statement.
    this.hangBlock = true;
    this.emitBody(last);
    this.hangBlock = false;
  }

  /**
   * Text to append after a case label, or `null` when the body has to start on
   * its own line (a block, a nested control construct, or just too long).
   */
  inlineCaseBody(stmt, label) {
    if (!this.cfg.caseItemOnSameLine || !stmt) return null;
    const inner = unwrapOne(stmt);
    if (!inner || BLOCK_NODE_TYPES.has(inner.type)) return null;
    const text = collapse(this.text(stmt)).replace(/\s*;$/, ';').trim();
    if (!text || !/;$/.test(text)) return null;
    if (splitBlockText(text) !== null) return null;
    if (/^(if|for|foreach|while|repeat|forever|case|casex|casez|fork|begin)\b/.test(text)) return null;
    const width = this.indent * this.cfg.indentSize + label.length + 1 + text.length;
    if (this.cfg.maxLineLength && width > this.cfg.maxLineLength) return null;
    return text;
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
    const lines = nodeLines(node.text);
    lines.forEach((ln, i) => {
      this.push(ln.replace(/\s+$/, ''), i === 0 ? this.indent : 0, 'raw', null);
    });
  }

  /**
   * Emit a comment.
   *
   * The first line gets the current indent; continuation lines of a block
   * comment are emitted verbatim so that reformatting never ratchets their
   * indentation (which would make formatting non-idempotent).
   */
  commentBlock(node) {
    const lines = nodeLines(node.text);
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

  /**
   * Append a trailing comment to the last emitted line instead of creating
   * a new line.  This keeps `reg x; // comment` on one line.
   */
  appendTrailingComment(node) {
    const comment = node.text.trim();
    if (this.lines.length > 0) {
      const last = this.lines[this.lines.length - 1];
      if (last.text && !last.joinPrev) {
        last.text = last.text + ' ' + comment;
        return;
      }
    }
    this.emit(comment, { indent: this.indent, group: 'comment' });
  }

  // ------------------------------------------------------------- emitting

  /**
   * True when the previously emitted line is a block terminator (`end`,
   * `endcase`, `endgenerate`, …). Used to keep `else` on the `end` line.
   */
  prevLineIsEnd() {
    for (let i = this.lines.length - 1; i >= 0; i--) {
      const ln = this.lines[i];
      if (!ln.text) continue;
      // A trailing `// …` owns the rest of the line: appending `else` there would
      // push the keyword into the comment and silently break the code.
      if (ln.text.includes('//')) return false;
      return /^end[a-z_]*\b/.test(ln.text) && !ln.joinPrev;
    }
    return false;
  }

  /**
   * Emit a comment that sits between two siblings: appended to the previous
   * line when it shares that line in the source, otherwise on its own line.
   */
  commentInSequence(node, prev) {
    if (prev && this.sameSourceLine(prev, node)) this.appendTrailingComment(node);
    else this.commentBlock(node);
  }

  /**
   * Do `prev` and `cur` share a source line?
   *
   * Row numbers alone are not enough: nodes such as `one_line_comment` and
   * `` `define `` can swallow their line terminator, which bumps
   * `endPosition.row` to the *next* line and used to glue a following comment
   * onto the previous statement. Compare the actual gap text instead.
   */
  sameSourceLine(prev, cur) {
    if (!prev || !cur) return false;
    if (/[\r\n]$/.test(prev.text || '')) return false;
    return !/[\r\n]/.test(this.src.slice(prev.endIndex, cur.startIndex));
  }

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
    // Code lines get their operator spacing normalised here, before the
    // alignment pass measures columns, so padded columns are computed from the
    // final text. Raw (macro / directive) and comment lines pass through
    // untouched.
    if (kind === 'code') text = normalizeSpacing(text, this.cfg);
    this.lines.push({
      text,
      indent,
      kind,
      group: o.group || null,
      // Structured payload for lines the align pass has to rebuild from parts
      // rather than pad in place (compact instances).
      compact: o.compact || null,
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

/**
 * Operator spacing.
 *
 * The tree gives us structure, not formatting, and most expressions arrive as
 * raw source text — so `q<=cnt+1'b1;` would stay cramped. This normalises a
 * single code line: one space on each side of a binary operator, one space after
 * a comma.
 *
 * Deliberately conservative:
 *   - index / part-select ranges (`[W-1:0]`) are copied untouched;
 *   - string literals, `//` comments and directive lines are untouched;
 *   - operators that are really punctuation (`::`, `++`, `--`, `**`, `->`, `.*`)
 *     are copied as-is;
 *   - an operator with no left operand (`(-1)`, `*ptr`) is unary and keeps its
 *     tight spacing.
 */
const ATOMIC_OPS = ['<<<=', '>>>=', '::', '++', '--', '**', '->', '.*'];
const BINARY_OPS = [
  '<<<', '>>>', '<<=', '>>=', '===', '!==', '==?', '!=?',
  '<<', '>>', '<=', '>=', '==', '!=', '&&', '||',
  '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=',
  '+', '-', '*', '/', '%', '&', '|', '^', '<', '>', '=', '?', ':',
];
const ALL_OPS = ATOMIC_OPS.concat(BINARY_OPS).sort((a, b) => b.length - a.length);
const OPERAND_END = /[A-Za-z0-9_$'\]\)}]/;

function normalizeSpacing(text, cfg) {
  const wantOps = cfg.spaceAroundBinaryOperators !== false;
  const wantComma = cfg.spaceAfterComma !== false;
  if (!text || (!wantOps && !wantComma)) return text;
  if (/^\s*`/.test(text)) return text;
  if (!/[-+*/%&|^<>=!?:,]/.test(text)) return text;

  const n = text.length;
  let out = '';
  let i = 0;
  let bracket = 0;
  // `?` open ternary levels. A `:` only separates expressions when one is
  // pending; otherwise it terminates a case item label and stays tight.
  let ternary = 0;

  const lastReal = () => {
    for (let k = out.length - 1; k >= 0; k--) {
      if (out[k] !== ' ' && out[k] !== '\t') return out[k];
    }
    return '';
  };
  const nextReal = (from) => {
    for (let k = from; k < n; k++) {
      if (text[k] !== ' ' && text[k] !== '\t') return { ch: text[k], at: k };
    }
    return { ch: '', at: n };
  };

  while (i < n) {
    const c = text[i];

    if (c === '"') {                                   // string literal
      out += c;
      i++;
      while (i < n) {
        out += text[i];
        if (text[i] === '\\' && i + 1 < n) { out += text[i + 1]; i += 2; continue; }
        if (text[i] === '"') { i++; break; }
        i++;
      }
      continue;
    }
    if (c === '/' && text[i + 1] === '/') { out += text.slice(i); break; }
    if (c === '/' && text[i + 1] === '*') {
      const end = text.indexOf('*/', i + 2);
      if (end === -1) { out += text.slice(i); break; }
      out += text.slice(i, end + 2);
      i = end + 2;
      continue;
    }
    if (c === '[') { bracket++; out += c; i++; continue; }
    if (c === ']') { bracket = Math.max(0, bracket - 1); out += c; i++; continue; }

    // Index and range contents keep the author's spacing.
    if (bracket > 0) { out += c; i++; continue; }

    if (wantComma && c === ',') {
      out += c;
      const nx = nextReal(i + 1);
      if (nx.ch && !/[)\]};]/.test(nx.ch)) { out += ' '; i = nx.at; } else i++;
      continue;
    }

    // `for (i = 0; i < 8; i = i + 1)` — one space after a statement separator,
    // but a terminator at end of line stays bare.
    if (c === ';') {
      if (cfg.spaceBeforeSemicolon === false) {
        while (out.endsWith(' ') || out.endsWith('\t')) out = out.slice(0, -1);
      }
      out += c;
      const nx = nextReal(i + 1);
      if (nx.ch && !/[;)\]}]/.test(nx.ch)) { out += ' '; i = nx.at; } else i++;
      continue;
    }

    if (wantOps) {
      let op = null;
      for (const cand of ALL_OPS) {
        if (text.startsWith(cand, i)) { op = cand; break; }
      }
      if (op) {
        if (ATOMIC_OPS.includes(op)) { out += op; i += op.length; continue; }
        if (op === '?') {
          const nx = nextReal(i + 1);
          while (out.endsWith(' ') || out.endsWith('\t')) out = out.slice(0, -1);
          const prev = lastReal();
          out += (prev && OPERAND_END.test(prev) ? ' ? ' : '? ');
          ternary++;
          i = nx.at;
          continue;
        }
        if (op === ':') {
          if (ternary === 0) {
            // Case item label: `2'd0:` / `default:` — no space before the colon.
            // A block label keeps its spacing: `begin : name`.
            let head = out;
            while (head.endsWith(' ') || head.endsWith('\t')) head = head.slice(0, -1);
            if (/\bbegin$/.test(head)) {
              const nx = nextReal(i + 1);
              out = head + ' : ';
              i = nx.at;
              continue;
            }
            out = head + ':';
            i += 1;
            continue;
          }
          ternary--;
          const nx = nextReal(i + 1);
          while (out.endsWith(' ') || out.endsWith('\t')) out = out.slice(0, -1);
          out += ' : ';
          i = nx.at;
          continue;
        }
        const nx = nextReal(i + op.length);
        const prev = lastReal();
        const binary = prev && OPERAND_END.test(prev) &&
          nx.ch && !/[;,)\]}]/.test(nx.ch);
        if (binary) {
          while (out.endsWith(' ') || out.endsWith('\t')) out = out.slice(0, -1);
          out += ' ' + op + ' ';
          i = nx.at;
          continue;
        }
        out += op;
        i += op.length;
        continue;
      }
    }

    out += c;
    i++;
  }

  return out.replace(/[ \t]+$/, '');
}

/**
 * Split a node's text into lines.
 *
 * Some nodes swallow their line terminator: with CRLF input the grammar gives
 * `one_line_comment` the text `// x\r`, and `` `define `` nodes the text
 * `...\r\n`. A naive split then yields a trailing empty element, which used to
 * emit a phantom blank line after every comment and every macro — and, since
 * the output is LF-only, made the second format pass differ from the first.
 * Trailing terminators are therefore dropped here.
 */
function nodeLines(text) {
  return text
    .replace(/(?:(?:\r\n|\r|\n)[ \t]*)+$/, '')
    .split(/\r\n|\r|\n/);
}

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
 * Split a header string into segments, preserving `//` line comments on their
 * own lines.  Without this, collapse() would join everything into one line and
 * a `//` comment would eat the rest of the header.
 */
function collapseHeadSegments(s) {
  if (!s) return [''];
  const segments = [];
  let code = '';
  let i = 0;
  while (i < s.length) {
    if (s[i] === '"') {
      code += s[i++];
      while (i < s.length && s[i] !== '"') {
        if (s[i] === '\\' && i + 1 < s.length) { code += s[i++] + s[i++]; }
        else code += s[i++];
      }
      if (i < s.length) code += s[i++];
      continue;
    }
    if (s[i] === '/' && s[i + 1] === '/') {
      if (code.trim()) segments.push(collapse(code));
      code = '';
      let comment = '';
      while (i < s.length && s[i] !== '\n') comment += s[i++];
      segments.push(comment.trim());
      continue;
    }
    code += s[i++];
  }
  if (code.trim()) segments.push(collapse(code));
  return segments.length ? segments : [''];
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
  const bindComment = (c) => {
    const prev = found.length ? found[found.length - 1] : null;
    // A comment belongs to the item it trails only when it starts on the same
    // source line. Port and connection lists are normally documented one
    // comment per line *above* the entry; treating that as the previous entry's
    // trailing comment shifts every comment up by one, so each port ends up
    // carrying its neighbour's documentation.
    const sameLine = prev && !prev.isComment && !prev.isRaw && !prev.comment &&
      !/[\r\n]/.test(src.slice(prev.endIndex, c.startIndex));
    if (sameLine) {
      prev.comment = c.text.trim();
    } else {
      found.push({ startIndex: c.startIndex, endIndex: c.endIndex, text: '', comment: c.text.trim(), isComment: true });
    }
  };
  const walk = (n, depth) => {
    if (depth > 4) return;
    for (let i = 0; i < n.namedChildCount; i++) {
      const c = n.namedChild(i);
      if (c.type === 'ansi_port_declaration' || c.type === 'port_declaration' || c.type === 'port') {
        found.push({ startIndex: c.startIndex, endIndex: c.endIndex, text: c.text, comment: '' });
        continue;
      }
      if (c.type === 'conditional_compilation_directive' || c.type === 'ERROR') {
        found.push({ startIndex: c.startIndex, endIndex: c.endIndex, text: c.text, comment: '', isRaw: true });
        continue;
      }
      // Bind trailing comment to the preceding port, or emit as a standalone line
      // (group comment / second comment on the same port).
      if (isCommentNode(c) && depth === 0) { bindComment(c); continue; }
      if (c.namedChildCount > 0) walk(c, depth + 1);
    }
  };
  walk(portList, 0);
  if (found.length) return found.sort((a, b) => a.startIndex - b.startIndex);

  // Non-ANSI list_of_ports: bare `port` nodes (`clk`, `rst`, ...) with optional
  // trailing one_line_comment / block_comment siblings. Bind each comment to the
  // preceding port so it stays on the same line instead of merging into the next.
  const ports = [];
  for (let i = 0; i < portList.namedChildCount; i++) {
    const c = portList.namedChild(i);
    if (c.type === 'port') {
      ports.push({ startIndex: c.startIndex, endIndex: c.endIndex, text: c.text, comment: '' });
    } else if (isCommentNode(c) && ports.length > 0) {
      ports[ports.length - 1].comment = c.text.trim();
    }
  }
  if (ports.length) return ports.sort((a, b) => a.startIndex - b.startIndex);

  // Fallback: split the raw text at top-level commas (comment-aware).
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

/** Same test as `isCommentNode`, for a rendered line of text. */
function isCommentText(text) {
  return /^\s*(\/\/|\/\*)/.test(text || '');
}

/**
 * Line kind for an entry of a port / connection list.
 *
 * `//@@svd-dir:N@@` is a preprocessor directive that was masked so the grammar
 * could parse the list; it must behave like a directive, not like a comment, or
 * the alignment would treat two alternative `ifdef` branches as one table.
 */
function itemKind(text) {
  return /^\s*\/\/@@svd-dir:\d+@@/.test(text || '') ? 'raw' : 'code';
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

/**
 * `else if (...)` is parsed as an `else` block with no `begin` in the source
 * that holds one nested conditional generate construct. Return that construct
 * so the else-if chain can be emitted flat, or `null` for a real block.
 */
function implicitGenerateIf(block, src) {
  if (!src) return null;
  if (/^\s*begin\b/.test(src.slice(block.startIndex, block.endIndex))) return null;
  const kids = namedChildren(block);
  if (kids.length !== 1) return null;
  const only = kids[0];
  if (only.type === 'conditional_generate_construct' || only.type === 'if_generate_construct') {
    const inner = only.type === 'conditional_generate_construct'
      ? namedChildren(only)[0]
      : only;
    return inner && inner.type === 'if_generate_construct' ? inner : null;
  }
  return null;
}

/** Split text into `head` / `body` / `tail` around the first block keyword. */
/**
 * Split `for (...) begin ... end` into header / body / terminator.
 *
 * The scan has to be nesting-aware: a `begin` inside the body opens a block
 * whose `end` must not be mistaken for the loop's own terminator. Tracking the
 * parenthesis depth alone was enough to miss that, which silently truncated the
 * body of any loop containing an inner block (`for (...) begin ... for (...)
 * begin ... end end`).
 *
 * The header keeps its opener keyword (`begin`, `fork`, …) so the caller can
 * emit it as `for (...) begin` without re-deriving it.
 */
function splitBlockText(text) {
  const openers = ['begin', 'case', 'casex', 'casez', 'randcase', 'fork'];
  const closers = ['end', 'endcase', 'join', 'join_any', 'join_none'];
  let i = 0;
  let pdepth = 0;
  let nest = 0;
  let inStr = false;
  let headEnd = -1;
  let openerLen = 0;

  while (i < text.length) {
    const c = text[i];
    if (inStr) {
      if (c === '\\') i++;
      else if (c === '"') inStr = false;
      i++;
      continue;
    }
    if (c === '"') { inStr = true; i++; continue; }
    if (c === '(' || c === '[' || c === '{') { pdepth++; i++; continue; }
    if (c === ')' || c === ']' || c === '}') { pdepth--; i++; continue; }

    // Only look at word starts at paren depth 0: `end` inside `f(end_x)` or
    // inside `weekend` is not a terminator.
    if (pdepth === 0 && /[A-Za-z_]/.test(c) && (i === 0 || !/[\w$]/.test(text[i - 1]))) {
      const rest = text.slice(i);
      const om = openers.map((o) => new RegExp('^' + o + '\\b').exec(rest)).find(Boolean);
      const cm = closers.map((o) => new RegExp('^' + o + '\\b').exec(rest)).find(Boolean);

      if (om && headEnd < 0) {
        headEnd = i;
        openerLen = om[0].length;
        nest = 1;
        i += om[0].length;
        continue;
      }
      if (cm) {
        nest--;
        if (nest <= 0) {
          return {
            head: (collapse(text.slice(0, headEnd)).replace(/\s*$/, '') + ' ' +
              text.slice(headEnd, headEnd + openerLen)).trim(),
            body: text.slice(headEnd + openerLen, i),
            tail: collapse(text.slice(i)),
          };
        }
        i += cm[0].length;
        continue;
      }
      if (om) {
        nest++;
        i += om[0].length;
        continue;
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
      const pt = predicateText(k);
      out.push({
        elseIf: seenPred > 0,
        else: false,
        cond: pt.text,
        condComments: pt.comments,
        stmt: null,
      });
      seenPred++;
      continue;
    }
    // Preserve comments between branches so they are not silently dropped.
    if (isCommentNode(k)) {
      if (out.length && out[out.length - 1].stmt === null && !out[out.length - 1].comment) {
        out[out.length - 1].comment = k;
      } else {
        out.push({ comment: k });
      }
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
  if (inner) {
    const { text, comments } = stripLineComments(inner.text);
    return { text: '(' + collapse(text) + ')', comments };
  }
  const { text, comments } = stripLineComments(pred.text);
  const t = collapse(text).replace(/^\(/, '').replace(/\)$/, '');
  return { text: '(' + t + ')', comments };
}

function stripLineComments(s) {
  const comments = [];
  let out = '';
  let i = 0;
  while (i < s.length) {
    if (s[i] === '"') {
      out += s[i++];
      while (i < s.length && s[i] !== '"') {
        if (s[i] === '\\' && i + 1 < s.length) { out += s[i++] + s[i++]; }
        else out += s[i++];
      }
      if (i < s.length) out += s[i++];
      continue;
    }
    if (s[i] === '/' && s[i + 1] === '/') {
      let comment = '';
      while (i < s.length && s[i] !== '\n') comment += s[i++];
      comments.push(comment.trim());
      continue;
    }
    out += s[i++];
  }
  return { text: out, comments };
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
    // Line comment: attach to the preceding segment so it does not leak into
    // the next comma-separated entry.
    if (c === '/' && s[i + 1] === '/') {
      let j = i;
      while (j < s.length && s[j] !== '\n') j++;
      const comment = s.slice(i, j);
      if (cur.trim() === '' && res.length > 0) res[res.length - 1] += comment;
      else cur += comment;
      i = j - 1;
      continue;
    }
    // Block comment: same binding rule.
    if (c === '/' && s[i + 1] === '*') {
      let j = i + 2;
      while (j < s.length && !(s[j] === '*' && s[j + 1] === '/')) j++;
      const comment = s.slice(i, j + 2);
      if (cur.trim() === '' && res.length > 0) res[res.length - 1] += comment;
      else cur += comment;
      i = j + 1;
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
    this.alignCompactInstances(out);
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
    const transparent = (l) => l.group === 'port' && (l.kind === 'raw' || isCommentText(l.text));
    for (let i = 0; i < lines.length;) {
      if (!isAlignableDecl(lines[i], 'port')) { i++; continue; }
      const group = this.collectGroup(lines, i, (l) => isAlignableDecl(l, 'port'), transparent);
      if (group.length > 1) this.alignDeclGroup(group);
      i = group.end > i ? group.end : i + 1;
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
      const group = [];
      while (j < lines.length) {
        const ln = lines[j];
        if (ln.group !== 'inst-port') break;
        // Banner comments (`/*AUTOINST*/`, `// Outputs`) sit inside the map but
        // have no paren of their own, so they are skipped rather than ending the
        // run. A preprocessor directive does end it: the branches it separates
        // are alternative port maps, and letting one wide name in another branch
        // (`.txrx_enablelinktest_reg`) set the column padded every short entry
        // out by 60+ columns.
        if (ln.kind === 'raw') break;
        if (isCommentText(ln.text)) { j++; continue; }
        group.push(ln);
        j++;
      }

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
      i = j > i ? j : i + 1;
    }
  }

  /**
   * Align compact instances into a table.
   *
   *   mod u_a  (.clk  (clk), .rst_n(rst_n), .dout(d0));
   *   mod u_bb (.clk  (clk), .rst_n(rst_n), .dout(d1));
   *
   * Only a run of consecutive lines with the same module, the same connection
   * count and the same indent forms a group. Those are the only lines whose
   * k-th `.port(expr)` is the same port; padding a column across anything else
   * would line up unrelated signals and read as noise.
   */
  alignCompactInstances(lines) {
    for (let i = 0; i < lines.length;) {
      const head = lines[i].compact;
      if (lines[i].group !== 'inst-compact' || !head) { i++; continue; }
      let j = i + 1;
      while (j < lines.length) {
        const ln = lines[j];
        if (ln.group !== 'inst-compact' || !ln.compact) break;
        if (ln.kind !== 'code' || ln.indent !== lines[i].indent) break;
        if (ln.compact.mod !== head.mod) break;
        if (ln.compact.items.length !== head.items.length) break;
        if (ln.compact.sig !== head.sig) break;
        if (ln.compact.names !== head.names) break;
        j++;
      }
      this.rebuildCompactGroup(lines.slice(i, j));
      i = j;
    }
  }

  /** Rebuild one group of compact instances with its columns padded. */
  rebuildCompactGroup(group) {
    const head = group[0].compact;
    const cols = head.items.length;
    const widest = (pick) => Math.max(...group.map((l) => pick(l.compact).length));

    const wPrefix = widest((c) => c.prefix);
    const wName = widest((c) => c.name);
    const wPort = new Array(cols).fill(0);
    const wExpr = new Array(cols).fill(0);

    for (const l of group) {
      for (let k = 0; k < cols; k++) {
        const it = l.compact.items[k];
        wPort[k] = Math.max(wPort[k], it.name.length);
        if (it.expr !== null) wExpr[k] = Math.max(wExpr[k], it.expr.length);
      }
    }

    // One wide expression in a column would push every other instance out by
    // the difference; leave that column unpadded instead.
    const cap = this.cfg.alignTerminatorMaxPad;
    if (cap > 0) {
      for (let k = 0; k < cols; k++) {
        const lens = group.map((l) => (l.compact.items[k].expr || '').length);
        if (Math.max(...lens) - Math.min(...lens) > cap) wExpr[k] = 0;
      }
    }

    for (const l of group) {
      const { prefix, name, items } = l.compact;
      const parts = items.map((it, k) => {
        let s = it.name;
        if (s.length < wPort[k]) s += ' '.repeat(wPort[k] - s.length);
        if (it.expr === null) return s;
        if (!it.paren) {
          // Ordered connection: the parentheses belong to the connection list,
          // not to this entry, so there is nothing to align them against.
          s += it.expr;
          if (it.expr.length < wExpr[k]) s += ' '.repeat(wExpr[k] - it.expr.length);
          return s;
        }
        s += '(' + it.expr;
        if (it.expr.length < wExpr[k]) s += ' '.repeat(wExpr[k] - it.expr.length);
        return s + ')';
      });
      l.text = prefix.padEnd(wPrefix) + ' ' + name.padEnd(wName) +
        ' (' + parts.join(', ') + ');';
    }
  }

  alignDeclarations(lines) {
    if (!this.cfg.alignConsecutiveDeclarations) return;
    const transparent = (l) => l.group === 'decl' && (l.kind === 'raw' || isCommentText(l.text));
    for (let i = 0; i < lines.length;) {
      if (!isAlignableDecl(lines[i], 'decl')) { i++; continue; }
      const group = this.collectGroup(lines, i, (l) => isAlignableDecl(l, 'decl'), transparent);
      if (group.length > 1) this.alignDeclGroup(group);
      i = group.end > i ? group.end : i + 1;
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
    for (const ln of group) {
      const text = ln.text;
      const cmt = text.indexOf('//');
      if (cmt >= 0) {
        ln.text = text.slice(0, cmt).replace(/[ \t]{2,}/g, ' ') + text.slice(cmt);
      } else {
        ln.text = text.replace(/[ \t]{2,}/g, ' ');
      }
    }
    const parsed = group.map((l) => declarationColumns(l.text));
    if (parsed.some((p) => p === null)) return;

    // Rebuild each line from its fields rather than nudging boundaries: a line
    // that omits the type (`input [7:0] d`) or the packed width (`input clk`)
    // still has to leave an empty slot of the group's width, otherwise the name
    // column — the one `ref.md` actually asks for — ends up ragged.
    const rows = group.map((l, i) => {
      const c = parsed[i];
      const t = l.text;
      return {
        dir: c.dirEnd > 0 ? t.slice(0, c.dirEnd).trim() : '',
        type: c.typeEnd > 0 ? t.slice(c.dirEnd, c.typeEnd).trim() : '',
        dim: c.dimEnd > 0 ? t.slice(c.dimStart, c.dimEnd).trim() : '',
        name: t.slice(c.nameStart, c.nameEnd).trim(),
        // The gap before `,` / `;` disappears (the name column supplies it), but
        // the gap before `=` is content: `localparam int P = 1;` must not become
        // `P= 1;`.
        tail: /^[ \t]*[,;]/.test(t.slice(c.nameEnd))
          ? t.slice(c.nameEnd).replace(/^[ \t]+/, '')
          : (' ' + t.slice(c.nameEnd).trim()).replace(/[ \t]+$/, ''),
      };
    });
    const width = (k) => Math.max(...rows.map((r) => r[k].length));
    const wDir = width('dir'), wType = width('type'), wDim = width('dim'), wName = width('name');

    for (let k = 0; k < rows.length; k++) {
      const r = rows[k];
      let out = '';
      if (wDir) out += r.dir.padEnd(wDir) + ' ';
      if (wType) out += r.type.padEnd(wType) + ' ';
      if (wDim) out += r.dim.padEnd(wDim) + ' ';
      out += r.name.padEnd(wName) + r.tail;
      group[k].text = out;
    }
  }

  /**
   * Collect a run of consecutive lines matching `predicate`.
   *
   * `predicate` receives the whole line object, not just its text, because
   * callers also need the `group` tag to decide what kind of line this is.
   *
   * `transparent` (optional) names lines that neither join the group nor end
   * it: a `//!` comment above a port, or an `` `ifdef `` inside the list. Those
   * lines carry no columns of their own, but the ports on either side of them
   * still belong to the same table — cutting the run there is what makes a
   * documented port list come out with three different name columns.
   *
   * The returned array carries `.end`, the index just past the run, so callers
   * can resume scanning after the lines that were skipped over.
   */
  collectGroup(lines, from, predicate, transparent) {
    const group = [];
    let i = from;
    while (i < lines.length) {
      const ln = lines[i];
      if (predicate(ln)) { group.push(ln); i++; continue; }
      if (ln.kind !== 'blank' && transparent && transparent(ln)) { i++; continue; }
      break;
    }
    group.end = i;
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
    // A comment line between two assignments documents one of them; cutting the
    // run there would leave every parameter list that is documented per line
    // with its `=` in a different column per entry.
    const transparent = (l) => l.kind === 'raw' || isCommentText(l.text);
    let i = 0;
    while (i < lines.length) {
      if (!this.isAssignable(lines[i])) { i++; continue; }
      let j = i;
      const members = [];
      while (j < lines.length) {
        if (this.isAssignable(lines[j])) { members.push(lines[j]); j++; continue; }
        if (lines[j].kind !== 'blank' && transparent(lines[j])) { j++; continue; }
        break;
      }
      if (members.length > 1) this.alignAssignGroup(members);
      i = j > i ? j : i + 1;
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
    //
    // Only declarations take part: `ref.md` pads the terminator of `wire`/
    // `logic`/`localparam` lines but leaves `assign x = y;` tight. It also keeps
    // a one-line-first rule — a 300-column concatenation in the same group must
    // not drag every short statement's `;` out to its column.
    if (!this.cfg.alignDeclarationTerminators) return;
    const maxPad = Math.max(0, Number(this.cfg.alignTerminatorMaxPad) || 0);
    const ends = group.map((l) => {
      if (!isDeclarationLine(l.text)) return -1;
      const t = l.text.replace(/\s+$/, '');
      return /[;,]/.test(t.slice(-1)) ? t.length - 1 : -1;
    });
    const used = ends.filter((e) => e >= 0);
    if (used.length < 2) return;
    const endTarget = Math.max(...used);
    if (maxPad && endTarget - Math.min(...used) > maxPad) return;
    for (let k = 0; k < group.length; k++) {
      if (ends[k] < 0) continue;
      const pad = endTarget - ends[k];
      if (pad > 0) {
        const ln = group[k];
        ln.text = ln.text.slice(0, ends[k]) + ' '.repeat(pad) + ln.text.slice(ends[k]);
      }
    }
  }

  isAssignable(ln) {
    if (ln.kind !== 'code') return false;
    // Control constructs carry assignments in their header (`for (i = 0; …)`) or
    // in an unblocked body (`if (x) y = 1;`). Aligning those would drag every
    // neighbouring statement out to the header's operator column.
    if (/^(begin|end|else|endcase|case|casex|casez|randcase|for|foreach|while|repeat|forever|if|always\w*|initial|final|generate|endgenerate)\b/.test(ln.text)) {
      return false;
    }
    // Case items are excluded too: `default:` is wider than `9'h003:`, so a
    // single `default` in a decode table would shift every other item's operator
    // by one column for no reason.
    if (CASE_ITEM_LINE.test(ln.text)) return false;
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

/**
 * A case item whose body sits on the label line: `2'd0: x = 1'b1;`. The label
 * may be `default`, a literal / identifier list, or a concatenation.
 */
const CASE_ITEM_LINE = /^\s*(?:default|\{[^}]*\}|[A-Za-z0-9_'$.]+(?:\s*,\s*(?:\{[^}]*\}|[A-Za-z0-9_'$.]+))*):\s/;

const DECL_KEYWORDS = new Set([
  'wire', 'uwire', 'tri', 'tri0', 'tri1', 'wand', 'wor', 'supply0', 'supply1',
  'reg', 'logic', 'bit', 'byte', 'shortint', 'int', 'longint', 'integer',
  'real', 'shortreal', 'realtime', 'time', 'genvar', 'event', 'string',
  'chandle', 'parameter', 'localparam', 'input', 'output', 'inout', 'ref',
  'typedef', 'enum', 'struct', 'union', 'var', 'const', 'static', 'automatic',
]);

/** Does this line read as a net/variable/parameter declaration? */
function isDeclarationLine(text) {
  const m = /^(\s*)([A-Za-z_$][\w$]*)/.exec(text);
  if (!m) return false;
  if (DECL_KEYWORDS.has(m[2])) return true;
  // `logic signed [15:0] x;` — a qualifier may precede the type keyword.
  if (m[2] === 'signed' || m[2] === 'unsigned') {
    const n = /^\s*[A-Za-z_$][\w$]*\s+([A-Za-z_$][\w$]*)/.exec(text);
    return !!n && DECL_KEYWORDS.has(n[1]);
  }
  return false;
}

/** `<=` is an assignment unless it is the tail of a relational compare. */
function isAssignCtx(text, i) {
  const prev = text[i - 1];
  return !(prev === '<' || prev === '>' || prev === '=' || prev === '!');
}

function format(source, config) {
  const direct = new Formatter(source, config).format();
  if (!direct.hadError) return direct;

  // The grammar cannot parse a preprocessor directive that sits *inside* a
  // port list or an instantiation connection list — yet real RTL uses
  //
  //     .data (`ifdef WIDE (wide_data) `else (narrow_data) `endif)
  //
  // constantly. Mask those directives to same-line comments, format the file,
  // then splice the directives back. Only done when the direct parse failed, so
  // a file that parses is never reformatted through the masking path.
  const masked = maskDirectivesInParens(source);
  if (!masked.map.length) return direct;

  const result = new Formatter(masked.text, config).format();
  if (result.hadError) return direct;
  return { text: restoreDirectives(result.text, masked.map), hadError: false };
}

const DIRECTIVE_RE = /^\s*`(?:ifdef|ifndef|elsif|else|endif)\b/;

/**
 * Replace directives that appear inside parentheses with marker comments.
 *
 * Returns the rewritten source plus the table needed to restore them.
 */
function maskDirectivesInParens(src) {
  const masked = maskLiteralsAndComments(src);
  const srcLines = src.split(/(?<=\n)/);
  const maskLines = masked.split(/(?<=\n)/);
  const map = [];
  let depth = 0;

  const out = srcLines.map((line, i) => {
    const startDepth = depth;
    for (const ch of (maskLines[i] || '')) {
      if (ch === '(') depth++;
      else if (ch === ')') depth--;
    }
    if (startDepth <= 0 || !DIRECTIVE_RE.test(line)) return line;
    const indent = line.match(/^\s*/)[0];
    const eol = /\r?\n$/.exec(line);
    const marker = `//@@svd-dir:${map.length}@@`;
    map.push(line.trim());
    return indent + marker + (eol ? eol[0] : '');
  });

  return { text: out.join(''), map };
}

/**
 * Put masked directives back.
 *
 * A marker that survived as a line of its own is replaced in place. A marker
 * the layout attached as a trailing comment (`sysref, //@@svd-dir:7@@`) is
 * lifted onto its own line right after that line, which is where the directive
 * stood in the source. Directives are line-oriented, so keeping them alone on a
 * line is what makes the result both valid and stable across repeated runs.
 */
function restoreDirectives(text, map) {
  const out = [];
  for (const line of text.split('\n')) {
    const alone = /^(\s*)\/\/@@svd-dir:(\d+)@@\s*$/.exec(line);
    if (alone) {
      out.push(alone[1] + map[Number(alone[2])]);
      continue;
    }
    if (!line.includes('@@svd-dir:')) {
      out.push(line);
      continue;
    }
    const indent = line.match(/^\s*/)[0];
    const dirs = [];
    const rest = line
      .replace(/\/\/@@svd-dir:(\d+)@@/g, (_, d) => { dirs.push(map[Number(d)]); return ''; })
      .replace(/\s+$/, '');
    if (rest.trim()) out.push(rest);
    for (const d of dirs) out.push(indent + d);
  }
  return out.join('\n');
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
 * Parameter overrides of an instantiation, in source order.
 *
 * `#(/*AUTOINSTPARAM* / // Parameters .A(1), .B(2))` ->
 *   [{comment, '/*AUTOINSTPARAM* /'}, {comment, '// Parameters'},
 *    {'.A(1)'}, {'.B(2)'}]
 * Comments stay in the list so the `/*AUTOINSTPARAM* /` banner and the group
 * comments inside a parameter block keep their position.
 */
function paramAssignments(params) {
  const found = [];
  const walk = (n) => {
    for (const c of namedChildren(n)) {
      if (isCommentNode(c)) { found.push({ text: c.text.trim(), isComment: true }); continue; }
      if (c.type === 'list_of_parameter_value_assignments') { walk(c); continue; }
      found.push({ text: c.text, isComment: false });
    }
  };
  walk(params);
  return found;
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
        found.push({ startIndex: c.startIndex, endIndex: c.endIndex, text: c.text, comment: '' });
        continue;
      }
      if (c.type === 'conditional_compilation_directive' || c.type === 'ERROR') {
        found.push({ startIndex: c.startIndex, endIndex: c.endIndex, text: c.text, comment: '', isRaw: true });
        continue;
      }
      // Keep comments that sit between port connections (e.g. `// Outputs`).
      if (isCommentNode(c)) {
        found.push({ startIndex: c.startIndex, endIndex: c.endIndex, text: '', comment: c.text.trim() });
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
 * Split one port connection into the pieces the compact layout aligns.
 *
 *   .clk(clk)  -> { name: '.clk', expr: 'clk',  paren: true  }
 *   .clk       -> { name: '.clk', expr: null,   paren: false }  (same-name)
 *   .*         -> { name: '.*',   expr: null,   paren: false }
 *   (clk)      -> { name: '',     expr: 'clk',  paren: true  }  (ordered)
 *   clk        -> { name: '',     expr: 'clk',  paren: false }  (ordered, the
 *                  grammar hands these back without the list's parentheses)
 *
 * Returns null for anything it cannot reproduce exactly, which makes the caller
 * fall back to the exploded layout instead of emitting a guess.
 */
function splitPortConnection(text) {
  const s = String(text).trim();
  if (!s) return null;

  if (s.startsWith('.')) {
    const m = /^(\.\s*[A-Za-z_][\w$]*|\.\*)\s*(?:\(([\s\S]*)\))?$/.exec(s);
    if (!m) return null;
    return {
      name: m[1].replace(/\s+/g, ''),
      expr: m[2] === undefined ? null : collapse(m[2]).trim(),
      paren: m[2] !== undefined,
    };
  }
  if (s.startsWith('(') && s.endsWith(')')) {
    return { name: '', expr: collapse(s.slice(1, -1)).trim(), paren: true };
  }
  // A bare ordered connection. Reject anything with a top-level `,` — that is a
  // sign the grammar grouped more than one connection here.
  if (!s.includes(',')) {
    return { name: '', expr: collapse(s).trim(), paren: false };
  }
  return null;
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
      ws();
      out.dirEnd = i;
      // Consume packed dimensions with implicit type (e.g. `input [31:0] din`).
      if (i < t.length && t[i] === '[') {
        out.dimStart = i;
        let dimEnd = 0;
        while (i < t.length && t[i] === '[') {
          let depth = 0;
          while (i < t.length) {
            const c = t[i];
            if (c === '[') { depth++; i++; }
            else if (c === ']') { depth--; i++; if (depth === 0) break; }
            else { i++; }
            if (depth > 64) break;
          }
          if (depth !== 0) return null;
          dimEnd = i;
          ws();
        }
        out.dimEnd = dimEnd;
      }
      continue;
    }
    if (QUALIFIERS.includes(w) || TYPE_KEYWORDS.has(w) || w === 'signed' || w === 'unsigned') {
      words.push(w);
      out.type = w;
      ws();
      out.typeEnd = i;
      // Consume packed dimensions that follow the base type.
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
        dimEnd = i;
        ws();
      }
      out.dimEnd = dimEnd;
      continue;
    }

    // First word that is neither qualifier nor type: this is the signal name.
    out.name = w;
    out.nameStart = before;
    out.nameEnd = i;
    ws();
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
  const bindComment = (c) => {
    const prev = found.length ? found[found.length - 1] : null;
    // A comment belongs to the item it trails only when it starts on the same
    // source line. Port and connection lists are normally documented one
    // comment per line *above* the entry; treating that as the previous entry's
    // trailing comment shifts every comment up by one, so each port ends up
    // carrying its neighbour's documentation.
    const sameLine = prev && !prev.isComment && !prev.isRaw && !prev.comment &&
      !/[\r\n]/.test(src.slice(prev.endIndex, c.startIndex));
    if (sameLine) {
      prev.comment = c.text.trim();
    } else {
      found.push({ startIndex: c.startIndex, endIndex: c.endIndex, text: '', comment: c.text.trim(), isComment: true });
    }
  };
  const walk = (n, depth) => {
    if (depth > 4) return;
    for (let i = 0; i < n.namedChildCount; i++) {
      const c = n.namedChild(i);
      if (/^(?:parameter|localparam)_declaration$/.test(c.type) ||
          c.type === 'parameter_declaration' || c.type === 'localparam_declaration') {
        found.push({ startIndex: c.startIndex, endIndex: c.endIndex, text: '', comment: '' });
        continue;
      }
      if (isCommentNode(c) && depth === 0) { bindComment(c); continue; }
      if (c.namedChildCount > 0) walk(c, depth + 1);
    }
  };
  walk(paramList, 0);

  if (found.length) {
    found.sort((a, b) => a.startIndex - b.startIndex);
    const real = found.filter((f) => !f.isComment);
    for (const f of found) {
      if (f.isComment) continue;
      const idx = real.indexOf(f);
      f.text = collapse(src.slice(f.startIndex, f.endIndex)) +
        (idx === real.length - 1 ? '' : ',') +
        (f.comment ? ' ' + f.comment : '');
    }
    return found;
  }

  // Fallback: split the raw text at top-level commas.
  const text = src.slice(paramList.startIndex, paramList.endIndex)
    .replace(/^\s*#?\s*\(/, '')
    .replace(/\)\s*$/, '');
  const items = splitTopLevel(text, ',').map((s) => collapse(s)).filter(Boolean);
  return items.map((t, i) => ({ text: t + (i === items.length - 1 ? '' : ','), comment: '' }));
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
