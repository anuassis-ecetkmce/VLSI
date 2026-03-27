`ifndef CFS_BRIDGE_TEST_REG_ACCESS_SV
	`define CFS_BRIDGE_TEST_REG_ACCESS_SV
	
	class cfs_bridge_test_reg_access extends cfs_bridge_test_base;
	
      `uvm_component_utils(cfs_bridge_test_reg_access)
	
		function new(string name = "", uvm_component parent);
			super.new(name, parent);
		endfunction
		
		virtual task run_phase(uvm_phase phase);
			
			phase.raise_objection(this, "TEST_DONE");
			
			`uvm_info("DEBUG", "Start of test", UVM_LOW)
          
			#300ns
          
			begin
				axi_sequence_rw seq_rw = axi_sequence_rw::type_id::create("seq_rw");

				void'(seq_rw.randomize() with{num_trans == 6;});
				seq_rw.start(env.axi_agent1.sequencer);

			end

			#200ns
			begin
				axi_write_stress_seq seq_write = axi_write_stress_seq::type_id::create("seq_write");

				seq_write.start(env.axi_agent1.sequencer);
			end

			#200ns
			begin
				axi_write_slow_master_seq seq_slow_wr = axi_write_slow_master_seq::type_id::create("seq_slow_wr");

				seq_slow_wr.start(env.axi_agent1.sequencer);
			end

			#200ns
			begin
				axi_write_random_delay_seq seq_rand_wr = axi_write_random_delay_seq::type_id::create("seq_rand_wr");

				seq_rand_wr.start(env.axi_agent1.sequencer);
			end

			#100ns
			//begin
			//	axi_random_read_seq seq_rand_rd = axi_random_read_seq::type_id::create("seq_rand_rd");

            //    seq_rand_rd.start(env.axi_agent1.sequencer);
			//end


          
          	`uvm_info("DEBUG", "End of test", UVM_LOW)
			
			phase.drop_objection(this, "TEST_DONE");
			
		endtask
		
	endclass
	
`endif
