#!/usr/bin/env node
'use strict';

/**
 * Command line interface to the formatter core.
 *
 *   sv-fmt file.sv                 format to stdout
 *   sv-fmt -i file.sv              format in place
 *   sv-fmt --check file.sv ...     exit 1 if any file is not formatted (CI)
 *   sv-fmt --indent-size 4 file.sv override any setting
 */

const fs = require('fs');
const path = require('path');
const { format } = require('../src/formatter');
const { DEFAULTS } = require('../src/config');

function parseArgs(argv) {
  const opts = { inPlace: false, check: false, files: [], config: {} };
  const configKeys = new Set(Object.keys(DEFAULTS));

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '-i' || a === '--in-place') opts.inPlace = true;
    else if (a === '--check') opts.check = true;
    else if (a === '-h' || a === '--help') opts.help = true;
    else if (a.startsWith('--')) {
      const key = a.slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase());
      if (!configKeys.has(key)) {
        process.stderr.write(`unknown option: ${a}\n`);
        process.exit(2);
      }
      const raw = argv[++i];
      const def = DEFAULTS[key];
      if (typeof def === 'boolean') {
        opts.config[key] = raw !== 'false' && raw !== '0';
      } else if (typeof def === 'number') {
        opts.config[key] = Number(raw);
      } else {
        // enum-valued settings (`instanceLayout`) must stay strings; coercing
        // them to Number made every such override silently become NaN.
        opts.config[key] = raw;
      }
    } else opts.files.push(a);
  }
  return opts;
}

function usage() {
  process.stdout.write(
    'Usage: sv-fmt [options] <file.sv>...\n\n' +
    '  -i, --in-place        rewrite files in place\n' +
    '      --check           exit 1 if any file is not formatted\n' +
    '      --<setting> <v>   override any systemverilogFormatter setting\n'
  );
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help || !opts.files.length) {
    usage();
    process.exit(opts.help ? 0 : 1);
  }

  let unformatted = 0;
  let failed = 0;

  for (const file of opts.files) {
    let src;
    try {
      src = fs.readFileSync(file, 'utf8');
    } catch (e) {
      process.stderr.write(`cannot read ${file}: ${e.message}\n`);
      failed++;
      continue;
    }

    const result = format(src, opts.config);

    if (result.hadError && !opts.config.formatOnParseError) {
      process.stderr.write(`${file}: skipped (syntax errors)\n`);
      failed++;
      continue;
    }

    // The engine emits LF, so a CRLF file must be compared with its line
    // endings normalised — otherwise `--check` reports every Windows file as
    // unformatted no matter how many times `-i` has run over it.
    if (result.text === src.replace(/\r\n/g, '\n')) continue;

    if (opts.check) {
      unformatted++;
      process.stdout.write(`${file}: not formatted\n`);
      continue;
    }

    if (opts.inPlace) {
      // Preserve the original line ending style.
      const eol = src.includes('\r\n') ? '\r\n' : '\n';
      const out = eol === '\r\n' ? result.text.replace(/\n/g, '\r\n') : result.text;
      fs.writeFileSync(file, out, 'utf8');
    } else {
      process.stdout.write(result.text);
    }
  }

  if (opts.check && unformatted > 0) process.exit(1);
  if (failed > 0) process.exit(1);
}

main();
