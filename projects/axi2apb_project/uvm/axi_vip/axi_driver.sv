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
    // WRITE ADDRESS (AW)
    // --------------------
    @(axi_vif.cb);
    axi_vif.cb.AWID    <= tr.id;
    axi_vif.cb.AWADDR  <= tr.addr;
    axi_vif.cb.AWLEN   <= tr.len;
    axi_vif.cb.AWSIZE  <= tr.size;
    axi_vif.cb.AWBURST <= tr.burst;
    axi_vif.cb.AWVALID <= 1'b1;

    // Wait for handshake
    do @(axi_vif.cb); while (!axi_vif.cb.AWREADY);
    axi_vif.cb.AWVALID <= 1'b0;

    // --------------------
    // WRITE DATA (W)
    // --------------------
    axi_vif.cb.WVALID <= 1'b1;

    for (int i = 0; i < beats; i++) begin
      @(axi_vif.cb);
      axi_vif.cb.WDATA <= tr.data_ary[i];
      axi_vif.cb.WSTRB <= '1;
      axi_vif.cb.WLAST <= (i == beats - 1);

      do @(axi_vif.cb); while (!axi_vif.cb.WREADY);
    end

    axi_vif.cb.WVALID <= 1'b0;
    axi_vif.cb.WLAST  <= 1'b0;

    // --------------------
    // WRITE RESPONSE (B)
    // --------------------
    axi_vif.cb.BREADY <= 1'b1;
    do @(axi_vif.cb); while (!axi_vif.cb.BVALID);
    tr.resp = axi_vif.cb.BRESP;
    axi_vif.cb.BREADY <= 1'b0;
  endtask

  // ============================================
  // READ TRANSACTION
  // ============================================
  task drive_read(axi_transaction tr);
    int beats = tr.len + 1;
    tr.alloc_data_array();

    // --------------------
    // READ ADDRESS (AR)
    // --------------------
    @(axi_vif.cb);
    axi_vif.cb.ARID    <= tr.id;
    axi_vif.cb.ARADDR  <= tr.addr;
    axi_vif.cb.ARLEN   <= tr.len;
    axi_vif.cb.ARSIZE  <= tr.size;
    axi_vif.cb.ARBURST <= tr.burst;
    axi_vif.cb.ARVALID <= 1'b1;

    do @(axi_vif.cb); while (!axi_vif.cb.ARREADY);
    axi_vif.cb.ARVALID <= 1'b0;

    // --------------------
    // READ DATA (R)
    // --------------------
    axi_vif.cb.RREADY <= 1'b1;

    for (int i = 0; i < beats; i++) begin
      do @(axi_vif.cb); while (!axi_vif.cb.RVALID);
      tr.data_ary[i] = axi_vif.cb.RDATA;
      if (axi_vif.cb.RLAST)
        break;
    end

    tr.resp = axi_vif.cb.RRESP;
    axi_vif.cb.RREADY <= 1'b0;
  endtask

endclass : axi_driver

`endif

