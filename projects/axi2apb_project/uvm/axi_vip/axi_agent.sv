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
  axi_agent_config axi_cfg;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get AXI agent configuration
    axi_cfg = axi_agent_config::type_id::create("cfg", this);

    // Monitor is always created
    monitor = axi_monitor::type_id::create("monitor", this);

    // Active agent: create driver and sequencer
    if (axi_cfg.get_active_passive() == UVM_ACTIVE) begin
      driver    = axi_driver::type_id::create("driver", this);
      sequencer = axi_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  
  // Connect phase
  function void connect_phase(uvm_phase phase);
    virtual axi_if axi_vif;

    super.connect_phase(phase);

    if (!uvm_config_db#(virtual axi_if)::get(this, "", "axi_vif", axi_vif)) begin
       `uvm_fatal("AXI_NO_VIF", "Could not get AXI virtual interface from uvm_config_db")
    end
    else begin
      axi_cfg.set_axi_vif(axi_vif);
    end

    // Pass configuration to monitor
    monitor.axi_cfg = axi_cfg; // Assuming monitor has a 'cfg' handle
    // Pass virtual interface to monitor (if monitor uses it directly)
    // monitor.vif = cfg.get_vif(); 

    // Connect sequencer to driver only if active
    if (axi_cfg.get_active_passive() == UVM_ACTIVE) begin
       driver.axi_cfg = axi_cfg; // Pass config to driver
       driver.seq_item_port.connect(sequencer.seq_item_export);
       
       // Pass virtual interface to driver via config DB or direct handle assignment
       // Direct assignment is preferred if driver has 'vif' handle:
       // driver.vif = cfg.get_vif(); 
       
       // OR if you use sub-component config_db setting (Legacy way):
      uvm_config_db#(virtual axi_if)::set(this, "driver", "vif", axi_cfg.get_axi_vif());
    end
    
    // Also set for monitor if using config_db method
    uvm_config_db#(virtual axi_if)::set(this, "monitor", "vif", axi_cfg.get_axi_vif());

  endfunction

endclass : axi_agent

`endif // AXI_AGENT_SV


