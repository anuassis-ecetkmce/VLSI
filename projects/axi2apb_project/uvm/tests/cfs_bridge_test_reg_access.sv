`ifndef CFS_BRIDGE_TEST_REG_ACCESS_SV
	`define CFS_BRIDGE_TEST_REG_ACCESS_SV
	
	class cfs_bridge_test_reg_access extends cfs_bridge_test_base;
	
      `uvm_component_utils(cfs_bridge_test_reg_access)
	
		function new(string name = "", uvm_component parent);
			super.new(name, parent);
		endfunction
		
		virtual task run_phase(uvm_phase phase);
          
          //create the sequence
          axi_sequence_rw seq_rw = axi_sequence_rw::type_id::create("seq_rw");
			
			phase.raise_objection(this, "TEST_DONE");
			
			`uvm_info("DEBUG", "Start of test", UVM_LOW)
          
			#100ns
          
          	fork
          		begin
              		void'(seq_rw.randomize() with{num_trans == 3;});
              		seq_rw.start(env.axi_agent1.sequencer);
            	end
            join_any
          
          /*fork
          	begin
              cfs_apb_sequence_simple seq_simple = cfs_apb_sequence_simple::type_id::create("seq_simple");
              
              void'(seq_simple.randomize() with{
                item.addr == 'h0;
                item.dir  == CFS_APB_WRITE;
                item.data == 'h11;
              });
              
              seq_simple.start(env.apb_agent.sequencer);
            end
          
          	begin
              cfs_apb_sequence_rw seq_rw = cfs_apb_sequence_rw::type_id::create("seq_rw");
              
              void'(seq_rw.randomize() with{
                addr == 'hc;
              });
              
              seq_rw.start(env.apb_agent.sequencer);
              
            end
          
          	begin
              cfs_apb_sequence_random seq_rand = cfs_apb_sequence_random::type_id::create("seq_rand");
              
              void'(seq_rand.randomize() with{
                num_items == 3;
              });
              
              seq_rand.start(env.apb_agent.sequencer);
              
            end
          join*/
          
          	`uvm_info("DEBUG", "End of test", UVM_LOW)
			
			phase.drop_objection(this, "TEST_DONE");
			
		endtask
		
	endclass
	
`endif