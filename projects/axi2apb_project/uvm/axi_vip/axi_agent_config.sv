
`ifndef AXI_AGENT_CONFIG_SV
`define AXI_AGENT_CONFIG_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import axi_types_pkg::*;

class axi_agent_config extends uvm_object;

  `uvm_object_utils(axi_agent_config)


  // Agent configuration fields

  // Active or passive agent
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  // Enable/disable coverage
  bit enable_coverage = 1'b1;

  
  // AXI interface parameters (for flexibility & reuse)


  int unsigned id_width   = AXI_ID_WIDTH;
  int unsigned addr_width = AXI_ADDR_WIDTH;
  int unsigned data_width = AXI_DATA_WIDTH;

 
  // AXI protocol-related defaults
 

  axi_burst_t default_burst = AXI_BURST_INCR;
  axi_size_t  default_size  = AXI_SIZE_4B;

  // Maximum outstanding transactions (can be used later)
  int unsigned max_outstanding_txn = 8;

  
  // Virtual interface handle
 

  virtual axi_if vif;

  
  // Constructor
  

  function new(string name = "axi_agent_config");
    super.new(name);
  endfunction

endclass : axi_agent_config

`endif // AXI_AGENT_CONFIG_SV

