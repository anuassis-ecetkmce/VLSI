`ifndef CFS_APB_PKG_SV
`define CFS_APB_PKG_SV

`include "uvm_macros.svh"
`include "cfs_apb_if.sv"

package cfs_apb_pkg;

	// Import UVM
	import uvm_pkg::*;

	// Include all APB side files
	`include "cfs_apb_types.sv"
	`include "cfs_apb_trans.sv"
	`include "cfs_apb_item_drv.sv"
	`include "cfs_apb_item_mon.sv"
	`include "cfs_apb_agent_config.sv"
	`include "cfs_apb_sequencer.sv"
	`include "cfs_apb_driver.sv"
	`include "cfs_apb_monitor.sv"
	`include "cfs_apb_agent.sv"

	`include "cfs_apb_sequence_base.sv"

	// Add more includes as needed for all APB files

endpackage

`endif
