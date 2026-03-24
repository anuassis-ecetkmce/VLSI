class axi_coverage_subscriber extends uvm_subscriber #(axi_transaction);
  `uvm_component_utils(axi_coverage_subscriber)

  axi_transaction tr;

  // Define the Coverage Model
  covergroup axi_cg;
    // 1. Check if we covered both Read and Write
    cp_direction: coverpoint tr.is_write {
      bins write = {1};
      bins read  = {0};
    }

    // 2. Check various Burst Lengths (0 to 15)
    cp_len: coverpoint tr.len {
      bins single_beat = {0};
      bins short_burst = {[1:7]};
      bins long_burst  = {[8:15]};
    }

    // 3. Check AXI Sizes
    cp_size: coverpoint tr.size {
      bins size_1B = {AXI_SIZE_1B};
      bins size_2B = {AXI_SIZE_2B};
      bins size_4B = {AXI_SIZE_4B};
    }

    // 4. Cross Coverage:
    cross_dir_size: cross cp_direction, cp_size;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    axi_cg = new(); // Instantiate the covergroup
  endfunction

  // This function is automatically called by the Monitor's analysis port
  function void write(axi_transaction t);
    this.tr = t;
    axi_cg.sample(); // Record the data
  endfunction

endclass
