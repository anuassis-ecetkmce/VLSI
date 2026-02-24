`ifndef AXI_TRANSACTION_SV
`define AXI_TRANSACTION_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_transaction extends uvm_sequence_item;

  // AXI fields

  rand bit [3:0]   id;
  rand bit [31:0]  addr;
  rand bit [7:0]   len;        // beats = len + 1
  rand bit [2:0]   size;       // bytes = 2**size
  rand bit [1:0]   burst;      // FIXED / INCR / WRAP
  rand bit         is_write;

  // Per-beat data
  rand bit [31:0]  data_ary[];

  // Response
  bit [1:0]        resp;

  // Field automation
  `uvm_object_utils_begin(axi_transaction)
    `uvm_field_int(id,       UVM_ALL_ON)
    `uvm_field_int(addr,     UVM_ALL_ON)
    `uvm_field_int(len,      UVM_ALL_ON)
    `uvm_field_int(size,     UVM_ALL_ON)
    `uvm_field_int(burst,    UVM_ALL_ON)
    `uvm_field_int(is_write, UVM_ALL_ON)
    `uvm_field_int(resp,     UVM_ALL_ON)
    `uvm_field_array_int(data_ary, UVM_ALL_ON)
  `uvm_object_utils_end


  // Constraints (CRITICAL)


  // Reasonable burst length
  constraint c_len {
    len inside {[0:15]};   // up to 16 beats
  }

  // Supported sizes (1B–4B typical for APB)
  constraint c_size {
    size inside {3'b000, 3'b001, 3'b010}; // 1B, 2B, 4B
  }

  // Address alignment rule
  constraint c_addr_align {
    addr % (1 << size) == 0;
  }

  // Burst type limitation (APB-friendly)
  constraint c_burst {
    burst inside {2'b00, 2'b01}; // FIXED, INCR
  }

  // Data array size must match burst
  constraint c_data_size {
    data_ary.size() == (len + 1);
  }


  // Constructor

  function new(string name = "axi_transaction");
    super.new(name);
  endfunction


  // Utility methods


  function void alloc_data_array();
    data_ary.delete();
    data_ary = new[len + 1];
    foreach (data_ary[i])
      data_ary[i] = '0;
  endfunction

  // Deep copy (important for scoreboard)
  function void do_copy(uvm_object rhs);
    axi_transaction rhs_t;
    if (!$cast(rhs_t, rhs)) begin
      `uvm_fatal("COPY", "Cast failed in axi_transaction::do_copy")
    end

    super.do_copy(rhs);
    id       = rhs_t.id;
    addr     = rhs_t.addr;
    len      = rhs_t.len;
    size     = rhs_t.size;
    burst    = rhs_t.burst;
    is_write = rhs_t.is_write;
    resp     = rhs_t.resp;

    data_ary = new[rhs_t.data_ary.size()];
    foreach (data_ary[i])
      data_ary[i] = rhs_t.data_ary[i];
  endfunction

  // Compare (used by scoreboard/debug)
  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    axi_transaction rhs_t;
    if (!$cast(rhs_t, rhs))
      return 0;

    if (id       != rhs_t.id)       return 0;
    if (addr     != rhs_t.addr)     return 0;
    if (len      != rhs_t.len)      return 0;
    if (size     != rhs_t.size)     return 0;
    if (burst    != rhs_t.burst)    return 0;
    if (is_write != rhs_t.is_write) return 0;

    if (data_ary.size() != rhs_t.data_ary.size())
      return 0;

    foreach (data_ary[i])
      if (data_ary[i] != rhs_t.data_ary[i])
        return 0;

    return 1;
  endfunction

endclass

`endif
