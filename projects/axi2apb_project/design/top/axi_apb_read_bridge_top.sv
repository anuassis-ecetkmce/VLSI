`timescale 1ns/1ps

//==============================================================================
// Module: axi_apb_read_bridge_top
// Description: Top-level wrapper — AXI Read Channel to APB Master Bridge
//
// Pipeline:
//   Module 1  axi_read_input_stage    — AR hold reg + FIFO
//   Module 2  read_transaction_engine — address decode, APB FSM, rdata capture
//   Module 3  axi_read_data_stage     — rdata FIFO → AXI R channel
//
// Backpressure loop:
//   rdata_fifo_full (Module 3 → Module 2) stalls the engine in RESP_STALL
//   without toggling PSEL, preventing a partial APB transfer.
//
// APB notes:
//   pwrite  = 0 always (hardwired by Module 2)
//   pwdata  = 0 (not driven for reads; port omitted from top)
//   pstrb   = 0 (not driven for reads; port omitted from top)
//   prdata  comes back from the APB slave and is captured by Module 2
//
// AXI notes:
//   Single-beat reads only (arlen=0, rlast=1 always). Burst support
//   would require per-beat APB transfers and is not in scope here.
//==============================================================================

module axi_apb_read_bridge_top #(
    parameter ADDR_WIDTH       = 32,
    parameter DATA_WIDTH       = 32,
    parameter ID_WIDTH         = 4,
    parameter NUM_SLAVES       = 4,

    parameter ADDR_FIFO_DEPTH  = 8,
    parameter RDATA_FIFO_DEPTH = 8,

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

    // AXI4 Read Address Channel
    input  logic                    arvalid,
    output logic                    arready,
    input  logic [ADDR_WIDTH-1:0]   araddr,
    input  logic [2:0]              arsize,
    input  logic [7:0]              arlen,
    input  logic [1:0]              arburst,
    input  logic [ID_WIDTH-1:0]     arid,

    // AXI4 Read Data Channel
    output logic                    rvalid,
    input  logic                    rready,
    output logic [DATA_WIDTH-1:0]   rdata,
    output logic [1:0]              rresp,
    output logic [ID_WIDTH-1:0]     rid,
    output logic                    rlast,

    // APB Master Interface
    output logic [NUM_SLAVES-1:0]   psel,
    output logic                    penable,
    output logic [ADDR_WIDTH-1:0]   paddr,
    output logic                    pwrite,   // always 0
    input  logic [DATA_WIDTH-1:0]   prdata,
    input  logic                    pready,
    input  logic                    pslverr
);

    //==========================================================================
    // Internal Signals: Module 1 → Module 2
    //==========================================================================
    logic                   cmd_valid;
    logic                   cmd_ready;
    logic [ADDR_WIDTH-1:0]  cmd_addr;
    logic [ID_WIDTH-1:0]    cmd_id;
    logic [7:0]             cmd_len;

    //==========================================================================
    // Internal Signals: Module 2 → Module 3
    //==========================================================================
    logic                   txn_complete;
    logic [ID_WIDTH-1:0]    txn_id;
    logic [1:0]             txn_resp;
    logic [DATA_WIDTH-1:0]  txn_rdata;

    //==========================================================================
    // Internal Signals: Module 3 → Module 2 (backpressure)
    //==========================================================================
    logic                   rdata_fifo_full;

    //==========================================================================
    // MODULE 1: AXI Read Input Stage
    //==========================================================================
    axi_read_input_stage #(
        .ADDR_WIDTH     (ADDR_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .ID_WIDTH       (ID_WIDTH),
        .ADDR_FIFO_DEPTH(ADDR_FIFO_DEPTH)
    ) u_axi_read_input_stage (
        .clk        (clk),
        .rst_n      (rst_n),

        .arvalid    (arvalid),
        .arready    (arready),
        .araddr     (araddr),
        .arsize     (arsize),
        .arlen      (arlen),
        .arburst    (arburst),
        .arid       (arid),

        .cmd_valid  (cmd_valid),
        .cmd_ready  (cmd_ready),
        .cmd_addr   (cmd_addr),
        .cmd_id     (cmd_id),
        .cmd_len    (cmd_len)
    );

    //==========================================================================
    // MODULE 2: Read Transaction Engine
    //==========================================================================
    read_transaction_engine #(
        .ADDR_WIDTH     (ADDR_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .ID_WIDTH       (ID_WIDTH),
        .NUM_SLAVES     (NUM_SLAVES),
        .SLAVE_BASE_ADDR(SLAVE_BASE_ADDR),
        .SLAVE_SIZE     (SLAVE_SIZE)
    ) u_read_transaction_engine (
        .clk            (clk),
        .rst_n          (rst_n),

        .cmd_valid      (cmd_valid),
        .cmd_ready      (cmd_ready),
        .cmd_addr       (cmd_addr),
        .cmd_id         (cmd_id),
        .cmd_len        (cmd_len),

        .txn_complete   (txn_complete),
        .txn_id         (txn_id),
        .txn_resp       (txn_resp),
        .txn_rdata      (txn_rdata),

        .rdata_fifo_full(rdata_fifo_full),

        .psel           (psel),
        .penable        (penable),
        .paddr          (paddr),
        .pwrite         (pwrite),
        .pready         (pready),
        .prdata         (prdata),
        .pslverr        (pslverr)
    );

    //==========================================================================
    // MODULE 3: AXI Read Data Stage
    //==========================================================================
    axi_read_data_stage #(
        .DATA_WIDTH      (DATA_WIDTH),
        .ID_WIDTH        (ID_WIDTH),
        .RDATA_FIFO_DEPTH(RDATA_FIFO_DEPTH)
    ) u_axi_read_data_stage (
        .clk            (clk),
        .rst_n          (rst_n),

        .txn_complete   (txn_complete),
        .txn_id         (txn_id),
        .txn_resp       (txn_resp),
        .txn_rdata      (txn_rdata),

        .rdata_fifo_full(rdata_fifo_full),

        .rvalid         (rvalid),
        .rready         (rready),
        .rdata          (rdata),
        .rresp          (rresp),
        .rid            (rid),
        .rlast          (rlast)
    );

endmodule
