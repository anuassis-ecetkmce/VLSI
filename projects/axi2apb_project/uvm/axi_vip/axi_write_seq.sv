`ifndef AXI_WRITE_SEQUENCES_SV
`define AXI_WRITE_SEQUENCES_SV

// --- Stress Sequence (No Delays) ---
class axi_write_stress_seq extends axi_sequence_base;
  `uvm_object_utils(axi_write_stress_seq)

  function new(string name="axi_write_stress_seq");
    super.new(name);
  endfunction

  task body();
    axi_transaction tr;
    repeat(15) begin
      tr = axi_transaction::type_id::create("tr");
      start_item(tr);
      if(!tr.randomize() with {
        addr inside {[32'h10000000:32'h4FFFFFFF]}; // Standardized Address
        is_write             == 1;
        pre_addr_delay       == 0;
        addr_to_data_gap     == 0;
        inter_beat_delay     == 0;
        wait_for_bresp_delay == 0;
      }) `uvm_error("SEQ", "Rand failed")
      finish_item(tr);
    end
  endtask
endclass

// --- Slow Master Sequence (High Delays) ---
class axi_write_slow_master_seq extends axi_sequence_base;
  `uvm_object_utils(axi_write_slow_master_seq)

  function new(string name="axi_write_slow_master_seq");
    super.new(name);
  endfunction

  task body();
    axi_transaction tr;
    repeat(10) begin
      tr = axi_transaction::type_id::create("tr");
      start_item(tr);
      if(!tr.randomize() with {
        addr inside {[32'h10000000:32'h4FFFFFFF]}; // Standardized Address
        is_write             == 1;
        pre_addr_delay       inside {[10:20]};
        addr_to_data_gap     inside {[15:30]};
        inter_beat_delay     inside {[5:10]};
        wait_for_bresp_delay inside {[10:25]};
      }) `uvm_error("SEQ", "Rand failed")
      finish_item(tr);
    end
  endtask
endclass

// --- Random Delay Sequence ---
class axi_write_random_delay_seq extends axi_sequence_base;
  `uvm_object_utils(axi_write_random_delay_seq)

  function new(string name="axi_write_random_delay_seq");
    super.new(name);
  endfunction

  task body();
    axi_transaction tr;
    repeat(20) begin
      tr = axi_transaction::type_id::create("tr");
      start_item(tr);
      if(!tr.randomize() with {
        addr inside {[32'h10000000:32'h4FFFFFFF]}; // Standardized Address
        is_write == 1;
      }) `uvm_error("SEQ", "Rand failed")
      finish_item(tr);
    end
  endtask
endclass

`endif