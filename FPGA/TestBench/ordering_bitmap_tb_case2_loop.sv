`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/14/2024 05:19:27 AM
// Design Name: 
// Module Name: ordering_bitmap_tb_case2_loop
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

module ordering_bitmap_tb_case2_loop;

    // Clock and reset signals
    logic clk;
    logic reset_n;

    // Inputs to the DUT (Device Under Test)
    logic [31:0] seq;
    logic is_last;

    // Outputs from the DUT
    logic ooo_notification;
    logic bitmap_extended;

    // Instantiate the ordering_bitmap module
    ordering_bitmap #(64, 1500, 256) dut (
        .clk(clk),
        .reset_n(reset_n),
        .seq(seq),
        .is_last(is_last),
        .ooo_notification(ooo_notification),
        .bitmap_extended(bitmap_extended)
    );

    // Clock generation: 10ns period
    always #5 clk = ~clk;

    // Test variables
    integer i;

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
            // Display internal signals
            $display("        Head: %0d | Tail: %0d | Head_Index: %0d | Linear_Bitmap_Used: %0d", 
                     dut.head, dut.tail, dut.head_index, dut.linear_bitmap_used);
            $display("        Dynamic_Size: %0d | Total_Bitmaps: %0d", 
                     dut.dynamic_size, dut.total_bitmaps);
            // Clear inputs
            seq <= 32'd0;
            is_last <= 1'b0;
        end
    endtask

    // Initial block to drive the test
    initial begin
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

        // Test Case 1: Send in-order packets
        $display("\n--- Test Case 1: In-Order Packets ---");
        for (i = 0; i < 5; i = i + 1) begin
            send_packet(i * 1500, 1'b0);
        end

        // Test Case 2: Send an out-of-order packet ahead of head
        $display("\n--- Test Case 2: Out-of-Order Packet ---");
        send_packet(10 * 1500, 1'b0);  // This should set ooo_notification

        // Test Case 3: Send packets to fill up circular bitmap and extend it
        $display("\n--- Test Case 3: Extend Bitmap ---");
        for (i = 5; i < 70; i = i + 1) begin
            send_packet(i * 1500, 1'b0);
        end

        // Test Case 4: Send packets that cause merging back
        $display("\n--- Test Case 4: Merge Bitmaps Back ---");
        // Send the missing packet to fill the gap
        send_packet(5 * 1500, 1'b0);

        // Test Case 5: Mark the last packet
        $display("\n--- Test Case 5: Last Packet ---");
        send_packet(70 * 1500, 1'b1);  // Mark the last packet

        // End of simulation
        $display("\nSimulation Complete at time %0t", $time);
        $finish;
    end

endmodule