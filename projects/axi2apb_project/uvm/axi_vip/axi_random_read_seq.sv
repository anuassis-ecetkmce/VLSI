`ifndef AXI_RANDOM_READ_SEQ_SV
`define AXI_RANDOM_READ_SEQ_SV

    class axi_random_read_seq extends uvm_sequence #(axi_transaction);

    `uvm_object_utils(axi_random_read_seq)

  function new(string name="axi_random_read_seq");
    super.new(name);
  endfunction

  task body();
    axi_transaction tr;

    // Generate 20 random single-beat read transactions
    repeat(20) begin
      tr = axi_transaction::type_id::create("tr");

      start_item(tr);

      if(!tr.randomize() with {
        addr inside {[32'h10000000:32'h4FFFFFFF]}; // Valid slave address range
        is_write == 0;                             // 0 = READ
        len      == 0;                             // 1-beat burst (0 means 1 beat)
        size     == 3'b010;                        // 4 bytes per beat (AXI_SIZE_4B)
        burst    == 2'b01;                         // INCR mode (AXI_BURST_INCR)

        // Randomize the delay before the master drives ARVALID
        pre_addr_delay inside {[5:25]};

        // Note: If your axi_transaction has a variable for delaying RREADY
        // (like rready_delay or wait_for_data_delay), you can randomize it here too!
        // rready_delay inside {[0:10]};
      }) `uvm_error("SEQ", "Rand failed")

      // Allocate the expected read buffer based on the randomized 'len'
      tr.alloc_data_array();

      finish_item(tr);

      `uvm_info("AXI_READ_SEQ", $sformatf("Sent READ tr: addr=0x%0h, pre_addr_delay=%0d", tr.addr, tr.pre_addr_delay), UVM_MEDIUM)
    end

  endtask
endclass

`endif
