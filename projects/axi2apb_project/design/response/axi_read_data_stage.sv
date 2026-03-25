`timescale 1ns/1ps

//==============================================================================
// Module: axi_read_data_stage
// Description: AXI Read Data Stage (Module 3 of 3)
//
// Mirrors axi_response_stage for the write bridge, but carries read data.
//
// FIFO width: DATA_WIDTH + ID_WIDTH + 2 (rdata + rid + rresp)
//
// rdata FIFO is written by read_transaction_engine (txn_complete pulse).
// rdata FIFO is read by the AXI R channel (rvalid && rready).
//
// rdata_fifo_full is exported back to Module 2 for backpressure.
//
// rlast is always 1 — single-beat reads only (matching write bridge scope).
//==============================================================================

module axi_read_data_stage #(
    parameter DATA_WIDTH       = 32,
    parameter ID_WIDTH         = 4,
    parameter RDATA_FIFO_DEPTH = 8
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // From Module 2: Transaction Completion
    input  logic                    txn_complete,
    input  logic [ID_WIDTH-1:0]     txn_id,
    input  logic [1:0]              txn_resp,
    input  logic [DATA_WIDTH-1:0]   txn_rdata,

    // To Module 2: Backpressure
    output logic                    rdata_fifo_full,

    // AXI Read Data Channel
    output logic                    rvalid,
    input  logic                    rready,
    output logic [DATA_WIDTH-1:0]   rdata,
    output logic [1:0]              rresp,
    output logic [ID_WIDTH-1:0]     rid,
    output logic                    rlast    // always 1 (single-beat)
);

    localparam FIFO_W = DATA_WIDTH + ID_WIDTH + 2;

    logic            rdata_fifo_empty;
    logic [FIFO_W-1:0] rdata_fifo_rd;

    sync_fifo #(
        .WIDTH(FIFO_W),
        .DEPTH(RDATA_FIFO_DEPTH)
    ) u_rdata_fifo (
        .clk    (clk),
        .rst_n  (rst_n),
        .wr_en  (txn_complete),
        .wr_data({txn_resp, txn_id, txn_rdata}),
        .full   (rdata_fifo_full),
        .rd_en  (rvalid && rready),
        .rd_data(rdata_fifo_rd),
        .empty  (rdata_fifo_empty)
    );

    // Bit layout: [FIFO_W-1 : DATA_WIDTH+ID_WIDTH] = rresp  (2 bits)
    //             [DATA_WIDTH+ID_WIDTH-1 : DATA_WIDTH] = rid (ID_WIDTH bits)
    //             [DATA_WIDTH-1 : 0]                 = rdata
    assign rvalid = !rdata_fifo_empty;
    assign rresp  = rdata_fifo_rd[FIFO_W-1        : DATA_WIDTH+ID_WIDTH];
    assign rid    = rdata_fifo_rd[DATA_WIDTH+ID_WIDTH-1 : DATA_WIDTH];
    assign rdata  = rdata_fifo_rd[DATA_WIDTH-1    : 0];
    assign rlast  = 1'b1;  // single-beat only

endmodule
