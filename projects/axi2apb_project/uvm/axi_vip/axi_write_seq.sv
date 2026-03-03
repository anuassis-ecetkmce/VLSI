`ifndef AXI_WRITE_SEQUENCES_SV
`define AXI_WRITE_SEQUENCES_SV

// ---------------------------------------------------------------------------
// 1. STRESS SEQUENCE: High throughput, zero delays
// ---------------------------------------------------------------------------
class axi_write_stress_seq extends axi_sequence_base;
  `uvm_object_utils(axi_write_stress_seq)
  
  function new(string name = "axi_write_stress_seq");
    super.new(name);
  endfunction

  task body();
    axi_transaction tr;
    `uvm_info("SEQ", "Starting Stress Write Sequence (Zero Delay)", UVM_LOW)
    repeat(15) begin
      tr = axi_transaction::type_id::create("tr");
      start_item(tr);
      if(!tr.randomize() with {
        is_write             == 1;
        pre_addr_delay       == 0; 
        addr_to_data_gap     == 0; 
        inter_beat_delay     == 0; 
        wait_for_bresp_delay == 0;
      }) `uvm_error("SEQ", "Randomization failed")
      finish_item(tr);
    end
  endtask
endclass

// ---------------------------------------------------------------------------
// 2. SLOW MASTER SEQUENCE: Heavy randomized delays to test stalls
// ---------------------------------------------------------------------------
class axi_write_slow_master_seq extends axi_sequence_base;
  `uvm_object_utils(axi_write_slow_master_seq)

  function new(string name = "axi_write_slow_master_seq");
    super.new(name);
  endfunction

  task body();
    axi_transaction tr;
    `uvm_info("SEQ", "Starting Slow Master Sequence (High Delays)", UVM_LOW)
    repeat(10) begin
      tr = axi_transaction::type_id::create("tr");
      start_item(tr);
      if(!tr.randomize() with {
        is_write             == 1;
        pre_addr_delay       inside {[10:20]}; 
        addr_to_data_gap     inside {[15:30]}; 
        inter_beat_delay     inside {[5:10]};  
      }) `uvm_error("SEQ", "Randomization failed")
      finish_item(tr);
    end
  endtask
endclass

// ---------------------------------------------------------------------------
// 3. BOUNDARY SEQUENCE: Testing unaligned addresses and 4KB crossings
// ---------------------------------------------------------------------------
class axi_write_boundary_seq extends axi_sequence_base;
  `uvm_object_utils(axi_write_boundary_seq)

  function new(string name = "axi_write_boundary_seq");
    super.new(name);
  endfunction

  task body();
    axi_transaction tr;
    `uvm_info("SEQ", "Starting Boundary & Alignment Sequence", UVM_LOW)
    
    // Scenario A: Unaligned Address
    tr = axi_transaction::type_id::create("tr_unaligned");
    start_item(tr);
    void'(tr.randomize() with { is_write == 1; addr % 4 != 0; len == 3; });
    finish_item(tr);

    // Scenario B: 4KB Boundary Crossing (Testing Slave Error Handling)
    tr = axi_transaction::type_id::create("tr_boundary");
    start_item(tr);
    void'(tr.randomize() with { is_write == 1; addr == 32'h0000_0FFC; len == 4; });
    finish_item(tr);
  endtask
endclass

// ---------------------------------------------------------------------------
// 4. ALL-IN-ONE SEQUENCE: The "axi_write" master group
// ---------------------------------------------------------------------------
class axi_write_all_seq extends axi_sequence_base;
  `uvm_object_utils(axi_write_all_seq)

  axi_write_stress_seq      stress;
  axi_write_slow_master_seq slow;
  axi_write_boundary_seq    boundary;

  function new(string name = "axi_write_all_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info("SEQ_MASTER", "Executing all Write Scenarios...", UVM_LOW)
    
    `uvm_do(stress)
    `uvm_do(slow)
    `uvm_do(boundary)
    
    `uvm_info("SEQ_MASTER", "All Write Scenarios Completed.", UVM_LOW)
  endtask
endclass

`endif