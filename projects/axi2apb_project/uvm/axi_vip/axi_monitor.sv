`ifndef AXI_MONITOR_SV
`define AXI_MONITOR_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_monitor extends uvm_component;
  `uvm_component_utils(axi_monitor)

  // Analysis port
  uvm_analysis_port #(axi_transaction) axi_ap;

  // Virtual interface
  virtual axi_if vif;

  // Constructor
  function new(string name = "axi_monitor", uvm_component parent = null);
    super.new(name, parent);
    axi_ap = new("axi_ap", this);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "axi_if not set for axi_monitor")
    end
  endfunction

  // Run phase
  task run_phase(uvm_phase phase);
    axi_transaction tr;

    // Wait for reset deassertion
    wait (vif.ARESETn == 1'b1);

    forever begin
      @(posedge vif.ACLK);

      
      // WRITE TRANSACTION MONITORING
      
      if (vif.AWVALID && vif.AWREADY) begin
        tr = axi_transaction::type_id::create("axi_wr_tr", this);
        tr.is_write = 1;
        tr.id       = vif.AWID;
        tr.addr     = vif.AWADDR;
        tr.len      = vif.AWLEN;
        tr.size     = vif.AWSIZE;
        tr.burst    = vif.AWBURST;

        tr.alloc_data_array();

        int beats = tr.len + 1;
        int beat  = 0;

        // Capture write data beats
        while (beat < beats) begin
          @(posedge vif.ACLK);
          if (vif.WVALID && vif.WREADY) begin
            tr.data_ary[beat] = vif.WDATA;
            beat++;
            if (vif.WLAST)
              break;
          end
        end

        // Capture response
        @(posedge vif.ACLK);
        wait (vif.BVALID);
        tr.resp = vif.BRESP;

        axi_ap.write(tr);
      end

      
      // READ TRANSACTION MONITORING
      
      if (vif.ARVALID && vif.ARREADY) begin
        tr = axi_transaction::type_id::create("axi_rd_tr", this);
        tr.is_write = 0;
        tr.id       = vif.ARID;
        tr.addr     = vif.ARADDR;
        tr.len      = vif.ARLEN;
        tr.size     = vif.ARSIZE;
        tr.burst    = vif.ARBURST;

        tr.alloc_data_array();

        int beats = tr.len + 1;
        int beat  = 0;

        // Capture read data beats
        while (beat < beats) begin
          @(posedge vif.ACLK);
          if (vif.RVALID && vif.RREADY && vif.RID == tr.id) begin
            tr.data_ary[beat] = vif.RDATA;
            beat++;
            if (vif.RLAST)
              break;
          end
        end

        tr.resp = vif.RRESP;
        axi_ap.write(tr);
      end
    end
  endtask

endclass : axi_monitor

`endif
//AXI_MONITOR

