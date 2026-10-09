'use strict';

const vscode = require('vscode');
const { format } = require('./formatter');

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
    })
  );
}

function deactivate() {}

module.exports = { activate, deactivate, readConfig };
