`ifndef AXI_SEQUENCE_RW_SV
`define AXI_SEQUENCE_RW_SV


class axi_sequence_rw extends uvm_sequence #(axi_transaction);

  `uvm_object_utils(axi_sequence_rw)

  // Test configuration
  rand bit [31:0] base_addr;
  rand int unsigned num_trans;     // how many RW pairs
  bit [31:0] addr_stride;      // stride between addresses

  constraint num_trans_default {
    num_trans inside{[1:10]};
  }

  constraint max_addr { (base_addr + ((num_trans - 1) * addr_stride)) < 32'h4FFFFFFF; }

  function new(string name = "axi_sequence_rw");
    super.new(name);
   // base_addr   = 32'h1000;
    //num_trans   = 1;
    addr_stride = 32'h4;
  endfunction

  task body();

    axi_transaction tr;

    // Generate read and write transactions in alternating order
    for (int unsigned i = 0; i < num_trans; i++) begin

      // ---- AXI WRITE ----
      //tr = axi_transaction::type_id::create("axi_write");


      // Write config
      //tr.is_write = 1;
      //tr.addr     = base_addr + (i * addr_stride);
      //tr.len      = 0;               // single beat
      //tr.size     = AXI_SIZE_4B;     // 4 bytes
      //tr.burst    = AXI_BURST_INCR;
      //tr.alloc_data_array();

      // Fill write data
      //tr.data_ary[0] = $urandom;

      // send to driver
      //start_item(tr);
      //finish_item(tr);

      //`uvm_info("AXI_SEQ_RW", $sformatf("Sent WRITE tr: addr=0x%0h data=0x%0h", tr.addr, tr.data_ary[0]), UVM_MEDIUM)

      // ---- AXI READ ----
      tr = axi_transaction::type_id::create("axi_read");

      tr.is_write = 0;
      tr.addr     = base_addr + (i * addr_stride);
      tr.len      = 0;
      tr.size     = AXI_SIZE_4B;
      tr.burst    = AXI_BURST_INCR;
      tr.alloc_data_array(); // expected read buffer

      start_item(tr);
      finish_item(tr);

      `uvm_info("AXI_SEQ_RW", $sformatf("Sent READ tr: addr=0x%0h", tr.addr), UVM_MEDIUM)

    end // for

  endtask : body

endclass : axi_sequence_rw

`endif // AXI_SEQUENCE_RW_SV
