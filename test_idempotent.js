const { format } = require('./src/formatter.js');

function fmt(src) {
  return format(src, {}).text;
}

const test1 = `module test (
  input  wire        clk, // clock
  input  wire        rst, // reset
  output wire [31:0] data // output data
);
endmodule`;

const result1 = fmt(test1);
const result2 = fmt(result1);

console.log('=== Original ===');
console.log(test1);
console.log('=== First format ===');
console.log(result1);
console.log('=== Second format ===');
console.log(result2);
console.log('=== Idempotent? ===', result1 === result2);
if (result1 !== result2) {
  for (let i = 0; i < Math.max(result1.length, result2.length); i++) {
    if (result1[i] !== result2[i]) {
      console.log('First diff at offset', i);
      console.log('  result1:', JSON.stringify(result1.slice(Math.max(0,i-30), i+30)));
      console.log('  result2:', JSON.stringify(result2.slice(Math.max(0,i-30), i+30)));
      break;
    }
  }
}
