`ifndef CFS_BRIDGE_ENV_SV
	`define CFS_BRIDGE_ENV_SV
	
	class cfs_bridge_env extends uvm_env;
      	cfs_apb_agent apb_agent;
      	axi_agent axi_agent1;
		axi2apb_scoreboard scb;

		//Instantiate Virtual Sequencer
		cfs_bridge_virtual_sequencer v_sqr;
	
		`uvm_component_utils(cfs_bridge_env)
	
		function new(string name = "", uvm_component parent);
			super.new(name, parent);
		endfunction
      
      	virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
          apb_agent = cfs_apb_agent::type_id::create("apb_agent", this);
          axi_agent1 = axi_agent::type_id::create("axi_agent", this);

		  // Create the scoreboard
		  scb = axi2apb_scoreboard::type_id::create("scb", this);

		  //Build the virtual sequencer
		  v_sqr = cfs_bridge_virtual_sequencer::type_id::create("v_sqr", this);

		endfunction

		// Connect Phase: Connect monitor ports to scoreboard exports
		virtual function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);

			// CONNECT AXI MONITOR TO SCOREBOARD
			axi_agent1.monitor.axi_ap.connect(scb.axi_export);

			// CONNECT APB MONITOR TO SCOREBOARD
			apb_agent.monitor.output_port.connect(scb.apb_export);

			//Connect the pointers to the actual sequencers
			if(axi_agent1.sequencer != null)
				v_sqr.axi_sqr = axi_agent1.sequencer;
			if(apb_agent.sequencer != null)
				v_sqr.apb_sqr = apb_agent.sequencer;

		endfunction

	
	endclass
	
`endif
