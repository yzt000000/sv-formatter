const fs = require('fs');
const { format } = require('../src/formatter');

const file = process.argv[2] || 'samples/a_basics.sv';
const src = fs.readFileSync(file, 'utf8');
const r = format(src, {});
console.log('===== OUTPUT (' + file + ') =====');
process.stdout.write(r.text);
console.log('===== hadError: ' + r.hadError + ' =====');

// Idempotency: formatting the output again must be a no-op.
const r2 = format(r.text, {});
if (r2.text !== r.text) {
  console.log('!!! NOT IDEMPOTENT !!!');
  const a = r.text.split('\n'), b = r2.text.split('\n');
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    if (a[i] !== b[i]) { console.log('line ' + (i+1) + '\n  1st: ' + JSON.stringify(a[i]) + '\n  2nd: ' + JSON.stringify(b[i])); break; }
  }
  process.exitCode = 1;
} else {
  console.log('idempotent: OK');
}
