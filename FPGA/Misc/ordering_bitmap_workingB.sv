`timescale 1ns / 1ps
module ordering_bitmap #(
    parameter SIZE = 16,
    parameter MTU = 1500,
    parameter MAX_BITMAPS = 16,
    parameter CONN_ID_WIDTH = 8
    )
(
    input logic clk,                 // Clock signal
    input logic reset_n,             // Active-low reset signal
    input logic [31:0] seq,          // Packet sequence number - absolute
    input logic is_last,             // Flag to indicate if it's the last packet
    input logic [CONN_ID_WIDTH-1:0] conn_id, // New input conn_id
	output logic [31:0] head,
	output logic [31:0] tail,
	output logic [31:0] last_seq,
    output logic ooo_noacc_signal,   // Renamed from ooo_notification
    output logic ooo_acc_signal,     // New signal when packet fits in the bitmap
    output logic bitmap_extended,    // Signal to indicate a new bitmap has been added
    output logic merged,             // Signal to indicate a bitmap merge occurred
    output integer bitmap_used,       // Number of bitmaps used
	output integer total_bitmaps_dbg,
	output integer circular_bm_size_dbg,
	output integer dynamic_size_dbg,
	output integer added_size_dbg,
	output integer max_range_dbg,
	output integer head_bm_id,
	output integer head_index
);
	assign max_range_dbg = max_range;
	assign added_size_dbg = added_size;
	assign dynamic_size_dbg = dynamic_size;
	assign circular_bm_size_dbg = circular_bm_size;
	assign total_bitmaps_dbg = total_bitmaps;
    
    // Combined bitmap storage: first SIZE elements are circular, the rest are linear
    logic bitmap [MAX_BITMAPS + 1][SIZE]; // Single combined bitmap array. 2-D 1 bit by default.
    // Max iterations for adding bitmap
    integer max_iter = 128;             // for adding bit maps
    integer max_iter_merge = 256;       // for merging loop
    
    integer dynamic_size;             // Current size of the entire combined bitmap
    integer linear_bitmap_used;       // Number of additional linear bitmap segments used
    
    // Variables tracking bitmap state
    logic [31:0] head;                  // Head of the circular bitmap (next expected packet seq number)
    logic [31:0] tail;                  // Tail of the circular bitmap (seq number)
    logic [31:0] last_seq;              // The last packet sequence number (when is_last is set)
    integer circular_bm_size;           // The current size of the circular bitmap
    integer total_bitmaps;              // Total number of bitmaps created (1 circular + linear)
    integer added_size;                 // Size being added through the entire process
    integer head_index;
	integer head_bm_id;
	
    integer max_range;                  // Max size of the entire bitmap (i.e. max number of packets can be tracked)
    integer i_reset;                    // Loop variable for reset
    
    // Define the check_bitmaps_needed function, used to check if we can accommodate with current max # of bitmaps.
    function logic check_bitmaps_needed(input logic [31:0] seq, input logic [31:0] tail);
        int index_on_linear_bm;
        //When the tail is not -1
        if (tail != -1) begin
            index_on_linear_bm = (seq - tail) / MTU - 1;  // Calculate index on logic linear bitmap

            // Check if additional bitmaps are needed
            if (index_on_linear_bm >= (linear_bitmap_used * SIZE)) begin
                // We need more bitmaps if the current linear bitmaps are not enough
                return 1'b1;  // Additional bitmaps are needed
            end
            return 1'b0;  // No additional bitmaps are needed
        // the tail is -1
        end else begin
            // the seq is within the circular bitmap range
            if(seq < tail) begin
                return 1'b0;
            end
            // seq greater than the circular bitmap tail, linear bitmap required
            return 1'b1;
        end         
    endfunction

    // Define the is_finished function, check if all things finished
    function logic is_finished(input integer next_head, input integer next_last_seq);
        if (next_head >= next_last_seq) begin
            return 1'b1;
        end else begin
            return 1'b0;
        end
    endfunction

    // Define the add_bitmaps task
    task automatic add_bitmap(
        inout logic [31:0] next_dynamic_size,
        inout integer next_added_size,
        inout logic next_bitmap_extended,
        inout integer next_total_bitmaps
    );
        begin
            next_total_bitmaps = next_total_bitmaps + 1;
            next_dynamic_size = next_dynamic_size + SIZE;
            next_added_size = next_added_size + SIZE;
            next_bitmap_extended = 1'b1;
        end
    endtask

    // Sequential logic block triggered on clock or reset
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset all state variables on reset
            head <= 32'd0;
            tail <= -1;
            dynamic_size <= SIZE;         // Initialize combined size to SIZE (only circular bitmap)
            last_seq <= -1;
            total_bitmaps <= 1;            // Start with 1 bitmap (circular)
            ooo_noacc_signal <= 1'b0;
            ooo_acc_signal <= 1'b0;
            merged <= 1'b0;
            bitmap_used <= total_bitmaps;
            bitmap_extended <= 1'b0;
            linear_bitmap_used <= 0;
            circular_bm_size <= SIZE;
            max_range <= SIZE * MAX_BITMAPS;
            added_size <= 0;
			head_index <= 0;
			head_bm_id <= 0;

        end else begin
            // Declare all variables at the beginning and mark as `automatic`
            automatic logic [31:0] next_head = head;
            automatic logic [31:0] next_tail = tail;
            automatic logic [31:0] next_dynamic_size = dynamic_size;
            automatic logic [31:0] next_last_seq = last_seq;
            automatic integer next_circular_bm_size = circular_bm_size;
            automatic integer next_total_bitmaps = total_bitmaps;
            automatic logic next_ooo_noacc_signal = 1'b0;
            automatic logic next_ooo_acc_signal = 1'b0;
            automatic logic next_bitmap_extended = 1'b0;
            automatic integer next_linear_bitmap_used = linear_bitmap_used;
            automatic integer next_max_range = max_range;
            automatic integer next_added_size = added_size;
            automatic logic next_merged = 1'b0;

            automatic integer linear_bm_id;   // Declare local variables for loops, conditions, and temp use.
            automatic integer linear_index;
            automatic integer i, j;
            automatic integer linear_bm_size;
            // automatic integer head_bm_id = 0;
            // automatic integer head_index = 0;
            automatic integer next_head_bm_id = head_bm_id;
            automatic integer next_head_index = head_index;
            automatic integer total_circular_bms = next_circular_bm_size / SIZE;
            automatic integer first_linear_idx; // the index of the first linear bitmap in the entire array.
            automatic integer abs_idx;          // the index of the packet in the entire array.
            automatic integer curr_bm_id;
            automatic integer gap_filled = 0;
            automatic integer index_on_curr_bm;

            automatic int index_on_linear_bm; // Declare here to avoid the scope issue

            // Process incoming packet sequence numbers, otherwise drop the packet
            if (seq >= next_head) begin
                automatic int index_from_head = (seq - next_head) / MTU;  // Calculate index from the head
                // Case 1: If the packet is outside the current bm range
                if (index_from_head >= next_dynamic_size || seq > next_tail) begin
                    linear_bm_size = next_dynamic_size - next_circular_bm_size;
                    
                    if (linear_bm_size == 0) begin
                        // create the first linear bitmap & set tail
                        next_tail = next_head + ((next_circular_bm_size - 1) * MTU);
                    end
                    // Find the index the packet on the linear bitmap
                    index_on_linear_bm = ((seq - next_tail) / MTU) - 1;
                    
                    // Check if we can accommodate within the max allowed bitmaps
                    if ((next_circular_bm_size + index_on_linear_bm) >= next_max_range) begin
                        // reset tail if needed
                        if (next_circular_bm_size == next_dynamic_size) begin
                            next_tail = -1;
                        end
                        next_ooo_noacc_signal = 1'b1;  // Out-of-order no accommodate signal
                    end else begin
                        // while packet can fit
                        if (index_on_linear_bm >= linear_bm_size) begin
                            // we need additional linear bitmaps
                            add_bitmap(next_dynamic_size, next_added_size, next_bitmap_extended, next_total_bitmaps);
                            linear_bm_size = linear_bm_size + SIZE;
                            i = 0;
                            while (index_on_linear_bm >= linear_bm_size && i < max_iter) begin
                                i = i + 1;
                                // keep adding linear bitmaps until the packet can fit
                                add_bitmap(next_dynamic_size, next_added_size, next_bitmap_extended, next_total_bitmaps);
                                linear_bm_size = linear_bm_size + SIZE;
                            end
                            i = 0;
                        end
                        
                        // The abs index of where the linear bitmap starts
                        first_linear_idx = total_circular_bms * SIZE;
                        // Find the actual bitmap index for current packet
                        abs_idx = first_linear_idx + index_on_linear_bm;
                        
                        // Find the ID of current bitmap
                        curr_bm_id = abs_idx / SIZE;
                        // Find the index of current packet on the corresponding bitmap block
                        index_on_curr_bm = index_on_linear_bm % SIZE;
                        // Assign the actual value
                        // Block assignment, update value immediately
                        bitmap[curr_bm_id][index_on_curr_bm] = 1'b1;
                    end
                end else begin
                    // The packet can be accommodated in the circular bitmap
                    
                    // On the linear circular bitmap
                    abs_idx = (next_head_bm_id * SIZE) + next_head_index + index_from_head;
                    if (abs_idx > next_circular_bm_size) begin
                        abs_idx = abs_idx - next_circular_bm_size;
                    end
                    
                    // On the circular portion of dynamic table
                    curr_bm_id = abs_idx / SIZE;
                    if (curr_bm_id >= total_circular_bms) begin
                        curr_bm_id = curr_bm_id - total_circular_bms;
                    end
                    
                    // The exact index on that bitmap
                    index_on_curr_bm = abs_idx % SIZE;
                    
                    // Assign the actual value
                    bitmap[curr_bm_id][index_on_curr_bm] = 1'b1;
                
                end
                
                // Check if gaps filled and move forward
                if (seq == next_head) begin
                   automatic integer cnt = 0;

                    // move forward on the circular bitmap until an index with non-1 is encountered
                    while(bitmap[next_head_bm_id][next_head_index] == 1 && cnt < 2000) begin
                        cnt = cnt + 1;
                        // add filled gap by 1
                        gap_filled = gap_filled + 1;
                        // remove the encountered value
                        bitmap[next_head_bm_id][next_head_index] = 0;
                        // Increment head_index
                        next_head_index = next_head_index + 1;
                        // If we reach the end of a block
                        if (next_head_index == SIZE) begin
                            // Reset the idx to the first
                            next_head_index = 0;
                            // proceed to next row
                            next_head_bm_id = next_head_bm_id + 1;
                            // If reach the end of circular bitmap 
                            if (next_head_bm_id == total_circular_bms) begin
                                next_head_bm_id = 0;
                            end
                        end
                    end
                    
                    // Update head
                    next_head = next_head + gap_filled * MTU;
                    
                    //Finished the circular bitmap, move to the linear bitmap
                    // reset gap filled var
                    gap_filled = 0;
                    
                    // if(tail != 32'hFFFFFFFF && head > tail) begin
                    if(next_tail != 32'hFFFFFFFF) begin
						// next_head = next_head + MTU;
					    //gap_filled = gap_filled + 1;
						if(next_head > next_tail) begin
							// next_head = next_head + MTU;
							// start with the linear bitmap
							next_head_bm_id = total_circular_bms;
							next_head_index = 0;
							
							j = 0;
							while(bitmap[next_head_bm_id][next_head_index] == 1 && j < max_iter_merge) begin
								j = j + 1;
								// add filled gap by 1
								gap_filled = gap_filled + 1;
								// remove the encountered value
								bitmap[next_head_bm_id][next_head_index] = 0;
								// Increment head_index
								next_head_index = next_head_index + 1;
								if (next_head_index == SIZE) begin
									// Reset the idx to the first
									next_head_index = 0;
									// proceed to next row
									next_head_bm_id = next_head_bm_id + 1;
									if (next_head_bm_id >= next_total_bitmaps) begin
										next_head_bm_id = 0;
									end
								end
							end
							// update head
							next_head = next_head + gap_filled * MTU;
							// next_head = next_head + MTU;
							if (next_circular_bm_size != next_dynamic_size) begin
								// next_head = next_head + MTU;
								next_merged = 1'b1;
							end
							// merge the linear bitmap to the circular one
							next_circular_bm_size = next_dynamic_size;
							// reset tail
							next_tail = -1;
						end
                    end
                    // TODO: last packet related logic
                end

                // If the packet was accepted (not rejected), set ooo_acc_signal
                if (next_ooo_noacc_signal == 1'b0) begin
                    next_ooo_acc_signal = 1'b1;
                end
                        
            end
            // Assign temporary variables back to the original state
			head_bm_id <= next_head_bm_id;
			head_index <= next_head_index;
            head <= next_head;
            tail <= next_tail;
            dynamic_size <= next_dynamic_size;
            last_seq <= next_last_seq;
            total_bitmaps <= next_total_bitmaps;
            circular_bm_size <= next_circular_bm_size;
            ooo_noacc_signal <= next_ooo_noacc_signal;
            ooo_acc_signal <= next_ooo_acc_signal;
            bitmap_extended <= next_bitmap_extended;
            linear_bitmap_used <= next_linear_bitmap_used;
            max_range <= next_max_range;
            added_size <= next_added_size;
            bitmap_used <= next_total_bitmaps;
            merged <= next_merged;
        end
    end

endmodule
