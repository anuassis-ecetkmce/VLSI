`timescale 1ns/1ps

//==============================================================================
// Module: axi_input_stage
// Description: AXI Write Channel Input Stage (Module 1 of 3)
// Project: AXI-APB Write Bridge
//
// Dependencies:
//   - sync_fifo (from design/common/)
//   - axi_hold_reg (from design/common/)
//==============================================================================

module axi_input_stage #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter ID_WIDTH        = 4,
    parameter ADDR_FIFO_DEPTH = 8,
    parameter DATA_FIFO_DEPTH = 8
)(
    input  logic                      clk,
    input  logic                      rst_n,

    // AXI Write Address Channel
    input  logic                      awvalid,
    output logic                      awready,
    input  logic [ADDR_WIDTH-1:0]     awaddr,
    input  logic [2:0]                awsize,
    input  logic [7:0]                awlen,
    input  logic [1:0]                awburst,
    input  logic [ID_WIDTH-1:0]       awid,

    // AXI Write Data Channel
    input  logic                      wvalid,
    output logic                      wready,
    input  logic [DATA_WIDTH-1:0]     wdata,
    input  logic [DATA_WIDTH/8-1:0]   wstrb,
    input  logic                      wlast,

    // To Module 2: Command Output
    output logic                      cmd_valid,
    input  logic                      cmd_ready,
    output logic [ADDR_WIDTH-1:0]     cmd_addr,
    output logic [ID_WIDTH-1:0]       cmd_id,

    // To Module 2: Write Data Output
    output logic                      wdata_valid,
    input  logic                      wdata_ready,
    output logic [DATA_WIDTH-1:0]     wdata_out,
    output logic [DATA_WIDTH/8-1:0]   wstrb_out
);

    localparam STRB_W = DATA_WIDTH / 8;
    localparam AW_W   = ADDR_WIDTH + ID_WIDTH;
    localparam W_W    = DATA_WIDTH + STRB_W;

    // AW path
    logic              aw_push, cmd_full, cmd_empty;
    logic [AW_W-1:0]   aw_packed, cmd_out;

    // W path
    logic              w_push, wdat_full, wdat_empty;
    logic [W_W-1:0]    w_packed, wdat_out;

    //==========================================================================
    // AW hold reg → Command FIFO
    //==========================================================================
    axi_hold_reg #(.WIDTH(AW_W)) u_aw_hold (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(awvalid),
        .in_ready(awready),
        .data_in({awaddr, awid}),
        .fifo_full(cmd_full),
        .push(aw_push),
        .data_out(aw_packed)
    );

    sync_fifo #(.WIDTH(AW_W), .DEPTH(ADDR_FIFO_DEPTH)) u_cmd_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(aw_push),
        .wr_data(aw_packed),
        .full(cmd_full),
        .rd_en(cmd_valid && cmd_ready),
        .rd_data(cmd_out),
        .empty(cmd_empty)
    );

    //==========================================================================
    // W hold reg → Write Data FIFO
    //==========================================================================
    axi_hold_reg #(.WIDTH(W_W)) u_w_hold (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(wvalid),
        .in_ready(wready),
        .data_in({wdata, wstrb}),
        .fifo_full(wdat_full),
        .push(w_push),
        .data_out(w_packed)
    );

    sync_fifo #(.WIDTH(W_W), .DEPTH(DATA_FIFO_DEPTH)) u_wdat_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(w_push),
        .wr_data(w_packed),
        .full(wdat_full),
        .rd_en(wdata_valid && wdata_ready),
        .rd_data(wdat_out),
        .empty(wdat_empty)
    );

    //==========================================================================
    // FIFO output → Module 2
    //==========================================================================
    assign cmd_valid = !cmd_empty;
    assign cmd_addr  = cmd_out[ADDR_WIDTH+ID_WIDTH-1 : ID_WIDTH];
    assign cmd_id    = cmd_out[ID_WIDTH-1 : 0];

    assign wdata_valid = !wdat_empty;
    assign wdata_out   = wdat_out[DATA_WIDTH+STRB_W-1 : STRB_W];
    assign wstrb_out   = wdat_out[STRB_W-1 : 0];

endmodule