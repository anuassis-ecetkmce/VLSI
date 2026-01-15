`ifndef CFS_APB_MONITOR_SV
	`define CFS_APB_MONITOR_SV

class cfs_apb_monitor extends uvm_monitor;
  
  uvm_analysis_port#(cfs_apb_item_mon) output_port;
  
  //pointer to the agent configuration
  cfs_apb_agent_config agent_config;
  
  `uvm_component_utils(cfs_apb_monitor)
  
  function new(string name = "", uvm_component parent);
    super.new(name, parent);
    
    output_port = new("output_port", this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    collect_transactions();
  endtask
  
  protected virtual task collect_transactions();
    
    forever begin
      collect_transaction();
    end
    
  endtask
  
  protected virtual task collect_transaction();
  	cfs_apb_vif apb_vif = agent_config.get_apb_vif();
    cfs_apb_item_mon item = cfs_apb_item_mon::type_id::create("item");
    
    while(apb_vif.psel !== 1) begin
      @(posedge apb_vif.pclk);
      item.prev_item_delay++;
    end
    
    item.addr = apb_vif.paddr;
    item.dir = cfs_apb_dir'(apb_vif.pwrite);
    
    if(item.dir == CFS_APB_WRITE) begin
      item.wdata = apb_vif.pwdata;
    end
    
    item.length = 1;
    
    @(posedge apb_vif.pclk);
    item.length++;
    
    while(apb_vif.pready !== 1) begin
      @(posedge apb_vif.pclk);
      item.length++;
    end
    
    item.response = cfs_apb_response'(apb_vif.pslverr);
    
    if(item.dir == CFS_APB_READ) begin
      item.rdata = apb_vif.prdata;
    end

    output_port.write(item);
    
    `uvm_info("DEBUG", $sformatf("Monitored item: Dir: \"%0s\", Addr: %0x%0s", item.dir.name(), item.addr,  item.convert2string()), UVM_NONE)
    
    @(posedge apb_vif.pclk);
    
  endtask
  
endclass

`endif