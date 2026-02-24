`timescale 1ns/1ps

//==============================================================================
// Module: axi_hold_reg
// Description: Hold register for AXI handshake protocol timing
// Project: AXI-APB Write Bridge
// Used By: Module 1 (AW and W channel hold registers)
//==============================================================================

module axi_hold_reg #(
    parameter WIDTH = 36
)(
    input  logic               clk,
    input  logic               rst_n,
    input  logic               in_valid,
    output logic               in_ready,
    input  logic [WIDTH-1:0]   data_in,
    input  logic               fifo_full,
    output logic               push,
    output logic [WIDTH-1:0]   data_out
);

    logic occupied;

    assign in_ready = !occupied;
    assign push     = occupied && !fifo_full;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            occupied <= 1'b0;
            data_out <= '0;
        end
        else begin
            if (push)
                occupied <= 1'b0;

            if (in_valid && in_ready) begin
                data_out <= data_in;
                occupied <= 1'b1;
            end
        end
    end

endmodule