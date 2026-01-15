`timescale 1ns/1ps
`include "cfs_bridge_test_pkg.sv"

module axi_apb_bridge_tb_top;


// Imports

import uvm_pkg::*;
import cfs_bridge_test_pkg::*;
`include "uvm_macros.svh"


// Clock & Reset signals

logic axi_aclk;
logic axi_aresetn;
logic apb_pclk;
logic apb_presetn;


// Interface instances

axi_if axi_if (
  .ACLK    (axi_aclk),
  .ARESETn (axi_aresetn)
);

cfs_apb_if apb_if (
  .pclk(apb_pclk)
);

// DUT instantiation

axi_apb_bridge #(
  .AXI_ADDR_WIDTH(32),
  .AXI_DATA_WIDTH(32),
  .AXI_ID_WIDTH(4)
) DUT (

  // AXI clocks & resets
  .axi_aclk    (axi_aclk),
  .axi_aresetn (axi_aresetn),

  //AXI WRITE ADDRESS
  .axi_awid    (axi_if.AWID),
  .axi_awaddr  (axi_if.AWADDR),
  .axi_awlen   (axi_if.AWLEN),
  .axi_awsize  (axi_if.AWSIZE),
  .axi_awburst (axi_if.AWBURST),
  .axi_awvalid (axi_if.AWVALID),
  .axi_awready (axi_if.AWREADY),

  //AXI WRITE DATA
  .axi_wdata   (axi_if.WDATA),
  .axi_wstrb   (axi_if.WSTRB),
  .axi_wlast   (axi_if.WLAST),
  .axi_wvalid  (axi_if.WVALID),
  .axi_wready  (axi_if.WREADY),

  //AXI WRITE RESPONSE
  .axi_bid     (axi_if.BID),
  .axi_bresp   (axi_if.BRESP),
  .axi_bvalid  (axi_if.BVALID),
  .axi_bready  (axi_if.BREADY),

  //AXI READ ADDRESS
  .axi_arid    (axi_if.ARID),
  .axi_araddr  (axi_if.ARADDR),
  .axi_arlen   (axi_if.ARLEN),
  .axi_arsize  (axi_if.ARSIZE),
  .axi_arburst (axi_if.ARBURST),
  .axi_arvalid (axi_if.ARVALID),
  .axi_arready (axi_if.ARREADY),

  //AXI READ DATA
  .axi_rid     (axi_if.RID),
  .axi_rdata   (axi_if.RDATA),
  .axi_rresp   (axi_if.RRESP),
  .axi_rlast   (axi_if.RLAST),
  .axi_rvalid  (axi_if.RVALID),
  .axi_rready  (axi_if.RREADY),

  //APB CLOCK & RESET
  .apb_pclk    (apb_pclk),
  .apb_presetn (apb_presetn),

  // APB SIGNALS 
  .apb_paddr   (apb_if.paddr),
  .apb_pprot   (apb_if.pprot),
  .apb_psel    (apb_if.psel),
  .apb_penable (apb_if.penable),
  .apb_pwrite  (apb_if.pwrite),
  .apb_pwdata  (apb_if.pwdata),
  .apb_pstrb   (apb_if.pstrb),
  .apb_pready  (apb_if.pready),
  .apb_prdata  (apb_if.prdata),
  .apb_pslverr (apb_if.pslverr)
);


// Clock generation

initial begin
  axi_aclk = 0;
  forever #5 axi_aclk = ~axi_aclk; // 100 MHz
end

initial begin
  apb_pclk = 0;
  forever #5 apb_pclk = ~apb_pclk; // 100 MHz
end


// Reset generation (active-low)

initial begin
  axi_aresetn = 0;
  apb_presetn = 0;

  repeat (20) @(posedge axi_aclk);

  axi_aresetn = 1;
  apb_presetn = 1;
end

// UVM configuration & test start

initial begin
  $dumpfile("axi_apb_bridge_tb.vcd");
  $dumpvars(0, axi_apb_bridge_tb_top);

  // Register virtual interfaces for UVM
  uvm_config_db#(virtual axi_if)::set(null, "*", "axi_vif", axi_if);
  uvm_config_db#(virtual cfs_apb_if)::set(null, "*", "apb_vif", apb_if);

  // Run UVM test
  run_test("");
end


// Safety timeout

initial begin
  #100ms;
  `uvm_fatal("TIMEOUT", "Simulation timed out")
end

endmodule

