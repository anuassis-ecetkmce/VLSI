`timescale 1ns/1ps

//==============================================================================
// Module: axi_read_input_stage
// Description: AXI Read Channel Input Stage (Module 1 of 3)
//
// Mirrors axi_input_stage for the write bridge, but handles only the AR
// channel — reads have no data channel.
//
// AR hold reg absorbs the AXI handshake burst, then pushes into a FIFO
// that decouples the AXI master from the APB engine.
//
// FIFO packing (AR):
//   [AW_W-1 : ID_WIDTH+8] = araddr
//   [ID_WIDTH+7 : 8]      = arid
//   [7:0]                 = arlen   (for future burst support; engine uses it)
//==============================================================================

module axi_read_input_stage #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter ID_WIDTH        = 4,
    parameter ADDR_FIFO_DEPTH = 8
)(
    input  logic                      clk,
    input  logic                      rst_n,

    // AXI Read Address Channel
    input  logic                      arvalid,
    output logic                      arready,
    input  logic [ADDR_WIDTH-1:0]     araddr,
    input  logic [2:0]                arsize,
    input  logic [7:0]                arlen,
    input  logic [1:0]                arburst,
    input  logic [ID_WIDTH-1:0]       arid,

    // To Module 2: Command Output
    output logic                      cmd_valid,
    input  logic                      cmd_ready,
    output logic [ADDR_WIDTH-1:0]     cmd_addr,
    output logic [ID_WIDTH-1:0]       cmd_id,
    output logic [7:0]                cmd_len
);

    // AR FIFO packs: {araddr, arid, arlen}
    localparam AR_W = ADDR_WIDTH + ID_WIDTH + 8;

    logic             ar_push, cmd_full, cmd_empty;
    logic [AR_W-1:0]  ar_packed, cmd_out;

    // AR hold reg → Command FIFO
    axi_hold_reg #(.WIDTH(AR_W)) u_ar_hold (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (arvalid),
        .in_ready (arready),
        .data_in  ({araddr, arid, arlen}),
        .fifo_full(cmd_full),
        .push     (ar_push),
        .data_out (ar_packed)
    );

    sync_fifo #(
        .WIDTH(AR_W),
        .DEPTH(ADDR_FIFO_DEPTH)
    ) u_cmd_fifo (
        .clk    (clk),
        .rst_n  (rst_n),
        .wr_en  (ar_push),
        .wr_data(ar_packed),
        .full   (cmd_full),
        .rd_en  (cmd_valid && cmd_ready),
        .rd_data(cmd_out),
        .empty  (cmd_empty)
    );

    // FIFO output → Module 2
    assign cmd_valid = !cmd_empty;
    assign cmd_addr  = cmd_out[AR_W-1        : ID_WIDTH+8];
    assign cmd_id    = cmd_out[ID_WIDTH+7    : 8];
    assign cmd_len   = cmd_out[7:0];

endmodule
