`ifndef CFS_BRIDGE_TEST_PKG_SV
	`define CFS_BRIDGE_TEST_PKG_SV
	
	`include "uvm_macros.svh"
	`include "cfs_bridge_pkg.sv"
	
	package cfs_bridge_test_pkg;
		import uvm_pkg::*;
		import cfs_bridge_pkg::*;
		import cfs_apb_pkg::*;

		`include "cfs_bridge_test_base.sv"
		`include "cfs_bridge_test_reg_access.sv"
		
	endpackage

`endif // CFS_BRIDGE_TEST_PKG_SV