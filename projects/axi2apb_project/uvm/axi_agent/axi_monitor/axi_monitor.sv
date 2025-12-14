`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import axi_apb_pkg::*; // your package with axi_trans/apb_trans/axi2apb

// Simple AXI4-Lite style virtual interface
interface axi4_if (input bit ACLK, input bit ARESETn);
  // Address Read
  logic          ARVALID;
  logic          ARREADY;
  logic [31:0]   ARADDR;
  logic [3:0]    ARID;

  // Read Data
  logic          RVALID;
  logic          RREADY;
  logic [31:0]   RDATA;
  logic [1:0]    RRESP;
  logic [3:0]    RID;

  // Address Write
  logic          AWVALID;
  logic          AWREADY;
  logic [31:0]   AWADDR;
  logic [3:0]    AWID;

  // Write Data
  logic          WVALID;
  logic          WREADY;
  logic [31:0]   WDATA;
  logic [3:0]    WID;
  logic [3:0]    WSTRB;

  // Write response
  logic          BVALID;
  logic          BREADY;
  logic [1:0]    BRESP;
  logic [3:0]    BID;

  // convenience tasks or signals can be added if desired
endinterface : axi4_if


// AXI monitor
class axi4_monitor extends uvm_component;
  `uvm_component_utils(axi4_monitor)

  // Analysis ports for publishing observed transactions
  uvm_analysis_port #(axi_trans) axi_ap;   // publishes captured AXI transactions
  uvm_analysis_port #(apb_trans) apb_ap;   // publishes converted APB transactions

  // Virtual interface handle
  virtual axi4_if vif;

  // constructor
  function new(string name = "axi4_monitor", uvm_component parent = null);
    super.new(name, parent);
    axi_ap = new("axi_ap");
    apb_ap = new("apb_ap");
  endfunction

  // get virtual interface from config DB (typical UVM pattern)
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", {"Virtual interface must be set in config DB: ", get_full_name()})
    end
  endfunction

  // main monitoring loop
  task run_phase(uvm_phase phase);
    super.run_phase(phase);

    // Wait until reset is de-asserted
    wait (vif.ARESETn == 1);

    // forever sample on clock edge
    forever begin
      @(posedge vif.ACLK);

      // Capture a write transaction when AWVALID & AWREADY AND WVALID & WREADY are accepted.
      // AXI4-Lite: AW and W may happen in same or separate cycles; we keep it simple:
      if (vif.AWVALID && vif.AWREADY) begin
        // either W might already be accepted same cycle or later.
        axi_trans at = axi_trans::type_id::create("axi_write");
        at.addr = vif.AWADDR;
        at.id   = vif.AWID;

        // Determine write data: prefer if WVALID & WREADY present now,
        // otherwise wait for WVALID & WREADY
        if (vif.WVALID && vif.WREADY) begin
          at.data = vif.WDATA;
          at.rw   = AXI_WRITE;
          // publish immediately
          axi_ap.write(at);
          // publish converted APB trans
          apb_ap.write(axi2apb(at));
        end
        else begin
          // wait for WVALID & WREADY to capture write data
          // Avoid infinite blocking: sample on next clock edges
          forever begin
            @(posedge vif.ACLK);
            if (vif.WVALID && vif.WREADY) begin
              at.data = vif.WDATA;
              at.rw   = AXI_WRITE;
              axi_ap.write(at);
              apb_ap.write(axi2apb(at));
              break;
            end
          end
        end
      end // if AW

      // Capture a read address acceptance and the corresponding read data
      if (vif.ARVALID && vif.ARREADY) begin
        axi_trans at = axi_trans::type_id::create("axi_read");
        at.addr = vif.ARADDR;
        at.id   = vif.ARID;
        at.rw   = AXI_READ;

        // Wait for the read data beat (RVALID & RREADY). In AXI4-Lite single beat:
        forever begin
          @(posedge vif.ACLK);
          if (vif.RVALID && vif.RREADY && vif.RID == at.id) begin
            at.data = vif.RDATA;
            axi_ap.write(at);
            apb_ap.write(axi2apb(at));
            break;
          end
        end
      end // if AR
    end // forever
  endtask

endclass : axi4_monitor
