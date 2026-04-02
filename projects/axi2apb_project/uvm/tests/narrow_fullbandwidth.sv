`ifndef CFS_BRIDGE_NARROW_FULL_BAND_VSEQ_SV
`define CFS_BRIDGE_NARROW_FULL_BAND_VSEQ_SV

// This sequence handles both Narrow (8/16-bit) and Full (32-bit) transfers
class cfs_bridge_narrow_full_band_vseq extends cfs_bridge_virtual_sequence;
    
    `uvm_object_utils(cfs_bridge_narrow_full_band_vseq)

    // Constructor
    function new(string name = "cfs_bridge_narrow_full_band_vseq");
        super.new(name);
    endfunction

    // Main execution task
    virtual task body();
        axi_sequence_rw mixed_bus_seq;

        `uvm_info("VSEQ_MIXED", "Starting Mixed Band (Narrow & Full) Test...", UVM_LOW)

        // 1. Create the sequence object
        mixed_bus_seq = axi_sequence_rw::type_id::create("mixed_bus_seq");

        // 2. Randomize with Mixed Band Constraints
        if(!mixed_bus_seq.randomize() with {
            num_trans == 50;              // High count to ensure we hit all sizes
            
            // Testing 1-byte, 2-bytes, and 4-bytes (Full Band)
            axi_size inside {0, 1, 2};    
            
            // Testing Incremental bursts (shifts the 'lanes' across the bus)
            axi_burst_type == 1;          
            
            // Randomize Strobes to test cases like '3-lanes active'
            wstrb inside {[4'h1 : 4'hF]}; 
            
            // Keep addresses word-aligned to avoid bridge-specific alignment errors
            // (Unless you specifically want to test unaligned transfers)
            addr[1:0] == 2'b00;           
        }) begin
            `uvm_error("VSEQ_MIXED", "Randomization failed for Mixed Band Sequence!")
        end

        // 3. Start the sequence on the AXI sequencer handle from p_sequencer
        mixed_bus_seq.start(p_sequencer.axi_sqr);

        `uvm_info("VSEQ_MIXED", "Mixed Band (Narrow & Full) Test Completed.", UVM_LOW)
    endtask

endclass

`endif // CFS_BRIDGE_NARROW_FULL_BAND_VSEQ_SV
