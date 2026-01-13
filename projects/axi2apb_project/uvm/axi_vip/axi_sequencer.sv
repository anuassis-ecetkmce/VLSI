`ifndef AXI_SEQUENCER_SV
`define AXI_SEQUENCER_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_sequencer extends uvm_sequencer #(axi_transaction);

  `uvm_component_utils(axi_sequencer)

 
  // Constructor


  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : axi_sequencer

`endif // AXI_SEQUENCER_SV

