`timescale 1ns / 1ps
module tb_ordering_bitmap_01;

// Clock and Reset
reg clk;
reg reset_n;

// Inputs to ordering_bitmap
reg [31:0] seq;
reg is_last;
reg [1:0] conn_id;

// Outputs from ordering_bitmap
wire ooo_noacc_signal;
wire ooo_acc_signal;
wire bitmap_extended;
wire merged;
wire [31:0] bitmap_used;
// Memory Controller Interface Signals
wire meta_req;
wire meta_wr;
wire [1:0] meta_module_id;
wire [3:0] meta_field_select;
wire [31:0] meta_wdata;
wire [31:0] meta_rdata;
wire meta_done;

// Declare rw_module_id as reg for procedural assignment
reg [1:0] rw_module_id;

// Other Memory Controller Interface Signals
wire rw_req;
wire rw_wr;
wire [3:0] rw_block_number;
wire [3:0] rw_index;
wire [7:0] rw_wdata;
wire [7:0] rw_rdata;
wire rw_done;
wire pkt_done;
wire conn_done;

// Wires to connect to debug outputs
wire [31:0] dbg_head;
wire [31:0] dbg_tail;
wire [31:0] dbg_last_seq;
wire [31:0] dbg_circular_bm_size;
wire [31:0] dbg_dynamic_size;
wire [31:0] dbg_total_bitmaps;
wire [31:0] dbg_added_size;
wire [31:0] dbg_linear_bitmap_used;
wire [31:0] dbg_max_range;
wire [31:0] dbg_head_bm_id;
wire [31:0] dbg_head_index;
wire [31:0] dbg_gap_filled;
wire [31:0] dbg_index_from_head;
wire [31:0] dbg_index_on_linear_bm;
wire [31:0] dbg_curr_bm_id;
wire [31:0] dbg_index_on_curr_bm;
wire [31:0] dbg_abs_idx;
wire [31:0] dbg_seq;
wire [5:0]  dbg_state;

// Instantiate ordering_bitmap module
ordering_bitmap ob_inst (
    .clk(clk),
    .reset_n(reset_n),
    .seq(seq),
    .is_last(is_last),
    .conn_id(conn_id),
    .ooo_noacc_signal(ooo_noacc_signal),
    .ooo_acc_signal(ooo_acc_signal),
    .bitmap_extended(bitmap_extended),
    .merged(merged),
    .bitmap_used(bitmap_used),
    .meta_req(meta_req),
    .meta_wr(meta_wr),
    .meta_module_id(meta_module_id),
    .init_module_id(init_module_id),
    .meta_field_select(meta_field_select),
    .meta_wdata(meta_wdata),
    .meta_rdata(meta_rdata),
    .meta_done(meta_done),
    .rw_req(rw_req),
    .rw_wr(rw_wr),
    .rw_block_number(rw_block_number),
	.rw_module_id(rw_module_id),
    .rw_index(rw_index),
    .rw_wdata(rw_wdata),
    .rw_rdata(rw_rdata),
    .rw_done(rw_done),
	.pkt_done(pkt_done),
	.conn_done(conn_done),
    .dbg_head(dbg_head),
    .dbg_tail(dbg_tail),
    .dbg_last_seq(dbg_last_seq),
    .dbg_circular_bm_size(dbg_circular_bm_size),
    .dbg_dynamic_size(dbg_dynamic_size),
    .dbg_total_bitmaps(dbg_total_bitmaps),
    .dbg_added_size(dbg_added_size),
    .dbg_linear_bitmap_used(dbg_linear_bitmap_used),
    .dbg_max_range(dbg_max_range),
    .dbg_head_bm_id(dbg_head_bm_id),
    .dbg_head_index(dbg_head_index),
    .dbg_gap_filled(dbg_gap_filled),
    .dbg_index_from_head(dbg_index_from_head),
    .dbg_index_on_linear_bm(dbg_index_on_linear_bm),
    .dbg_curr_bm_id(dbg_curr_bm_id),
    .dbg_index_on_curr_bm(dbg_index_on_curr_bm),
    .dbg_abs_idx(dbg_abs_idx),
    .dbg_seq(dbg_seq),
    .dbg_state(dbg_state)
);

// Instantiate memory_controller module
memory_controller mc_inst (
    .clk(clk),
    .rst_n(reset_n),

    // Interface for module initialization
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

    // Interface for metadata read/write operations
    .meta_req(meta_req),
    .meta_wr(meta_wr),
    .meta_module_id(meta_module_id),
    .meta_field_select(meta_field_select),
    .meta_wdata(meta_wdata),
    .meta_rdata(meta_rdata),
    .meta_done(meta_done),

    // Interface for module reset
    .reset_module_req(1'b0),
    .reset_module_id(8'd0),
    .reset_module_done(),

    // Interface for read/write operations
    .rw_req(rw_req),
    .rw_wr(rw_wr),
    .rw_module_id(rw_module_id), // Connect to the reg rw_module_id
    .rw_block_number(rw_block_number),
    .rw_index(rw_index),
    .rw_wdata(rw_wdata),
    .rw_rdata(rw_rdata),
    .rw_done(rw_done),

    // Interface for performance measurement
    .total_bitmaps(),
    .total_blocks()
);

// Memory Controller Initialization Signals
reg init_req;
reg [1:0] init_module_id;
reg [31:0] init_head;
reg [31:0] init_tail;
reg [31:0] init_last;
reg [7:0] init_head_bm_id;
reg [7:0] init_head_bm_index;
reg [7:0] init_circular_size;
reg [7:0] init_dynamic_size;

wire init_done;

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100 MHz clock
end

// Test sequence
initial begin
    // Initialize inputs
    reset_n = 0;
    seq = 32'd0;
    is_last = 1'b0;
    conn_id = 2'd1;
    init_req = 0;
    #20;

    // Release reset
    reset_n = 1;
    #100;

    // Initialize the memory controller for conn_id = 1
    init_head = 32'd0;
    init_tail = -1;
    init_last = -1;
    init_head_bm_id = 8'd0;
    init_head_bm_index = 8'd0;
    init_circular_size = 8'd16;  // Assuming SIZE = 16
    init_dynamic_size = 8'd16;   // Initially, dynamic_size = circular_size
    init_req = 1;
    #300;
    // Wait for init_done
    wait (init_done == 1);
    init_req = 0;


    // Feed packet with seq = 1500
    seq = 32'd1500;
    is_last = 1'b0;
	wait (pkt_done == 1);
    #500; // Wait sufficient time for processing

	// Feed packet with seq = 4500
	seq = 32'd4500;
	is_last = 1'b1;
	#500; // Wait sufficient time for processing
	is_last = 1'b0;

	// Feed packet with seq = 45000
	seq = 32'd45000;
	#500;
	seq = 32'd0;
	#500;

	// Feed packet with seq = 7500
	seq = 32'd7500;
	#500

	// Feed packet with seq = 2000
	seq = 32'd2000;
	#500;
	
	seq = 32'd200000;
	#500;


    // Finish simulation
    $stop;
end

// Monitor signals
initial begin
    $monitor("Time: %0t | State: %0d | seq: %0d | ooo_acc_signal: %b | ooo_noacc_signal: %b | bitmap_extended: %b | merged: %b | head: %0d | tail: %0d | circular_bm_size: %0d | dynamic_size: %0d | total_bitmaps: %0d | rw_module_id: %0d",
             $time, dbg_state, dbg_seq, ooo_acc_signal, ooo_noacc_signal, bitmap_extended, merged, dbg_head, dbg_tail, dbg_circular_bm_size, dbg_dynamic_size, dbg_total_bitmaps, rw_module_id);
end

endmodule