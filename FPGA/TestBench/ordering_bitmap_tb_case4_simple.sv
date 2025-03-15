`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2024 11:27:58 AM
// Design Name: 
// Module Name: ordering_bitmap_tb_case4_simple
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


module ordering_bitmap_tb_case4_simple;

    // Define clock and reset signals
    logic clk;
    logic reset_n;

    // Inputs to the ordering_bitmap module
    logic [31:0] seq;
    logic is_last;

    // Outputs from the ordering_bitmap module
    logic ooo_notification;
    logic bitmap_extended;
	logic merged;
	integer bitmap_used;  // Change to 32-bit logic to monitor multiple bitmaps

    // Instantiate the ordering_bitmap module
    ordering_bitmap #(
        .SIZE(8),       // Set smaller size for quick simulation (you can adjust SIZE)
        .MTU(1500),
        .MAX_BITMAPS(4) // Smaller max bitmaps for testing (you can adjust as needed)
    ) uut (
        .clk(clk),
        .reset_n(reset_n),
        .seq(seq),
        .is_last(is_last),
        .ooo_notification(ooo_notification),
        .bitmap_extended(bitmap_extended),
		.merged(merged),
		.bitmap_used(bitmap_used)
    );
 
    // Clock generation
    always #5 clk = ~clk; // 10 ns clock period

    // Test sequence
    initial begin
        // Initialize
        clk = 0;
        reset_n = 0;
        seq = 32'd0;
        is_last = 1'b0;

        // Apply reset
        #10;
        reset_n = 1;
        #10;

        // TEST CASE 1: Circular bitmap test (in-order packets)
        $display("TEST CASE 1: Circular bitmap test (in-order packets)");
        seq = 32'd0; #10;
        seq = 32'd1500; #10;
        seq = 32'd3000; #10;
        seq = 32'd4500; #10;

        // TEST CASE 2: Circular bitmap wrap-around (in-order packets)
        $display("TEST CASE 2: Circular bitmap wrap-around");
        seq = 32'd6000; #10;
        seq = 32'd7500; #10;
        seq = 32'd9000; #10;
        seq = 32'd10500; #10; // Should wrap around and reuse the circular bitmap
        
        // TEST CASE 3: Out-of-order packets using linear bitmaps
        $display("TEST CASE 3: Out-of-order packets (linear bitmap test)");
        seq = 32'd200000; #10; // Out-of-order packet should go to linear bitmap
        seq = 32'd21500; #10; // Another out-of-order packet to linear bitmap
        seq = 32'd18000; #10; // Another out-of-order packet

        // TEST CASE 4: Merging back from linear to circular
        $display("TEST CASE 4: Merging linear bitmap back to circular");
        seq = 32'd12000; #10; // Trigger merge back as head progresses forward

        // TEST CASE 5: Linear bitmap with gaps
        $display("TEST CASE 5: Linear bitmap with gaps");
        seq = 32'd40000; #10;
        seq = 32'd43000; #10; // Gap between packets (32'd41500 is missing)

        // Wait and finish
        #50;
        $finish;
    end

    // Monitor outputs and display them
    initial begin
        $monitor("Time = %0t | seq = %0d | ooo_notification = %b | bitmap_extended = %b | merged = %b | bitmap_used = %0d", 
                 $time, seq, ooo_notification, bitmap_extended, merged, bitmap_used);
    end

endmodule

