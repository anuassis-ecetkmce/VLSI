`ifndef CFS_APB_DRIVER_SV
`define CFS_APB_DRIVER_SV

class cfs_apb_driver extends uvm_driver #(cfs_apb_item_drv);
    `uvm_component_utils(cfs_apb_driver)

    cfs_apb_agent_config agent_config;
  	cfs_apb_vif apb_vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
              
        drive_transactions();

    endtask

    protected virtual task drive_transactions();
      
 	    cfs_apb_vif apb_vif = agent_config.get_apb_vif();

        // Reset signals
        apb_vif.penable <= 0;
        apb_vif.psel    <= 0;
        apb_vif.pwrite  <= 0;
        apb_vif.paddr   <= 0;
        apb_vif.pwdata  <= 0;

        forever begin
            cfs_apb_item_drv item;
            seq_item_port.get_next_item(item);
            drive_apb(item);
            seq_item_port.item_done();
        end     
    endtask

  task drive_apb(cfs_apb_item_drv item);
      @(posedge apb_vif.pclk);

        // Address and control phase
        apb_vif.psel   <= 1;
        apb_vif.paddr  <= item.addr;
    	apb_vif.pwrite <= bit'(item.dir);
        apb_vif.pwdata <= item.wdata;
      @(posedge apb_vif.pclk);

        // Enable phase
        apb_vif.penable <= 1;
      @(posedge apb_vif.pclk);

        // Wait for ready
      wait (apb_vif.pready == 1);
    if (!item.dir)
        item.rdata = apb_vif.prdata;

        // Deassert signals
        apb_vif.psel    <= 0;
        apb_vif.penable <= 0;
        apb_vif.pwrite  <= 0;
        apb_vif.paddr   <= 0;
        apb_vif.pwdata  <= 0;
      @(posedge apb_vif.pclk);
    endtask

endclass

`endif
