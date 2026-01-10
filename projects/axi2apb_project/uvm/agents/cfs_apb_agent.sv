// APB Agent for UVM Verification of AXI to APB Bridge
// This agent provides APB bus functional model for testing AXI to APB bridge

`ifndef CFS_APB_AGENT_SV
`define CFS_APB_AGENT_SV

class cfs_apb_agent extends uvm_agent;
  
    `uvm_component_utils(cfs_apb_agent)

    // Configuration object
    cfs_apb_agent_config agent_config;

    // Agent components
    cfs_apb_sequencer sequencer;
    cfs_apb_driver driver;
    cfs_apb_monitor monitor;

    // Analysis port for monitor transactions
    //uvm_analysis_port #(cfs_apb_transaction) ap;

    function new(string name = "", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_build_phase phase);
        super.build_phase(phase);

        // Get agent configuration from config_db
        agent_config = cfs_apb_agent_config::type_id::create("agent_config", this);

        // Create monitor
        monitor = cfs_apb_monitor::type_id::create("monitor", this);

        if(agent_config.get_active_passive() == UVM_ACTIVE) begin
            // Create sequencer
            sequencer = cfs_apb_sequencer::type_id::create("sequencer", this);
        
            // Create driver
            driver = cfs_apb_driver::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_connect_phase phase);
        super.connect_phase(phase);

        cfs_apb_vif vif;
        
        if (!uvm_config_db#(virtual cfs_apb_vif)::get(this, "", "vif", vif)) begin
            `uvm_fatal("APB_NO_VIF", "Could not get from the database the APB virtual interface")
        end
        else begin
            agent_config.set_vif(vif);
        end
        monitor.agent_config = agent_config;

        if(agent_config.get_active_passive() == UVM_ACTIVE) begin
            driver.agent_config = agent_config;
            // Connect driver to sequencer
            driver.seq_item_port.connect(sequencer.seq_item_export);    
        end
    endfunction

    function void end_of_elaboration_phase(uvm_end_of_elaboration_phase phase);
        super.end_of_elaboration_phase(phase);
        `uvm_info(get_type_name(), $sformatf("APB Agent created: %s", get_full_name()), UVM_HIGH)
    endfunction

endclass

`endif // CFS_APB_AGENT_SV
