package cfs_apb_pkg;

	// Import UVM
	import uvm_pkg::*;
	`include "uvm_macros.svh"

	// Include all APB side files
	`include "../apb/apb_if.sv"
	`include "../apb/apb_agent.sv"
	`include "../apb/apb_driver.sv"
	`include "../apb/apb_monitor.sv"
	`include "../apb/apb_sequencer.sv"
	`include "../apb/apb_sequence.sv"
	`include "../apb/apb_config.sv"
	`include "../apb/apb_transaction.sv"

	// Add more includes as needed for all APB files

endpackage : cfs_apb_pkg
