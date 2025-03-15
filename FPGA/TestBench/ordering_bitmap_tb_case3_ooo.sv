`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/14/2024 05:32:00 AM
// Design Name: 
// Module Name: ordering_bitmap_tb_case3_ooo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module ordering_bitmap_tb_case3_ooos;

    // Clock and reset signals
    logic clk;
    logic reset_n;

    // Inputs to the DUT (Device Under Test)
    logic [31:0] seq;
    logic is_last;

    // Outputs from the DUT
    logic ooo_notification;
    logic bitmap_extended;

    // Instantiate the ordering_bitmap module with MAX_BITMAPS set to 8
    ordering_bitmap #(64, 1500, 8) dut (
        .clk(clk),
        .reset_n(reset_n),
        .seq(seq),
        .is_last(is_last),
        .ooo_notification(ooo_notification),
        .bitmap_extended(bitmap_extended)
    );

    // Clock generation: 10ns period
    always #5 clk = ~clk;

    // Task to send a packet
    task send_packet(input logic [31:0] packet_seq, input logic packet_is_last);
        begin
            @(negedge clk);
            seq <= packet_seq;
            is_last <= packet_is_last;
            @(posedge clk);
            // Display outputs and internal states
            $display("Time: %0t | Seq: %0d | Is_Last: %b | OOO_Notif: %b | Bitmap_Extended: %b", 
                     $time, seq, is_last, ooo_notification, bitmap_extended);
            $display("        Head: %0d | Tail: %0d | Dynamic_Size: %0d | Linear_Bitmap_Used: %0d", 
                     dut.head, dut.tail, dut.dynamic_size, dut.linear_bitmap_used);
            // Clear inputs
            seq <= 32'd0;
            is_last <= 1'b0;
        end
    endtask

    // Initial block to drive the test
    initial begin
        integer i;
        // Initialize signals
        clk = 0;
        reset_n = 0;
        seq = 32'd0;
        is_last = 1'b0;

        // Wait for a few clock cycles
        repeat(2) @(posedge clk);

        // Deassert reset
        reset_n = 1;
        $display("Reset deasserted at time %0t", $time);

        // Wait for a clock cycle
        @(posedge clk);

        // Test Case 1: Fill bitmaps to maximum capacity
        $display("\n--- Test Case 1: Fill Bitmaps to Maximum Capacity ---");

        for (i = 0; i < 512; i = i + 1) begin
            send_packet(i * 1500, 1'b0);
            if (dut.linear_bitmap_used == 7 && dut.dynamic_size == 64 + 7 * 64) begin
                // Reached maximum bitmap capacity
                $display("Maximum bitmap capacity reached at time %0t", $time);
                break;
            end
        end

        // Test Case 2: Send out-of-order packet beyond capacity
        $display("\n--- Test Case 2: Out-of-Order Packet Beyond Capacity ---");
        // Send a packet that's out-of-order and cannot be accommodated
        send_packet((i + 10) * 150000, 1'b0);  // Sequence number beyond current capacity

        // Wait for a few clock cycles
        repeat(5) @(posedge clk);

        // End of simulation
        $display("\nSimulation Complete at time %0t", $time);
        $finish;
    end

endmodule

