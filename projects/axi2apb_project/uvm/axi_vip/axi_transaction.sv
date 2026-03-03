
`ifndef AXI_TRANSACTION_SV
`define AXI_TRANSACTION_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_transaction extends uvm_sequence_item;
  `uvm_object_utils(axi_transaction)

  // -------------------------------------------------
  // Standard AXI protocol fields
  // -------------------------------------------------
  rand bit [3:0]   id;
  rand bit [31:0]  addr;
  rand bit [7:0]   len;      // beats = len + 1
  rand bit [2:0]   size;     // bytes = 2**size
  rand bit [1:0]   burst;    // FIXED / INCR / WRAP
  rand bit         is_write;

  // Per-beat data
  rand bit [31:0]  data_ary[];

  // Response sampled from bus
  bit [1:0]        resp;

  // -------------------------------------------------
  // NEW: Timing & Delay Knobs for specialized testing
  // -------------------------------------------------
  // Delay before asserting AWVALID/ARVALID
  rand int unsigned pre_addr_delay;  
  
  // Delay between Address Handshake and first Data beat (WVALID)
  rand int unsigned addr_to_data_gap; 
  
  // Delay between individual data beats within a burst
  rand int unsigned inter_beat_delay; 
  
  // Delay before asserting BREADY to accept response
  rand int unsigned wait_for_bresp_delay;

  // -------------------------------------------------
  // Constraints
  // -------------------------------------------------

  // Reasonable burst length
  constraint c_len {
    len inside {[0:15]};   // up to 16 beats
  }

  // Supported sizes (1B–4B typical)
  constraint c_size {
    size inside {3'b000, 3'b001, 3'b010}; // 1B, 2B, 4B
  }

  // Address alignment rule
  constraint c_addr_align {
    addr % (1 << size) == 0;
  }

  // Burst type limitation
  constraint c_burst {
    burst inside {2'b00, 2'b01}; // FIXED, INCR
  }

  // Data array size must match burst
  constraint c_data_size {
    data_ary.size() == (len + 1);
  }

  // Default Delay Constraints (Weighted toward fast transactions)
  constraint c_default_delays {
    pre_addr_delay       dist {0 :/ 70, [1:5] :/ 20, [6:20] :/ 10};
    addr_to_data_gap     dist {0 :/ 70, [1:5] :/ 20, [6:20] :/ 10};
    inter_beat_delay     dist {0 :/ 80, [1:3] :/ 20};
    wait_for_bresp_delay dist {0 :/ 90, [1:5] :/ 10};
  }

  // Constructor
  function new(string name = "axi_transaction");
    super.new(name);
  endfunction

  // -------------------------------------------------
  // Utility methods
  // -------------------------------------------------

  function void alloc_data_array();
    data_ary.delete();
    data_ary = new[len + 1];
    foreach (data_ary[i])
      data_ary[i] = '0;
  endfunction

  // Deep copy
  function void do_copy(uvm_object rhs);
    axi_transaction rhs_t;
    if (!$cast(rhs_t, rhs)) begin
      `uvm_fatal("COPY", "Cast failed in axi_transaction::do_copy")
    end

    super.do_copy(rhs);
    id                   = rhs_t.id;
    addr                 = rhs_t.addr;
    len                  = rhs_t.len;
    size                 = rhs_t.size;
    burst                = rhs_t.burst;
    is_write             = rhs_t.is_write;
    resp                 = rhs_t.resp;
    
    // Copy new timing fields
    pre_addr_delay       = rhs_t.pre_addr_delay;
    addr_to_data_gap     = rhs_t.addr_to_data_gap;
    inter_beat_delay     = rhs_t.inter_beat_delay;
    wait_for_bresp_delay = rhs_t.wait_for_bresp_delay;

    data_ary = new[rhs_t.data_ary.size()];
    foreach (data_ary[i])
      data_ary[i] = rhs_t.data_ary[i];
  endfunction

  // Compare
  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    axi_transaction rhs_t;
    if (!$cast(rhs_t, rhs)) return 0;


return (super.do_compare(rhs, comparer) &&
            (id                   == rhs_t.id) &&
            (addr                 == rhs_t.addr) &&
            (len                  == rhs_t.len) &&
            (size                 == rhs_t.size) &&
            (burst                == rhs_t.burst) &&
            (is_write             == rhs_t.is_write) &&
            (pre_addr_delay       == rhs_t.pre_addr_delay) &&
            (addr_to_data_gap     == rhs_t.addr_to_data_gap) &&
            (inter_beat_delay     == rhs_t.inter_beat_delay) &&
            (wait_for_bresp_delay == rhs_t.wait_for_bresp_delay) &&
            (data_ary             == rhs_t.data_ary));
  endfunction

  // Field automation
  `uvm_field_int(id,                   UVM_ALL_ON)
  `uvm_field_int(addr,                 UVM_ALL_ON)
  `uvm_field_int(len,                  UVM_ALL_ON)
  `uvm_field_int(size,                 UVM_ALL_ON)
  `uvm_field_int(burst,                UVM_ALL_ON)
  `uvm_field_int(is_write,             UVM_ALL_ON)
  `uvm_field_int(resp,                 UVM_ALL_ON)
  `uvm_field_array_int(data_ary,       UVM_ALL_ON)
  
  // Automate new delay fields
  `uvm_field_int(pre_addr_delay,       UVM_ALL_ON | UVM_DEC)
  `uvm_field_int(addr_to_data_gap,     UVM_ALL_ON | UVM_DEC)
  `uvm_field_int(inter_beat_delay,     UVM_ALL_ON | UVM_DEC)
  `uvm_field_int(wait_for_bresp_delay, UVM_ALL_ON | UVM_DEC)

endclass

`endif