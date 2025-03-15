`timescale 1ns / 1ps

module tb_memory_controller_03;

  // Parameters
  parameter MASTER_ARRAY_SIZE = 1024;
  parameter BLOCK_SIZE        = 16;
  parameter NUM_MODULES       = 4;
  parameter NUM_BLOCKS        = 16;

  // Inputs
  reg                         clk;
  reg                         rst_n;
  reg                         init_req;
  reg       [$clog2(NUM_MODULES)-1:0] init_module_id;
  reg       [31:0]            init_head;
  reg       [31:0]            init_tail;
  reg       [31:0]            init_last;
  reg       [7:0]             init_head_bm_id;
  reg       [7:0]             init_head_bm_index;
  reg       [7:0]             init_circular_size;
  reg       [7:0]             init_dynamic_size;

  reg                         meta_req;
  reg                         meta_wr;
  reg       [$clog2(NUM_MODULES)-1:0] meta_module_id;
  reg       [3:0]             meta_field_select;
  reg       [31:0]            meta_wdata;

  reg                         rw_req;
  reg                         rw_wr;
  reg       [$clog2(NUM_MODULES)-1:0] rw_module_id;
  reg       [$clog2(NUM_BLOCKS)-1:0]  rw_block_number;
  reg       [$clog2(BLOCK_SIZE)-1:0]  rw_index;
  reg                         rw_wdata;

  // Outputs
  wire                        init_done;
  wire [31:0]                 meta_rdata;
  wire                        meta_done;
  wire                        rw_rdata;
  wire                        rw_done;
  wire [31:0]                 total_bitmaps;
  wire [31:0]                 total_blocks;

  // Instantiate the Unit Under Test (UUT)
  memory_controller #(
    .MASTER_ARRAY_SIZE(MASTER_ARRAY_SIZE),
    .BLOCK_SIZE(BLOCK_SIZE),
    .NUM_MODULES(NUM_MODULES),
    .NUM_BLOCKS(NUM_BLOCKS)
  ) uut (
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
    .reset_module_req(1'b0),
    .reset_module_id(0),
    .reset_module_done(),
    .rw_req(rw_req),
    .rw_wr(rw_wr),
    .rw_module_id(rw_module_id),
    .rw_block_number(rw_block_number),
    .rw_index(rw_index),
    .rw_wdata(rw_wdata),
    .rw_rdata(rw_rdata),
    .rw_done(rw_done),
    .total_bitmaps(total_bitmaps),
    .total_blocks(total_blocks),
    .reset_state_out(),
    .init_state_out(),
    .find_consec_state_out(),
    .find_first_state_out(),
    .rw_state_out()
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz clock
  end

  // Test sequence
  initial begin
    // Initialize Inputs
    rst_n = 0;
    init_req = 0;
    init_module_id = 0;
    init_head = 32'h00000001;
    init_tail = 32'h00000002;
    init_last = 32'h00000003;
    init_head_bm_id = 8'h01;
    init_head_bm_index = 8'h02;
    init_circular_size = 8'h10;
    init_dynamic_size = 8'h20;

    meta_req = 0;
    meta_wr = 0;
    meta_module_id = 0;
    meta_field_select = 0;
    meta_wdata = 0;

    rw_req = 0;
    rw_wr = 0;
    rw_module_id = 0;
    rw_block_number = 0;
    rw_index = 0;
    rw_wdata = 0;

    // Wait for reset
    #20;
    rst_n = 1;

    // Initialize module 0
    @(posedge clk);
    init_req = 1;
    @(posedge clk);
    init_req = 0;

    // Wait for initialization to complete
    wait(init_done);

    // Update some metadata fields
    @(posedge clk);
    meta_req = 1;
    meta_wr = 1;
    meta_module_id = 0;
    meta_field_select = 4'd0; // META_HEAD
    meta_wdata = 32'hDEADBEEF;
    @(posedge clk);
    meta_req = 0;

    // Wait for metadata write to complete
    wait(meta_done);

    // Read metadata field
    @(posedge clk);
    meta_req = 1;
    meta_wr = 0;
    meta_module_id = 0;
    meta_field_select = 4'd0; // META_HEAD
    @(posedge clk);
    meta_req = 0;

    // Wait for metadata read to complete
    wait(meta_done);

    // Display read data
    $display("Read META_HEAD: %h", meta_rdata);
	
    // Read metadata field
    @(posedge clk);
    meta_req = 1;
    meta_wr = 0;
    meta_module_id = 0;
    meta_field_select = 4'd1; // META_HEAD
    @(posedge clk);
    meta_req = 0;

    // Wait for metadata read to complete
    wait(meta_done);

    // Display read data
    $display("Read META_HEAD: %h", meta_rdata);
	
	/////////////////////////////////////////////////////////////
	
	
    // Write to block 1 index 1
    @(posedge clk);
    rw_req = 1;
    rw_wr = 1;
    rw_module_id = 0;
    rw_block_number = 1;
    rw_index = 1;
    rw_wdata = 1'b1;
    @(posedge clk);
    rw_req = 0;

    // Wait for write to complete
    wait(rw_done);
    #50;
	//#10;

    // Read from block 1 index 1
    @(posedge clk);
    rw_req = 1;
    rw_wr = 0;
    rw_module_id = 0;
    rw_block_number = 1;
    rw_index = 1;
    @(posedge clk);
    rw_req = 0;

    // Wait for read to complete
    wait(rw_done);
    #50;

    // Display read data
    $display("Read from block 1 index 1: %b", rw_rdata);
	
    // Finish simulation
    #100;
    $finish;
  end

endmodule
