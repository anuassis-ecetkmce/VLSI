// uvm_env/items/axi_transaction.sv  (AXI4-ready)
`ifndef AXI_TRANSACTION_SV
`define AXI_TRANSACTION_SV
`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_transaction extends uvm_sequence_item;
  `uvm_object_utils(axi_transaction)

  // Key fields
  rand bit [3:0]         id;       // we'll use 4-bit ID by default
  rand bit [31:0]        addr;     // start address
  // dynamic array for per-beat payloads (size = AWLEN+1)
  rand bit [31:0]        data_ary[]; 
  rand bit [7:0]         len;      // AWLEN/ARLEN (0 => single beat). Actual beats = len + 1
  rand bit [2:0]         size;     // number of bytes = 2**size
  rand bit [1:0]         burst;    // 00 FIXED, 01 INCR, 10 WRAP
  rand bit               is_write;

  // Responses
  bit [1:0]             resp;      // BRESP or RRESP
  bit                   err;

  // Constructor
  function new(string name = "axi_transaction");
    super.new(name);
    id = 0; addr = 0; len = 0; size = 3'd2; burst = 2'b01; is_write = 0;
    resp = 2'b00; err = 0;
    data_ary = new[0]; // empty by default; tests should resize to len+1
  endfunction

  // Helper: resize data array to (len+1) and optionally initialize
  function void alloc_data_array();
    int beats = len + 1;
    data_ary.delete();
    data_ary = new[beats];
    for (int i = 0; i < beats; i++) data_ary[i] = 32'h0;
  endfunction

  `uvm_field_int(id, UVM_ALL_ON)
  `uvm_field_int(addr, UVM_ALL_ON)
  // do not automatically print the dynamic array by default; you can add custom print if needed
  `uvm_field_int(len, UVM_ALL_ON)
  `uvm_field_int(size, UVM_ALL_ON)
  `uvm_field_int(burst, UVM_ALL_ON)
  `uvm_field_int(is_write, UVM_ALL_ON)
  `uvm_field_int(resp, UVM_ALL_ON)
  `uvm_field_int(err, UVM_ALL_ON)

endclass
`endif

