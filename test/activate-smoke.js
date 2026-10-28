'use strict';

// Smoke-test for src/extension.js without a real VS Code host.
//
// It stubs `require('vscode')` with just enough of the API surface, then runs
// activate() and asserts that the formatter providers and commands were
// registered. This catches activation-time crashes (wrong API names, bad
// requires, native module load failures) that would otherwise only show up in
// the extension host log as "Activating extension ... failed".
//
//   node test/activate-smoke.js

const Module = require('module');
const path = require('path');
const assert = require('assert');

const registered = { formatting: 0, rangeFormatting: 0, commands: [], providers: {} };

class Position {
  constructor(line, character) { this.line = line; this.character = character; }
}
class Range {
  constructor(start, end) { this.start = start; this.end = end; }
}
class TextEdit {
  static replace(range, newText) { return { range, newText }; }
}
class WorkspaceEdit {
  constructor() { this.edits = new Map(); }
  set(uri, edits) { this.edits.set(uri, edits); }
}

const fakeVscode = {
  version: '1.96.0',
  Position,
  Range,
  TextEdit,
  WorkspaceEdit,
  languages: {
    registerDocumentFormattingEditProvider(selector, provider) {
      registered.formatting += 1;
      registered.providers.document = provider;
      assert.ok(Array.isArray(selector), 'selector must be an array');
      assert.strictEqual(typeof provider.provideDocumentFormattingEdits, 'function');
      return { dispose() {} };
    },
    registerDocumentRangeFormattingEditProvider(selector, provider) {
      registered.rangeFormatting += 1;
      registered.providers.range = provider;
      assert.strictEqual(typeof provider.provideDocumentRangeFormattingEdits, 'function');
      return { dispose() {} };
    },
  },
  commands: {
    registerCommand(id, handler) {
      registered.commands.push(id);
      assert.strictEqual(typeof handler, 'function');
      return { dispose() {} };
    },
  },
  window: {
    activeTextEditor: undefined,
    showWarningMessage() {},
    showInformationMessage() {},
  },
  workspace: {
    getConfiguration() {
      return { get: (_key, fallback) => fallback };
    },
    async applyEdit() { return true; },
  },
};

const originalLoad = Module._load;
Module._load = function load(request, parent, isMain) {
  if (request === 'vscode') return fakeVscode;
  return originalLoad.call(this, request, parent, isMain);
};

const extensionPath = path.join(__dirname, '..', 'src', 'extension.js');
let ext;
try {
  ext = require(extensionPath);
} finally {
  Module._load = originalLoad;
}

assert.strictEqual(typeof ext.activate, 'function', 'extension must export activate()');
assert.strictEqual(typeof ext.deactivate, 'function', 'extension must export deactivate()');

const context = { subscriptions: [] };
ext.activate(context);

assert.strictEqual(registered.formatting, 1, 'expected one document formatting provider');
assert.strictEqual(registered.rangeFormatting, 1, 'expected one range formatting provider');
assert.deepStrictEqual(
  registered.commands.sort(),
  [
    'svFormatter.formatDocument',
    'svFormatter.formatSelectionCompact',
    'svFormatter.formatSelectionExplode',
    'svFormatter.formatSelectionOnly',
    'svFormatter.formatSelectionWithLayout',
  ],
  'expected all commands to be registered'
);
assert.strictEqual(context.subscriptions.length, 7, 'expected 7 disposables in subscriptions');

ext.deactivate();

// ---------------------------------------------------------------------------
// Drive the registered provider against a real demo file, the same code path
// VS Code takes on "Format Document".
// ---------------------------------------------------------------------------

const fs = require('fs');

function fakeDocument(filePath, languageId) {
  const text = fs.readFileSync(filePath, 'utf8').replace(/\r\n/g, '\n');
  const lineStarts = [0];
  for (let i = 0; i < text.length; i += 1) {
    if (text[i] === '\n') lineStarts.push(i + 1);
  }
  return {
    fileName: filePath,
    languageId,
    uri: { fsPath: filePath, scheme: 'file', toString: () => 'file:///' + filePath },
    getText: () => text,
    lineCount: lineStarts.length,
    positionAt(offset) {
      let line = 0;
      while (line + 1 < lineStarts.length && lineStarts[line + 1] <= offset) line += 1;
      return new Position(line, offset - lineStarts[line]);
    },
    offsetAt(position) {
      const base = lineStarts[Math.min(position.line, lineStarts.length - 1)];
      return Math.min(base + position.character, text.length);
    },
  };
}

const demoFile = path.join(__dirname, '..', 'demo', 'jesd_jesd204b_tx_link_top.v');
assert.ok(fs.existsSync(demoFile), 'demo file missing: ' + demoFile);

const doc = fakeDocument(demoFile, 'systemverilog');
const edits = registered.providers.document.provideDocumentFormattingEdits(doc, {
  tabSize: 4,
  insertSpaces: true,
});
assert.ok(Array.isArray(edits) && edits.length === 1, 'expected exactly one whole-document edit');
const formatted = edits[0].newText;
assert.ok(formatted.length > 0, 'formatted text must not be empty');
assert.ok(formatted.includes('endmodule'), 'formatted text lost the module terminator');

// Selection formatting takes a different path: the range is grown to the
// enclosing block, formatted in isolation, and spliced back. Exercise it on a
// statement run inside an `always @(*)` block, which is what a user selects
// when they only want one block tidied.
const blockFile = path.join(__dirname, '..', 'demo', 'jesd_8b10b_encode.v');
assert.ok(fs.existsSync(blockFile), 'demo file missing: ' + blockFile);
const blockDoc = fakeDocument(blockFile, 'systemverilog');

const rangeEdits = registered.providers.range.provideDocumentRangeFormattingEdits(
  blockDoc,
  new Range(new Position(46, 0), new Position(52, 0)),
  { tabSize: 4, insertSpaces: true }
);
assert.strictEqual(rangeEdits.length, 1,
  'expected one range edit for a statement run inside an always block');
assert.ok(rangeEdits[0].newText.length > 0, 'range edit text must not be empty');
assert.ok(!/^\s*module\b/m.test(rangeEdits[0].newText),
  'the range edit must not swallow the whole module');

console.log('provider smoke test passed:');
console.log('  input lines  :', doc.getText().split('\n').length);
console.log('  output lines :', formatted.split('\n').length);
console.log('  range edits  :', rangeEdits.length,
  '(selection is formatter-local, nothing outside the block moves)');

console.log('\nactivate() smoke test passed:');
console.log('  document formatting providers :', registered.formatting);
console.log('  range formatting providers   :', registered.rangeFormatting);
console.log('  commands                     :', registered.commands.join(', '));
console.log('  subscriptions                :', context.subscriptions.length);
