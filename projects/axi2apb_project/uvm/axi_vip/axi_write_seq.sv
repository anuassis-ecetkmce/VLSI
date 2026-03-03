`ifndef AXI_WRITE_SEQUENCES_SV
`define AXI_WRITE_SEQUENCES_SV

// 1. STRESS SEQUENCE: Zero delays (unchanged)
class axi_write_stress_seq extends axi_sequence_base;
  `uvm_object_utils(axi_write_stress_seq)
  function new(string name = "axi_write_stress_seq"); super.new(name); endfunction

  task body();
    axi_transaction tr;
    repeat(15) begin
      tr = axi_transaction::type_id::create("tr");
      start_item(tr);
      if(!tr.randomize() with {
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

// 2. SLOW MASTER SEQUENCE: UPDATED with Post-Delay (BREADY delay)
class axi_write_slow_master_seq extends axi_sequence_base;
  `uvm_object_utils(axi_write_slow_master_seq)
  function new(string name = "axi_write_slow_master_seq"); super.new(name); endfunction

  task body();
    axi_transaction tr;
    repeat(10) begin
      tr = axi_transaction::type_id::create("tr");
      start_item(tr);
      if(!tr.randomize() with {
        is_write             == 1;
        pre_addr_delay       inside {[10:20]}; // Pre-delay
        addr_to_data_gap     inside {[15:30]}; // Post-Addr delay
        inter_beat_delay     inside {[5:10]};  // Post-Beat delay
        wait_for_bresp_delay inside {[10:25]}; // Post-Write (B channel) delay
      }) `uvm_error("SEQ", "Rand failed")
      finish_item(tr);
    end
  endtask
endclass

// 3. RANDOMIZED DELAY SEQUENCE: Fully randomized for wide coverage
class axi_write_random_delay_seq extends axi_sequence_base;
  `uvm_object_utils(axi_write_random_delay_seq)
  function new(string name = "axi_write_random_delay_seq"); super.new(name); endfunction

  task body();
    axi_transaction tr;
    repeat(20) begin
      tr = axi_transaction::type_id::create("tr");
      start_item(tr);
      // Here we don't force specific ranges, we let the transaction's 
      // internal constraints handle the randomization.
      if(!tr.randomize() with { is_write == 1; }) 
        `uvm_error("SEQ", "Rand failed")
      finish_item(tr);
    end
  endtask
endclass

// 4. BOUNDARY SEQUENCE (unchanged)
class axi_write_boundary_seq extends axi_sequence_base;
  `uvm_object_utils(axi_write_boundary_seq)
  function new(string name = "axi_write_boundary_seq"); super.new(name); endfunction

  task body();
    axi_transaction tr;
    // Unaligned
    tr = axi_transaction::type_id::create("tr_unaligned");
    start_item(tr);
    void'(tr.randomize() with { is_write == 1; addr % 4 != 0; len == 3; });
    finish_item(tr);
    // Boundary Crossing
    tr = axi_transaction::type_id::create("tr_boundary");
    start_item(tr);
    void'(tr.randomize() with { is_write == 1; addr == 32'h0000_0FFC; len == 4; });
    finish_item(tr);
  endtask
endclass

// 5. THE MASTER GROUP
class axi_write_all_seq extends axi_sequence_base;
  `uvm_object_utils(axi_write_all_seq)
  
  axi_write_stress_seq       stress;
  axi_write_slow_master_seq  slow;
  axi_write_random_delay_seq r_delay;
  axi_write_boundary_seq     boundary;

  function new(string name = "axi_write_all_seq"); super.new(name); endfunction

  task body();
    `uvm_do(stress)
    `uvm_do(slow)
    `uvm_do(r_delay)
    `uvm_do(boundary)
  endtask
endclass

`endif