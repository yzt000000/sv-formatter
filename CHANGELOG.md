# Changelog

All notable changes to this extension are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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