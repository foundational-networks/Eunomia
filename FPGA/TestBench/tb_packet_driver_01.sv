`timescale 1ns / 1ps
module tb_packet_driver_01;

    // Clock and Reset
    reg clk;
    reg reset_n;

    // Inputs to packet_driver
    reg [31:0] seq;
    reg is_last;
    reg [1:0] conn_id;
    reg conn_done;

    // Outputs from packet_driver
    wire ooo_old_signal;
    wire inorder_acc_signal;
    wire ooo_noacc_signal;
    wire ooo_acc_signal;
    wire bitmap_extended;
    wire merged;
    wire [31:0] bitmap_used;
    wire meta_req;
    wire meta_wr;
    wire [1:0] meta_module_id;
    wire [3:0] meta_field_select;
    wire [31:0] meta_wdata;
    wire [31:0] meta_rdata;
    wire meta_done;
    wire rw_req;
    wire rw_wr;
    wire [3:0] rw_block_number;
    wire [3:0] rw_index;
    wire  rw_wdata;
    wire  rw_rdata;
    wire rw_done;
    wire pkt_done;
	wire [31:0] total_bitmaps;
	wire [31:0] total_blocks;

    // Debug Outputs
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
	

    // Instantiate packet_driver module
    packet_driver pd_inst (
        .clk(clk),
        .reset_n(reset_n),
        .seq(seq),
        .is_last(is_last),
        .conn_id(conn_id),
        .conn_done(conn_done),
        .ooo_old_signal(ooo_old_signal),
        .inorder_acc_signal(inorder_acc_signal),
        .ooo_noacc_signal(ooo_noacc_signal),
        .ooo_acc_signal(ooo_acc_signal),
        .bitmap_extended(bitmap_extended),
        .merged(merged),
        .bitmap_used(bitmap_used),
        .meta_req(meta_req),
        .meta_wr(meta_wr),
        .meta_module_id(meta_module_id),
        .meta_field_select(meta_field_select),
        .meta_wdata(meta_wdata),
        .meta_rdata(meta_rdata),
        .meta_done(meta_done),
        .rw_req(rw_req),
        .rw_wr(rw_wr),
        .rw_block_number(rw_block_number),
        .rw_index(rw_index),
        .rw_wdata(rw_wdata),
        .rw_rdata(rw_rdata),
        .rw_done(rw_done),
        .pkt_done(pkt_done),
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
        .dbg_state(dbg_state),
		.total_bitmaps(total_bitmaps),
		.total_blocks(total_blocks)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz Clock
    end

    // Test Sequence
    initial begin
        // Initialize Inputs
        reset_n    = 0;
        seq        = 32'd0;
        is_last    = 1'b0;
        conn_id    = 2'd1;
        conn_done  = 1'b0;
        #20;

        // Release Reset
        reset_n = 1;
        #500;

        // Feed packet with seq = 1500
        seq = 32'd1500;
        is_last = 1'b0;
        #500;
        seq = 32'd0; // Clear seq to simulate packet arrival
        #500;

        // Feed packet with seq = 4500
        seq = 32'd4500;
        is_last = 1'b0;
        #500;
        seq = 32'd0;
        is_last = 1'b0;
        #500;

        // Feed packet with seq = 45000
        seq = 32'd45000;
        #500;
        seq = 32'd0;
        #500;

        // Feed packet with seq = 7500
        seq = 32'd7500;
        #500;
        seq = 32'd0;
        #500;

        // Feed packet with seq = 2000
        seq = 32'd2000;
        #500;
        seq = 32'd0;
        #500;

        // Finish Simulation
        $stop;
    end

    // Monitor Signals
    initial begin
        $monitor("Time: %0t | State: %0d | seq: %0d | ooo_old_signal: %b | inorder_acc_signal: %b | ooo_acc_signal: %b | ooo_noacc_signal: %b | bitmap_extended: %b | merged: %b | head: %0d | tail: %0d | circular_bm_size: %0d | dynamic_size: %0d | total_bitmaps: %0d",
                 $time, dbg_state, dbg_seq, ooo_old_signal, inorder_acc_signal, ooo_acc_signal, ooo_noacc_signal, bitmap_extended, merged, dbg_head, dbg_tail, dbg_circular_bm_size, dbg_dynamic_size, dbg_total_bitmaps);
    end

endmodule
