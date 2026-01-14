`ifndef AXI_ITEM_DRV_SV
`define AXI_ITEM_DRV_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import axi_types_pkg::*;
`include "axi_item_base.sv"

/**
 * Driver-side AXI sequence item
 * - Extends axi_item_base
 * - Adds data array for writes
 */
class axi_item_drv extends axi_item_base;

  `uvm_object_utils(axi_item_drv)

  // Dynamic array for payload data (write data)
  bit [AXI_DATA_WIDTH-1:0] data_ary[];

  // -------------------------------------------------
  // Constructor
  // -------------------------------------------------
  function new(string name = "axi_item_drv");
    super.new(name);
    data_ary = new[0]; // empty by default
  endfunction

  // -------------------------------------------------
  // Helper: allocate data array according to len
  // -------------------------------------------------
  function void alloc_data_array();
    int beats = len + 1;
    data_ary.delete();
    data_ary = new[beats];
    for (int i = 0; i < beats; i++) data_ary[i] = '0;
  endfunction

  // -------------------------------------------------
  // UVM field automation
  // - base fields are already included from axi_item_base
  // - add data_ary as dynamic array
  // -------------------------------------------------
  `uvm_field_array_int(data_ary, UVM_ALL_ON)

endclass : axi_item_drv

`endif // AXI_ITEM_DRV_SV
