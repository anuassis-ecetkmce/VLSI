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
  .pclk(axi_aclk)
);

assign apb_if.presetn = axi_aresetn;

// DUT instantiation

axi_apb_bridge_top #(
  .ADDR_WIDTH(32),
  .DATA_WIDTH(32),
  .ID_WIDTH(4),
  .NUM_SLAVES(4),
  .STRB_W(32/8),
  .MAX_WR_CONSEC(4),
  .CLK_PERIOD(10)
) DUT (

  // AXI clocks & resets
  .clk    	(axi_aclk),
  .rst_n 	(axi_aresetn),

  // AXI4 Write Address Channel
  .awvalid     (axi_if.AWVALID),
  .awready     (axi_if.AWREADY),
  .awaddr      (axi_if.AWADDR),
  .awsize      (axi_if.AWSIZE),
  .awlen       (axi_if.AWLEN),
  .awburst     (axi_if.AWBURST),
  .awid        (axi_if.AWID),

  // AXI4 Write Data Channel
  .wvalid      (axi_if.WVALID),
  .wready      (axi_if.WREADY),
  .wdata       (axi_if.WDATA),
  .wstrb       (axi_if.WSTRB),
  .wlast       (axi_if.WLAST),

  // AXI4 Write Response Channel
  .bvalid      (axi_if.BVALID),
  .bready      (axi_if.BREADY),
  .bresp       (axi_if.BRESP),
  .bid         (axi_if.BID),

  // AXI4 Read Address Channel
  .arvalid     (axi_if.ARVALID),
  .arready     (axi_if.ARREADY),
  .araddr      (axi_if.ARADDR),
  .arsize      (axi_if.ARSIZE),
  .arlen       (axi_if.ARLEN),
  .arburst     (axi_if.ARBURST),
  .arid        (axi_if.ARID),

  // AXI4 Read Data Channel
  .rvalid      (axi_if.RVALID),
  .rready      (axi_if.RREADY),
  .rdata       (axi_if.RDATA),
  .rresp       (axi_if.RRESP),
  .rid         (axi_if.RID),
  .rlast       (axi_if.RLAST),

  //APB CLOCK & RESET
  //.clk		(apb_pclk),
  //.rst_n	(apb_presetn),

  // APB Master Interface
  .psel        (apb_if.psel),
  .penable     (apb_if.penable),
  .paddr       (apb_if.paddr),
  .pwrite      (apb_if.pwrite),
  .pready      (apb_if.pready),
  .pslverr     (apb_if.pslverr),
  .pwdata      (apb_if.pwdata),
  .pstrb       (apb_if.pstrb),
  .prdata      (apb_if.prdata)
);


// Clock generation

initial begin
  axi_aclk = 0;
  forever #5 axi_aclk = ~axi_aclk; // 100 MHz
end

//initial begin
//  apb_pclk = 0;
//  forever #5 apb_pclk = ~apb_pclk; // 100 MHz
//end


// Reset generation (active-low)

initial begin
  axi_aresetn = 0;
  //apb_presetn = 0;

  repeat (20) @(posedge axi_aclk);

  axi_aresetn = 1;
  //apb_presetn = 1;
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

