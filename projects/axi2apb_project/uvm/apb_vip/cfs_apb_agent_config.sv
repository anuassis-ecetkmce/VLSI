// APB Agent Configuration Class
// UVM 1.2 Version
// For AXI to APB Bridge Verification

`ifndef CFS_APB_AGENT_CONFIG_SV
`define CFS_APB_AGENT_CONFIG_SV

class cfs_apb_agent_config extends uvm_component;

    // Register with UVM factory
    `uvm_component_utils(cfs_apb_agent_config)

    // Configuration parameters
    local cfs_apb_vif apb_vif;
    
    // Agent mode: UVM_ACTIVE or UVM_PASSIVE
    local uvm_active_passive_enum active_passive;
    
    // APB Interface signals configuration
    bit has_coverage = 1;
    bit has_functional_coverage = 1;
    bit has_assertion_coverage = 0;
    
    // APB Protocol parameters
    int unsigned apb_addr_width = 32;
    int unsigned apb_data_width = 32;
    int unsigned apb_strobe_width = 4;
    
    // Timing and behavior parameters
    bit enable_response_delay = 1;
    int unsigned min_response_delay = 0;
    int unsigned max_response_delay = 10;
    
    // Wait states configuration
    bit enable_wait_states = 1;
    int unsigned min_wait_states = 0;
    int unsigned max_wait_states = 5;
    
    // Error injection configuration
    bit enable_error_injection = 0;
    int unsigned error_injection_percentage = 5;
  
  
    // Constructor
    function new(string name = "", uvm_component parent);
        super.new(name, parent);

        active_passive = UVM_ACTIVE;
    endfunction : new

    virtual function cfs_apb_vif get_apb_vif();
        return apb_vif;
    endfunction

    virtual function void set_apb_vif(cfs_apb_vif value);
      if(apb_vif == null) begin
            apb_vif = value;
        end
        else begin
            `uvm_fatal("ALGORITHM_ISSUE", "Trying to set the APB virtual interface more than once")
        end
    endfunction

    virtual function uvm_active_passive_enum get_active_passive();
        return active_passive;
    endfunction
        
    virtual function void set_active_passive(uvm_active_passive_enum value);
        active_passive = value;
    endfunction

    virtual function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        
      if(get_apb_vif == null) begin
          `uvm_fatal("ALGORITHM_ISSUE", "the APB virtual interface is not configured at \"start of simulation\" phase")
        end
        else begin
          `uvm_info("APB_CONFIG", "The APB virtual interface is configured at \"start of simulation\" phase", UVM_LOW)
        end
    endfunction
  /*
  // Convert to string method for printing configuration
  virtual function string convert2string();
    string s = "";
    s = {s, "\n"};
    s = {s, "=== APB Agent Configuration ===\n"};
    s = {s, $sformatf("is_active                : %s\n", is_active.name())};
    s = {s, $sformatf("has_coverage             : %0b\n", has_coverage)};
    s = {s, $sformatf("has_functional_coverage  : %0b\n", has_functional_coverage)};
    s = {s, $sformatf("has_assertion_coverage   : %0b\n", has_assertion_coverage)};
    s = {s, $sformatf("apb_addr_width           : %0d\n", apb_addr_width)};
    s = {s, $sformatf("apb_data_width           : %0d\n", apb_data_width)};
    s = {s, $sformatf("apb_strobe_width         : %0d\n", apb_strobe_width)};
    s = {s, $sformatf("enable_response_delay    : %0b\n", enable_response_delay)};
    s = {s, $sformatf("min_response_delay       : %0d\n", min_response_delay)};
    s = {s, $sformatf("max_response_delay       : %0d\n", max_response_delay)};
    s = {s, $sformatf("enable_wait_states       : %0b\n", enable_wait_states)};
    s = {s, $sformatf("min_wait_states          : %0d\n", min_wait_states)};
    s = {s, $sformatf("max_wait_states          : %0d\n", max_wait_states)};
    s = {s, $sformatf("enable_error_injection   : %0b\n", enable_error_injection)};
    s = {s, $sformatf("error_injection_percent  : %0d\n", error_injection_percentage)};
    return s;
  endfunction : convert2string
  
  // Copy method
  virtual function void copy(uvm_object rhs);
    cfs_apb_agent_config cfg;
    if (!$cast(cfg, rhs)) begin
      `uvm_fatal("COPY", "Cannot cast rhs to cfs_apb_agent_config")
    end
    this.is_active = cfg.is_active;
    this.has_coverage = cfg.has_coverage;
    this.has_functional_coverage = cfg.has_functional_coverage;
    this.has_assertion_coverage = cfg.has_assertion_coverage;
    this.apb_addr_width = cfg.apb_addr_width;
    this.apb_data_width = cfg.apb_data_width;
    this.apb_strobe_width = cfg.apb_strobe_width;
    this.enable_response_delay = cfg.enable_response_delay;
    this.min_response_delay = cfg.min_response_delay;
    this.max_response_delay = cfg.max_response_delay;
    this.enable_wait_states = cfg.enable_wait_states;
    this.min_wait_states = cfg.min_wait_states;
    this.max_wait_states = cfg.max_wait_states;
    this.enable_error_injection = cfg.enable_error_injection;
    this.error_injection_percentage = cfg.error_injection_percentage;
    this.apb_if = cfg.apb_if;
  endfunction : copy
  
  // Comparison method
  virtual function bit compare(uvm_object rhs);
    cfs_apb_agent_config cfg;
    if (!$cast(cfg, rhs)) begin
      return 0;
    end
    return (this.is_active == cfg.is_active &&
            this.has_coverage == cfg.has_coverage &&
            this.apb_addr_width == cfg.apb_addr_width &&
            this.apb_data_width == cfg.apb_data_width &&
            this.apb_strobe_width == cfg.apb_strobe_width &&
            this.enable_response_delay == cfg.enable_response_delay &&
            this.min_response_delay == cfg.min_response_delay &&
            this.max_response_delay == cfg.max_response_delay &&
            this.enable_wait_states == cfg.enable_wait_states &&
            this.min_wait_states == cfg.min_wait_states &&
            this.max_wait_states == cfg.max_wait_states &&
            this.enable_error_injection == cfg.enable_error_injection &&
            this.error_injection_percentage == cfg.error_injection_percentage);
  endfunction : compare
*/
endclass

`endif // CFS_APB_AGENT_CONFIG_SV
