`timescale 1ns / 1ps

module tb_ordering_bitmap_03;

    // Parameters
    localparam SIZE = 16;
    localparam MTU = 1500;
    localparam MAX_BITMAPS = 8;
    localparam CONN_ID_WIDTH = 8;
    localparam MASTER_ARRAY_SIZE = 1024;
    localparam BLOCK_SIZE = 16;
    localparam NUM_MODULES = 4;
    localparam NUM_BLOCKS = 16;

    // Clock and Reset
    reg clk;
    reg reset_n;

    // Inputs to ordering_bitmap
    reg [31:0] seq;
    reg is_last;
    reg [CONN_ID_WIDTH-1:0] conn_id;

    // Outputs from ordering_bitmap
    wire ooo_noacc_signal;
    wire ooo_acc_signal;
    wire bitmap_extended;
    wire merged;
    wire [31:0] bitmap_used;
    wire [4:0] state; // State wire

    // Instantiate the ordering_bitmap module
    ordering_bitmap #(
        .SIZE(SIZE),
        .MTU(MTU),
        .MAX_BITMAPS(MAX_BITMAPS),
        .CONN_ID_WIDTH(CONN_ID_WIDTH),
        .MASTER_ARRAY_SIZE(MASTER_ARRAY_SIZE),
        .BLOCK_SIZE(BLOCK_SIZE),
        .NUM_MODULES(NUM_MODULES),
        .NUM_BLOCKS(NUM_BLOCKS)
    ) uut (
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
        .current_state(state) // Connect state
    );

    // Clock Generation: 10ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Monitor state transitions and signals
    initial begin
        $monitor("Time: %0t | State: %0d | seq: %0d | ooo_noacc: %b | ooo_acc: %b | bitmap_extended: %b | merged: %b",
                 $time, state, seq, ooo_noacc_signal, ooo_acc_signal, bitmap_extended, merged);
    end

    // Test Sequence
    initial begin
        // Initialize Inputs
        reset_n = 0;
        seq = 0;
        is_last = 0;
        conn_id = 8'd0; // Fixed module ID 0

        // Apply Reset
        #20;
        reset_n = 1;

        // Wait for a few clock cycles to ensure initialization
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        // TEST CASES
        seq = 32'd0; #10;
        seq = 32'd1500; #10;
        seq = 32'd3000; #10;
        seq = 32'd4500; #10;

        // Circular bitmap wrap-around
        seq = 32'd6000; #10;
        seq = 32'd75000; #10;
        seq = 32'd9000; #10;
        seq = 32'd105000; #10;

        // Out-of-order packets using linear bitmaps
        seq = 32'd200000; #10;
        seq = 32'd2150000; #10;
        seq = 32'd18000000; #10;

        // Merging back from linear to circular
        seq = 32'd12000; #10;
        seq = 32'd13000; #10;
        seq = 32'd14000; #10;
        seq = 32'd18000; #10;
        seq = 32'd20000; #10;
        seq = 32'd25000; #10;

        // Linear bitmap with gaps
        seq = 32'd40000; #10;
        seq = 32'd43000; #10;

        // End of Test
        #20;
        $finish;
    end

endmodule
