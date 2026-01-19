`ifndef AXI_MONITOR_SV
`define AXI_MONITOR_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_monitor extends uvm_component;
  `uvm_component_utils(axi_monitor)
  axi_agent_config axi_cfg;

  // Analysis port
  uvm_analysis_port #(axi_transaction) axi_ap;

  // Virtual interface
  virtual axi_if axi_vif;

  // Constructor
  function new(string name = "axi_monitor", uvm_component parent = null);
    super.new(name, parent);
    axi_ap = new("axi_ap", this);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "axi_vif", axi_vif)) begin
      `uvm_fatal("NOVIF", "axi_if not set for axi_monitor")
    end
  endfunction

  // Run phase
  task run_phase(uvm_phase phase);
    axi_transaction tr;
    int beats;
    int beat;

    // Wait for reset deassertion
    wait (axi_vif.ARESETn == 1'b1);

    forever begin
      @(posedge axi_vif.ACLK);

      
      // WRITE TRANSACTION MONITORING
      
      if (axi_vif.AWVALID && axi_vif.AWREADY) begin
        tr = axi_transaction::type_id::create("axi_wr_tr", this);
        tr.is_write = 1;
        tr.id       = axi_vif.AWID;
        tr.addr     = axi_vif.AWADDR;
        tr.len      = axi_vif.AWLEN;
        tr.size     = axi_vif.AWSIZE;
        tr.burst    = axi_vif.AWBURST;

        tr.alloc_data_array();

        beats = tr.len + 1;
        beat  = 0;

        // Capture write data beats
        while (beat < beats) begin
          @(posedge axi_vif.ACLK);
          if (axi_vif.WVALID && axi_vif.WREADY) begin
            tr.data_ary[beat] = axi_vif.WDATA;
            beat++;
            if (axi_vif.WLAST)
              break;
          end
        end

        // Capture response
        @(posedge axi_vif.ACLK);
        wait (axi_vif.BVALID);
        tr.resp = axi_vif.BRESP;

        axi_ap.write(tr);
      end

      
      // READ TRANSACTION MONITORING
      
      if (axi_vif.ARVALID && axi_vif.ARREADY) begin
        tr = axi_transaction::type_id::create("axi_rd_tr", this);
        tr.is_write = 0;
        tr.id       = axi_vif.ARID;
        tr.addr     = axi_vif.ARADDR;
        tr.len      = axi_vif.ARLEN;
        tr.size     = axi_vif.ARSIZE;
        tr.burst    = axi_vif.ARBURST;

        tr.alloc_data_array();

        beats = tr.len + 1;
        beat  = 0;

        // Capture read data beats
        while (beat < beats) begin
          @(posedge axi_vif.ACLK);
          if (axi_vif.RVALID && axi_vif.RREADY && axi_vif.RID == tr.id) begin
            tr.data_ary[beat] = axi_vif.RDATA;
            beat++;
            if (axi_vif.RLAST)
              break;
          end
        end

        tr.resp = axi_vif.RRESP;
        axi_ap.write(tr);
      end
    end
  endtask

endclass : axi_monitor

`endif
//AXI_MONITOR


