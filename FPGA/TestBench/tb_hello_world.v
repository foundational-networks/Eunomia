`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/11/2024 01:06:37 PM
// Design Name: 
// Module Name: tb_hello_world
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


module tb_hello_world();

    reg clk;
    wire led;
    
    // Instantiate the design (Device Under Test - DUT)
    hello_world dut (
        .clk(clk),
        .led(led)
    );
    
    // Clock generation (50 MHz clock for simulation)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;  // 100ns period = 50MHz clock
    end
    
    // Simulation control
    initial begin
        // Let the simulation run for a while to observe the LED toggle
        #10000000;  // Simulate for 10ms (adjust as needed)
        $finish;
    end
    
endmodule

