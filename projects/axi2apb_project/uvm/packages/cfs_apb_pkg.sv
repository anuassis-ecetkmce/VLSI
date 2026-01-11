`ifndef CFS_APB_PKG_SV
`define CFS_APB_PKG_SV

package cfs_apb_pkg;

	import uvm_pkg::*;
	`include "uvm_macros.svh"

    //Include the types
    `include "uvm/types/cfs_apb_types.sv"

	//Include the Interface
	`include "uvm/interface/cfs_apb_if.sv"

	// Include APB transaction
	`include "uvm/transaction/cfs_apb_trans.sv"

	// Include APB driver
	`include "uvm/driver/cfs_apb_driver.sv"

	// Include APB monitor
	`include "uvm/monitor/cfs_apb_monitor.sv"

	//Include APB Sequencer
	`include "uvm/sequences/cfs_apb_sequencer.sv"

	// Include APB agent
	`include "uvm/agents/cfs_apb_agent.sv"

	// Include APB agent configuration
	`include "uvm/agents/cfs_apb_agent_config.sv"

	


	// Optionally include scoreboard, coverage, etc.
	// `include "../scoreboard/cfs_apb_scoreboard.sv"
	// `include "../coverage/cfs_apb_coverage.sv"

endpackage : cfs_apb_pkg

`endif // CFS_APB_PKG_SV
