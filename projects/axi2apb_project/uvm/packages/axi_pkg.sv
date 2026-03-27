`ifndef AXI_PKG_SV
`define AXI_PKG_SV

`include "uvm_macros.svh"
//Include APB interface
//`include "axi_if.sv"
`include "axi_types.sv"

package axi_pkg;

	// Import UVM
	import uvm_pkg::*;
	import axi_types_pkg::*;

	// Include all APB side files

	`include "axi_transaction.sv"
	`include "axi_item_drv.sv"
	`include "axi_item_mon.sv"
	`include "axi_agent_config.sv"
	`include "axi_sequencer.sv"
	`include "axi_driver.sv"
	`include "axi_monitor.sv"
	`include "axi_bridge_coverage.sv"
	`include "axi_agent.sv"

	`include "axi_sequence_base.sv"
	`include "axi_sequence_rw.sv"
	`include "axi_write_seq.sv"
	`include "axi_random_read_seq.sv"

	// Add more includes as needed for all APB files

endpackage

`endif
