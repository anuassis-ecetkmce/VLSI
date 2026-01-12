`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_driver extends uvm_driver #(axi_transaction);
  `uvm_component_utils(axi_driver)

  // AXI4 master virtual interface
  virtual axi_if.master vif;

  // Constructor
  function new(string name = "axi_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if.master)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "AXI4 virtual interface not set for axi_driver")
    end
  endfunction

  // Run phase
  task run_phase(uvm_phase phase);
    axi_transaction tr;

    // Reset interface
    vif.reset();

    // Drive defaults
    vif.AWVALID <= 0;
    vif.WVALID  <= 0;
    vif.WLAST   <= 0;
    vif.BREADY  <= 0;
    vif.ARVALID <= 0;
    vif.RREADY  <= 0;

    forever begin
      seq_item_port.get_next_item(tr);

      // ====================================================
      // AXI WRITE TRANSACTION
      // ====================================================
      if (tr.is_write) begin
        int beats;

        // --------------------
        // WRITE ADDRESS (AW)
        // --------------------
        vif.AWID    <= tr.id;
        vif.AWADDR  <= tr.addr;
        vif.AWLEN   <= tr.len;
        vif.AWSIZE  <= tr.size;
        vif.AWBURST <= tr.burst;
        vif.AWVALID <= 1'b1;

        do @(posedge vif.ACLK);
        while (vif.AWREADY !== 1'b1);

        vif.AWVALID <= 1'b0;

        // --------------------
        // WRITE DATA (W)
        // --------------------
        beats = tr.len + 1;
        vif.WVALID <= 1'b1;

        for (int i = 0; i < beats; i++) begin
          vif.WDATA <= tr.data_ary[i];
          vif.WSTRB <= '1;
          vif.WLAST <= (i == beats-1);

          do @(posedge vif.ACLK);
          while (vif.WREADY !== 1'b1);
        end

        vif.WVALID <= 1'b0;
        vif.WLAST  <= 1'b0;

        // --------------------
        // WRITE RESPONSE (B)
        // --------------------
        vif.BREADY <= 1'b1;

        do @(posedge vif.ACLK);
        while (vif.BVALID !== 1'b1);

        tr.resp = vif.BRESP;
        vif.BREADY <= 1'b0;
      end

      // ====================================================
      // AXI READ TRANSACTION
      // ====================================================
      else begin
        int beats;

        // --------------------
        // READ ADDRESS (AR)
        // --------------------
        vif.ARID    <= tr.id;
        vif.ARADDR  <= tr.addr;
        vif.ARLEN   <= tr.len;
        vif.ARSIZE  <= tr.size;
        vif.ARBURST <= tr.burst;
        vif.ARVALID <= 1'b1;

        do @(posedge vif.ACLK);
        while (vif.ARREADY !== 1'b1);

        vif.ARVALID <= 1'b0;

        // --------------------
        // READ DATA (R)
        // --------------------
        beats = tr.len + 1;
        tr.data_ary = new[beats];
        vif.RREADY  <= 1'b1;

        for (int i = 0; i < beats; i++) begin
          do @(posedge vif.ACLK);
          while (vif.RVALID !== 1'b1);

          tr.data_ary[i] = vif.RDATA;

          // RLAST should assert on final beat
          if (vif.RLAST)
            break;
        end

        tr.resp = vif.RRESP;
        vif.RREADY <= 1'b0;
      end

      // Transaction is fully complete
      seq_item_port.item_done();
    end
  endtask

endclass

