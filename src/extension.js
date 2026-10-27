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
    indentSize: get('indentSize', 2),
    useTabs: get('useTabs', false),
    explodePortList: get('explodePortList', true),
    explodeDeclarations: get('explodeDeclarations', true),
    explodeInstancePorts: get('explodeInstancePorts', true),
    alignPortsInHeader: get('alignPortsInHeader', true),
    alignDeclarationTerminators: get('alignDeclarationTerminators', true),
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
 * Format a selection.
 *
 * The engine always formats the complete document (its layout decisions depend
 * on enclosing blocks), then trims the edit to the requested range expanded to
 * whole lines. This avoids producing syntactically broken fragments.
 */
function formatRange(document, range, options) {
  const config = readConfig();
  const source = document.getText();
  const result = format(source, config);

  if (result.hadError && !config.formatOnParseError) {
    return [];
  }

  // Expand the requested range to full lines.
  const startLine = range.start.line;
  const endLine = range.end.line + (range.end.character === 0 ? 0 : 1);

  const startOffset = document.offsetAt(new vscode.Position(startLine, 0));
  const endOffset = Math.min(
    source.length,
    document.offsetAt(new vscode.Position(endLine, 0))
  );

  // Map the original line span onto the formatted output.
  const formattedLines = result.text.split('\n');
  const originalLines = source.split('\n');
  const lineCount = Math.min(endLine, originalLines.length) - startLine;
  if (lineCount <= 0) return [];

  // Find the corresponding slice by matching indentation-stable anchors is
  // fragile; instead take the same line indices when counts allow, otherwise
  // fall back to formatting the whole document.
  if (Math.abs(formattedLines.length - originalLines.length) > formattedLines.length) {
    const whole = new vscode.Range(document.positionAt(0), document.positionAt(source.length));
    return [vscode.TextEdit.replace(whole, result.text)];
  }

  const slice = formattedLines.slice(startLine, startLine + lineCount).join('\n');
  if (!slice.trim()) return [];

  return [vscode.TextEdit.replace(
    new vscode.Range(document.positionAt(startOffset), document.positionAt(endOffset)),
    slice
  )];
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

class SvIndentProvider {
  provideDocumentOnTypeFormattingEdits() {
    // On-type formatting is intentionally not implemented: this formatter makes
    // whole-block layout decisions, so partial on-type edits would fight it.
    return [];
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
    vscode.languages.registerDocumentOnTypeFormattingEditProvider(
      [{ language: 'systemverilog', scheme: '*' }],
      new SvIndentProvider(),
      '\n'
    ),
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

      const source = document.getText();

      // Expand the selection to whole lines. The replacement covers from the
      // start line's first column up to (but not including) the line after the
      // last touched line, so the trailing newline of the last line is included
      // and the following line is left intact.
      const startLine = selection.start.line;
      const endLine = selection.end.line + (selection.end.character === 0 ? 0 : 1);
      const selStart = document.offsetAt(new vscode.Position(startLine, 0));
      const selEnd = endLine >= document.lineCount
        ? source.length
        : document.offsetAt(new vscode.Position(endLine, 0));

      // Grow the selection to the smallest block-level syntax node that contains
      // it (always_construct / data_declaration / module_declaration / …). The
      // block boundary is syntactically natural, so re-formatting it never
      // dangles indentation into the surrounding text and line-count changes
      // inside the block do not realign anything outside it. Falls back to the
      // raw line range when the document does not parse or the range is not
      // inside any block.
      let fmtStart = selStart;
      let fmtEnd = selEnd;
      const block = expandToBlock(source, selStart, selEnd);
      if (block) {
        fmtStart = source.lastIndexOf('\n', block.start) + 1;
        let lineEnd = source.indexOf('\n', block.end);
        fmtEnd = lineEnd === -1 ? source.length : lineEnd + 1;
      }

      const fragText = source.slice(fmtStart, fmtEnd);
      if (!fragText.trim()) return;

      const { text: formatted, hadError } = formatFragment(fragText, config);
      if (trace === 'messages') {
        console.log(`[sv-formatter] selection ${document.fileName}: ` +
          `block=${block ? block.type : 'line-range'} hadError=${hadError}`);
      }
      if (hadError && !config.formatOnParseError) {
        vscode.window.showWarningMessage(
          'SV Formatter: 选区有语法错误，已跳过 ' +
          '(enable systemverilogFormatter.formatOnParseError to override).'
        );
        return;
      }

      const replaceRange = new vscode.Range(
        document.positionAt(fmtStart),
        document.positionAt(fmtEnd)
      );
      const edit = new vscode.WorkspaceEdit();
      edit.set(document.uri, [vscode.TextEdit.replace(replaceRange, formatted)]);
      await vscode.workspace.applyEdit(edit);
    })
  );
}

function deactivate() {}

module.exports = { activate, deactivate, readConfig };
