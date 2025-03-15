`timescale 1ns / 1ps
module memory_controller #(
  parameter MASTER_ARRAY_SIZE = 128,   // Number of blocks in the master array
  parameter BLOCK_SIZE        = 16,     // Size of each block in bits
  parameter NUM_MODULES       = 4,      // Number of modules that can access the memory controller
  parameter NUM_BLOCKS        = 16      // Maximum number of bitmap blocks per module
)(
  input                         clk,
  input                         rst_n,

  // Interface for module initialization
  input                         init_req,
  input       [$clog2(NUM_MODULES)-1:0] init_module_id,
  input       [31:0]            init_head,
  input       [31:0]            init_tail,
  input       [31:0]            init_last,
  input       [7:0]             init_head_bm_id,
  input       [7:0]             init_head_bm_index,
  input       [7:0]             init_circular_size,
  input       [7:0]             init_dynamic_size,
  output reg                    init_done,

  // Interface for metadata read/write operations
  input                         meta_req,
  input                         meta_wr, // 1: write, 0: read
  input       [$clog2(NUM_MODULES)-1:0] meta_module_id,
  input       [3:0]             meta_field_select, // Select which field to read/write
  input       [31:0]            meta_wdata, // Data to write
  output reg  [31:0]            meta_rdata, // Data read
  output reg                    meta_done,

  // Interface for module reset
  input                         reset_module_req,
  input       [$clog2(NUM_MODULES)-1:0] reset_module_id,
  output reg                    reset_module_done,

  // Interface for read/write operations
  input                         rw_req,
  input                         rw_wr, // 1: write, 0: read
  input       [$clog2(NUM_MODULES)-1:0] rw_module_id,
  input       [$clog2(NUM_BLOCKS)-1:0]  rw_block_number,
  input       [$clog2(BLOCK_SIZE)-1:0]  rw_index, // Index within the block (bit addressing)
  input                         rw_wdata, // Data to write
  output reg                    rw_rdata, // Data read
  output reg                    rw_done,

  // Interface for performance measurement
  output reg [31:0]             total_bitmaps,
  output reg [31:0]             total_blocks
);

  // Master array: 1024 blocks of 16 bits each
  reg [BLOCK_SIZE-1:0] master_array [0:MASTER_ARRAY_SIZE-1];

  // Block allocation bitmap
  reg [MASTER_ARRAY_SIZE-1:0] block_alloc_bitmap;

  // Invalid block index
  localparam [15:0] INVALID_BLOCK_INDEX = 16'hFFFF; // 16-bit invalid index

  // Array to store the starting index of metadata in master_array for each module
  reg [$clog2(MASTER_ARRAY_SIZE)-1:0] metadata_start_index [0:NUM_MODULES-1];

  // Constants for metadata offsets (in blocks)
  localparam METADATA_HEAD_OFFSET               = 0;   // blocks 0 and 1
  localparam METADATA_TAIL_OFFSET               = 2;   // blocks 2 and 3
  localparam METADATA_LAST_OFFSET               = 4;   // blocks 4 and 5
  localparam METADATA_HEAD_BM_OFFSET            = 6;   // block 6
  localparam METADATA_CIRCULAR_DYNAMIC_OFFSET   = 7;   // block 7
  localparam METADATA_BLOCK_INDICES_OFFSET      = 8;   // starting at block 8, one block per bitmap block index

  localparam METADATA_BLOCKS_PER_MODULE         = 8 + NUM_BLOCKS; // Total metadata blocks per module

  // Metadata field selectors
  localparam META_HEAD          = 4'd0;
  localparam META_TAIL          = 4'd1;
  localparam META_LAST          = 4'd2;
  localparam META_HEAD_BM_ID    = 4'd3;
  localparam META_HEAD_BM_INDEX = 4'd4;
  localparam META_CIRCULAR_SIZE = 4'd5;
  localparam META_DYNAMIC_SIZE  = 4'd6;

  // Integer variables for loops
  integer i, j;

  // Function to find consecutive free blocks (searching backward from tail to head)
  function integer find_consecutive_free_blocks(input integer num_blocks, output integer start_index);
    integer i, count;
    begin
      find_consecutive_free_blocks = 0; // default to not found
      count = 0;
      for (i = MASTER_ARRAY_SIZE - 1; i >= 0; i = i - 1) begin
        if (block_alloc_bitmap[i] == 0) begin
          count = count + 1;
          if (count == num_blocks) begin
            start_index = i;
            find_consecutive_free_blocks = 1;
            return;
          end
        end else begin
          count = 0;
        end
      end
      // If not found
      start_index = 0;
    end
  endfunction

  // Function to find the first free block
  function integer find_first_free_block(output integer index);
    integer i;
    begin
      find_first_free_block = 0; // default to not found
      for (i = 0; i < MASTER_ARRAY_SIZE; i = i + 1) begin
        if (block_alloc_bitmap[i] == 0) begin
          index = i;
          find_first_free_block = 1;
          return;
        end
      end
      // If not found
      index = 0;
    end
  endfunction

  // Main logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset logic
      for (i = 0; i < MASTER_ARRAY_SIZE; i = i + 1) begin
        master_array[i] <= {BLOCK_SIZE{1'b0}};
        block_alloc_bitmap[i] <= 1'b0;
      end
      for (i = 0; i < NUM_MODULES; i = i + 1) begin
        metadata_start_index[i] <= 0;
      end
      init_done          <= 1'b0;
      rw_done            <= 1'b0;
      meta_done          <= 1'b0;
      reset_module_done  <= 1'b0;
      total_bitmaps      <= 0;
      total_blocks       <= 0;
    end else begin
      // Handle module initialization request
      if (init_req) begin
        integer found;
        integer start_idx;
        // Find consecutive free blocks for metadata (searching backward)
        found = find_consecutive_free_blocks(METADATA_BLOCKS_PER_MODULE, start_idx);
        if (found) begin
          integer bitmap_block_idx;
          // Allocate metadata blocks
          metadata_start_index[init_module_id] <= start_idx;
          // for (i = start_idx; i < start_idx + METADATA_BLOCKS_PER_MODULE; i = i + 1) begin
            // block_alloc_bitmap[i] <= 1'b1;
          // end
          for (i = 0; i < METADATA_BLOCKS_PER_MODULE; i = i + 1) begin
            block_alloc_bitmap[i + start_idx] <= 1'b1;
          end
          // Update total_blocks
          total_blocks = total_blocks + METADATA_BLOCKS_PER_MODULE;
          // Initialize metadata in master_array using start_idx
          write_metadata32_with_start_idx(start_idx, METADATA_HEAD_OFFSET, init_head);
          write_metadata32_with_start_idx(start_idx, METADATA_TAIL_OFFSET, init_tail);
          write_metadata32_with_start_idx(start_idx, METADATA_LAST_OFFSET, init_last);
          write_metadata8_pair_with_start_idx(start_idx, METADATA_HEAD_BM_OFFSET, init_head_bm_id, init_head_bm_index);
          write_metadata8_pair_with_start_idx(start_idx, METADATA_CIRCULAR_DYNAMIC_OFFSET, init_circular_size, init_dynamic_size);
          // Initialize block_indices to INVALID_BLOCK_INDEX
          for (i = 0; i < NUM_BLOCKS; i = i + 1) begin
            write_block_index_with_start_idx(start_idx, i, INVALID_BLOCK_INDEX);
          end
          // Allocate the first bitmap block
          found = find_first_free_block(bitmap_block_idx);
          if (found) begin
            block_alloc_bitmap[bitmap_block_idx] <= 1'b1;
            write_block_index_with_start_idx(start_idx, 0, bitmap_block_idx);
            total_bitmaps <= total_bitmaps + 1;
            total_blocks <= total_blocks + 1;
            init_done <= 1'b1;
          end else begin
            // Not enough space for bitmap block
            init_done <= 1'b0;
          end
        end else begin
          // Not enough space for metadata
          init_done <= 1'b0;
        end
      end else begin
        init_done <= 1'b0;
      end

      // Handle module reset request
      if (reset_module_req) begin
        integer start_idx;
        integer bitmap_decrement;
        integer blocks_decrement;
        bitmap_decrement = 0;
        blocks_decrement = 0;
        // Get metadata start index
        start_idx = metadata_start_index[reset_module_id];
        if (start_idx != 0 || block_alloc_bitmap[start_idx] == 1'b1) begin
          // Deallocate metadata blocks
          // for (i = start_idx; i < start_idx + METADATA_BLOCKS_PER_MODULE; i = i +1) begin
            // block_alloc_bitmap[i] <= 1'b0;
            // master_array[i] <= {BLOCK_SIZE{1'b0}};
            // blocks_decrement = blocks_decrement + 1;
          // end
          for (i = 0; i < METADATA_BLOCKS_PER_MODULE; i = i +1) begin
            block_alloc_bitmap[i + start_idx] <= 1'b0;
            master_array[i + start_idx] <= {BLOCK_SIZE{1'b0}};
            blocks_decrement = blocks_decrement + 1;
          end
          metadata_start_index[reset_module_id] <= 0;
          // Deallocate bitmap blocks
          for (i = 0; i < NUM_BLOCKS; i = i + 1) begin
            reg [15:0] block_idx;
            block_idx = read_block_index_with_start_idx(start_idx, i);
            if (block_idx != INVALID_BLOCK_INDEX) begin
              block_alloc_bitmap[block_idx] <= 1'b0;
              master_array[block_idx] <= {BLOCK_SIZE{1'b0}};
              bitmap_decrement = bitmap_decrement + 1;
              blocks_decrement = blocks_decrement + 1;
            end
          end
          // Update total_bitmaps and total_blocks
          total_bitmaps <= total_bitmaps - bitmap_decrement;
          total_blocks <= total_blocks - blocks_decrement;
          reset_module_done <= 1'b1;
        end else begin
          reset_module_done <= 1'b0;
        end
      end else begin
        reset_module_done <= 1'b0;
      end

      // Handle metadata read/write requests
      if (meta_req) begin
        if (meta_wr) begin
          // Write operation
          case (meta_field_select)
            META_HEAD:          write_metadata32(meta_module_id, METADATA_HEAD_OFFSET, meta_wdata);
            META_TAIL:          write_metadata32(meta_module_id, METADATA_TAIL_OFFSET, meta_wdata);
            META_LAST:          write_metadata32(meta_module_id, METADATA_LAST_OFFSET, meta_wdata);
            META_HEAD_BM_ID:    write_metadata8(meta_module_id, METADATA_HEAD_BM_OFFSET, 1, meta_wdata[7:0]);
            META_HEAD_BM_INDEX: write_metadata8(meta_module_id, METADATA_HEAD_BM_OFFSET, 0, meta_wdata[7:0]);
            META_CIRCULAR_SIZE: write_metadata8(meta_module_id, METADATA_CIRCULAR_DYNAMIC_OFFSET, 1, meta_wdata[7:0]);
            META_DYNAMIC_SIZE:  write_metadata8(meta_module_id, METADATA_CIRCULAR_DYNAMIC_OFFSET, 0, meta_wdata[7:0]);
            default: ; // Do nothing
          endcase
          meta_done <= 1'b1;
        end else begin
          // Read operation
          case (meta_field_select)
            META_HEAD:          meta_rdata <= read_metadata32(meta_module_id, METADATA_HEAD_OFFSET);
            META_TAIL:          meta_rdata <= read_metadata32(meta_module_id, METADATA_TAIL_OFFSET);
            META_LAST:          meta_rdata <= read_metadata32(meta_module_id, METADATA_LAST_OFFSET);
            META_HEAD_BM_ID:    meta_rdata <= {24'b0, read_metadata8(meta_module_id, METADATA_HEAD_BM_OFFSET, 1)};
            META_HEAD_BM_INDEX: meta_rdata <= {24'b0, read_metadata8(meta_module_id, METADATA_HEAD_BM_OFFSET, 0)};
            META_CIRCULAR_SIZE: meta_rdata <= {24'b0, read_metadata8(meta_module_id, METADATA_CIRCULAR_DYNAMIC_OFFSET, 1)};
            META_DYNAMIC_SIZE:  meta_rdata <= {24'b0, read_metadata8(meta_module_id, METADATA_CIRCULAR_DYNAMIC_OFFSET, 0)};
            default:            meta_rdata <= 32'b0;
          endcase
          meta_done <= 1'b1;
        end
      end else begin
        meta_done <= 1'b0;
      end

      // Handle read/write requests
      if (rw_req) begin
        reg [15:0] block_index;
        if (rw_module_id < NUM_MODULES && rw_block_number < NUM_BLOCKS) begin
          block_index = read_block_index(rw_module_id, rw_block_number);
          if (block_index != INVALID_BLOCK_INDEX) begin
            if (rw_wr) begin
              // Write operation
              master_array[block_index][rw_index] <= rw_wdata;
              rw_done <= 1'b1;
            end else begin
              // Read operation
              rw_rdata <= master_array[block_index][rw_index];
              rw_done <= 1'b1;
            end
          end else begin
            // Block is not allocated
            if (rw_wr) begin
              // Allocate a new block
              integer new_block_idx;
              if (find_first_free_block(new_block_idx)) begin
                block_alloc_bitmap[new_block_idx] <= 1'b1;
                write_block_index(rw_module_id, rw_block_number, new_block_idx[15:0]);
                total_bitmaps <= total_bitmaps + 1;
                total_blocks <= total_blocks + 1;
                // Perform write operation
                master_array[new_block_idx][rw_index] <= rw_wdata;
                rw_done <= 1'b1;
              end else begin
                // Not enough space
                rw_done <= 1'b0;
              end
            end else begin
              // Read operation, block not allocated
              rw_rdata <= 1'b1; // Return default value
              rw_done <= 1'b1;
            end
          end
        end else begin
          // Invalid module ID or block number
          rw_done <= 1'b1;
        end
      end else begin
        rw_done <= 1'b0;
      end
    end
  end

  // Task to write a 32-bit metadata field (occupies two blocks)
  task write_metadata32(input [$clog2(NUM_MODULES)-1:0] module_id, input integer field_offset, input [31:0] data);
    integer idx;
    begin
      idx = metadata_start_index[module_id] + field_offset;
      master_array[idx]     = data[31:16];
      master_array[idx + 1] = data[15:0];
    end
  endtask

  // Task to write an 8-bit metadata field (within a 16-bit block)
  task write_metadata8(input [$clog2(NUM_MODULES)-1:0] module_id, input integer field_offset, input integer byte_index, input [7:0] data);
    integer idx;
    reg [15:0] temp;
    begin
      idx = metadata_start_index[module_id] + field_offset;
      temp = master_array[idx];
      if (byte_index == 1) begin
        temp[15:8] = data;
      end else begin
        temp[7:0] = data;
      end
      master_array[idx] = temp;
    end
  endtask

  // Task to write two 8-bit metadata fields sharing one block with start_idx
  task write_metadata8_pair_with_start_idx(input integer start_idx, input integer field_offset, input [7:0] data1, input [7:0] data2);
    integer idx;
    begin
      idx = start_idx + field_offset;
      master_array[idx] = {data1, data2};
    end
  endtask

  // Task to write a 32-bit metadata field with start_idx
  task write_metadata32_with_start_idx(input integer start_idx, input integer field_offset, input [31:0] data);
    integer idx;
    begin
      idx = start_idx + field_offset;
      master_array[idx]     = data[31:16];
      master_array[idx + 1] = data[15:0];
    end
  endtask

  // Function to read a 32-bit metadata field
  function [31:0] read_metadata32(input [$clog2(NUM_MODULES)-1:0] module_id, input integer field_offset);
    integer idx;
    begin
      idx = metadata_start_index[module_id] + field_offset;
      read_metadata32 = {master_array[idx], master_array[idx + 1]};
    end
  endfunction

  // Function to read an 8-bit metadata field (within a 16-bit block)
  function [7:0] read_metadata8(input [$clog2(NUM_MODULES)-1:0] module_id, input integer field_offset, input integer byte_index);
    integer idx;
    reg [15:0] temp;
    begin
      idx = metadata_start_index[module_id] + field_offset;
      temp = master_array[idx];
      if (byte_index == 1) begin
        read_metadata8 = temp[15:8];
      end else begin
        read_metadata8 = temp[7:0];
      end
    end
  endfunction

  // Task to write a block index with start_idx
  task write_block_index_with_start_idx(input integer start_idx, input integer block_number, input [15:0] block_index);
    integer idx;
    begin
      idx = start_idx + METADATA_BLOCK_INDICES_OFFSET + block_number;
      master_array[idx] = block_index;
    end
  endtask

  // Task to write a block index
  task write_block_index(input [$clog2(NUM_MODULES)-1:0] module_id, input integer block_number, input [15:0] block_index);
    integer idx;
    begin
      idx = metadata_start_index[module_id] + METADATA_BLOCK_INDICES_OFFSET + block_number;
      master_array[idx] = block_index;
    end
  endtask

  // Function to read a block index
  function [15:0] read_block_index(input [$clog2(NUM_MODULES)-1:0] module_id, input integer block_number);
    integer idx;
    begin
      idx = metadata_start_index[module_id] + METADATA_BLOCK_INDICES_OFFSET + block_number;
      read_block_index = master_array[idx];
    end
  endfunction

  // Function to read a block index with start_idx
  function [15:0] read_block_index_with_start_idx(input integer start_idx, input integer block_number);
    integer idx;
    begin
      idx = start_idx + METADATA_BLOCK_INDICES_OFFSET + block_number;
      read_block_index_with_start_idx = master_array[idx];
    end
  endfunction

endmodule
