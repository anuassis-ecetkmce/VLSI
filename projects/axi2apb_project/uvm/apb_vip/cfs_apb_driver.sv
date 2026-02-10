`ifndef CFS_APB_DRIVER_SV
`define CFS_APB_DRIVER_SV

class cfs_apb_driver extends uvm_driver #(cfs_apb_item_drv);
    `uvm_component_utils(cfs_apb_driver)

    cfs_apb_agent_config apb_agent_config;
  	cfs_apb_vif apb_vif;
  
    // Memory model for slave behavior
    bit [31:0] slave_memory[bit [31:0]];
  
  	// Control knobs
    bit enable_response = 1;
    int default_response_delay = 0;
    bit default_error_response = 0;
  
  	// Timeout control
    int transaction_timeout_cycles = 100; // Default timeout cycles
    bit enable_timeout_check = 1; // Enable timeout checking

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      	apb_vif = apb_agent_config.get_apb_vif();
              
        // Initialize signals
        initialize_signals();
        
        // Start response handler
        fork
            handle_reset();
            process_responses();
        join_none
    endtask
    
    task initialize_signals();
        apb_vif.pready <= 0;
        apb_vif.prdata <= 0;
        apb_vif.pslverr <= 0;
    endtask
  
  	task handle_reset();
        forever begin
            @(negedge apb_vif.presetn);
            initialize_signals();
            @(posedge apb_vif.presetn);
        end
    endtask
  
  	task process_responses();
        cfs_apb_item_drv item;
        
        forever begin
            // Wait for transaction initiation by DUT
            wait_for_transaction();
            
            // Get response configuration from sequence (if any)
          	get_response_config(item);
            
            // Generate response
          generate_response(item);
        end
    endtask
  
  	task wait_for_transaction();
        // Wait for PSEL asserted (start of transaction)
      @(posedge apb_vif.pclk iff (apb_vif.psel === 1'b1 && apb_vif.penable === 1'b0));
        
        `uvm_info("DRIVER", $sformatf("Transaction detected: %s @ 0x%0h", 
            apb_vif.pwrite ? "WRITE" : "READ", apb_vif.paddr), UVM_HIGH)
    endtask
  
  	task get_response_config(ref cfs_apb_item_drv item);
        // Try to get response configuration from sequence
    	seq_item_port.try_next_item(item);
        
    	if (item == null) begin
    		// Use default configuration
        	item = cfs_apb_item_drv::type_id::create("default_rsp");
        	item.pre_drive_delay = get_default_delay();
            item.rdata = get_read_data(apb_vif.paddr);
        end else begin
            seq_item_port.item_done();
        end
    endtask
    
  task generate_response(cfs_apb_item_drv item);
        int delay_cycles;
        bit inject_error;
        
        // Determine delay cycles
        if (apb_agent_config.enable_response_delay) begin
          if (item.pre_drive_delay > 0) begin
                delay_cycles = item.pre_drive_delay;
          end else if (apb_agent_config.enable_random_delay) begin
                delay_cycles = $urandom_range(
                    apb_agent_config.min_response_delay,
                    apb_agent_config.max_response_delay
                );
          end else begin
                delay_cycles = apb_agent_config.min_response_delay;
          end
        end else begin
            delay_cycles = 0;
        end
        
        // Determine if we should inject error
        if (apb_agent_config.enable_error_injection) begin
            int rand_val = $urandom_range(0, 99);
            inject_error = (rand_val < apb_agent_config.error_injection_percentage);
        end else begin
            inject_error = default_error_response;
        end
        
        // Apply wait states (if any)
        apply_wait_states(delay_cycles);
        
        // Drive response
        drive_response(item, inject_error);
        
        // Complete transaction
        wait_for_transaction_end();
        
        // Clean up signals
        cleanup_signals();
    endtask
          
    task apply_wait_states(int cycles);
        for (int i = 0; i < cycles; i++) begin
            apb_vif.pready <= 1'b0;
            @(posedge apb_vif.pclk);
        end
    endtask
          
    task drive_response(cfs_apb_item_drv item, bit inject_error);
        // Assert PREADY to complete transfer
        apb_vif.pready <= 1'b1;
        
        // Set error response if needed
        apb_vif.pslverr <= inject_error ? 1'b1 : 1'b0;
        
        // For read transactions, drive data
        if (!apb_vif.pwrite) begin
            if (!inject_error) begin
                apb_vif.prdata <= item.rdata;
            end else begin
                apb_vif.prdata <= 'hDEADBEEF; // Error pattern
            end
        end else begin
            // For write transactions, store data in memory if no error
            if (!inject_error) begin
                slave_memory[apb_vif.paddr] = apb_vif.pwdata;
                `uvm_info("DRIVER", $sformatf("Stored 0x%0h at address 0x%0h", 
                    apb_vif.pwdata, apb_vif.paddr), UVM_HIGH)
            end
        end
    endtask
  
  	task wait_for_transaction_end();
      
      	int cycle_count = 0;
        bit timeout_occurred = 0;
        
        fork
            //Wait for normal APB completion (PSEL goes low)
            begin
                wait(apb_vif.psel === 1'b0);
                `uvm_info("DRIVER", "Transaction completed normally (PSEL=0)", UVM_HIGH)
            end
            
            //Wait for PENABLE to go low (alternative protocol)
            begin
                wait(apb_vif.penable === 1'b0);
                `uvm_info("DRIVER", "Transaction completed (PENABLE=0)", UVM_HIGH)
            end
            
            //Timeout protection with UVM error
            if (enable_timeout_check) begin
                begin
                    while (cycle_count < transaction_timeout_cycles) begin
                        @(posedge apb_vif.pclk);
                        cycle_count++;
                        
                        // Check if transaction is still active
                        if (apb_vif.psel === 1'b0 || apb_vif.penable === 1'b0) begin
                            break;
                        end
                    end
                    
                    if (cycle_count >= transaction_timeout_cycles && 
                        apb_vif.psel === 1'b1) begin
                        timeout_occurred = 1;
                        `uvm_error("APB_TIMEOUT", 
                            $sformatf("APB transaction timeout after %0d cycles! PSEL=1, PENABLE=%0d, PADDR=0x%0h", 
                            transaction_timeout_cycles, apb_vif.penable, apb_vif.paddr))
                    end
                end
            end
        join_any
        
        // Kill all parallel processes
        disable fork;
        
        if (timeout_occurred) begin
            // Additional recovery actions can be added here
            @(posedge apb_vif.pclk);
        end else begin
            `uvm_info("DRIVER", $sformatf("Transaction completed in %0d cycles", cycle_count), UVM_HIGH)
            @(posedge apb_vif.pclk);  // Clean handoff
        end

        // Wait for master to complete transaction
        // (PSEL goes low or PENABLE goes low depending on protocol)
      	fork
        	wait(apb_vif.psel === 1'b0);           // Normal APB completion
        	wait(apb_vif.penable === 1'b0);        // Alternative
        	repeat(10) @(posedge apb_vif.pclk);    // Timeout protection
        	@(posedge apb_vif.pclk);              // Simple one-cycle wait
    	join_any
    	disable fork;  // Kill other waiting processes
    	@(posedge apb_vif.pclk);  // Clean handoff
    endtask
    
    task cleanup_signals();
        apb_vif.pready <= 1'b0;
        apb_vif.pslverr <= 1'b0;
        if (!apb_vif.pwrite) begin
            apb_vif.prdata <= 'h0; // Stop driving read data
        end
    endtask
    
          
    function int get_default_delay();
        if (apb_agent_config.enable_random_delay) begin
            return $urandom_range(
                apb_agent_config.min_response_delay,
                apb_agent_config.max_response_delay
            );
        end else begin
            return apb_agent_config.min_response_delay;
        end
    endfunction
    
    function bit [31:0] get_read_data(bit [31:0] addr);
      if (slave_memory.exists(addr)) begin
            return slave_memory[addr];
        end else begin
            // Return random data for uninitialized addresses
            bit [31:0] rand_data;
            void'(std::randomize(rand_data));
            return rand_data;
        end
    endfunction
    
    // Helper method for sequences to preload memory
    function void write_memory(bit [31:0] addr, bit [31:0] data);
        slave_memory[addr] = data;
        `uvm_info("DRIVER", $sformatf("Preloaded 0x%0h at address 0x%0h", data, addr), UVM_MEDIUM)
    endfunction
    
    function bit [31:0] read_memory(bit [31:0] addr);
      if (slave_memory.exists(addr)) begin
            return slave_memory[addr];
        end else begin
            `uvm_warning("MEM", $sformatf("Address 0x%0h not initialized", addr))
            return 'h0;
        end
    endfunction
          
endclass

`endif
