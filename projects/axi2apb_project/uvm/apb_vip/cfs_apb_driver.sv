`ifndef CFS_APB_DRIVER_SV
`define CFS_APB_DRIVER_SV

class cfs_apb_driver extends uvm_driver #(cfs_apb_item_drv);
    `uvm_component_utils(cfs_apb_driver)

    cfs_apb_agent_config apb_agent_config;
    cfs_apb_vif apb_vif;

    // Memory model for slave behavior
    bit [31:0] slave_memory[bit [31:0]];

    // Control knobs
    bit enable_response        = 1;
    int default_response_delay = 0;
    bit default_error_response = 0;

    // Timeout control
    int transaction_timeout_cycles = 100;
    bit enable_timeout_check       = 1;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        apb_vif = apb_agent_config.get_apb_vif();
        initialize_signals();
        fork
            handle_reset();
            process_responses();
        join_none
    endtask

    //------------------------------------------------------------------
    task initialize_signals();
        apb_vif.pready  <= 0;
        apb_vif.prdata  <= 0;
        apb_vif.pslverr <= 0;
    endtask

    //------------------------------------------------------------------
    task handle_reset();
        forever begin
            @(negedge apb_vif.presetn);
            initialize_signals();
            @(posedge apb_vif.presetn);
        end
    endtask

    //------------------------------------------------------------------
    task process_responses();
        cfs_apb_item_drv item;
        forever begin
            wait_for_transaction();
            get_response_config(item);
            generate_response(item);
        end
    endtask

    //------------------------------------------------------------------
    // SETUP phase: psel asserted, penable still low
    task wait_for_transaction();
        @(posedge apb_vif.pclk iff (apb_vif.psel !== '0 &&
                                     apb_vif.penable === 1'b0));
        `uvm_info("DRIVER", $sformatf("Transaction detected: %s @ 0x%0h",
            apb_vif.pwrite ? "WRITE" : "READ", apb_vif.paddr), UVM_LOW)
    endtask

    //------------------------------------------------------------------
    task get_response_config(ref cfs_apb_item_drv item);
        seq_item_port.try_next_item(item);
        if (item == null) begin
            item = cfs_apb_item_drv::type_id::create("default_rsp");
            item.pre_drive_delay = get_default_delay();
            item.rdata           = get_read_data(apb_vif.paddr);
        end else begin
            seq_item_port.item_done();
        end
    endtask

    //------------------------------------------------------------------
    task generate_response(cfs_apb_item_drv item);
        int delay_cycles;
        bit inject_error;

        // Determine delay cycles
        if (apb_agent_config.enable_response_delay) begin
            if (item.pre_drive_delay > 0)
                delay_cycles = item.pre_drive_delay;
            else if (apb_agent_config.enable_random_delay)
                delay_cycles = $urandom_range(apb_agent_config.min_response_delay,
                                              apb_agent_config.max_response_delay);
            else
                delay_cycles = apb_agent_config.min_response_delay;
        end else begin
            delay_cycles = 0;
        end

        // Determine error injection
        if (apb_agent_config.enable_error_injection) begin
            int rand_val = $urandom_range(0, 99);
            inject_error = (rand_val < apb_agent_config.error_injection_percentage);
        end else begin
            inject_error = default_error_response;
        end

        // *** Wait for ACCESS phase ONCE here ***
        @(posedge apb_vif.pclk iff (apb_vif.penable === 1'b1 &&
                                     apb_vif.psel !== '0));

        // Apply wait states then drive response
        apply_wait_states(delay_cycles);
        drive_response(item, inject_error);
        wait_for_transaction_end();
        cleanup_signals();
    endtask

    //------------------------------------------------------------------
    // No edge-wait here — already consumed in generate_response
    task apply_wait_states(int cycles);
        for (int i = 0; i < cycles; i++) begin
            apb_vif.pready <= 1'b0;
            @(posedge apb_vif.pclk);
        end
    endtask

    //------------------------------------------------------------------
    // No edge-wait here — already consumed in generate_response
    task drive_response(cfs_apb_item_drv item, bit inject_error);
        apb_vif.pready  <= 1'b1;
        apb_vif.pslverr <= inject_error ? 1'b1 : 1'b0;

        if (!apb_vif.pwrite) begin
            apb_vif.prdata <= (!inject_error) ? item.rdata : 'hDEADBEEF;
        end else begin
            if (!inject_error) begin
                slave_memory[apb_vif.paddr] = apb_vif.pwdata;
                `uvm_info("DRIVER", $sformatf("Stored 0x%0h at 0x%0h",
                    apb_vif.pwdata, apb_vif.paddr), UVM_HIGH)
            end
        end
    endtask

    //------------------------------------------------------------------
    task wait_for_transaction_end();
        int cycle_count    = 0;
        bit timeout_occurred = 0;

        fork
            // Branch 1: Normal APB completion — psel deasserts
            begin
                wait(apb_vif.psel === '0);
                `uvm_info("DRIVER", "Transaction completed (PSEL=0)", UVM_LOW)
            end

            // Branch 2: penable goes low
            begin
                wait(apb_vif.penable === 1'b0);
                `uvm_info("DRIVER", "Transaction completed (PENABLE=0)", UVM_HIGH)
            end

            // Branch 3: Timeout protection
            begin
                repeat(transaction_timeout_cycles) @(posedge apb_vif.pclk);
                if (apb_vif.psel !== '0) begin
                    timeout_occurred = 1;
                    `uvm_error("APB_TIMEOUT",
                        $sformatf("Timeout after %0d cycles! PADDR=0x%0h",
                        transaction_timeout_cycles, apb_vif.paddr))
                end
            end
        join_any
        disable fork;

        @(posedge apb_vif.pclk); // Clean handoff
    endtask

    //------------------------------------------------------------------
    task cleanup_signals();
        apb_vif.pready  <= 1'b0;
        apb_vif.pslverr <= 1'b0;
        if (!apb_vif.pwrite)
            apb_vif.prdata <= '0;
    endtask

    //------------------------------------------------------------------
    function int get_default_delay();
        if (apb_agent_config.enable_random_delay)
            return $urandom_range(apb_agent_config.min_response_delay,
                                  apb_agent_config.max_response_delay);
        else
            return apb_agent_config.min_response_delay;
    endfunction

    //------------------------------------------------------------------
    function bit [31:0] get_read_data(bit [31:0] addr);
        if (slave_memory.exists(addr)) begin
            return slave_memory[addr];
        end else begin
            bit [31:0] rand_data;
            void'(std::randomize(rand_data));
            return rand_data;
        end
    endfunction

    //------------------------------------------------------------------
    function void write_memory(bit [31:0] addr, bit [31:0] data);
        slave_memory[addr] = data;
        `uvm_info("DRIVER", $sformatf("Preloaded 0x%0h at 0x%0h", data, addr), UVM_MEDIUM)
    endfunction

    //------------------------------------------------------------------
    function bit [31:0] read_memory(bit [31:0] addr);
        if (slave_memory.exists(addr)) begin
            return slave_memory[addr];
        end else begin
            `uvm_warning("MEM", $sformatf("Address 0x%0h not initialized", addr))
            return '0;
        end
    endfunction

endclass
`endif
