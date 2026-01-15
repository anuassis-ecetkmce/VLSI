`ifndef CFS_APB_TRANS_SV
`define CFS_APB_TRANS_SV

// APB Transaction for AXI2APB bridge UVM environment
class cfs_apb_trans extends uvm_sequence_item;

	// APB transaction fields
	rand cfs_apb_addr   addr;
	rand cfs_apb_wdata  wdata;
	cfs_apb_rdata       rdata;
	rand cfs_apb_dir    direction;
	cfs_apb_response    response;
  	rand cfs_apb_dir	dir;
  
  	`uvm_object_utils(cfs_apb_trans)
  
  	// Constructor
	function new(string name = "");
		super.new(name);
	endfunction

	// Optionally add additional fields
	rand bit               write_strobe;
/*
	// Constraints (if any)
	constraint addr_c { addr inside {[0:2**`CFS_APB_MAX_ADDR_WIDTH-1]}; }
	constraint wdata_c { wdata inside {[0:2**`CFS_APB_MAX_DATA_WIDTH-1]}; }

	// UVM macros
	`uvm_object_utils_begin(cfs_apb_trans)
		`uvm_field_int(addr, UVM_ALL_ON)
		`uvm_field_int(wdata, UVM_ALL_ON)
		`uvm_field_int(rdata, UVM_ALL_ON)
		`uvm_field_enum(cfs_apb_dir, direction, UVM_ALL_ON)
		`uvm_field_enum(cfs_apb_response, response, UVM_ALL_ON)
		`uvm_field_int(write_strobe, UVM_ALL_ON)
	`uvm_object_utils_end

	// Copy method
	function void copy(uvm_object rhs);
		cfs_apb_trans rhs_; rhs_ = cfs_apb_trans::type_id::cast(rhs);
		if(rhs_ == null) return;
		addr         = rhs_.addr;
		wdata        = rhs_.wdata;
		rdata        = rhs_.rdata;
		direction    = rhs_.direction;
		response     = rhs_.response;
		write_strobe = rhs_.write_strobe;
	endfunction
*/
	// Convert2string for debug
	function string convert2string();
		
      string result = $sformatf("APB_TRANS: addr=0x%0h dir=%s wstrb=%0b",addr, direction.name(), write_strobe);

	endfunction

endclass : cfs_apb_trans

`endif // CFS_APB_TRANS_SV
