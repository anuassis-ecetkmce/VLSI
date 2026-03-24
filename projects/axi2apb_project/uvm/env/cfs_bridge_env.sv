`ifndef CFS_BRIDGE_ENV_SV
	`define CFS_BRIDGE_ENV_SV
	
	class cfs_bridge_env extends uvm_env;
      	cfs_apb_agent apb_agent;
      	axi_agent axi_agent1;
		axi2apb_scoreboard scb;
	
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

		endfunction

		// Connect Phase: Connect monitor ports to scoreboard exports
		virtual function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);

			// CONNECT AXI MONITOR TO SCOREBOARD
			// Replace 'analysis_port' with the actual name of the port in your AXI monitor
			axi_agent1.monitor.axi_ap.connect(scb.axi_export);

			// CONNECT APB MONITOR TO SCOREBOARD
			// Replace 'analysis_port' with the actual name of the port in your APB monitor
			apb_agent.monitor.output_port.connect(scb.apb_export);

		endfunction

	
	endclass
	
`endif
