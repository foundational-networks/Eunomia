`timescale 1ns / 1ps
module tb_ordering_bitmap_02;

    parameter SIZE = 16;
    parameter MTU = 1500;
    parameter MAX_BITMAPS = 8;
    parameter CONN_ID_WIDTH = 8;

    // Signals
    logic clk;
    logic reset_n;
    logic [31:0] seq;
    logic is_last;
    logic [CONN_ID_WIDTH-1:0] conn_id;
    logic ooo_noacc_signal;
    logic ooo_acc_signal;
    logic bitmap_extended;
    logic merged;
    integer bitmap_used;

    // Instantiate the DUT
    ordering_bitmap #(
        .SIZE(SIZE),
        .MTU(MTU),
        .MAX_BITMAPS(MAX_BITMAPS),
        .CONN_ID_WIDTH(CONN_ID_WIDTH)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        .seq(seq),
        .is_last(is_last),
        .conn_id(conn_id),
        .ooo_noacc_signal(ooo_noacc_signal),
        .ooo_acc_signal(ooo_acc_signal),
        .bitmap_extended(bitmap_extended),
        .merged(merged),
        .bitmap_used(bitmap_used)
    );

    // Clock generation
    always #5 clk = ~clk; // 10ns clock period

    // Testbench
    initial begin
        // Initialize signals
        clk = 0;
        reset_n = 0;
        seq = 0;
        is_last = 0;
        conn_id = 0;

        // Apply reset
        #10;
        reset_n = 1;
        #10;

        // Test in-order packets
        test_in_order_packets();

        // Test out-of-order packets within bitmap range
        test_out_of_order_within_range();

        // Test out-of-order packets outside bitmap range
        test_out_of_order_outside_range();

        // Test reset
        test_reset();

        // Saturate the bitmap block with actual data
        saturate_bitmap();

        $stop;
    end

    // Task to check signals
    task check_signals;
        begin
            if (ooo_noacc_signal) begin
                $display("Time %0t: ooo_noacc_signal asserted when seq=%0d", $time, seq);
            end
            if (ooo_acc_signal) begin
                $display("Time %0t: ooo_acc_signal asserted when seq=%0d", $time, seq);
            end
            if (bitmap_extended) begin
                $display("Time %0t: bitmap_extended asserted", $time);
            end
            if (merged) begin
                $display("Time %0t: merged asserted", $time);
            end
        end
    endtask

    // Test in-order packets
    task test_in_order_packets;
        integer i;
        begin
            $display("Testing in-order packets...");
            for (i = 0; i < 10; i = i + 1) begin
                seq = i * MTU;
                is_last = 0;
                conn_id = 0;
                @(posedge clk);
                #1;
                check_signals();
            end
            $display("In-order packets test completed.");
        end
    endtask

    // Test out-of-order packets within bitmap range
    task test_out_of_order_within_range;
        integer seq_list[0:9];
        integer temp;
        integer i, j;
        begin
            $display("Testing out-of-order packets within bitmap range...");
            // Initialize sequence list
            for (i = 0; i < 10; i = i + 1) begin
                seq_list[i] = i * MTU;
            end
            // Shuffle the sequence list
            for (i = 0; i < 10; i = i + 1) begin
                j = $urandom%10;
                temp = seq_list[i];
                seq_list[i] = seq_list[j];
                seq_list[j] = temp;
            end

            for (i = 0; i < 10; i = i + 1) begin
                seq = seq_list[i];
                is_last = 0;
                conn_id = 0;
                @(posedge clk);
                #1;
                check_signals();
            end
            seq = 32'd4500; #10;
            seq = 32'd45000; #10;
            seq = 32'd450000; #10;
            $display("Out-of-order within range test completed.");
        end
    endtask

    // Test out-of-order packets outside bitmap range
    task test_out_of_order_outside_range;
        integer i;
        begin
            $display("Testing out-of-order packets outside bitmap range...");
            // Send a packet far beyond the current head
            seq = 1000 * MTU;
            is_last = 0;
            conn_id = 0;
            @(posedge clk);
            #1;
            check_signals();
            $display("Out-of-order outside range test completed.");
        end
    endtask

    // Test reset
    task test_reset;
        begin
            $display("Testing reset...");
            reset_n = 0;
            @(posedge clk);
            reset_n = 1;
            @(posedge clk);
            #1;
            // Cannot access internal signals, so check outputs
            if (ooo_noacc_signal !== 1'b0 && ooo_acc_signal !== 1'b0) begin
                $display("Time %0t: Reset failed, signals are not reset properly", $time);
            end else begin
                $display("Reset test passed.");
            end
        end
    endtask

    // Saturate the bitmap block with actual data
    task saturate_bitmap;
        integer i;
        begin
            $display("Saturating the bitmap with data...");
            for (i = 0; i < (SIZE * MAX_BITMAPS); i = i + 1) begin
                seq = i * MTU;
                is_last = 0;
                conn_id = 0;
                @(posedge clk);
                #1;
                check_signals();
            end
            $display("Bitmap saturation test completed.");
        end
    endtask

endmodule
