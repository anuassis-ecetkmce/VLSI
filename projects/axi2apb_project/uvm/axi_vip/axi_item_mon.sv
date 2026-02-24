`ifndef AXI_ITEM_MON_SV
`define AXI_ITEM_MON_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import axi_types_pkg::*;

// Monitor-side AXI item class
class axi_item_mon extends axi_transaction;

  // Time when this transaction was observed
  time signed   timestamp;

  // Optional - track if this was accepted by ready/valid handshake
  bit           accepted;

  `uvm_object_utils_begin(axi_item_mon)
  	`uvm_field_int(timestamp, UVM_ALL_ON)
    `uvm_field_int(accepted,  UVM_ALL_ON)
  `uvm_object_utils_end

  // Constructor
  function new(string name = "axi_item_mon");
    super.new(name);
    timestamp = 0;
    accepted  = 0;
  endfunction

  // Customization: capture handshake acceptance
  function void set_accepted();
    accepted = 1;
    timestamp = $time;
  endfunction

  // Optional: a printable summary override
  function string convert2string();
    string s;
    s = $sformatf(
      "AXI_MON: id=%0d, addr=0x%0h, write=%0d, data0=0x%0h, resp=0x%0h, accepted=%0d @time=%0t",
      id, addr, is_write,
      (data_ary.size() > 0 ? data_ary[0] : '0),
      resp, accepted, timestamp
    );
    return s;
  endfunction

  // Register fields for automation (optional dynamic array not printed)


endclass : axi_item_mon

`endif // AXI_ITEM_MON_SV
