`ifndef CFS_BRIDGE_BURST_VARIATION_VSEQ_SV
`define CFS_BRIDGE_BURST_VARIATION_VSEQ_SV

// This sequence specifically stresses Burst Lengths and Data Widths
class cfs_bridge_burst_variation_vseq extends cfs_bridge_virtual_sequence;
    
    `uvm_object_utils(cfs_bridge_burst_variation_vseq)

    // Constructor
    function new(string name = "cfs_bridge_burst_variation_vseq");
        super.new(name);
    endfunction

    virtual task body();
        axi_sequence_rw burst_stress_seq;

        `uvm_info("VSEQ_BURST", "Starting Burst Length & Data Width Stress Test...", UVM_LOW)

        // 1. Create the sequence
        burst_stress_seq = axi_sequence_rw::type_id::create("burst_stress_seq");

        // 2. Randomize with Focus on Length and Data Variation
        if(!burst_stress_seq.randomize() with {
            num_trans == 30;              // 30 independent bursts
            
            // --- DATA WIDTH VARIATION ---
            // Randomly pick 8-bit, 16-bit, or 32-bit for each burst
            axi_size inside {0, 1, 2};    
            
            // --- BURST SIZE (LENGTH) VARIATION ---
            // AXI_LEN 0 = 1 beat, 15 = 16 beats. 
            // This tests the Bridge's internal address incrementer.
            axi_len inside {[0 : 15]};    

            // --- DATA VALUE STRESS ---
            // Ensure we aren't just sending 0s; we want to toggle every bit.
            foreach(data[i]) {
                data[i] inside {[32'h0000_0000 : 32'hFFFF_FFFF]};
            }

            // --- PROTOCOL SETTINGS ---
            axi_burst_type == 1;          // INCR (Required for multi-beat bursts)
            wstrb == 4'hF;                // Keeping strobes FULL to focus on Length/Width
            addr[1:0] == 2'b00;           // Keep aligned to isolate Burst/Size issues
            
        }) begin
            `uvm_error("VSEQ_BURST", "Randomization failed for Burst Stress Sequence!")
        end

        // 3. Start the sequence
        burst_stress_seq.start(p_sequencer.axi_sqr);

        `uvm_info("VSEQ_BURST", "Burst Length & Data Width Stress Test Completed.", UVM_LOW)
    endtask

endclass

`endif // CFS_BRIDGE_BURST_VARIATION_VSEQ_SV