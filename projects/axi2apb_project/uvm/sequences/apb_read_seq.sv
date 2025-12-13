// apb_read_seq.sv
import uvm_pkg::*;
`include "apb_trans.sv"

class apb_read_seq extends uvm_sequence#(apb_trans);
	`uvm_object_utils(apb_read_seq)

	bit [31:0] addr;

	function new(string name="apb_read_seq");
		super.new(name);
	endfunction

	virtual task body();
		apb_trans tr = apb_trans::type_id::create("tr");
		tr.op = apb_trans::READ;
		tr.addr = addr;
		start_item(tr);
		finish_item(tr);
	endtask
endclass
