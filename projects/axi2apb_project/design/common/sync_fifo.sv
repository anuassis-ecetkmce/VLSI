`timescale 1ns/1ps

//==============================================================================
// Module: sync_fifo
// Description: Generic synchronous FIFO with dual-pointer architecture
// Project: AXI-APB Write Bridge
// Used By: Module 1 (Command & Data FIFOs), Module 3 (Response FIFO)
//==============================================================================

module sync_fifo #(
    parameter WIDTH = 32,
    parameter DEPTH = 8
)(
    input  logic               clk,
    input  logic               rst_n,
    input  logic               wr_en,
    input  logic [WIDTH-1:0]   wr_data,
    output logic               full,
    input  logic               rd_en,
    output logic [WIDTH-1:0]   rd_data,
    output logic               empty
);

    localparam PTR_W = $clog2(DEPTH);

    logic [WIDTH-1:0]  mem [0:DEPTH-1];
    logic [PTR_W:0]    wr_ptr;
    logic [PTR_W:0]    rd_ptr;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[PTR_W] != rd_ptr[PTR_W]) &&
                   (wr_ptr[PTR_W-1:0] == rd_ptr[PTR_W-1:0]);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;
        else if (wr_en && !full) begin
            mem[wr_ptr[PTR_W-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end

    assign rd_data = mem[rd_ptr[PTR_W-1:0]];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (rd_en && !empty)
            rd_ptr <= rd_ptr + 1;
    end

endmodule
