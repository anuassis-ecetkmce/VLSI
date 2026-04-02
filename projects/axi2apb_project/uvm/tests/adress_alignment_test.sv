`ifndef CFS_BRIDGE_ADDRESS_ALIGN_VSEQ_SV
`define CFS_BRIDGE_ADDRESS_ALIGN_VSEQ_SV

// This sequence implements the "axi_sequence_address_align" from your test plan
class cfs_bridge_address_align_vseq extends cfs_bridge_virtual_sequence;
    
    `uvm_object_utils(cfs_bridge_address_align_vseq)

    // Constructor
    function new(string name = "cfs_bridge_address_align_vseq");
        super.new(name);
    endfunction

    // Main execution task
    virtual task body();
        axi_sequence_rw align_stress_seq;

        `uvm_info("VSEQ_ALIGN", "Starting Alignment Testing (1B, 2B, 4B sizes)...", UVM_LOW)

        // 1. Create the sequence object
        align_stress_seq = axi_sequence_rw::type_id::create("align_stress_seq");

        // 2. Randomize with UNALIGNED constraints
        if(!align_stress_seq.randomize() with {
            num_trans == 50;              // High count to hit all alignment combinations
            
            // --- THE ALIGNMENT KEY ---
            // We allow the last two bits to be 01, 10, or 11. 
            // This forces "Crooked" starting points.
            addr[1:0] inside {2'b00, 2'b01, 2'b10, 2'b11}; 

            // --- SIZE VARIATION (From your Config table) ---
            // 0=1-Byte (1B), 1=2-Bytes (2B), 2=4-Bytes (4B)
            axi_size inside {0, 1, 2};    

            // --- BURST SETTINGS ---
            axi_burst_type == 1;          // INCR burst
            
            // We start with shorter bursts (0-3) to isolate alignment math bugs
            axi_len inside {[0 : 3]};     

            // Randomize data to ensure integrity across shifted lanes
            foreach(data[i]) {
                data[i] inside {[32'h0000_0000 : 32'hFFFF_FFFF]};
            }
            
        }) begin
            `uvm_error("VSEQ_ALIGN", "Randomization failed for Alignment Sequence!")
        end

        // 3. Start the sequence
        align_stress_seq.start(p_sequencer.axi_sqr);

        `uvm_info("VSEQ_ALIGN", "Address Alignment Testing Completed.", UVM_LOW)
    endtask

endclass

`endif // CFS_BRIDGE_ADDRESS_ALIGN_VSEQ_SV