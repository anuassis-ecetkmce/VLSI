`ifndef CFS_APB_DRIVER_SV
`define CFS_APB_DRIVER_SV

class cfs_apb_driver extends uvm_driver #(cfs_apb_trans);
    `uvm_component_utils(cfs_apb_driver)

    cfs_apb_agent_config agent_config;

    cfs_apb_vif vif = agent_config.get_vif();

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "Virtual interface must be set for: " + get_full_name())
    endfunction

    task run_phase(uvm_phase phase);
        
        drive_transactions();

    endtask

    protected virtual task drive_transactions();

        // Reset signals
        vif.penable <= 0;
        vif.psel    <= 0;
        vif.pwrite  <= 0;
        vif.paddr   <= 0;
        vif.pwdata  <= 0;

        forever begin
            cfs_apb_item_drv item;
            seq_item_port.get_next_item(item);
            drive_apb(item);
            seq_item_port.item_done();
        end     
    endtask

    task drive_apb(cfs_apb_item_drv req);
        @(posedge vif.pclk);

        // Address and control phase
        vif.psel   <= 1;
        vif.paddr  <= req.addr;
        vif.pwrite <= req.write;
        vif.pwdata <= req.wdata;
        @(posedge vif.pclk);

        // Enable phase
        vif.penable <= 1;
        @(posedge vif.pclk);

        // Wait for ready
        wait (vif.pready == 1);
        if (!item.write)
        item.rdata = vif.prdata;

        // Deassert signals
        vif.psel    <= 0;
        vif.penable <= 0;
        vif.pwrite  <= 0;
        vif.paddr   <= 0;
        vif.pwdata  <= 0;
        @(posedge vif.pclk);
    endtask

endclass

`endif
