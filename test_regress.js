const fs = require('fs');
const path = require('path');
const { format } = require('./src/formatter.js');

const rtlDir = './test_rtl';
const files = fs.readdirSync(rtlDir).filter(f => f.endsWith('.v') || f.endsWith('.sv'));

let idempotentFail = [];
let commentLoss = [];
let identLoss = [];

for (const f of files) {
  const src = fs.readFileSync(path.join(rtlDir, f), 'utf8');
  const r1 = format(src, {});
  if (r1.hadError) continue;
  const r2 = format(r1.text, {});
  
  // Idempotency
  if (r1.text !== r2.text) {
    // Find first diff
    let diffPos = -1;
    for (let i = 0; i < Math.max(r1.text.length, r2.text.length); i++) {
      if (r1.text[i] !== r2.text[i]) { diffPos = i; break; }
    }
    idempotentFail.push({ file: f, diffPos, 
      ctx1: r1.text.slice(Math.max(0,diffPos-40), diffPos+40),
      ctx2: r2.text.slice(Math.max(0,diffPos-40), diffPos+40)
    });
  }
}

console.log(`Total files: ${files.length}`);
console.log(`Idempotency failures: ${idempotentFail.length}`);
console.log();
for (const fail of idempotentFail.slice(0, 10)) {
  console.log(`  ${fail.file} (diff at ${fail.diffPos})`);
  console.log(`    r1: ${JSON.stringify(fail.ctx1)}`);
  console.log(`    r2: ${JSON.stringify(fail.ctx2)}`);
}
