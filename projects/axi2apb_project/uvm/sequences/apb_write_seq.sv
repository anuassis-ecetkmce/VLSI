// apb_write_seq.sv
import uvm_pkg::*;
`include "apb_trans.sv"

class apb_write_seq extends uvm_sequence#(apb_trans);
	`uvm_object_utils(apb_write_seq)

	bit [31:0] addr;
	bit [31:0] data;

	function new(string name="apb_write_seq"); super.new(name); endfunction

	virtual task body();
		apb_trans tr = apb_trans::type_id::create("tr");
		tr.op = apb_trans::WRITE;
		tr.addr = addr;
		tr.data = data;
		start_item(tr);
		finish_item(tr);
	endtask
endclass
