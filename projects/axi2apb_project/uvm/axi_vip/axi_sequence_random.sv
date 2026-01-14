`ifndef AXI_SEQUENCE_RANDOM_SV
`define AXI_SEQUENCE_RANDOM_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import axi_types_pkg::*;

class axi_sequence_random extends uvm_sequence #(axi_transaction);

  `uvm_object_utils(axi_sequence_random)

  // Configurable ranges
  rand bit [31:0] base_addr      = 32'h0000_1000;
  rand bit [31:0] addr_mask      = 32'h0000_0FFF;   // mask bits for address range
  rand int unsigned num_trans    = 10;              // total number of transactions
  rand int unsigned write_percentage = 50;          // % of write transactions

  // Optional burst support
  rand bit use_burst;    // enable random bursts
  rand bit [3:0] burst_len;      // length if burst enabled

  // Constraints
  constraint addr_align_c {
    (base_addr & 32'h3) == 0; // words are 4-byte aligned
  }

  constraint burst_c {
    if (!use_burst)
      burst_len == 0;
    else
      burst_len inside {[1:15]}; // 1 to 15 for AXI4
  }

  task body();

    axi_transaction tr;

    for (int unsigned i = 0; i < num_trans; i++) begin

      // Create new transaction
      tr = axi_transaction::type_id::create($sformatf("axi_rand_tr_%0d", i), this);

      // Try to randomize fields
      if (!tr.randomize() with {
            // Weighted write/read
            tr.is_write dist {
               1 :/ write_percentage,
               0 :/ 100 - write_percentage
            };

            // Random address using masked bits
            tr.addr inside { [base_addr : base_addr + addr_mask] };
            (tr.addr % 4) == 0; // 4-byte alignment

            // AXI4 Lite defaults
            tr.size == AXI_SIZE_4B;
            tr.burst == AXI_BURST_INCR;

            // Burst length only if enabled
            tr.len == burst_len;
         })
      begin
        `uvm_error("RAND_FAIL", $sformatf("Transaction randomization failed for index %0d", i))
        // Fallback: create safe default
        tr.is_write = 1;
        tr.addr     = base_addr;
        tr.len      = 0;
        tr.size     = AXI_SIZE_4B;
        tr.burst    = AXI_BURST_INCR;
        burst_len   = 0;
      end

      // Write or read payload
      tr.alloc_data_array();
      if (tr.is_write) begin
        tr.data_ary[0] = $urandom;
      end

      // Send transaction
      start_item(tr);
      finish_item(tr);

      `uvm_info("AXI_SEQ_RANDOM",
                $sformatf("Random AXI Trans[%0d]: %s addr=0x%0h data=0x%0h burst_len=%0d",
                          i,
                          (tr.is_write ? "WRITE" : "READ"),
                          tr.addr,
                          (tr.is_write ? tr.data_ary[0] : 'X),
                          tr.len),
                UVM_MEDIUM)

    end

  endtask

endclass : axi_sequence_random

`endif // AXI_SEQUENCE_RANDOM_SV
