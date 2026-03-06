`ifndef CFS_APB_SEQUENCER_SV
`define CFS_APB_SEQUENCER_SV


// APB Sequencer for AXI2APB bridge UVM environment
class cfs_apb_sequencer extends uvm_sequencer #(cfs_apb_item_drv);

	`uvm_component_utils(cfs_apb_sequencer)

	// Constructor
	function new(string name = "cfs_apb_sequencer", uvm_component parent = null);
		super.new(name, parent);
	endfunction

endclass : cfs_apb_sequencer

`endif // CFS_APB_SEQUENCER_SV
