`ifndef AXI_AGENT_SV
`define AXI_AGENT_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_agent extends uvm_agent;

  `uvm_component_utils(axi_agent)

  
  // AXI agent components
 

  axi_driver     driver;
  axi_sequencer  sequencer;
  axi_monitor    monitor;

  
  // Configuration object
 

  axi_agent_config cfg;

  
  // Constructor
  

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  
  // Build phase
  

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get AXI agent configuration
    if (!uvm_config_db #(axi_agent_config)::get(
          this, "", "axi_agent_config", cfg)) begin
      `uvm_fatal(get_type_name(),
        "axi_agent_config not found in uvm_config_db")
    end

    // Monitor is always created
    monitor = axi_monitor::type_id::create("monitor", this);

    // Active agent: create driver and sequencer
    if (cfg.is_active == UVM_ACTIVE) begin
      driver    = axi_driver::type_id::create("driver", this);
      sequencer = axi_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  
  // Connect phase
  

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect sequencer to driver only if active
    if (cfg.is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass : axi_agent

`endif // AXI_AGENT_SV

