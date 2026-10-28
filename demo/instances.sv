// Two instantiation shapes side by side.
//
// The `sync_cell` group is the case instanceLayout "compact"/"auto" is built
// for: three connections each, eight copies. One line per instance, and the
// `.d(...)` / `.q(...)` columns line up down the block.
//
// The `frame_store` instance is the opposite case: a wide port map, where
// exploding one connection per line is the only readable option.
module inst_demo (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  din,
    output wire [7:0]  dout
);

    sync_cell u_bit0 (.clk(clk), .d(din[0]), .q(q0));
    sync_cell u_bit1 (.clk(clk), .d(din[1]), .q(q1));
    sync_cell u_bit2 (.clk(clk), .d(din[2]), .q(q2));
    sync_cell u_bit3 (.clk(clk), .d(din[3]), .q(q3));
    sync_cell u_bit4 (.clk(clk), .d(din[4]), .q(q4));
    sync_cell u_bit5 (.clk(clk), .d(din[5]), .q(q5));
    sync_cell u_bit6 (.clk(clk), .d(din[6]), .q(q6));
    sync_cell u_bit7 (.clk(clk), .d(din[7]), .q(q7));

    frame_store #(.DEPTH(512)) u_store (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(store_wr_en),
        .wr_data(din),
        .rd_en(store_rd_en),
        .rd_data(dout),
        .full(store_full),
        .empty(store_empty),
        .level(store_level)
    );

endmodule
