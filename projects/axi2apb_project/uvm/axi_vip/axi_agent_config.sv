`ifndef AXI_AGENT_CONFIG_SV
`define AXI_AGENT_CONFIG_SV


class axi_agent_config extends uvm_component;

  `uvm_component_utils(axi_agent_config)

  // -- Configuration Fields --
  
  // Virtual interface handle (Made local to enforce use of setter/getter)
  local cfs_axi_vif axi_vif;

  // Active or passive agent
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  // Enable/disable coverage
  bit enable_coverage = 1'b1;

  // AXI interface parameters
  int unsigned id_width   = AXI_ID_WIDTH;
  int unsigned addr_width = AXI_ADDR_WIDTH;
  int unsigned data_width = AXI_DATA_WIDTH;

  // AXI protocol-related defaults
  axi_burst_t default_burst = AXI_BURST_INCR;
  axi_size_t  default_size  = AXI_SIZE_4B;
  int unsigned max_outstanding_txn = 8;

  // Constructor
  function new(string name = "",uvm_component parent );
    super.new(name, parent);
    
  endfunction

  // -- Accessor Methods (Matches APB Style) --

  // Get Virtual Interface
  virtual function cfs_axi_vif get_axi_vif();
    return axi_vif;
  endfunction

  // Set Virtual Interface (with check)
  virtual function void set_axi_vif(cfs_axi_vif value);
    if(axi_vif == null) begin
      axi_vif = value;
    end
    else begin
      `uvm_warning("AXI_CONFIG", "Overwriting existing AXI virtual interface")
      axi_vif = value;
    end
  endfunction

  // Active/Passive Getter
  virtual function uvm_active_passive_enum get_active_passive();
    return is_active;
  endfunction
  
  virtual function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        
    if(get_axi_vif() == null) begin
      `uvm_fatal("ALGORITHM_ISSUE", "the AXI virtual interface is not configured at \"start of simulation\" phase")
        end
        else begin
          `uvm_info("AXI_CONFIG", "The AXI virtual interface is configured at \"start of simulation\" phase", UVM_LOW)
        end
    endfunction
  
  

endclass : axi_agent_config

`endif // AXI_AGENT_CONFIG_SV

