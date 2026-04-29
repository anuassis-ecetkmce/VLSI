`ifndef CFS_BRIDGE_TEST_REG_ACCESS_SV
	`define CFS_BRIDGE_TEST_REG_ACCESS_SV
	
	class cfs_bridge_test_reg_access extends cfs_bridge_test_base;
	
      `uvm_component_utils(cfs_bridge_test_reg_access)
	
		function new(string name = "", uvm_component parent);
			super.new(name, parent);
		endfunction
		
		virtual task run_phase(uvm_phase phase);

			//Declare your new virtual sequence
			cfs_bridge_virtual_sequence vseq;

			
			phase.raise_objection(this, "TEST_DONE");
			
			`uvm_info("DEBUG", "Start of test", UVM_LOW)

			//Create and start the virtual sequence on the environment's virtual sequencer
			vseq = cfs_bridge_virtual_sequence::type_id::create("vseq");
			vseq.start(env.v_sqr);
          
          	`uvm_info("DEBUG", "End of test", UVM_LOW)
			
			phase.drop_objection(this, "TEST_DONE");
			
		endtask
		
	endclass
	
`endif
