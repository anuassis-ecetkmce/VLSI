`ifndef CFS_APB_READ_SEQ_SV
`define CFS_APB_READ_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "cfs_apb_trans.sv"
`include "cfs_apb_sequencer.sv"

// APB Read Sequence for AXI2APB bridge UVM environment
class cfs_apb_read_seq extends uvm_sequence #(cfs_apb_trans);

	`uvm_object_utils(cfs_apb_read_seq)

	// Sequence variables
	rand bit [31:0] paddr;

	// Constructor
	function new(string name = "cfs_apb_read_seq");
		super.new(name);
	endfunction

	// Body task
	virtual task body();
		cfs_apb_trans req;
		req = cfs_apb_trans::type_id::create("req");

		// Set up read transaction
		req.pwrite = 0; // Read
		req.paddr  = this.paddr;
		req.psel   = 1;
		req.penable = 1;

		// Start item
		start_item(req);
		if (!req.randomize() with { pwrite == 0; paddr == local::paddr; }) begin
			`uvm_error(get_type_name(), "Randomization failed in cfs_apb_read_seq")
		end
		finish_item(req);
	endtask

endclass : cfs_apb_read_seq

`endif // CFS_APB_READ_SEQ_SV
