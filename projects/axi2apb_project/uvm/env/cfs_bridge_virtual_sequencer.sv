`ifndef CFS_BRIDGE_VIRTUAL_SEQUENCER_SV
`define CFS_BRIDGE_VIRTUAL_SEQUENCER_SV

class cfs_bridge_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(cfs_bridge_virtual_sequencer)

  // Pointers to your EXACT existing sequencers
  axi_sequencer      axi_sqr;
  cfs_apb_sequencer  apb_sqr;

  function new(string name = "cfs_bridge_virtual_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass

`endif
