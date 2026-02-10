`ifndef AXI2APB_SCOREBOARD_SV
`define AXI2APB_SCOREBOARD_SV

// Macro to define the separate analysis ports
`uvm_analysis_imp_decl(_axi)
`uvm_analysis_imp_decl(_apb)

class axi2apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi2apb_scoreboard)

    // 1. Analysis ports to receive data from monitors
    uvm_analysis_imp_axi #(axi_transaction, axi2apb_scoreboard) axi_export;
    uvm_analysis_imp_apb #(cfs_apb_item_mon, axi2apb_scoreboard) apb_export;

    // 2. Queues to store incoming transactions
    axi_transaction    axi_queue[$];
    cfs_apb_item_mon   apb_queue[$];

    // Stats
    int match_count = 0;
    int error_count = 0;

    // Standard UVM Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // -------------------------------------------------------------------------
    // UVM Phases
    // -------------------------------------------------------------------------

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Proper UVM way: Initialize ports/exports during build_phase
        axi_export = new("axi_export", this);
        apb_export = new("apb_export", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Scoreboards usually don't have internal connections, 
        // but the phase is included for architectural consistency.
    endfunction

    // -------------------------------------------------------------------------
    // Implementation Functions
    // -------------------------------------------------------------------------

    // Capture AXI Transactions
    virtual function void write_axi(axi_transaction tr);
        axi_transaction copy;
        if (!$cast(copy, tr.clone())) begin
            `uvm_error("SCB_CLONE", "Failed to cast AXI transaction clone")
        end
        axi_queue.push_back(copy);
        check_data();
    endfunction

    // Capture APB Transactions
    virtual function void write_apb(cfs_apb_item_mon tr);
        cfs_apb_item_mon copy;
        if (!$cast(copy, tr.clone())) begin
            `uvm_error("SCB_CLONE", "Failed to cast APB transaction clone")
        end
        apb_queue.push_back(copy);
        check_data();
    endfunction

    // Comparison Logic
    virtual function void check_data();
        while (axi_queue.size() > 0) begin
            axi_transaction axi_tr = axi_queue[0];
            int expected_beats = axi_tr.len + 1;

            if (apb_queue.size() >= expected_beats) begin
                void'(axi_queue.pop_front());
                
                for (int i = 0; i < expected_beats; i++) begin
                    cfs_apb_item_mon apb_tr = apb_queue.pop_front();
                    
                    // Logic assumes 4-byte aligned INCR bursts
                    bit [31:0] expected_addr = axi_tr.addr + (i * 4); 

                    // 1. Compare Direction
                    if (bit'(apb_tr.dir) != axi_tr.is_write) begin
                        `uvm_error("SCB_MISMATCH", $sformatf("Direction Mismatch! AXI Write: %0b, APB Dir: %0s", axi_tr.is_write, apb_tr.dir.name()))
                        error_count++;
                    end

                    // 2. Compare Address
                    if (apb_tr.addr != expected_addr) begin
                        `uvm_error("SCB_MISMATCH", $sformatf("Address Mismatch! Beat %0d, Expected: 0x%0h, Actual: 0x%0h", i, expected_addr, apb_tr.addr))
                        error_count++;
                    end

                    // 3. Compare Data
                    if (axi_tr.is_write) begin
                        if (apb_tr.wdata != axi_tr.data_ary[i]) begin
                            `uvm_error("SCB_MISMATCH", $sformatf("Write Data Mismatch! Beat %0d, Exp: 0x%0h, Act: 0x%0h", i, axi_tr.data_ary[i], apb_tr.wdata))
                            error_count++;
                        end
                    end else begin
                        if (apb_tr.rdata != axi_tr.data_ary[i]) begin
                            `uvm_error("SCB_MISMATCH", $sformatf("Read Data Mismatch! Beat %0d, Exp: 0x%0h, Act: 0x%0h", i, axi_tr.data_ary[i], apb_tr.rdata))
                            error_count++;
                        end
                    end
                    match_count++;
                end
                `uvm_info("SCB_MATCH", $sformatf("Verified AXI Addr 0x%0h with %0d beats", axi_tr.addr, expected_beats), UVM_MEDIUM)
            end else begin
                break; // Wait for more APB beats
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("SCB_REPORT", $sformatf("Verification Complete: Matches=%0d, Errors=%0d", match_count, error_count), UVM_LOW)
        if (axi_queue.size() > 0 || apb_queue.size() > 0) begin
            `uvm_warning("SCB_REPORT", $sformatf("Dangling transactions! AXI:%0d, APB:%0d", axi_queue.size(), apb_queue.size()))
        end
    endfunction

endclass
`endif 
