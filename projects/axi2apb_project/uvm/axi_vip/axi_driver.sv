`ifndef AXI_DRIVER_SV
`define AXI_DRIVER_SV

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_driver extends uvm_driver #(axi_transaction);
  `uvm_component_utils(axi_driver)

  // AXI master virtual interface
  virtual axi_if vif;

  // Constructor
  function new(string name = "axi_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "axi_if not set for axi_driver")
    end
  endfunction

  // Reset task
  task reset_phase(uvm_phase phase);
    phase.raise_objection(this);
    vif.reset_signals();
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
    @(vif.cb);
    vif.cb.AWID    <= tr.id;
    vif.cb.AWADDR  <= tr.addr;
    vif.cb.AWLEN   <= tr.len;
    vif.cb.AWSIZE  <= tr.size;
    vif.cb.AWBURST <= tr.burst;
    vif.cb.AWVALID <= 1'b1;

    // Wait for handshake
    do @(vif.cb); while (!vif.cb.AWREADY);
    vif.cb.AWVALID <= 1'b0;

    // --------------------
    // WRITE DATA (W)
    // --------------------
    vif.cb.WVALID <= 1'b1;

    for (int i = 0; i < beats; i++) begin
      @(vif.cb);
      vif.cb.WDATA <= tr.data_ary[i];
      vif.cb.WSTRB <= '1;
      vif.cb.WLAST <= (i == beats - 1);

      do @(vif.cb); while (!vif.cb.WREADY);
    end

    vif.cb.WVALID <= 1'b0;
    vif.cb.WLAST  <= 1'b0;

    // --------------------
    // WRITE RESPONSE (B)
    // --------------------
    vif.cb.BREADY <= 1'b1;
    do @(vif.cb); while (!vif.cb.BVALID);
    tr.resp = vif.cb.BRESP;
    vif.cb.BREADY <= 1'b0;
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
    @(vif.cb);
    vif.cb.ARID    <= tr.id;
    vif.cb.ARADDR  <= tr.addr;
    vif.cb.ARLEN   <= tr.len;
    vif.cb.ARSIZE  <= tr.size;
    vif.cb.ARBURST <= tr.burst;
    vif.cb.ARVALID <= 1'b1;

    do @(vif.cb); while (!vif.cb.ARREADY);
    vif.cb.ARVALID <= 1'b0;

    // --------------------
    // READ DATA (R)
    // --------------------
    vif.cb.RREADY <= 1'b1;

    for (int i = 0; i < beats; i++) begin
      do @(vif.cb); while (!vif.cb.RVALID);
      tr.data_ary[i] = vif.cb.RDATA;
      if (vif.cb.RLAST)
        break;
    end

    tr.resp = vif.cb.RRESP;
    vif.cb.RREADY <= 1'b0;
  endtask

endclass : axi_driver

`endif

