`timescale 1ns/1ps

//==============================================================================
// Module: axi_response_stage
// Description: AXI Write Response Stage (Module 3 of 3)
//
// FIX (Bug #2 - no backpressure): resp_fifo_full is now exported as an output
//   port so the write_transaction_engine can stall before writing into the
//   FIFO. Previously, wr_en=txn_complete was asserted even when the FIFO was
//   full, silently dropping the response and causing the AXI B-channel to
//   never assert bvalid, hanging the UVM test.
//==============================================================================

module axi_response_stage #(
    parameter ID_WIDTH        = 4,
    parameter RESP_FIFO_DEPTH = 8
)(
    input  logic                clk,
    input  logic                rst_n,

    // From Module 2: Transaction Completion
    input  logic                txn_complete,
    input  logic [ID_WIDTH-1:0] txn_id,
    input  logic [1:0]          txn_resp,

    // FIX (Bug #2): backpressure signal back to Module 2
    output logic                resp_fifo_full,

    // AXI Write Response Channel
    output logic                bvalid,
    input  logic                bready,
    output logic [1:0]          bresp,
    output logic [ID_WIDTH-1:0] bid
);

    localparam FIFO_WIDTH = 2 + ID_WIDTH;

    logic                    resp_fifo_empty;
    logic [FIFO_WIDTH-1:0]   resp_fifo_rd_data;

    sync_fifo #(
        .WIDTH(FIFO_WIDTH),
        .DEPTH(RESP_FIFO_DEPTH)
    ) u_response_fifo (
        .clk    (clk),
        .rst_n  (rst_n),

        // Write side: From Module 2
        // FIX: txn_complete is only asserted by the engine when !resp_fifo_full
        //      (see write_transaction_engine.sv resp_valid logic), so wr_en
        //      will never fire when full — no data is dropped.
        .wr_en  (txn_complete),
        .wr_data({txn_resp, txn_id}),
        .full   (resp_fifo_full),    // FIX: exported

        // Read side: To B channel
        .rd_en  (bvalid && bready),
        .rd_data(resp_fifo_rd_data),
        .empty  (resp_fifo_empty)
    );

    assign bvalid = !resp_fifo_empty;
    assign bresp  = resp_fifo_rd_data[FIFO_WIDTH-1 : ID_WIDTH];
    assign bid    = resp_fifo_rd_data[ID_WIDTH-1   : 0];

endmodule
