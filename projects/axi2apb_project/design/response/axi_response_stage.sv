`timescale 1ns/1ps

module axi_response_stage #(
    parameter ID_WIDTH        = 4,
    parameter RESP_FIFO_DEPTH = 8
)(
    input  logic                clk,
    input  logic                rst_n,
    
    //--------------------------------------------------------------------------
    // From Module 2: Transaction Completion
    //--------------------------------------------------------------------------
    input  logic                txn_complete,
    input  logic [ID_WIDTH-1:0] txn_id,
    input  logic [1:0]          txn_resp,
    
    //--------------------------------------------------------------------------
    // AXI Write Response Channel
    //--------------------------------------------------------------------------
    output logic                bvalid,
    input  logic                bready,
    output logic [1:0]          bresp,
    output logic [ID_WIDTH-1:0] bid
);

    //==========================================================================
    // Local Parameters
    //==========================================================================
    localparam FIFO_WIDTH = 2 + ID_WIDTH;  // BRESP (2 bits) + BID (ID_WIDTH bits)

    //==========================================================================
    // Internal Wires
    //==========================================================================
    logic                    resp_fifo_empty;
    logic                    resp_fifo_full;
    logic [FIFO_WIDTH-1:0]   resp_fifo_rd_data;

    
    sync_fifo #(
        .WIDTH(FIFO_WIDTH),
        .DEPTH(RESP_FIFO_DEPTH)
    ) u_response_fifo (
        .clk(clk),
        .rst_n(rst_n),
        
        // Write side: From Module 2
        .wr_en(txn_complete),
        .wr_data({txn_resp, txn_id}),  // Pack: [resp(MSB), id(LSB)]
        .full(resp_fifo_full),
        
        // Read side: To B channel
        .rd_en(bvalid && bready),
        .rd_data(resp_fifo_rd_data),
        .empty(resp_fifo_empty)
    );
    
    //--------------------------------------------------------------------------
    // BVALID Generation: Simply invert FIFO empty flag
    //--------------------------------------------------------------------------
    assign bvalid = !resp_fifo_empty;
    assign bresp = resp_fifo_rd_data[FIFO_WIDTH-1 : ID_WIDTH];  // Upper 2 bits
    assign bid   = resp_fifo_rd_data[ID_WIDTH-1 : 0];           // Lower ID_WIDTH bits

endmodule