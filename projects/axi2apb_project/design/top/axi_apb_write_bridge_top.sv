`timescale 1ns/1ps

//==============================================================================
// Module: axi_apb_write_bridge_top
// Description: Top-level wrapper connecting the three pipeline stages.
//
// Changes vs original:
//   - New internal wires: resp_fifo_full, cmd_len, wdata_last
//   - axi_input_stage  : new ports cmd_len, wdata_last
//   - write_transaction_engine: new ports cmd_len, wdata_last, resp_fifo_full
//   - axi_response_stage: new port resp_fifo_full
//==============================================================================

module axi_apb_write_bridge_top #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter NUM_SLAVES = 4,

    parameter ADDR_FIFO_DEPTH = 8,
    parameter DATA_FIFO_DEPTH = 8,
    parameter RESP_FIFO_DEPTH = 8,

    // APB Slave Address Map
    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_BASE_ADDR = {
        32'h4000_0000,  // Slave 3
        32'h3000_0000,  // Slave 2
        32'h2000_0000,  // Slave 1
        32'h1000_0000   // Slave 0
    },
    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_SIZE = {
        32'h1000_0000,
        32'h1000_0000,
        32'h1000_0000,
        32'h1000_0000
    }
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // AXI4 Write Address Channel
    input  logic                    awvalid,
    output logic                    awready,
    input  logic [ADDR_WIDTH-1:0]   awaddr,
    input  logic [2:0]              awsize,
    input  logic [7:0]              awlen,
    input  logic [1:0]              awburst,
    input  logic [ID_WIDTH-1:0]     awid,

    // AXI4 Write Data Channel
    input  logic                    wvalid,
    output logic                    wready,
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [DATA_WIDTH/8-1:0] wstrb,
    input  logic                    wlast,

    // AXI4 Write Response Channel
    output logic                    bvalid,
    input  logic                    bready,
    output logic [1:0]              bresp,
    output logic [ID_WIDTH-1:0]     bid,

    // APB Master Interface
    output logic [NUM_SLAVES-1:0]   psel,
    output logic                    penable,
    output logic [ADDR_WIDTH-1:0]   paddr,
    output logic [DATA_WIDTH-1:0]   pwdata,
    output logic [DATA_WIDTH/8-1:0] pstrb,
    output logic                    pwrite,
    input  logic                    pready,
    input  logic                    pslverr
);

    //==========================================================================
    // Internal Signals: Module 1 → Module 2
    //==========================================================================
    logic                      cmd_valid;
    logic                      cmd_ready;
    logic [ADDR_WIDTH-1:0]     cmd_addr;
    logic [ID_WIDTH-1:0]       cmd_id;
    logic [7:0]                cmd_len;      // FIX: burst length

    logic                      wdata_valid;
    logic                      wdata_ready;
    logic [DATA_WIDTH-1:0]     wdata_out;
    logic [DATA_WIDTH/8-1:0]   wstrb_out;
    logic                      wdata_last;   // FIX: beat-last

    //==========================================================================
    // Internal Signals: Module 2 → Module 3
    //==========================================================================
    logic                      txn_complete;
    logic [ID_WIDTH-1:0]       txn_id;
    logic [1:0]                txn_resp;

    //==========================================================================
    // Internal Signals: Module 3 → Module 2 (backpressure)  FIX
    //==========================================================================
    logic                      resp_fifo_full;

    //==========================================================================
    // MODULE 1: AXI Input Stage
    //==========================================================================
    axi_input_stage #(
        .ADDR_WIDTH     (ADDR_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .ID_WIDTH       (ID_WIDTH),
        .ADDR_FIFO_DEPTH(ADDR_FIFO_DEPTH),
        .DATA_FIFO_DEPTH(DATA_FIFO_DEPTH)
    ) u_axi_input_stage (
        .clk        (clk),
        .rst_n      (rst_n),

        // AXI Write Address Channel
        .awvalid    (awvalid),
        .awready    (awready),
        .awaddr     (awaddr),
        .awsize     (awsize),
        .awlen      (awlen),
        .awburst    (awburst),
        .awid       (awid),

        // AXI Write Data Channel
        .wvalid     (wvalid),
        .wready     (wready),
        .wdata      (wdata),
        .wstrb      (wstrb),
        .wlast      (wlast),

        // To Module 2: Command FIFO Output
        .cmd_valid  (cmd_valid),
        .cmd_ready  (cmd_ready),
        .cmd_addr   (cmd_addr),
        .cmd_id     (cmd_id),
        .cmd_len    (cmd_len),       // FIX

        // To Module 2: Write Data FIFO Output
        .wdata_valid(wdata_valid),
        .wdata_ready(wdata_ready),
        .wdata_out  (wdata_out),
        .wstrb_out  (wstrb_out),
        .wdata_last (wdata_last)     // FIX
    );

    //==========================================================================
    // MODULE 2: Write Transaction Engine
    //==========================================================================
    write_transaction_engine #(
        .ADDR_WIDTH     (ADDR_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .ID_WIDTH       (ID_WIDTH),
        .NUM_SLAVES     (NUM_SLAVES),
        .SLAVE_BASE_ADDR(SLAVE_BASE_ADDR),
        .SLAVE_SIZE     (SLAVE_SIZE)
    ) u_write_transaction_engine (
        .clk            (clk),
        .rst_n          (rst_n),

        // From Module 1: Command Input
        .cmd_valid      (cmd_valid),
        .cmd_ready      (cmd_ready),
        .cmd_addr       (cmd_addr),
        .cmd_id         (cmd_id),
        .cmd_len        (cmd_len),        // FIX

        // From Module 1: Write Data Input
        .wdata_valid    (wdata_valid),
        .wdata_ready    (wdata_ready),
        .wdata_in       (wdata_out),
        .wstrb_in       (wstrb_out),
        .wdata_last     (wdata_last),     // FIX

        // To Module 3: Transaction Completion
        .txn_complete   (txn_complete),
        .txn_id         (txn_id),
        .txn_resp       (txn_resp),

        // From Module 3: Backpressure  FIX
        .resp_fifo_full (resp_fifo_full),

        // APB Master Interface
        .psel           (psel),
        .penable        (penable),
        .paddr          (paddr),
        .pwdata         (pwdata),
        .pstrb          (pstrb),
        .pwrite         (pwrite),
        .pready         (pready),
        .pslverr        (pslverr)
    );

    //==========================================================================
    // MODULE 3: AXI Response Stage
    //==========================================================================
    axi_response_stage #(
        .ID_WIDTH       (ID_WIDTH),
        .RESP_FIFO_DEPTH(RESP_FIFO_DEPTH)
    ) u_axi_response_stage (
        .clk            (clk),
        .rst_n          (rst_n),

        // From Module 2: Transaction Completion
        .txn_complete   (txn_complete),
        .txn_id         (txn_id),
        .txn_resp       (txn_resp),

        // To Module 2: Backpressure  FIX
        .resp_fifo_full (resp_fifo_full),

        // AXI Write Response Channel
        .bvalid         (bvalid),
        .bready         (bready),
        .bresp          (bresp),
        .bid            (bid)
    );

endmodule
