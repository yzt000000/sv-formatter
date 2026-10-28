'use strict';

/**
 * Formatter configuration. Mirrors the VSCode settings in package.json.
 */
/** Accepted values for `instanceLayout`. */
const LAYOUTS = new Set(['explode', 'compact', 'auto', 'off']);

const DEFAULTS = {
  // Indentation

  indentSize: 4,
  useTabs: false,
  // Space control
  spaceAroundBinaryOperators: true,   // a + b  vs  a+b
  spaceInsideParens: false,           // f( x )  ->  f(x)
  spaceAfterComma: true,
  spaceBeforeSemicolon: false,
  // Braces
  braceStyle: 'same',                 // same | next
  // Line breaks
  maxLineLength: 100,                 // 0 = disabled
  // Alignment
  alignConsecutiveAssignments: true,
  alignConsecutiveDeclarations: true,
  alignPortsInHeader: true,
  // Explode the module port list one port per line
  explodePortList: true,
  // Explode multi-signal declarations (`wire a, b, c;`) one signal per line,
  // each repeating the full type prefix
  explodeDeclarations: true,
  // Explode instance port connections one per line
  explodeInstancePorts: true,
  // Instance port map layout:
  //   'explode' — one connection per line, columns aligned (readable port maps)
  //   'compact' — whole instance on one line, and the `.port(expr)` columns of
  //               neighbouring instances aligned into a table (many tiny
  //               instances of the same module)
  //   'auto'    — 'compact' when the port count is <= compactInstanceMaxPorts,
  //               'explode' otherwise
  //   'off'     — leave the instance text untouched
  instanceLayout: 'explode',
  // Port count up to which 'auto' picks the compact layout
  compactInstanceMaxPorts: 4,
  // Keep a case item whose body is a single simple statement on the label line
  // (`2'd0: sel = 1'b1;`) instead of starting the body on its own line
  caseItemOnSameLine: true,
  // Align the trailing `;` of consecutive single-line declarations
  alignDeclarationTerminators: true,
  // Give up on `;` alignment when the widest line is further away than this
  // from the narrowest (0 = no limit)
  alignTerminatorMaxPad: 16,
  // Macros: verbatim / never touched
  formatMacros: false,
  // Blank lines
  maxConsecutiveBlankLines: 1,
  ensureTrailingNewline: true,
  // Safety
  formatOnParseError: false,
};

function resolveConfig(partial) {
  const cfg = Object.assign({}, DEFAULTS);
  if (partial && typeof partial === 'object') {
    for (const k of Object.keys(cfg)) {
      if (partial[k] !== undefined && partial[k] !== null) cfg[k] = partial[k];
    }
  }
  if (cfg.braceStyle !== 'same' && cfg.braceStyle !== 'next') cfg.braceStyle = 'same';
  if (!LAYOUTS.has(cfg.instanceLayout)) cfg.instanceLayout = 'explode';
  // `explodeInstancePorts: false` predates `instanceLayout` and meant "hands
  // off"; keep honouring it so an old settings.json still behaves.
  if (cfg.explodeInstancePorts === false) cfg.instanceLayout = 'off';
  cfg.compactInstanceMaxPorts = Math.max(0, Math.min(64, Number(cfg.compactInstanceMaxPorts) || 0));
  cfg.indentSize = Math.max(0, Math.min(16, Number(cfg.indentSize) || 0));
  cfg.maxLineLength = Math.max(0, Number(cfg.maxLineLength) || 0);
  cfg.maxConsecutiveBlankLines = Math.max(0, Math.min(5, Number(cfg.maxConsecutiveBlankLines) || 0));
  return cfg;
}

module.exports = { DEFAULTS, resolveConfig };
