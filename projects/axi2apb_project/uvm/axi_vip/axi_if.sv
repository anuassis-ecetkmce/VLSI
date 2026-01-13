`timescale 1ns/1ps

interface axi_if #(
  parameter ADDR_W = 32,
  parameter DATA_W = 32,
  parameter ID_W   = 4
)(
  input  logic ACLK,
  input  logic ARESETn
);


  // AXI4 Write Address Channel


  logic [ID_W-1:0]   AWID;
  logic [ADDR_W-1:0] AWADDR;
  logic [7:0]        AWLEN;
  logic [2:0]        AWSIZE;
  logic [1:0]        AWBURST;
  logic              AWVALID;
  logic              AWREADY;

 
  // AXI4 Write Data Channel


  logic [DATA_W-1:0]   WDATA;
  logic [DATA_W/8-1:0] WSTRB;
  logic                WLAST;
  logic                WVALID;
  logic                WREADY;


  // AXI4 Write Response Channel
 

  logic [ID_W-1:0] BID;
  logic [1:0]      BRESP;
  logic            BVALID;
  logic            BREADY;


  // AXI4 Read Address Channel
 

  logic [ID_W-1:0]   ARID;
  logic [ADDR_W-1:0] ARADDR;
  logic [7:0]        ARLEN;
  logic [2:0]        ARSIZE;
  logic [1:0]        ARBURST;
  logic              ARVALID;
  logic              ARREADY;

  
  // AXI4 Read Data Channel
  

  logic [ID_W-1:0]   RID;
  logic [DATA_W-1:0] RDATA;
  logic [1:0]        RRESP;
  logic              RLAST;
  logic              RVALID;
  logic              RREADY;

 
  // Clocking block (for race-free driving & sampling)
  
  clocking cb @(posedge ACLK);
    input  ARESETn;

    // Inputs sampled by master
    input  AWREADY, WREADY;
    input  BVALID, BRESP, BID;
    input  ARREADY;
    input  RVALID, RDATA, RRESP, RLAST;

    // Outputs driven by master
    output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID;
    output WDATA, WSTRB, WLAST, WVALID;
    output BREADY;
    output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID;
    output RREADY;
  endclocking

  
  // Master modport
  

  modport master (
    input  ACLK, ARESETn,
    input  AWREADY, WREADY,
    input  BVALID, BRESP, BID,
    input  ARREADY,
    input  RVALID, RDATA, RRESP, RLAST,
    output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID,
    output WDATA, WSTRB, WLAST, WVALID,
    output BREADY,
    output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID,
    output RREADY
  );

  
  // Reset task (clock-safe)
 

  task automatic reset_signals();
    @(posedge ACLK);
    cb.AWVALID <= 1'b0;
    cb.WVALID  <= 1'b0;
    cb.WLAST   <= 1'b0;
    cb.BREADY  <= 1'b0;
    cb.ARVALID <= 1'b0;
    cb.RREADY  <= 1'b0;
  endtask

endinterface : axi_if

