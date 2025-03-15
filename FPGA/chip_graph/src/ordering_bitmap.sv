`timescale 1ns / 1ps
module ordering_bitmap #(
    parameter SIZE = 16,
    parameter MTU = 1500,
    parameter MAX_BITMAPS = 8,
    parameter CONN_ID_WIDTH = 8,
    parameter NUM_MODULES = 4,        // Adjusted to match CONN_ID_WIDTH
    parameter NUM_BLOCKS = 16,
    parameter BLOCK_SIZE = 16,
	parameter MAX_ITERATIONS = 2000
    )
(
    input logic clk,                 // Clock signal
    input logic reset_n,             // Active-low reset signal
    input logic [31:0] seq,          // Packet sequence number - absolute
    input logic is_last,             // Flag to indicate if it's the last packet
    input logic [CONN_ID_WIDTH-1:0] conn_id, // New input conn_id
    output logic ooo_noacc_signal,   // Renamed from ooo_notification
    output logic ooo_acc_signal,     // New signal when packet fits in the bitmap
    output logic bitmap_extended,    // Signal to indicate a new bitmap has been added
    output logic merged,             // Signal to indicate a bitmap merge occurred
    output integer bitmap_used,      // Number of bitmaps used

    // Memory Controller Interface
    // For metadata read/write operations
    output logic                     meta_req,
    output logic                     meta_wr,
    output logic [$clog2(NUM_MODULES)-1:0] meta_module_id,
	output logic [$clog2(NUM_MODULES)-1:0] init_module_id,
    output logic [3:0]               meta_field_select,
    output logic [31:0]              meta_wdata,
    input logic [31:0]               meta_rdata,
    input logic                      meta_done,

    // For data read/write operations
	//output logic 					 init_req,
    output logic                     rw_req,
    output logic                     rw_wr,
	// signal for when the current packet is processed.
	input logic						 proc_pkt,
	output logic					 pkt_done,
	output logic					 conn_done,
    output logic [$clog2(NUM_MODULES)-1:0] rw_module_id,
    output logic [$clog2(NUM_BLOCKS)-1:0]  rw_block_number,
    output logic [$clog2(BLOCK_SIZE)-1:0]  rw_index, // Index within the block (bit addressing)
    output logic                      rw_wdata,
    input logic                       rw_rdata,
    input logic                       rw_done,
	//input logic						  init_done,

    // State indicator for debugging
    output logic [31:0] dbg_head,
    output logic [31:0] dbg_tail,
    output logic [31:0] dbg_last_seq,
    output logic [31:0] dbg_circular_bm_size,
    output logic [31:0] dbg_dynamic_size,
    output logic [31:0] dbg_total_bitmaps,
    output logic [31:0] dbg_added_size,
    output logic [31:0] dbg_linear_bitmap_used,
    output logic [31:0] dbg_max_range,
    output logic [31:0] dbg_head_bm_id,
    output logic [31:0] dbg_head_index,
    output logic [31:0] dbg_gap_filled,
    output logic [31:0] dbg_index_from_head,
    output logic [31:0] dbg_index_on_linear_bm,
    output logic [31:0] dbg_curr_bm_id,
    output logic [31:0] dbg_index_on_curr_bm,
    output logic [31:0] dbg_abs_idx,
    output logic [31:0] dbg_seq,
    output logic [5:0]  dbg_state
	
);

    // State machine states
    typedef enum logic [5:0] {				//State ID
        INIT,								//00
        INIT_WRITE_HEAD,					//01
        INIT_WRITE_HEAD_WAIT,				//02
        INIT_WRITE_TAIL,					//03
        INIT_WRITE_TAIL_WAIT,				//04
        INIT_WRITE_LAST_SEQ,				//05
        INIT_WRITE_LAST_SEQ_WAIT,			//06
        INIT_WRITE_HEAD_BM_ID,				//07
        INIT_WRITE_HEAD_BM_ID_WAIT,			//08
        INIT_WRITE_HEAD_INDEX,				//09
        INIT_WRITE_HEAD_INDEX_WAIT,			//0a
        INIT_WRITE_CIRCULAR_SIZE,			//0b
        INIT_WRITE_CIRCULAR_SIZE_WAIT,		//0c
        INIT_WRITE_DYNAMIC_SIZE,			//0d
        INIT_WRITE_DYNAMIC_SIZE_WAIT,		//0e
        IDLE,								//0f
        READ_META_HEAD,						//10
        READ_META_HEAD_WAIT,				//11
        READ_META_TAIL,						//12
        READ_META_TAIL_WAIT,				//13
        READ_META_LAST_SEQ,					//14
        READ_META_LAST_SEQ_WAIT,			//15
        READ_META_HEAD_BM_ID,				//16
        READ_META_HEAD_BM_ID_WAIT,			//17
        READ_META_HEAD_INDEX,				//18
        READ_META_HEAD_INDEX_WAIT,			//19
        READ_META_CIRCULAR_SIZE,			//1a
        READ_META_CIRCULAR_SIZE_WAIT,		//1b
        READ_META_DYNAMIC_SIZE,				//1c
        READ_META_DYNAMIC_SIZE_WAIT,		//1d
        PROCESS_PACKET_INIT,				//1e
        PROCESS_PACKET,						//1f
        PROCESS_PACKET_WAIT,				//20
        GAP_FILL_INIT,						//21
        GAP_FILL_READ,						//22
        GAP_FILL_READ_WAIT,					//23
        GAP_FILL_CHECK,						//24
        GAP_FILL_WRITE,						//25
        GAP_FILL_WRITE_WAIT,				//26
        WRITE_META_HEAD,					//27
        WRITE_META_HEAD_WAIT,				//28
        WRITE_META_TAIL,					//29
        WRITE_META_TAIL_WAIT,				//2a
        WRITE_META_LAST_SEQ,				//2b
        WRITE_META_LAST_SEQ_WAIT,			//2c
        WRITE_META_HEAD_BM_ID,				//2d
        WRITE_META_HEAD_BM_ID_WAIT,			//2e
        WRITE_META_HEAD_INDEX,				//2f
        WRITE_META_HEAD_INDEX_WAIT,			//30
        WRITE_META_CIRCULAR_SIZE,			//31
        WRITE_META_CIRCULAR_SIZE_WAIT,		//32
        WRITE_META_DYNAMIC_SIZE,			//33
        WRITE_META_DYNAMIC_SIZE_WAIT		//34
    } state_t;

    state_t state;

    // Variables to hold metadata
    logic [31:0] head;
    logic [31:0] tail;
    logic [31:0] last_seq;
    integer circular_bm_size;
    integer dynamic_size;
    integer total_bitmaps;
    integer added_size;
    integer linear_bitmap_used;
    integer max_range;
    integer head_bm_id;
    integer head_index;

    // Local variables
    integer linear_bm_id;
    integer linear_index;
    integer linear_bm_size;
    integer total_circular_bms;
    integer first_linear_idx;
    integer abs_idx;
    integer curr_bm_id;
    integer gap_filled;
    integer index_on_curr_bm;
    integer index_from_head;
    integer index_on_linear_bm;
    integer cnt;

    logic bitmap_bit;
    logic bitmap_bit_valid;
    logic bitmap_bit_write_done;

    // Module ID for memory controller
    logic [$clog2(NUM_MODULES)-1:0] module_id;

    // Constants for meta_field_select
    localparam META_HEAD          = 4'd0;
    localparam META_TAIL          = 4'd1;
    localparam META_LAST_SEQ      = 4'd2;
    localparam META_HEAD_BM_ID    = 4'd3;
    localparam META_HEAD_INDEX    = 4'd4;
    localparam META_CIRCULAR_SIZE = 4'd5;
    localparam META_DYNAMIC_SIZE  = 4'd6;

    // Assign module_id from conn_id
    assign module_id = conn_id[$clog2(NUM_MODULES)-1:0];
	assign rw_module_id = conn_id[$clog2(NUM_MODULES)-1:0];
	assign meta_module_id = conn_id[$clog2(NUM_MODULES)-1:0];
	assign init_module_id = conn_id[$clog2(NUM_MODULES)-1:0];
    // Assign internal variables to debug outputs
    assign dbg_head = head;
    assign dbg_tail = tail;
    assign dbg_last_seq = last_seq;
    assign dbg_circular_bm_size = circular_bm_size;
    assign dbg_dynamic_size = dynamic_size;
    assign dbg_total_bitmaps = total_bitmaps;
    assign dbg_added_size = added_size;
    assign dbg_linear_bitmap_used = linear_bitmap_used;
    assign dbg_max_range = max_range;
    assign dbg_head_bm_id = head_bm_id;
    assign dbg_head_index = head_index;
    assign dbg_gap_filled = gap_filled;
    assign dbg_index_from_head = index_from_head;
    assign dbg_index_on_linear_bm = index_on_linear_bm;
    assign dbg_curr_bm_id = curr_bm_id;
    assign dbg_index_on_curr_bm = index_on_curr_bm;
    assign dbg_abs_idx = abs_idx;
    assign dbg_seq = seq;
    assign dbg_state = state;

	//assign circular_bm_size = circular_bm_size_output;

    // Sequential logic for state machine
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset all state variables
            state <= INIT;
            // Outputs
            ooo_noacc_signal <= 1'b0;
            ooo_acc_signal <= 1'b0;
            bitmap_extended <= 1'b0;
            merged <= 1'b0;
            bitmap_used <= 0;
			pkt_done <= 1'b0;
			conn_done <= 1'b0;
            // Internal variables
            head <= 32'd0;
            tail <= -1;
            dynamic_size <= SIZE;         // Initialize only circular bitmap
            last_seq <= -1;
            total_bitmaps <= 1;           // Start with 1 bitmap (circular)
            circular_bm_size <= SIZE;
            linear_bitmap_used <= 0;
            max_range <= SIZE * MAX_BITMAPS;
            added_size <= 0;
            head_bm_id <= 0;
            head_index <= 0;
            // Memory controller interface signals
            meta_req <= 1'b0;
            meta_wr <= 1'b0;
            meta_field_select <= 4'd0;
            meta_wdata <= 32'd0;
            rw_req <= 1'b0;
			//init_req <= 1'b0;
            rw_wr <= 1'b0;
            rw_block_number <= 0;
            rw_index <= 0;
            rw_wdata <= 1'b0;
            bitmap_bit_valid <= 1'b0;
            bitmap_bit_write_done <= 1'b0;
            cnt <= 0;
        end else begin
            // Default assignments
            meta_req <= 1'b0;
            rw_req <= 1'b0;
			pkt_done <= 1'b0;
			//init_req <= 1b'0;
			conn_done = 1'b0;
            // Outputs
            ooo_noacc_signal <= 1'b0;
            ooo_acc_signal <= 1'b0;
            bitmap_extended <= 1'b0;
            merged <= 1'b0;
            bitmap_used <= total_bitmaps;
			conn_done <= 1'b0;
			
            case (state)
				INIT: begin
                    // Begin initialization
                    state <= INIT_WRITE_HEAD;
                end
                INIT_WRITE_HEAD: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b1;
                    meta_field_select <= META_HEAD;
                    meta_wdata <= head;
                    state <= INIT_WRITE_HEAD_WAIT;
                end
                INIT_WRITE_HEAD_WAIT: begin
                    if (meta_done) begin
                        state <= INIT_WRITE_TAIL;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                INIT_WRITE_TAIL: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b1;
                    meta_field_select <= META_TAIL;
                    meta_wdata <= tail;
                    state <= INIT_WRITE_TAIL_WAIT;
                end
                INIT_WRITE_TAIL_WAIT: begin
                    if (meta_done) begin
                        state <= INIT_WRITE_LAST_SEQ;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                INIT_WRITE_LAST_SEQ: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b1;
                    meta_field_select <= META_LAST_SEQ;
                    meta_wdata <= last_seq;
                    state <= INIT_WRITE_LAST_SEQ_WAIT;
                end
                INIT_WRITE_LAST_SEQ_WAIT: begin
                    if (meta_done) begin
                        state <= INIT_WRITE_HEAD_BM_ID;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                INIT_WRITE_HEAD_BM_ID: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b1;
                    meta_field_select <= META_HEAD_BM_ID;
                    meta_wdata <= head_bm_id;
                    state <= INIT_WRITE_HEAD_BM_ID_WAIT;
                end
                INIT_WRITE_HEAD_BM_ID_WAIT: begin
                    if (meta_done) begin
                        state <= INIT_WRITE_HEAD_INDEX;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                INIT_WRITE_HEAD_INDEX: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b1;
                    meta_field_select <= META_HEAD_INDEX;
                    meta_wdata <= head_index;
                    state <= INIT_WRITE_HEAD_INDEX_WAIT;
                end
                INIT_WRITE_HEAD_INDEX_WAIT: begin
                    if (meta_done) begin
                        state <= INIT_WRITE_CIRCULAR_SIZE;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                INIT_WRITE_CIRCULAR_SIZE: begin
					meta_field_select <= META_CIRCULAR_SIZE;
                    meta_wdata <= circular_bm_size;
                    meta_req <= 1'b1;
                    meta_wr <= 1'b1;
                    state <= INIT_WRITE_CIRCULAR_SIZE_WAIT;
                end
                INIT_WRITE_CIRCULAR_SIZE_WAIT: begin
                    if (meta_done) begin
                        state <= INIT_WRITE_DYNAMIC_SIZE;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                INIT_WRITE_DYNAMIC_SIZE: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b1;
                    meta_field_select <= META_DYNAMIC_SIZE;
                    meta_wdata <= dynamic_size;
                    state <= INIT_WRITE_DYNAMIC_SIZE_WAIT;
                end
                INIT_WRITE_DYNAMIC_SIZE_WAIT: begin
                    if (meta_done) begin
                        state <= IDLE;
						meta_wr <= 1'b0;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                IDLE: begin
                    // Wait for a new packet (seq input)
					if (proc_pkt == 1'd1) begin
						if (seq != 32'd0) begin  // check can be changed later
							state <= READ_META_HEAD;
						end
					end
                end
                READ_META_HEAD: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b0;
                    meta_field_select <= META_HEAD;
                    state <= READ_META_HEAD_WAIT;
                end
                READ_META_HEAD_WAIT: begin
                    if (meta_done) begin
                        head <= meta_rdata;
                        state <= READ_META_TAIL;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                READ_META_TAIL: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b0;
                    meta_field_select <= META_TAIL;
                    state <= READ_META_TAIL_WAIT;
                end
                READ_META_TAIL_WAIT: begin
                    if (meta_done) begin
                        tail <= meta_rdata;
                        state <= READ_META_LAST_SEQ;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                READ_META_LAST_SEQ: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b0;
                    meta_field_select <= META_LAST_SEQ;
                    state <= READ_META_LAST_SEQ_WAIT;
                end
                READ_META_LAST_SEQ_WAIT: begin
                    if (meta_done) begin
                        last_seq <= meta_rdata;
                        state <= READ_META_HEAD_BM_ID;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                READ_META_HEAD_BM_ID: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b0;
                    meta_field_select <= META_HEAD_BM_ID;
                    state <= READ_META_HEAD_BM_ID_WAIT;
                end
                READ_META_HEAD_BM_ID_WAIT: begin
                    if (meta_done) begin
                        head_bm_id <= meta_rdata;
                        state <= READ_META_HEAD_INDEX;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                READ_META_HEAD_INDEX: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b0;
                    meta_field_select <= META_HEAD_INDEX;
                    state <= READ_META_HEAD_INDEX_WAIT;
                end
                READ_META_HEAD_INDEX_WAIT: begin
                    if (meta_done) begin
                        head_index <= meta_rdata;
                        state <= READ_META_CIRCULAR_SIZE;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                READ_META_CIRCULAR_SIZE: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b0;
                    meta_field_select <= META_CIRCULAR_SIZE;
                    state <= READ_META_CIRCULAR_SIZE_WAIT;
                end
                READ_META_CIRCULAR_SIZE_WAIT: begin
                    if (meta_done) begin
                        circular_bm_size <= meta_rdata;
                        state <= READ_META_DYNAMIC_SIZE;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                READ_META_DYNAMIC_SIZE: begin
                    meta_req <= 1'b1;
                    meta_wr <= 1'b0;
                    meta_field_select <= META_DYNAMIC_SIZE;
                    state <= READ_META_DYNAMIC_SIZE_WAIT;
                end
                READ_META_DYNAMIC_SIZE_WAIT: begin
                    if (meta_done) begin
                        dynamic_size <= meta_rdata;
                        state <= PROCESS_PACKET_INIT;
                    end else begin
                        meta_req <= 1'b0;
                    end
                end
                PROCESS_PACKET_INIT: begin
                    // Initialize variables for processing
                    total_circular_bms = circular_bm_size / SIZE;
                    max_range = SIZE * MAX_BITMAPS;
                    linear_bitmap_used = total_bitmaps - total_circular_bms;
                    gap_filled = 0;
                    added_size = 0;
                    state <= PROCESS_PACKET;
                end
                PROCESS_PACKET: begin
					if (is_last) begin
						last_seq = seq;
					end
					
                    if (seq >= head) begin
                        index_from_head = (seq - head) / MTU;
                        if (index_from_head >= dynamic_size || seq > tail) begin
                            // Packet outside current bitmap range
                            linear_bm_size = dynamic_size - circular_bm_size;
                            if (linear_bm_size == 0) begin // the first bm is created during init, keep this code to align with original c codes.
                                // Create first linear bitmap and set tail
                                tail = head + ((circular_bm_size - 1) * MTU);
                            end
                            index_on_linear_bm = ((seq - tail) / MTU) - 1;
							// not able to accomodate this packet
                            if ((circular_bm_size + index_on_linear_bm) >= max_range) begin
                                if (circular_bm_size == dynamic_size) begin
                                    tail <= -1;
                                end
                                ooo_noacc_signal <= 1'b1;
                                state <= WRITE_META_HEAD; // Proceed to write back metadata
                            end else begin
                                // Need additional linear bitmaps
								cnt <= 0;
								for (int i = 0; i < MAX_ITERATIONS; i++) begin
									if (index_on_linear_bm < linear_bm_size) begin
										break;
									end
									// Add bitmap (update metadata)
									total_bitmaps <= total_bitmaps + 1;
									dynamic_size <= dynamic_size + SIZE;
									added_size <= added_size + SIZE;
									bitmap_extended <= 1'b1;
									linear_bm_size = linear_bm_size + SIZE;
									cnt <= cnt + 1;
								end
								cnt <= 0;
                                // Compute indices for bitmap access
                                first_linear_idx = total_circular_bms * SIZE;
                                abs_idx = first_linear_idx + index_on_linear_bm;
                                curr_bm_id = abs_idx / SIZE;
                                index_on_curr_bm = index_on_linear_bm % SIZE;

                                // Access bitmap bit via memory controller
                                rw_req <= 1'b1;
                                rw_wr <= 1'b1;
                                rw_block_number <= curr_bm_id;
                                rw_index <= index_on_curr_bm;
                                rw_wdata <= 1'b1;
                                state <= PROCESS_PACKET_WAIT;
                            end
                        end else begin
                            // Packet can be accommodated in circular bitmap
                            abs_idx = (head_bm_id * SIZE) + head_index + index_from_head;
                            if (abs_idx >= circular_bm_size) begin
                                abs_idx = abs_idx - circular_bm_size;
                            end
                            curr_bm_id = abs_idx / SIZE;
                            if (curr_bm_id >= total_circular_bms) begin
                                curr_bm_id = curr_bm_id - total_circular_bms;
                            end
                            index_on_curr_bm = abs_idx % SIZE;

                            // Access bitmap bit via memory controller
                            rw_req <= 1'b1;
                            rw_wr <= 1'b1;
                            rw_block_number <= curr_bm_id;
                            rw_index <= index_on_curr_bm;
                            rw_wdata <= 1'b1;
                            state <= PROCESS_PACKET_WAIT;
                        end
                    end else begin
                        // Packet is out of order and cannot be accommodated
                        ooo_noacc_signal <= 1'b1;
                        state <= WRITE_META_HEAD; // Proceed to write back metadata
                    end
                end
                PROCESS_PACKET_WAIT: begin
                    if (rw_done) begin
                        ooo_acc_signal <= 1'b1;
                        // Now check if gaps can be filled
                        if (seq == head) begin
                            // Move forward on circular bitmap
                            gap_filled = 0;
                            state <= GAP_FILL_INIT;
                        end else begin
                            // Proceed to write back metadata
                            state <= WRITE_META_HEAD;
                        end
                    end else begin
                        rw_req <= 1'b0;
                    end
                end
                GAP_FILL_INIT: begin
                    cnt <= 0;
                    state <= GAP_FILL_READ;
                end
                GAP_FILL_READ: begin
                    // Read bitmap bit
                    rw_req <= 1'b1;
                    rw_wr <= 1'b0;
                    rw_block_number <= head_bm_id;
                    rw_index <= head_index;
                    state <= GAP_FILL_READ_WAIT;
                end
                GAP_FILL_READ_WAIT: begin
                    if (rw_done) begin
                        bitmap_bit <= rw_rdata;
                        state <= GAP_FILL_CHECK;
                    end else begin
                        rw_req <= 1'b0;
                    end
                end
                GAP_FILL_CHECK: begin
                    if (bitmap_bit == 1'b1 && cnt < 2000) begin
                        // Clear the bit
                        rw_req <= 1'b1;
                        rw_wr <= 1'b1;
                        rw_block_number <= head_bm_id;
                        rw_index <= head_index;
                        rw_wdata <= 1'b0;
                        state <= GAP_FILL_WRITE_WAIT;
                    end else begin
                        // Exit gap filling
                        head <= head + (gap_filled * MTU);
                        // Check if tail needs to be reset
                        if (tail != -1 && head > tail) begin
                            // Merge linear bitmap into circular
                            circular_bm_size <= dynamic_size;
                            tail <= -1;
                            merged <= 1'b1;
                        end
						// Gap fill complete, signal finish and clear memory (mem clear done in pkt driver)
						conn_done = 1'b1;
                        state <= WRITE_META_HEAD;
                    end
                end
                GAP_FILL_WRITE_WAIT: begin
                    if (rw_done) begin
                        // Move to next index
                        gap_filled <= gap_filled + 1;
                        cnt <= cnt + 1;
                        head_index <= head_index + 1;
                        if (head_index == SIZE) begin
                            head_index <= 0;
                            head_bm_id <= head_bm_id + 1;
                            if (head_bm_id == total_circular_bms) begin
                                head_bm_id <= 0;
                            end
                        end
                        // Continue gap filling
                        state <= GAP_FILL_READ;
                    end else begin
                        rw_req <= 1'b0;
                    end
                end
                // Write back metadata states.
                WRITE_META_HEAD: begin
					meta_req <= 1'b1;
					meta_wr <= 1'b1;
					meta_field_select <= META_HEAD;
					meta_wdata <= head;
					state <= WRITE_META_HEAD_WAIT;
				end
				WRITE_META_HEAD_WAIT: begin
					if (meta_done) begin
						state <= WRITE_META_TAIL;
					end else begin
						meta_req <= 1'b0;
					end
				end
				WRITE_META_TAIL: begin
					meta_req <= 1'b1;
					meta_wr <= 1'b1;
					meta_field_select <= META_TAIL;
					meta_wdata <= tail;
					state <= WRITE_META_TAIL_WAIT;
				end
				WRITE_META_TAIL_WAIT: begin
					if (meta_done) begin
						state <= WRITE_META_LAST_SEQ;
					end else begin
						meta_req <= 1'b0;
					end
				end
				WRITE_META_LAST_SEQ: begin
					meta_req <= 1'b1;
					meta_wr <= 1'b1;
					meta_field_select <= META_LAST_SEQ;
					meta_wdata <= last_seq;
					state <= WRITE_META_LAST_SEQ_WAIT;
				end
				WRITE_META_LAST_SEQ_WAIT: begin
					if (meta_done) begin
						state <= WRITE_META_HEAD_BM_ID;
					end else begin
						meta_req <= 1'b0;
					end
				end
				WRITE_META_HEAD_BM_ID: begin
					meta_req <= 1'b1;
					meta_wr <= 1'b1;
					meta_field_select <= META_HEAD_BM_ID;
					meta_wdata <= head_bm_id;
					state <= WRITE_META_HEAD_BM_ID_WAIT;
				end
				WRITE_META_HEAD_BM_ID_WAIT: begin
					if (meta_done) begin
						state <= WRITE_META_HEAD_INDEX;
					end else begin
						meta_req <= 1'b0;
					end
				end
				WRITE_META_HEAD_INDEX: begin
					meta_req <= 1'b1;
					meta_wr <= 1'b1;
					meta_field_select <= META_HEAD_INDEX;
					meta_wdata <= head_index;
					state <= WRITE_META_HEAD_INDEX_WAIT;
				end
				WRITE_META_HEAD_INDEX_WAIT: begin
					if (meta_done) begin
						state <= WRITE_META_CIRCULAR_SIZE;
					end else begin
						meta_req <= 1'b0;
					end
				end
				WRITE_META_CIRCULAR_SIZE: begin
					meta_req <= 1'b1;
					meta_wr <= 1'b1;
					meta_field_select <= META_CIRCULAR_SIZE;
					meta_wdata <= circular_bm_size;
					state <= WRITE_META_CIRCULAR_SIZE_WAIT;
				end
				WRITE_META_CIRCULAR_SIZE_WAIT: begin
					if (meta_done) begin
						state <= WRITE_META_DYNAMIC_SIZE;
					end else begin
						meta_req <= 1'b0;
					end
				end
				WRITE_META_DYNAMIC_SIZE: begin
					meta_req <= 1'b1;
					meta_wr <= 1'b1;
					meta_field_select <= META_DYNAMIC_SIZE;
					meta_wdata <= dynamic_size;
					state <= WRITE_META_DYNAMIC_SIZE_WAIT;
				end
				WRITE_META_DYNAMIC_SIZE_WAIT: begin
					if (meta_done) begin
						pkt_done <= 1'b1;
						meta_wr <= 1'b0;
						state <= IDLE; 
					end else begin
						meta_req <= 1'b0;
					end
				end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
