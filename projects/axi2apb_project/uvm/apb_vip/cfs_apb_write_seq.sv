`ifndef CFS_APB_WRITE_SEQ_SV
`define CFS_APB_WRITE_SEQ_SV

// APB Write Sequence for AXI2APB bridge UVM environment
class cfs_apb_write_seq extends cfs_apb_sequence_base;

	rand cfs_apb_addr addr;
	rand cfs_apb_data wdata;
	rand bit write_strobe;

	`uvm_object_utils(cfs_apb_write_seq)

	function new(string name = "cfs_apb_write_seq");
		super.new(name);
	endfunction

	virtual task body();
		cfs_apb_trans tr;
		`uvm_info(get_type_name(), $sformatf("Starting APB WRITE sequence: addr=0x%0h, wdata=0x%0h, wstrb=%0b", addr, wdata, write_strobe), UVM_MEDIUM)

		tr = cfs_apb_trans::type_id::create("tr");
		tr.addr         = addr;
		tr.wdata        = wdata;
		tr.direction    = CFS_APB_WRITE;
		tr.write_strobe = write_strobe;

		start_item(tr);
		if (!tr.randomize() with { direction == CFS_APB_WRITE; addr == local::addr; wdata == local::wdata; write_strobe == local::write_strobe; }) begin
			`uvm_error(get_type_name(), "Randomization failed for APB write transaction")
		end
		finish_item(tr);
	endtask

endclass : cfs_apb_write_seq

`endif // CFS_APB_WRITE_SEQ_SV
