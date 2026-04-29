`ifndef CFS_BRIDGE_REG_ACCESS_VSEQ_SV
`define CFS_BRIDGE_REG_ACCESS_VSEQ_SV

class cfs_bridge_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(cfs_bridge_virtual_sequence)

  // This macro gives us access to p_sequencer.axi_sqr
  `uvm_declare_p_sequencer(cfs_bridge_virtual_sequencer)

    bit rw_seq = 1;
    bit wr_stress_seq = 1;
    bit wr_slow_seq = 1;
    bit wr_rand_seq = 1;
    bit rd_rand_seq = 1;

    function new(string name = "cfs_bridge_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        // Move all your sequence declarations here
        axi_sequence_rw            seq_rw;
        axi_write_stress_seq       seq_write;
        axi_write_slow_master_seq  seq_slow_wr;
        axi_write_random_delay_seq seq_rand_wr;

        if(rw_seq) begin
            #300ns;
            seq_rw = axi_sequence_rw::type_id::create("seq_rw");
            void'(seq_rw.randomize() with{num_trans == 6;});
            // Start it on the AXI sequencer via the virtual sequencer pointer
            seq_rw.start(p_sequencer.axi_sqr);
        end

        if(wr_stress_seq) begin
            #200ns;
            seq_write = axi_write_stress_seq::type_id::create("seq_write");
            seq_write.start(p_sequencer.axi_sqr);
        end

        if(wr_slow_seq) begin
            #200ns;
            seq_slow_wr = axi_write_slow_master_seq::type_id::create("seq_slow_wr");
            seq_slow_wr.start(p_sequencer.axi_sqr);
        end

        if(wr_rand_seq) begin
            #200ns;
            seq_rand_wr = axi_write_random_delay_seq::type_id::create("seq_rand_wr");
            seq_rand_wr.start(p_sequencer.axi_sqr);
        end
    endtask
endclass
`endif
