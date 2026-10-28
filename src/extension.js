'use strict';

const vscode = require('vscode');
const { format } = require('./formatter');
const { formatFragment, expandToBlock } = require('./fragment');

const CONFIG_SECTION = 'systemverilogFormatter';

/** Read the user's formatter settings into a plain config object. */
function readConfig() {
  const cfg = vscode.workspace.getConfiguration(CONFIG_SECTION);
  const get = (key, fallback) => cfg.get(key, fallback);

  return {
    indentSize: get('indentSize', 4),
    useTabs: get('useTabs', false),
    explodePortList: get('explodePortList', true),
    explodeDeclarations: get('explodeDeclarations', true),
    explodeInstancePorts: get('explodeInstancePorts', true),
    instanceLayout: get('instanceLayout', 'explode'),
    compactInstanceMaxPorts: get('compactInstanceMaxPorts', 4),
    alignPortsInHeader: get('alignPortsInHeader', true),
    alignDeclarationTerminators: get('alignDeclarationTerminators', true),
    alignTerminatorMaxPad: get('alignTerminatorMaxPad', 16),
    caseItemOnSameLine: get('caseItemOnSameLine', true),
    alignConsecutiveAssignments: get('alignConsecutiveAssignments', true),
    alignConsecutiveDeclarations: get('alignConsecutiveDeclarations', true),
    spaceAroundBinaryOperators: get('spaceAroundBinaryOperators', true),
    spaceAfterComma: get('spaceAfterComma', true),
    maxConsecutiveBlankLines: get('maxConsecutiveBlankLines', 1),
    ensureTrailingNewline: get('ensureTrailingNewline', true),
    formatOnParseError: get('formatOnParseError', false),
  };
}

/**
 * Format a whole document.
 *
 * When the source does not parse and `formatOnParseError` is off, we return no
 * edits at all: a formatter that rewrites code it could not understand is far
 * more dangerous than one that declines to act.
 */
function formatDocument(document, options) {
  const config = readConfig();
  const trace = vscode.workspace.getConfiguration(CONFIG_SECTION).get('trace.server', 'off');

  const source = document.getText();
  const result = format(source, config);

  if (trace === 'messages') {
    console.log(`[sv-formatter] ${document.fileName}: hadError=${result.hadError}`);
  }

  if (result.hadError && !config.formatOnParseError) {
    return [];
  }

  const whole = new vscode.Range(
    document.positionAt(0),
    document.positionAt(source.length)
  );
  return [vscode.TextEdit.replace(whole, result.text)];
}

/**
 * Compute the edit for a "format selection" request.
 *
 * The engine always formats a complete translation unit, so the requested
 * range is first grown to the smallest *block-level* syntax node containing it
 * (an `always_construct`, a declaration, one instantiation …). Formatting that
 * block in isolation is safe: it is syntactically self-contained, so its
 * nesting depth is recovered from the fragment itself and nothing outside it
 * moves — even when the number of lines inside changes.
 *
 * Returns
 *   { range, text, block }  the edit to apply
 *   { skipped: true }       the block has syntax errors and we may not touch it
 *   null                    nothing to do
 */
function selectionEdit(document, range, config) {
  const source = document.getText();

  // Grow the selection to whole lines: the replacement starts at the first
  // touched line's column 0 and ends at the start of the line after the last
  // touched one, so the trailing newline is inside the range.
  const startLine = range.start.line;
  const endLine = range.end.line + (range.end.character === 0 ? 0 : 1);
  const selStart = document.offsetAt(new vscode.Position(startLine, 0));
  const selEnd = endLine >= document.lineCount
    ? source.length
    : document.offsetAt(new vscode.Position(endLine, 0));
  if (selEnd <= selStart) return null;

  let fmtStart = selStart;
  let fmtEnd = selEnd;
  const block = expandToBlock(source, selStart, selEnd);
  if (block) {
    fmtStart = source.lastIndexOf('\n', block.start) + 1;
    const lineEnd = source.indexOf('\n', block.end);
    fmtEnd = lineEnd === -1 ? source.length : lineEnd + 1;
  }

  const fragText = source.slice(fmtStart, fmtEnd);
  if (!fragText.trim()) return null;

  const { text, hadError } = formatFragment(fragText, config);
  if (hadError && !config.formatOnParseError) return { skipped: true };

  return {
    range: new vscode.Range(document.positionAt(fmtStart), document.positionAt(fmtEnd)),
    text,
    block,
  };
}

/**
 * Range formatting provider entry point (`Format Selection`, Ctrl+K Ctrl+F).
 *
 * Deliberately returns no edit rather than a partial one when the block does
 * not parse: a formatter that rewrites code it could not understand is worse
 * than one that declines to act.
 */
function formatRange(document, range, options) {
  const result = selectionEdit(document, range, readConfig());
  if (!result || result.skipped || !result.text) return [];
  return [vscode.TextEdit.replace(result.range, result.text)];
}

/** Indent-only formatting on demand (Format Document Indentation). */
function formatIndentation(document) {
  return formatDocument(document, {});
}

class SvFormatterProvider {
  provideDocumentFormattingEdits(document, options) {
    return formatDocument(document, options);
  }

  provideDocumentRangeFormattingEdits(document, range, options) {
    return formatRange(document, range, options);
  }
}

function activate(context) {
  const selector = [
    { language: 'systemverilog', scheme: '*' },
    { language: 'verilog', scheme: '*' },
  ];

  context.subscriptions.push(
    vscode.languages.registerDocumentFormattingEditProvider(selector, new SvFormatterProvider()),
    vscode.languages.registerDocumentRangeFormattingEditProvider(selector, new SvFormatterProvider()),
    vscode.commands.registerCommand('svFormatter.formatDocument', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;
      const edits = await formatDocument(editor.document, {});
      if (!edits.length) {
        vscode.window.showWarningMessage(
          'SV Formatter: skipped because the file has syntax errors ' +
          '(enable systemverilogFormatter.formatOnParseError to override).'
        );
        return;
      }
      const edit = new vscode.WorkspaceEdit();
      edit.set(editor.document.uri, edits);
      await vscode.workspace.applyEdit(edit);
    }),
    vscode.commands.registerCommand('svFormatter.formatSelectionOnly', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;
      const { document, selection } = editor;

      if (selection.isEmpty) {
        vscode.window.showInformationMessage(
          'SV Formatter: 请先选中一段代码，再执行 Format Selection Only。'
        );
        return;
      }
      const lang = document.languageId;
      if (lang !== 'systemverilog' && lang !== 'verilog') {
        vscode.window.showWarningMessage(
          'SV Formatter: 当前文件不是 SystemVerilog / Verilog。'
        );
        return;
      }

      const config = readConfig();
      const trace = vscode.workspace.getConfiguration(CONFIG_SECTION).get('trace.server', 'off');

      const result = selectionEdit(document, selection, config);
      if (!result) return;
      if (result.skipped) {
        vscode.window.showWarningMessage(
          'SV Formatter: 选区有语法错误，已跳过 ' +
          '(enable systemverilogFormatter.formatOnParseError to override).'
        );
        return;
      }
      if (trace === 'messages') {
        console.log(`[sv-formatter] selection ${document.fileName}: ` +
          `block=${result.block ? result.block.type : 'line-range'}`);
      }

      const edit = new vscode.WorkspaceEdit();
      edit.set(document.uri, [vscode.TextEdit.replace(result.range, result.text)]);
      await vscode.workspace.applyEdit(edit);
    })
  );
}

function deactivate() {}

module.exports = { activate, deactivate, readConfig };
