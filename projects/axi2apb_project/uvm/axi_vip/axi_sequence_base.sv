`ifndef AXI_SEQUENCE_BASE_SV
`define AXI_SEQUENCE_BASE_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import axi_types_pkg::*;

/**
 * Base class for all AXI sequences
 * - Extended by driver-side sequences (axi_sequence_drv)
 * - Can be extended by other sequences if needed
 */
class axi_sequence_base extends uvm_sequence #(axi_transaction);

  `uvm_object_utils(axi_sequence_base)

  // Constructor
  function new(string name = "axi_sequence_base");
    super.new(name);
  endfunction

  // -------------------------------------------------
  // Helper task to create a generic AXI transaction
  // -------------------------------------------------
  virtual task create_transaction(bit is_write = 0,
                                  int unsigned addr = 0,
                                  int unsigned len = 0,
                                  axi_size_t size = AXI_SIZE_4B,
                                  axi_burst_t burst = AXI_BURST_INCR);
    axi_transaction tr;
    tr = axi_transaction::type_id::create("axi_tr");
    tr.is_write = is_write;
    tr.addr     = addr;
    tr.len      = len;
    tr.size     = size;
    tr.burst    = burst;
    tr.resp     = AXI_RESP_OKAY;
  endtask

  // -------------------------------------------------
  // Pre/post body hooks (optional, can override in child sequences)
  // -------------------------------------------------
  virtual task pre_body();
    // Placeholder for any pre-sequence actions
  endtask

  virtual task post_body();
    // Placeholder for any post-sequence actions
  endtask

endclass : axi_sequence_base

`endif // AXI_SEQUENCE_BASE_SV
