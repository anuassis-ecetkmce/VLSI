// apb_trans.sv
`ifndef APB_TRANS_SV
`define APB_TRANS_SV
import uvm_pkg::*;
`include "uvm_macros.svh"

class apb_trans extends uvm_sequence_item;
	`uvm_object_utils(apb_trans)

	typedef enum { READ, WRITE } apb_op_e;

	// Fields used by sequencer/driver/monitor/scoreboard
	rand bit [31:0] addr;
	rand bit [31:0] data;        // write data
	bit [31:0] resp_data;        // read response captured
	apb_op_e      op;
	bit [2:0]     prot;
	bit           err;

	function new(string name = "apb_trans");
		super.new(name);
		addr = '0; data = '0; resp_data = '0; op = READ; prot = 3'b000; err = 0;
	endfunction

	function string convert2string();
		return $sformatf("APB_TRANS op=%0s addr=0x%08h data=0x%08h resp=0x%08h err=%0b", (op==READ)?"READ":"WRITE", addr, data, resp_data, err);
	endfunction
endclass
`endif
