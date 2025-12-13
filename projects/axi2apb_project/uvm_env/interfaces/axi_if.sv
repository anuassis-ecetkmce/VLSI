`timescale 1ns/1ps
interface axi_if #(parameter ADDR_W = 32, DATA_W = 32, ID_W = 4) (
  input bit ACLK,
  input bit ARESETn
);

  logic [ID_W-1:0]   AWID;
  logic [ADDR_W-1:0] AWADDR;
  logic [7:0]        AWLEN;
  logic [2:0]        AWSIZE;
  logic [1:0]        AWBURST;
  logic              AWVALID;
  logic              AWREADY;

  logic [DATA_W-1:0]   WDATA;
  logic [DATA_W/8-1:0] WSTRB;
  logic                WLAST;
  logic                WVALID;
  logic                WREADY;

  logic [ID_W-1:0]   BID;
  logic [1:0]        BRESP;
  logic              BVALID;
  logic              BREADY;

  logic [ID_W-1:0]   ARID;
  logic [ADDR_W-1:0] ARADDR;
  logic [7:0]        ARLEN;
  logic [2:0]        ARSIZE;
  logic [1:0]        ARBURST;
  logic              ARVALID;
  logic              ARREADY;

  logic [ID_W-1:0]   RID;
  logic [DATA_W-1:0] RDATA;
  logic [1:0]        RRESP;
  logic              RLAST;
  logic              RVALID;
  logic              RREADY;

  clocking cb @(posedge ACLK);
    input  ARESETn;
    input  AWREADY, WREADY, BVALID, BRESP, BID;
    input  ARREADY, RVALID, RDATA, RRESP, RLAST;

    output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID;
    output WDATA, WSTRB, WLAST, WVALID;
    output BREADY;
    output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID;
    output RREADY;
  endclocking

  modport master (
    input  ACLK, ARESETn,
    input  AWREADY, WREADY, BVALID, BRESP, BID,
    input  ARREADY, RVALID, RDATA, RRESP, RLAST,
    output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID,
    output WDATA, WSTRB, WLAST, WVALID, BREADY,
    output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID,
    output RREADY
  );

  task automatic reset();
    AWVALID = 0;
    WVALID  = 0;
    WLAST   = 0;
    BREADY  = 0;
    ARVALID = 0;
    RREADY  = 0;
  endtask

endinterface

