// uvm_env/axi_agent/axi_driver.sv
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

  // Build phase: get AXI interface
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if.master)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "AXI4 virtual interface not set for axi_driver")
    end
  endfunction

  // Run phase: main driver loop
  task run_phase(uvm_phase phase);
    axi_transaction tr;

    // Reset interface to known state
    vif.reset();

    forever begin
      // Get next AXI transaction from sequencer
      seq_item_port.get_next_item(tr);

   
      // AXI4 WRITE ADDRESS (AW) CHANNEL

      if (tr.is_write) begin

        // Drive AW signals from transaction
        vif.AWID    <= tr.id;
        vif.AWADDR  <= tr.addr;
        vif.AWLEN   <= tr.len;
        vif.AWSIZE  <= tr.size;
        vif.AWBURST <= tr.burst;
        vif.AWVALID <= 1'b1;

        // Wait for AWREADY handshake
        do begin
          @(posedge vif.ACLK);
        end while (vif.AWREADY !== 1'b1);

        // Handshake complete, deassert AWVALID
        vif.AWVALID <= 1'b0;

      end

      // W / B / AR / R will be added step by step

      // Notify sequencer that transaction is complete
      seq_item_port.item_done();
    end
  endtask

endclass

