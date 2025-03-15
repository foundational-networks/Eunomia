`timescale 1ns / 1ps

module tb_memory_controller_02;

  parameter MASTER_ARRAY_SIZE = 1024;
  parameter BLOCK_SIZE        = 16;
  parameter NUM_MODULES       = 4;
  parameter NUM_BLOCKS        = 16;

  reg clk;
  reg rst_n;

  // Signals for module initialization
  reg init_req;
  reg [$clog2(NUM_MODULES)-1:0] init_module_id;
  reg [31:0] init_head;
  reg [31:0] init_tail;
  reg [31:0] init_last;
  reg [7:0] init_head_bm_id;
  reg [7:0] init_head_bm_index;
  reg [7:0] init_circular_size;
  reg [7:0] init_dynamic_size;
  wire init_done;

  // Signals for metadata read/write operations
  reg meta_req;
  reg meta_wr;
  reg [$clog2(NUM_MODULES)-1:0] meta_module_id;
  reg [3:0] meta_field_select;
  reg [31:0] meta_wdata;
  wire [31:0] meta_rdata;
  wire meta_done;

  // Signals for module reset
  reg reset_module_req;
  reg [$clog2(NUM_MODULES)-1:0] reset_module_id;
  wire reset_module_done;

  // Signals for read/write operations
  reg rw_req;
  reg rw_wr;
  reg [$clog2(NUM_MODULES)-1:0] rw_module_id;
  reg [$clog2(NUM_BLOCKS)-1:0] rw_block_number;
  reg [$clog2(BLOCK_SIZE/8)-1:0] rw_index;
  reg [7:0] rw_wdata;
  wire [7:0] rw_rdata;
  wire rw_done;

  // Performance measurement
  wire [31:0] total_bitmaps;

  // Instantiate the memory_controller
  memory_controller #(
    //.MASTER_ARRAY_SIZE(MASTER_ARRAY_SIZE),
    //.BLOCK_SIZE(BLOCK_SIZE),
    //.NUM_MODULES(NUM_MODULES),
    //.NUM_BLOCKS(NUM_BLOCKS)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    // Module initialization
    .init_req(init_req),
    .init_module_id(init_module_id),
    .init_head(init_head),
    .init_tail(init_tail),
    .init_last(init_last),
    .init_head_bm_id(init_head_bm_id),
    .init_head_bm_index(init_head_bm_index),
    .init_circular_size(init_circular_size),
    .init_dynamic_size(init_dynamic_size),
    .init_done(init_done),
    // Metadata operations
    .meta_req(meta_req),
    .meta_wr(meta_wr),
    .meta_module_id(meta_module_id),
    .meta_field_select(meta_field_select),
    .meta_wdata(meta_wdata),
    .meta_rdata(meta_rdata),
    .meta_done(meta_done),
    // Module reset
    .reset_module_req(reset_module_req),
    .reset_module_id(reset_module_id),
    .reset_module_done(reset_module_done),
    // Read/write operations
    .rw_req(rw_req),
    .rw_wr(rw_wr),
    .rw_module_id(rw_module_id),
    .rw_block_number(rw_block_number),
    .rw_index(rw_index),
    .rw_wdata(rw_wdata),
    .rw_rdata(rw_rdata),
    .rw_done(rw_done),
    // Performance measurement
    .total_bitmaps(total_bitmaps)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz clock
  end

  // Test procedure
  initial begin
    // Initialize signals
    rst_n = 0;
    init_req = 0;
    meta_req = 0;
    reset_module_req = 0;
    rw_req = 0;

    // Reset the DUT
    #10;
    rst_n = 1;

    // Initialize module 0
    init_module_id = 0;
    init_head = 32'd0;
    // init_tail = 32'hBBBB_BBBB;
    init_tail = -1;
    // init_last = 32'hCCCC_CCCC;
    init_last = -1;
    // init_head_bm_id = 8'hDD;
    // init_head_bm_index = 8'hEE;
    // init_circular_size = 8'h0F;
    // init_dynamic_size = 8'hF0;
    init_head_bm_id = 8'd0;
    init_head_bm_index = 8'd0;
    init_circular_size = 8'd16;
    init_dynamic_size = 8'd16;
    init_req = 1;
    #50;
    init_req = 0;
    wait (init_done);
    $display("Module %0d initialized. Total bitmaps: %0d", init_module_id, total_bitmaps);
    // Read metadata from module 0
    meta_module_id = 0;
    meta_req = 1;
    meta_wr = 0;
    // Read HEAD
    meta_field_select = 4'd0;
    #10;
    meta_req = 0;
    wait (meta_done);
    $display("Read HEAD from module %0d: %h", meta_module_id, meta_rdata);
	#50;
	
    // Read TAIL
    meta_field_select = 4'd1;
    #50;
    meta_req = 0;
    wait (meta_done);
    $display("Read TAIL from module %0d: %h", meta_module_id, meta_rdata);
	#50;
	    // Read LAST
    meta_field_select = 4'd2;
    #50;
    meta_req = 0;
    wait (meta_done);
    $display("Read LAST from module %0d: %h", meta_module_id, meta_rdata);
	#50;
    // Write metadata to module 0
    meta_module_id = 0;
    meta_req = 1;
    meta_wr = 1;
    meta_field_select = 4'd1; // TAIL
    meta_wdata = 32'hDEAD_BEEF;
    #10;
    meta_req = 0;
    wait (meta_done);
    $display("Wrote TAIL to module %0d: %h", meta_module_id, meta_wdata);

    // Read back the TAIL
    meta_module_id = 0;
    meta_req = 1;
    meta_wr = 0;
    meta_field_select = 4'd1; // TAIL
    #10;
    meta_req = 0;
    wait (meta_done);
    $display("Read TAIL from module %0d: %h", meta_module_id, meta_rdata);

    // Write and read other metadata fields for module 0
    // HEAD_BM_ID
    meta_module_id = 0;
    meta_req = 1;
    meta_wr = 1;
    meta_field_select = 4'd3; // HEAD_BM_ID
    meta_wdata = 32'h000000AA;
    #10;
    meta_req = 0;
    wait (meta_done);
    $display("Wrote HEAD_BM_ID to module %0d: %h", meta_module_id, meta_wdata[7:0]);

    meta_req = 1;
    meta_wr = 0;
    meta_field_select = 4'd3; // HEAD_BM_ID
    #10;
    meta_req = 0;
    wait (meta_done);
    $display("Read HEAD_BM_ID from module %0d: %h", meta_module_id, meta_rdata[7:0]);

    // HEAD_BM_INDEX
    meta_module_id = 0;
    meta_req = 1;
    meta_wr = 1;
    meta_field_select = 4'd4; // HEAD_BM_INDEX
    meta_wdata = 32'h000000BB;
    #10;
    meta_req = 0;
    wait (meta_done);
    $display("Wrote HEAD_BM_INDEX to module %0d: %h", meta_module_id, meta_wdata[7:0]);

    meta_req = 1;
    meta_wr = 0;
    meta_field_select = 4'd4; // HEAD_BM_INDEX
    #10;
    meta_req = 0;
    wait (meta_done);
    $display("Read HEAD_BM_INDEX from module %0d: %h", meta_module_id, meta_rdata[7:0]);

    // CIRCULAR_SIZE
    meta_module_id = 0;
    meta_req = 1;
    meta_wr = 1;
    meta_field_select = 4'd5; // CIRCULAR_SIZE
    meta_wdata = 32'h000000CC;
    #10;
    meta_req = 0;
    wait (meta_done);
    $display("Wrote CIRCULAR_SIZE to module %0d: %h", meta_module_id, meta_wdata[7:0]);

    meta_req = 1;
    meta_wr = 0;
    meta_field_select = 4'd5; // CIRCULAR_SIZE
    #10;
    meta_req = 0;
    wait (meta_done);
    $display("Read CIRCULAR_SIZE from module %0d: %h", meta_module_id, meta_rdata[7:0]);

    // DYNAMIC_SIZE
    meta_module_id = 0;
    meta_req = 1;
    meta_wr = 1;
    meta_field_select = 4'd6; // DYNAMIC_SIZE
    meta_wdata = 32'h000000DD;
    #10;
    meta_req = 0;
    wait (meta_done);
    $display("Wrote DYNAMIC_SIZE to module %0d: %h", meta_module_id, meta_wdata[7:0]);

    meta_req = 1;
    meta_wr = 0;
    meta_field_select = 4'd6; // DYNAMIC_SIZE
    #10;
    meta_req = 0;
    wait (meta_done);
    $display("Read DYNAMIC_SIZE from module %0d: %h", meta_module_id, meta_rdata[7:0]);

    // Write to bitmap block 2, index 1
    rw_module_id = 0;
    rw_block_number = 2;
    rw_index = 1; // Since BLOCK_SIZE is 16 bits (2 bytes), index can be 0 or 1
    rw_wdata = 8'hAB;
    rw_req = 1;
    rw_wr = 1;
    #50;
    rw_req = 0;
    wait (rw_done);
    $display("Wrote to module %0d, block %0d, index %0d: %h. Total bitmaps: %0d", rw_module_id, rw_block_number, rw_index, rw_wdata, total_bitmaps);

    // Read back from bitmap block 2, index 1
    rw_module_id = 0;
    rw_block_number = 2;
    rw_index = 1;
    rw_req = 1;
    rw_wr = 0;
    #50;
    rw_req = 0;
    wait (rw_done);
    $display("Read from module %0d, block %0d, index %0d: %h", rw_module_id, rw_block_number, rw_index, rw_rdata);
	$stop;
    // Loop to write to all possible blocks and indices for module 0
    for (integer blk = 0; blk < NUM_BLOCKS; blk = blk + 1) begin
      for (integer idx = 0; idx < (BLOCK_SIZE/8); idx = idx + 1) begin
        rw_module_id = 0;
        rw_block_number = blk;
        rw_index = idx;
        rw_wdata = (blk * 16 + idx) % 256;
        rw_req = 1;
        rw_wr = 1;
        #10;
        rw_req = 0;
        wait (rw_done);
        $display("Wrote to module %0d, block %0d, index %0d: %h", rw_module_id, rw_block_number, rw_index, rw_wdata);

      end
    end
    $display("Completed writing to all blocks and indices for module 0. Total bitmaps: %0d", total_bitmaps);

    // Loop to read back and verify data
    for (integer blk = 0; blk < NUM_BLOCKS; blk = blk + 1) begin
      for (integer idx = 0; idx < (BLOCK_SIZE/8); idx = idx + 1) begin
        rw_module_id = 0;
        rw_block_number = blk;
        rw_index = idx;
        rw_req = 1;
        rw_wr = 0;
        #10;
        rw_req = 0;
        wait (rw_done);
        $display("Read from module %0d, block %0d, index %0d: %h", rw_module_id, rw_block_number, rw_index, rw_rdata);
        #50;
      end
    end

    // Initialize module 1
    init_module_id = 1;
    init_head = 32'h1111_1111;
    init_tail = 32'h2222_2222;
    init_last = 32'h3333_3333;
    init_head_bm_id = 8'h44;
    init_head_bm_index = 8'h55;
    init_circular_size = 8'h66;
    init_dynamic_size = 8'h77;
    init_req = 1;
    #50;
    init_req = 0;
    wait (init_done);
    $display("Module %0d initialized. Total bitmaps: %0d", init_module_id, total_bitmaps);
	#50;
	$stop;
    // Read and write metadata fields for module 1
    // Similar to module 0 tests

    // Reset module 0
    reset_module_id = 0;
    reset_module_req = 1;
    #50;
    reset_module_req = 0;
    wait (reset_module_done);
    $display("Module %0d reset. Total bitmaps: %0d", reset_module_id, total_bitmaps);

    // End simulation
    $stop;
  end

endmodule
