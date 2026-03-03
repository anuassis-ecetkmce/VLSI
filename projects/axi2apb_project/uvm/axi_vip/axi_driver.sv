
`ifndef AXI_DRIVER_SV
`define AXI_DRIVER_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_driver extends uvm_driver #(axi_transaction);
  
  axi_agent_config axi_cfg;

  `uvm_component_utils(axi_driver)

  // AXI master virtual interface
  virtual axi_if axi_vif;

  // Constructor
  function new(string name = "axi_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "axi_vif", axi_vif)) begin
      `uvm_fatal("NOVIF", "axi_if not set for axi_driver")
    end
  endfunction

  // Reset task
  task reset_phase(uvm_phase phase);
    phase.raise_objection(this);
    axi_vif.reset_signals();
    phase.drop_objection(this);
  endtask

  // Run phase
  task run_phase(uvm_phase phase);
    axi_transaction tr;

    forever begin
      seq_item_port.get_next_item(tr);

      if (tr.is_write)
        drive_write(tr);
      else
        drive_read(tr);

      seq_item_port.item_done();
    end
  endtask

  // ============================================
  // WRITE TRANSACTION
  // ============================================
  task drive_write(axi_transaction tr);
    int beats = tr.len + 1;

    // --------------------
    // 1. PRE-ADDRESS DELAY
    // --------------------
    repeat(tr.pre_addr_delay) @(axi_vif.cb);

    // --------------------
    // 2. WRITE ADDRESS (AW)
    // --------------------
    axi_vif.cb.AWID    <= tr.id;
    axi_vif.cb.AWADDR  <= tr.addr;
    axi_vif.cb.AWLEN   <= tr.len;
    axi_vif.cb.AWSIZE  <= tr.size;
    axi_vif.cb.AWBURST <= tr.burst;
    axi_vif.cb.AWVALID <= 1'b1;

    // Wait for AWREADY handshake
    do @(axi_vif.cb); while (!axi_vif.cb.AWREADY);
    axi_vif.cb.AWVALID <= 1'b0;

    // --------------------
    // 3. ADDR TO DATA GAP (Gap between AW and W)
    // --------------------
    repeat(tr.addr_to_data_gap) @(axi_vif.cb);

    // --------------------
    // 4. WRITE DATA (W)
    // --------------------
    for (int i = 0; i < beats; i++) begin
      axi_vif.cb.WDATA  <= tr.data_ary[i];
      axi_vif.cb.WSTRB  <= '1; // Simplified: assumes full-width write
      axi_vif.cb.WLAST  <= (i == beats - 1);
      axi_vif.cb.WVALID <= 1'b1;

      // Wait for WREADY
      do @(axi_vif.cb); while (!axi_vif.cb.WREADY);
      
      axi_vif.cb.WVALID <= 1'b0;
      axi_vif.cb.WLAST  <= 1'b0;

      // Inter-beat delay (Gap between data beats)
      repeat(tr.inter_beat_delay) @(axi_vif.cb);
    end

    // --------------------
    // 5. WRITE RESPONSE (B)
    // --------------------
    // Randomized delay before asserting BREADY
    repeat(tr.wait_for_bresp_delay) @(axi_vif.cb);
    
    axi_vif.cb.BREADY <= 1'b1;
    // Wait for BVALID from slave
    do @(axi_vif.cb); while (!axi_vif.cb.BVALID);
    
    tr.resp = axi_vif.cb.BRESP;
    axi_vif.cb.BREADY <= 1'b0;
    
    `uvm_info("DRV_WRITE", $sformatf("Write Finished: Addr=0x%0h, Resp=0x%0h", tr.addr, tr.resp), UVM_HIGH)
  endtask

  // ============================================
  // READ TRANSACTION
  // ============================================
  task drive_read(axi_transaction tr);
    int beats = tr.len + 1;
    tr.alloc_data_array();

    // 1. PRE-ADDRESS DELAY (Reusing field for symmetry)
    repeat(tr.pre_addr_delay) @(axi_vif.cb);

    // --------------------
    // 2. READ ADDRESS (AR)
    // --------------------
    axi_vif.cb.ARID    <= tr.id;
    axi_vif.cb.ARADDR  <= tr.addr;
    axi_vif.cb.ARLEN   <= tr.len;
    axi_vif.cb.ARSIZE  <= tr.size;
    axi_vif.cb.ARBURST <= tr.burst;
    axi_vif.cb.ARVALID <= 1'b1;

    do @(axi_vif.cb); while (!axi_vif.cb.ARREADY);
    axi_vif.cb.ARVALID <= 1'b0;

    // --------------------
    // 3. READ DATA (R)
    // --------------------
    axi_vif.cb.RREADY <= 1'b1;

for (int i = 0; i < beats; i++) begin
      // Wait for RVALID
      do @(axi_vif.cb); while (!axi_vif.cb.RVALID);
      
      tr.data_ary[i] = axi_vif.cb.RDATA;
      
      // If we see RLAST, we should exit even if the loop isn't done (Protocol Safety)
      if (axi_vif.cb.RLAST) begin
         if (i != beats - 1) `uvm_warning("DRV_READ", "RLAST received earlier than expected")
         break;
      end
      
      // Optional: If you wanted to test RREADY throttling, you'd add delays here
      @(axi_vif.cb); 
    end

    tr.resp = axi_vif.cb.RRESP;
    axi_vif.cb.RREADY <= 1'b0;
  endtask

endclass : axi_driver

`endif