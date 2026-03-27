`ifndef CFS_bridge_PKG_SV
	`define CFS_bridge_PKG_SV
	
	`include "uvm_macros.svh"
	`include "cfs_apb_pkg.sv"
	`include "axi_pkg.sv"
	
	package cfs_bridge_pkg;
		import uvm_pkg::*;
		import cfs_apb_pkg::*;
		import axi_pkg::*;

		`include "scoreboard.sv"
		`include "cfs_bridge_env.sv"
		`include "cfs_bridge_virtual_sequencer.sv"
		
	endpackage
	
`endif
