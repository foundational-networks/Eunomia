`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/14/2024 12:34:36 AM
// Design Name: 
// Module Name: tb_ordering_bitmap
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

module tb_ordering_bitmap;

    // Testbench signals
    logic clk;
    logic reset_n;
    logic [31:0] seq;
    logic is_last;
    logic [31:0] updated_head;
    logic ooo_notification;

    // Instantiate the module under test (DUT)
    ordering_bitmap #(64, 1500) uut (
        .clk(clk),
        .reset_n(reset_n),
        .seq(seq),
        .is_last(is_last),
        .updated_head(updated_head),
        .ooo_notification(ooo_notification)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz clock
    end

    // Test procedure
    initial begin
        // Initialize the inputs
        reset_n = 0;
        seq = 32'd0;
        is_last = 0;

        // Apply reset
        #10 reset_n = 1;

        // Send a sequence of packets
        #20 seq = 32'd1500;  // First packet (head)
        #10 seq = 32'd3000;  // Second packet
        #10 seq = 32'd4500;  // Third packet (out of order)

        // Simulate the last packet
        #10 seq = 32'd6000;
        is_last = 1;

        // Wait and then finish simulation
        #50 $finish;
    end

    // Monitor for output changes
    initial begin
        $monitor("Time=%0d, seq=%d, updated_head=%d, ooo_notification=%b", $time, seq, updated_head, ooo_notification);
    end

endmodule

