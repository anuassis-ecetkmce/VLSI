`timescale 1ns/1ps

//==============================================================================
// Module: axi_hold_reg
// Description: Hold register for AXI handshake protocol timing.
//
// FIX 1: Push and new-capture are now mutually exclusive. The register will
//         not accept new data on the same cycle it is pushing to the FIFO.
//         This prevents the held data from being silently overwritten before
//         the FIFO has consumed it.
//
// FIX 2: data_out is cleared when push fires, removing stale data visibility.
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

    // FIX 1: Only assert ready when NOT occupied AND NOT in the middle of a
    // push. This ensures the master cannot send new data on the same cycle
    // the current hold data moves into the FIFO.
    assign in_ready = !occupied;

    // Push fires when we are holding data and the FIFO has room.
    assign push = occupied && !fifo_full;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            occupied <= 1'b0;
            data_out <= '0;
        end
        else begin
            // Push is always evaluated first (highest priority).
            // New capture is only allowed when we are NOT simultaneously pushing,
            // i.e. the slot is truly free on the NEXT cycle.
            if (push && !(in_valid && in_ready)) begin
                // Drain: slot becomes free, no new data this cycle.
                occupied <= 1'b0;
                data_out <= '0;            // FIX 2: clear stale data
            end
            else if (!push && (in_valid && in_ready)) begin
                // Normal capture: slot was empty, take new data.
                data_out <= data_in;
                occupied <= 1'b1;
            end
            else if (push && (in_valid && in_ready)) begin
                // Back-to-back: push out old, capture new in same cycle.
                // Slot stays occupied; just update the payload.
                data_out <= data_in;
                occupied <= 1'b1;
            end
            // else: push=0 and no new data → hold state unchanged.
        end
    end

endmodule
