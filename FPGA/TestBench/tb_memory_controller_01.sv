`timescale 1ns / 1ps
// Good
module tb_memory_controller_01;

  // Parameters
  parameter MASTER_ARRAY_SIZE = 1024;
  parameter BLOCK_SIZE        = 16;
  parameter NUM_MODULES       = 4;
  parameter NUM_BLOCKS        = 16;

  // Clock and reset
  reg clk;
  reg rst_n;

  // DUT inputs
  reg init_req;
  reg [$clog2(NUM_MODULES)-1:0] init_module_id;
  reg [31:0] init_head;
  reg [31:0] init_tail;
  reg [31:0] init_last;
  reg [7:0] init_head_bm_id;
  reg [7:0] init_head_bm_index;
  reg [7:0] init_circular_size;
  reg [7:0] init_dynamic_size;

  reg meta_req;
  reg meta_wr;
  reg [$clog2(NUM_MODULES)-1:0] meta_module_id;
  reg [3:0] meta_field_select;
  reg [31:0] meta_wdata;

  reg reset_module_req;
  reg [$clog2(NUM_MODULES)-1:0] reset_module_id;

  reg rw_req;
  reg rw_wr;
  reg [$clog2(NUM_MODULES)-1:0] rw_module_id;
  reg [$clog2(NUM_BLOCKS)-1:0]  rw_block_number;
  reg [$clog2(BLOCK_SIZE)-1:0]  rw_index;
  reg rw_wdata;

  // DUT outputs
  wire init_done;
  wire [31:0] meta_rdata;
  wire meta_done;
  wire reset_module_done;
  wire rw_rdata;
  wire rw_done;
  wire [31:0] total_bitmaps;
  wire [31:0] total_blocks;

  // Instantiate DUT
  memory_controller #(
    .MASTER_ARRAY_SIZE(MASTER_ARRAY_SIZE),
    .BLOCK_SIZE(BLOCK_SIZE),
    .NUM_MODULES(NUM_MODULES),
    .NUM_BLOCKS(NUM_BLOCKS)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
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
    .meta_req(meta_req),
    .meta_wr(meta_wr),
    .meta_module_id(meta_module_id),
    .meta_field_select(meta_field_select),
    .meta_wdata(meta_wdata),
    .meta_rdata(meta_rdata),
    .meta_done(meta_done),
    .reset_module_req(reset_module_req),
    .reset_module_id(reset_module_id),
    .reset_module_done(reset_module_done),
    .rw_req(rw_req),
    .rw_wr(rw_wr),
    .rw_module_id(rw_module_id),
    .rw_block_number(rw_block_number),
    .rw_index(rw_index),
    .rw_wdata(rw_wdata),
    .rw_rdata(rw_rdata),
    .rw_done(rw_done),
    .total_bitmaps(total_bitmaps),
    .total_blocks(total_blocks)
  );

  // Clock generation
  always #5 clk = ~clk;

  initial begin
    // Initialize inputs
    clk = 0;
    rst_n = 0;
    init_req = 0;
    init_module_id = 0;
    init_head = 0;
    init_tail = 0;
    init_last = 0;
    init_head_bm_id = 0;
    init_head_bm_index = 0;
    init_circular_size = 0;
    init_dynamic_size = 0;

    meta_req = 0;
    meta_wr = 0;
    meta_module_id = 0;
    meta_field_select = 0;
    meta_wdata = 0;

    reset_module_req = 0;
    reset_module_id = 0;

    rw_req = 0;
    rw_wr = 0;
    rw_module_id = 0;
    rw_block_number = 0;
    rw_index = 0;
    rw_wdata = 0;

    // Reset the system
    #10;
    rst_n = 1;

    // Initialize module 0
    #10;
    init_req = 1;
    init_module_id = 0;
    init_head = 32'hAAAA_AAAA;
    init_tail = 32'hBBBB_BBBB;
    init_last = 32'hCCCC_CCCC;
    init_head_bm_id = 8'h11;
    init_head_bm_index = 8'h22;
    init_circular_size = 8'h33;
    init_dynamic_size = 8'h44;
    #10;
    init_req = 0;
	//#100;
    wait (init_done);
	
    // Update some metadata fields
    #100;
    meta_req = 1;
    meta_wr = 1; // Write operation
    meta_module_id = 0;
    meta_field_select = 4'd0; // META_HEAD
    meta_wdata = 32'hDEAD_BEEF;
    #10;
    meta_req = 0;
    wait (meta_done);

    // Read back the updated metadata field
    #10;
    meta_req = 1;
    meta_wr = 0; // Read operation
    meta_module_id = 0;
    meta_field_select = 4'd0; // META_HEAD
    #10;
    meta_req = 0;
    wait (meta_done);
    $display("Meta HEAD read data: %h", meta_rdata);

    // Write to block 1 index 1
    #10;
    rw_req = 1;
    rw_wr = 1; // Write operation
    rw_module_id = 0;
    rw_block_number = 1;
    rw_index = 1;
    rw_wdata = 1'b1;
    #10;
    rw_req = 0;
    wait (rw_done);

    // Write to block 0 index 1
    #10;
    rw_req = 1;
    rw_wr = 1; // Write operation
    rw_module_id = 0;
    rw_block_number = 0;
    rw_index = 1;
    rw_wdata = 1'b0;
    #10;
    rw_req = 0;
    wait (rw_done);

    // Read from block 0 index 1
    #10;
    rw_req = 1;
    rw_wr = 0; // Read operation
    rw_module_id = 0;
    rw_block_number = 0;
    rw_index = 1;
    #10;
    rw_req = 0;
    wait (rw_done);
    $display("Read from block 0 index 1: %b", rw_rdata);

    // Read from block 1 index 1
    #10;
    rw_req = 1;
    rw_wr = 0; // Read operation
    rw_module_id = 0;
    rw_block_number = 1;
    rw_index = 1;
    #10;
    rw_req = 0;
    wait (rw_done);
    $display("Read from block 1 index 1: %b", rw_rdata);

    // Finish simulation
    #20;
    $finish;
  end

endmodule
