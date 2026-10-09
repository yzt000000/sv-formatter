'use strict';

/**
 * Formatter configuration. Mirrors the VSCode settings in package.json.
 */
const DEFAULTS = {
  // Indentation
  indentSize: 2,
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
  // Align the trailing `;` of consecutive single-line declarations
  alignDeclarationTerminators: true,
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
  cfg.indentSize = Math.max(0, Math.min(16, Number(cfg.indentSize) || 0));
  cfg.maxLineLength = Math.max(0, Number(cfg.maxLineLength) || 0);
  cfg.maxConsecutiveBlankLines = Math.max(0, Math.min(5, Number(cfg.maxConsecutiveBlankLines) || 0));
  return cfg;
}

module.exports = { DEFAULTS, resolveConfig };
