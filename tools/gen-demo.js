'use strict';
// Generate before/after text for the demo GIFs.
const fs = require('fs');
const path = require('path');
const { format } = require('../src/formatter');

const cases = {
  sync: `module sync_2stage#(parameter WIDTH=1)(input wire clk,input wire rst_n,input wire[WIDTH-1:0] d,output wire[WIDTH-1:0] q);
wire a,b,c;
assign q=d;
always@(posedge clk or negedge rst_n)
begin
if(!rst_n)q<=0;
else q<=d;
end
endmodule
`,
  instance: `module inst_demo(input wire clk,input wire rst_n,input wire[7:0] din,output wire[7:0] dout);
sync_cell u_bit0(.clk(clk),.d(din[0]),.q(q0));sync_cell u_bit1(.clk(clk),.d(din[1]),.q(q1));sync_cell u_bit2(.clk(clk),.d(din[2]),.q(q2));
frame_store#(.DEPTH(512),.WIDTH(8)) u_store(.clk(clk),.rst_n(rst_n),.wr_en(store_wr_en),.wr_data(din),.rd_en(store_rd_en),.rd_data(dout),.full(store_full),.empty(store_empty));
endmodule
`,
};

const dir = path.join(__dirname, 'demo-tmp');
fs.mkdirSync(dir, { recursive: true });

for (const [name, before] of Object.entries(cases)) {
  const out = format(before, {});
  if (out.hadError) {
    console.error(`[${name}] format reported error`);
    process.exit(1);
  }
  fs.writeFileSync(path.join(dir, `${name}-before.txt`), before, 'utf8');
  fs.writeFileSync(path.join(dir, `${name}-after.txt`), out.text, 'utf8');
  console.log(`=== ${name} BEFORE ===`);
  console.log(before);
  console.log(`=== ${name} AFTER ===`);
  console.log(out.text);
}

// keep old filenames for backward compat
fs.copyFileSync(path.join(dir, 'sync-before.txt'), path.join(dir, 'before.txt'));
fs.copyFileSync(path.join(dir, 'sync-after.txt'), path.join(dir, 'after.txt'));
console.log('written to', dir);