`ifndef AXI_ITEM_BASE_SV
`define AXI_ITEM_BASE_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import axi_types_pkg::*;

/**
 * Base class for all AXI items
 * - Extended by axi_item_drv (driver-side)
 * - Extended by axi_item_mon (monitor-side)
 */
class axi_item_base extends uvm_sequence_item;

  `uvm_object_utils(axi_item_base)

  // -------------------------------------------------
  // Common AXI fields (subset, protocol-agnostic)
  // -------------------------------------------------

  bit                is_write;   // 1 = write, 0 = read
  bit [AXI_ID_WIDTH-1:0]   id;
  bit [AXI_ADDR_WIDTH-1:0] addr;

  bit [7:0]          len;        // AXI burst length
  axi_size_t         size;       // AWSIZE / ARSIZE
  axi_burst_t        burst;      // FIXED / INCR / WRAP

  // Response
  axi_resp_t         resp;
  bit                err;

  // -------------------------------------------------
  // Constructor
  // -------------------------------------------------
  function new(string name = "axi_item_base");
    super.new(name);
    is_write = 0;
    id       = '0;
    addr     = '0;
    len      = 0;
    size     = AXI_SIZE_4B;
    burst    = AXI_BURST_INCR;
    resp     = AXI_RESP_OKAY;
    err      = 0;
  endfunction

  // -------------------------------------------------
  // UVM automation (NO data array here)
  // -------------------------------------------------
  `uvm_field_int(is_write, UVM_ALL_ON)
  `uvm_field_int(id,       UVM_ALL_ON)
  `uvm_field_int(addr,     UVM_ALL_ON)
  `uvm_field_int(len,      UVM_ALL_ON)
  `uvm_field_enum(axi_size_t,  size,  UVM_ALL_ON)
  `uvm_field_enum(axi_burst_t, burst, UVM_ALL_ON)
  `uvm_field_enum(axi_resp_t,  resp,  UVM_ALL_ON)
  `uvm_field_int(err,      UVM_ALL_ON)

endclass : axi_item_base

`endif // AXI_ITEM_BASE_SV
