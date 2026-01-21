`ifndef CFS_BRIDGE_ENV_SV
	`define CFS_BRIDGE_ENV_SV
	
	class cfs_bridge_env extends uvm_env;
      	cfs_apb_agent apb_agent;
      	axi_agent axi_agent1;
	
		`uvm_component_utils(cfs_bridge_env)
	
		function new(string name = "", uvm_component parent);
			super.new(name, parent);
		endfunction
      
      	virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
          apb_agent = cfs_apb_agent::type_id::create("apb_agent", this);
          axi_agent1 = axi_agent::type_id::create("axi_agent", this);
        
      endfunction
	
	endclass
	
`endif