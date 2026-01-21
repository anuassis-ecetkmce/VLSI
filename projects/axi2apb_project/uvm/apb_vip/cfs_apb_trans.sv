`ifndef CFS_APB_TRANS_SV
`define CFS_APB_TRANS_SV

// APB Transaction for AXI2APB bridge UVM environment
class cfs_apb_trans extends uvm_sequence_item;

	// APB transaction fields
	rand cfs_apb_addr   addr;
	rand cfs_apb_wdata  wdata;
	cfs_apb_rdata       rdata;
	cfs_apb_response    response;
  	rand cfs_apb_dir	dir;
  	// Optionally add additional fields
	rand bit			write_strobe;
  
  	// UVM macros
	`uvm_object_utils_begin(cfs_apb_trans)
		`uvm_field_int(addr, UVM_ALL_ON)
		`uvm_field_int(wdata, UVM_ALL_ON)
		`uvm_field_int(rdata, UVM_ALL_ON)
  		`uvm_field_enum(cfs_apb_dir, dir, UVM_ALL_ON)
		`uvm_field_enum(cfs_apb_response, response, UVM_ALL_ON)
		`uvm_field_int(write_strobe, UVM_ALL_ON)
	`uvm_object_utils_end
  
  	// Constructor
	function new(string name = "");
		super.new(name);
	endfunction

/*
	// Copy method
	function void copy(uvm_object rhs);
      cfs_apb_trans rhs_; rhs_ = cfs_apb_trans::type_id::create(rhs);
		if(rhs_ == null) return;
		addr			= rhs_.addr;
		wdata			= rhs_.wdata;
		rdata			= rhs_.rdata;
		dir				= rhs_.dir;
		response		= rhs_.response;
		write_strobe	= rhs_.write_strobe;
	endfunction
*/
	// Convert2string for debug
	function string convert2string();
		
      string result = $sformatf("APB_TRANS: addr=0x%0h dir=%s wstrb=%0b",addr, dir.name(), write_strobe);

	endfunction

endclass : cfs_apb_trans

`endif // CFS_APB_TRANS_SV
