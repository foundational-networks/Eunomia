module packet_driver #(
    parameter MAX_CONN = 4,  // Maximum number of supported connections
    parameter MTU = 1500
)(
    input  wire         clk,
    input  wire         reset_n,
    input  wire [31:0]  seq,
    input  wire         is_last,
    input  wire [1:0]   conn_id,
    input  wire         conn_done,
    output reg          ooo_old_signal,
    output reg          inorder_acc_signal,
    // Outputs from ordering_bitmap
    output wire         ooo_noacc_signal,
    output wire         ooo_acc_signal,
    output wire         bitmap_extended,
    output wire         merged,
    output wire [31:0]  bitmap_used,
    // Memory Controller Interface Signals
    output wire         meta_req,
    output wire         meta_wr,
    output wire [1:0]   meta_module_id,
    output wire [3:0]   meta_field_select,
    output wire [31:0]  meta_wdata,
    //input  wire [31:0]  meta_rdata,
    //input  wire         meta_done,
    // Other Memory Controller Interface Signals
    output wire         rw_req,
    output wire         rw_wr,
    output wire [3:0]   rw_block_number,
    output wire [3:0]   rw_index,
    output wire         rw_wdata,  // Width adjusted to 1 bit (Change made here)
    //input  wire         rw_rdata,  // Width adjusted to 1 bit (Change made here)
    //input  wire         rw_done,
    output wire         pkt_done,     // packet done by bitmap module: acc or noacc ooo packet
	output reg         pkt_done_d,   // packet done by packet driver: inorder & old
	input wire 		proc_pkt,
    output wire [31:0]  total_bitmaps,
    output wire [31:0]  total_blocks,
    // Debug Outputs
    // output wire [31:0]  dbg_head,
    // output wire [31:0]  dbg_tail,
    // output wire [31:0]  dbg_last_seq,
    // output wire [31:0]  dbg_circular_bm_size,
    // output wire [31:0]  dbg_dynamic_size,
    // output wire [31:0]  dbg_total_bitmaps,
    // output wire [31:0]  dbg_added_size,
    // output wire [31:0]  dbg_linear_bitmap_used,
    // output wire [31:0]  dbg_max_range,
    // output wire [31:0]  dbg_head_bm_id,
    // output wire [31:0]  dbg_head_index,
    // output wire [31:0]  dbg_gap_filled,
    // output wire [31:0]  dbg_index_from_head,
    // output wire [31:0]  dbg_index_on_linear_bm,
    // output wire [31:0]  dbg_curr_bm_id,
    // output wire [31:0]  dbg_index_on_curr_bm,
    // output wire [31:0]  dbg_abs_idx,
    // output wire [31:0]  dbg_seq,
    // output wire [5:0]   dbg_state,
	output reg init_req,
	output reg init_done
);

    // Internal Metadata Arrays
    reg [31:0] next_expected_seq [0:MAX_CONN-1]; // Next expected sequence number per connection
    reg        indicator         [0:MAX_CONN-1]; // Indicator per connection

    // Previous Packet Tracking for Edge Detection
    reg [31:0] prev_seq;
    reg [1:0]  prev_conn_id;
    reg        packet_arrived;

    // Internal Signals for Ordering Bitmap and Memory Controller
    reg [31:0] ob_seq;
    reg        ob_is_last;
    reg [1:0]  ob_conn_id;
    reg        ob_conn_done;

    reg        init_req;
    reg [1:0]  init_module_id;
    reg [31:0] init_head;
    reg [31:0] init_tail;
    reg [31:0] init_last;
    reg [7:0]  init_head_bm_id;
    reg [7:0]  init_head_bm_index;
    reg [7:0]  init_circular_size;
    reg [7:0]  init_dynamic_size;
    wire       init_done;

    reg        reset_module_req;
    reg [7:0]  reset_module_id;
    wire       reset_module_done;

    reg [1:0]  rw_module_id;

    integer i;

    // New variable to store module ID for current packet
    reg [1:0] assign_module_id;  // Changes made here

    // Array to map conn_id to module_id
    reg [1:0] conn_to_module_map [0:MAX_CONN-1];  // Changes made here

    // Valid bits for conn_to_module_map
    reg conn_module_valid [0:MAX_CONN-1];  // Changes made here

    // Array to track which modules are in use
    parameter N_MODULES = 2;  // Number of modules (could be hard coded for now) (Changes made here)
    reg module_in_use [0:N_MODULES-1];  // Changes made here

    // Instantiate ordering_bitmap module
    ordering_bitmap ob_inst (
        .clk(clk),
        .reset_n(reset_n),
        .seq(ob_seq),
        .is_last(ob_is_last),
        .conn_id(ob_conn_id),
        .ooo_noacc_signal(ooo_noacc_signal),
        .ooo_acc_signal(ooo_acc_signal),
        .bitmap_extended(bitmap_extended),
        .merged(merged),
        .bitmap_used(bitmap_used),
        .meta_req(meta_req),
        .meta_wr(meta_wr),
        .meta_module_id(meta_module_id),
        .init_module_id(init_module_id),
        .meta_field_select(meta_field_select),
        .meta_wdata(meta_wdata),
        .meta_rdata(meta_rdata),
        .meta_done(meta_done),
        .rw_req(rw_req),
        .rw_wr(rw_wr),
        .rw_block_number(rw_block_number),
        .rw_module_id(rw_module_id),
        .rw_index(rw_index),
        .rw_wdata(rw_wdata),  // Width adjusted to 1 bit (Changes made here)
        .rw_rdata(rw_rdata),  // Width adjusted to 1 bit (Changes made here)
        .rw_done(rw_done),
        .pkt_done(pkt_done),
		.proc_pkt(proc_pkt),
        .conn_done(ob_conn_done)
        // .dbg_head(dbg_head),
        // .dbg_tail(dbg_tail),
        // .dbg_last_seq(dbg_last_seq),
        // .dbg_circular_bm_size(dbg_circular_bm_size),
        // .dbg_dynamic_size(dbg_dynamic_size),
        // .dbg_total_bitmaps(dbg_total_bitmaps),
        // .dbg_added_size(dbg_added_size),
        // .dbg_linear_bitmap_used(dbg_linear_bitmap_used),
        // .dbg_max_range(dbg_max_range),
        // .dbg_head_bm_id(dbg_head_bm_id),
        // .dbg_head_index(dbg_head_index),
        // .dbg_gap_filled(dbg_gap_filled),
        // .dbg_index_from_head(dbg_index_from_head),
        // .dbg_index_on_linear_bm(dbg_index_on_linear_bm),
        // .dbg_curr_bm_id(dbg_curr_bm_id),
        // .dbg_index_on_curr_bm(dbg_index_on_curr_bm),
        // .dbg_abs_idx(dbg_abs_idx),
        // .dbg_seq(dbg_seq),
        // .dbg_state(dbg_state)
    );

    // Instantiate memory_controller module
    memory_controller mc_inst (
        .clk(clk),
        .rst_n(reset_n),
        // Interface for module initialization
        .init_req(init_req),
        .init_module_id(init_module_id),
        .init_head(init_head),
        .init_tail(init_tail),
        .init_last(init_last),
        .init_head_bm_id(init_head_bm_id),
        .init_head_bm_index(init_head_bm_index),
        .init_circular_size(init_circular_size),
        .init_dynamic_size(init_dynamic_size),
        .init_done(init_done),
        // Interface for metadata read/write operations
        .meta_req(meta_req),
        .meta_wr(meta_wr),
        .meta_module_id(meta_module_id),
        .meta_field_select(meta_field_select),
        .meta_wdata(meta_wdata),
        .meta_rdata(meta_rdata),
        .meta_done(meta_done),
        // Interface for module reset
        .reset_module_req(reset_module_req),
        .reset_module_id(reset_module_id),
        .reset_module_done(reset_module_done),
        // Interface for read/write operations
        .rw_req(rw_req),
        .rw_wr(rw_wr),
        .rw_module_id(rw_module_id),
        .rw_block_number(rw_block_number),
        .rw_index(rw_index),
        .rw_wdata(rw_wdata),
        .rw_rdata(rw_rdata),
        .rw_done(rw_done),
        // Interface for performance measurement
        .total_bitmaps(total_bitmaps),
        .total_blocks(total_blocks)
    );

    // Main Logic
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Asynchronous Reset
            for (i = 0; i < MAX_CONN; i = i + 1) begin
                next_expected_seq[i] <= 32'd0;
                indicator[i]         <= 1'b0;
            end
            prev_seq         <= 32'd0;
            prev_conn_id     <= 2'd0;
            packet_arrived   <= 1'b0;
            init_req         <= 1'b0;
            reset_module_req <= 1'b0;
            ob_seq           <= 32'd0;
            ob_is_last       <= 1'b0;
            ob_conn_id       <= 2'd0;
            ooo_old_signal   <= 1'b0;
            inorder_acc_signal <= 1'b0;
			pkt_done_d		 <= 1'b0;

            // Initialize new variables
            assign_module_id <= 2'd0;  // Changes made here
            for (i = 0; i < MAX_CONN; i = i + 1) begin
                conn_to_module_map[i] <= 2'd0;  // Changes made here
                conn_module_valid[i]  <= 1'b0;  // Changes made here
            end
            for (i = 0; i < N_MODULES; i = i + 1) begin
                module_in_use[i] <= 1'b0;  // Changes made here
            end
        end else begin
            // Edge Detection for New Packet Arrival
            if ((seq != prev_seq) || (conn_id != prev_conn_id)) begin
                packet_arrived <= 1'b1;
                prev_seq       <= seq;
                prev_conn_id   <= conn_id;
            end else begin
                packet_arrived <= 1'b0;
				pkt_done_d     <= 1'b0;
            end

            // Handle Connection Completion
            if (conn_done) begin
                reset_module_req       <= 1'b1;
                reset_module_id        <= conn_id;
                next_expected_seq[conn_id] <= 32'd0;
                indicator[conn_id]         <= 1'b0;

                // Release module assigned to this conn_id
                if (conn_module_valid[conn_id]) begin
                    module_in_use[conn_to_module_map[conn_id]] <= 1'b0;  // Changes made here
                    conn_module_valid[conn_id] <= 1'b0;  // Changes made here
                end
            end else begin
                reset_module_req <= 1'b0;
            end

            // Packet Processing Logic
            if (packet_arrived) begin
                // Fetch Metadata for Current Connection
                if (seq < next_expected_seq[conn_id]) begin
                    // Packet is older than expected; ignore and signal ooo_old_signal
                    ooo_old_signal     <= 1'b1;
                    inorder_acc_signal <= 1'b0;
                    init_req           <= 1'b0;
					pkt_done_d		   <= 1'b1;
                end else if (seq == next_expected_seq[conn_id] && !indicator[conn_id]) begin
                    // In-order packet; accept and update next expected sequence number
                    next_expected_seq[conn_id] <= next_expected_seq[conn_id] + MTU;
                    ooo_old_signal     <= 1'b0;
                    inorder_acc_signal <= 1'b1;
                    init_req           <= 1'b0;
					pkt_done_d		   <= 1'b1;
                end else begin
                    // Out-of-order packet; invoke ordering_bitmap module

                    // Assign module_id for the current packet
                    if (conn_module_valid[conn_id]) begin
                        // Module already assigned to this connection
                        assign_module_id <= conn_to_module_map[conn_id];  // Changes made here
                    end else begin
                        // Need to assign a new module to this connection
                        // Find next available module
                        if (!module_in_use[0]) begin
                            module_in_use[0] <= 1'b1;
                            conn_to_module_map[conn_id] <= 2'd0;
                            conn_module_valid[conn_id] <= 1'b1;
                            assign_module_id <= 2'd0;
							indicator[conn_id] <= 1'b1;
							// Initialize ordering_bitmap module
							init_req           <= 1'b1;
							init_head          <= next_expected_seq[conn_id] - MTU;
							init_tail          <= -1;
							init_last          <= -1;
							init_head_bm_id    <= 8'd0;
							init_head_bm_index <= 8'd0;
							init_circular_size <= 8'd16; // Configurable
							init_dynamic_size  <= 8'd16;
							
                        end else if (!module_in_use[1]) begin
                            module_in_use[1] <= 1'b1;
                            conn_to_module_map[conn_id] <= 2'd1;
                            conn_module_valid[conn_id] <= 1'b1;
                            assign_module_id <= 2'd1;
                        end else begin
                            // No module available
                            assign_module_id <= 2'd3;  // Invalid module_id (Changes made here)
                        end
                    end

                    // if (seq > next_expected_seq[conn_id]) begin
                        // indicator[conn_id] <= 1'b1;
                        // //Initialize ordering_bitmap module
                        // init_req           <= 1'b1;
                        // init_head          <= next_expected_seq[conn_id] - MTU;
                        // init_tail          <= -1;
                        // init_last          <= -1;
                        // init_head_bm_id    <= 8'd0;
                        // init_head_bm_index <= 8'd0;
                        // init_circular_size <= 8'd16; // Configurable
                        // init_dynamic_size  <= 8'd16;
                    // end else begin
                        // init_req <= 1'b0;
                    // end

                    // Wrap existing logic into if blocks based on module_id
                    if (assign_module_id == 2'd0) begin
                        // Pass packet to ordering_bitmap module with module_id == 0
                        ob_seq           <= seq;       // Changes made here
                        ob_is_last       <= is_last;   // Changes made here
                        ob_conn_id       <= conn_id;   // Changes made here
                        //ob_conn_done     <= conn_done; // Changes made here
                        // Include module_id if necessary
                    end else if (assign_module_id == 2'd1) begin
                        // Placeholders for future use (module_id == 1)
                        // Changes made here
                        // For now, do nothing or include placeholder code
                    end else begin
                        // No valid module assigned
                        // Handle error
                        // Changes made here
                    end

                    ooo_old_signal     <= 1'b0;
                    inorder_acc_signal <= 1'b0;
                end
            end else begin
                // No new packet; clear control signals
                ooo_old_signal     <= 1'b0;
                inorder_acc_signal <= 1'b0;
                init_req           <= 1'b0;
                ob_is_last         <= 1'b0;
            end
        end
    end

endmodule
