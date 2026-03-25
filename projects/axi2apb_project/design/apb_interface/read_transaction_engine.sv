`timescale 1ns/1ps

//==============================================================================
// Module: read_transaction_engine
// Description: AXI-APB Read Bridge — Transaction Engine (Module 2 of 3)
//
// Mirrors write_transaction_engine exactly, with these differences:
//   - No write-data channel (no wdata_valid/wdata_ready/wdata_in/wstrb_in)
//   - pwrite is hardwired 0 (read)
//   - prdata is captured when resp_valid fires and forwarded to Module 3
//   - Module 3 carries {rresp, rid, rdata} rather than just {bresp, bid}
//
// FSM states (same 8-state structure as write engine):
//   IDLE       — waiting for cmd_valid
//   SETUP      — capture registers written; decoder sees old txn_addr
//   DECODE     — decoder settled on new txn_addr; branch on decode_error
//   ENABLE     — APB SETUP phase: PSEL=1, PENABLE=0 (one full cycle)
//   ACCESS     — APB ACCESS phase: PSEL=1, PENABLE=1, waiting for PREADY
//   WAIT       — PREADY not seen in ACCESS; wait here
//   RESP_STALL — PREADY seen but rdata FIFO full; hold APB outputs, stall
//   ERROR      — decode error; generate DECERR response, no APB activity
//
// Backpressure:
//   rdata_fifo_full stalls in RESP_STALL (PSEL held, APB outputs frozen).
//   Same mechanism as write bridge resp_fifo_full.
//==============================================================================

//==============================================================================
// 1. ADDRESS DECODER  (identical to write bridge — reused verbatim)
//==============================================================================

module rd_address_decoder #(
    parameter ADDR_WIDTH  = 32,
    parameter NUM_SLAVES  = 4,

    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_BASE_ADDR = {
        32'h4000_0000,
        32'h3000_0000,
        32'h2000_0000,
        32'h1000_0000
    },
    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_SIZE = {
        32'h1000_0000,
        32'h1000_0000,
        32'h1000_0000,
        32'h1000_0000
    }
)(
    input  logic [ADDR_WIDTH-1:0]   addr_in,
    output logic [NUM_SLAVES-1:0]   slave_sel,
    output logic                    decode_error
);
    integer dec_i;
    always @(*) begin
        slave_sel    = {NUM_SLAVES{1'b0}};
        decode_error = 1'b1;
        for (dec_i = 0; dec_i < NUM_SLAVES; dec_i = dec_i + 1) begin
            if ((addr_in >= SLAVE_BASE_ADDR[dec_i*ADDR_WIDTH +: ADDR_WIDTH]) &&
                (addr_in <  SLAVE_BASE_ADDR[dec_i*ADDR_WIDTH +: ADDR_WIDTH]
                          + SLAVE_SIZE    [dec_i*ADDR_WIDTH +: ADDR_WIDTH])) begin
                slave_sel[dec_i] = 1'b1;
                decode_error     = 1'b0;
            end
        end
    end
endmodule

//==============================================================================
// 2. APB OUTPUT REGS  (same as write bridge; pwrite hardwired 0 at top level)
//    pwrite port kept so the module is reusable; top-level ties it to 0.
//==============================================================================

module rd_apb_output_regs #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_SLAVES = 4
)(
    input  logic                        clk,
    input  logic                        rst_n,

    input  logic                        load_en,
    input  logic                        clear_en,
    input  logic                        enable_set,

    input  logic [NUM_SLAVES-1:0]       slave_sel_in,
    input  logic [ADDR_WIDTH-1:0]       addr_in,

    output logic [NUM_SLAVES-1:0]       psel,
    output logic                        penable,
    output logic [ADDR_WIDTH-1:0]       paddr
);
    // PSEL — load_en beats clear_en
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)        psel <= '0;
        else if (load_en)  psel <= slave_sel_in;
        else if (clear_en) psel <= '0;
    end

    // PENABLE
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)                    penable <= 1'b0;
        else if (clear_en || load_en)  penable <= 1'b0;
        else if (enable_set)           penable <= 1'b1;
    end

    // PADDR
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)       paddr <= '0;
        else if (load_en) paddr <= addr_in;
    end

endmodule

//==============================================================================
// 3. READ RESPONSE CTRL
//    Captures rdata + rresp + rid on resp_valid; fires txn_complete one cycle
//    later.  Same latching strategy as write_response_ctrl to avoid race
//    between resp_valid and txn_start overwriting txn_id_reg.
//==============================================================================

module read_response_ctrl #(
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4
)(
    input  logic                    clk,
    input  logic                    rst_n,

    input  logic                    resp_valid,
    input  logic                    resp_is_decerr,
    input  logic                    resp_pslverr,
    input  logic [DATA_WIDTH-1:0]   resp_prdata,      // from APB slave
    input  logic [ID_WIDTH-1:0]     resp_id,

    output logic                    txn_complete,
    output logic [ID_WIDTH-1:0]     txn_id,
    output logic [1:0]              txn_resp,
    output logic [DATA_WIDTH-1:0]   txn_rdata
);
    logic [ID_WIDTH-1:0]   id_lat;
    logic [1:0]            resp_lat;
    logic [DATA_WIDTH-1:0] rdata_lat;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_lat    <= '0;
            resp_lat  <= 2'b00;
            rdata_lat <= '0;
        end else if (resp_valid) begin
            id_lat    <= resp_id;
            rdata_lat <= resp_is_decerr ? '0 : resp_prdata;
            if (resp_is_decerr)
                resp_lat <= 2'b11;                         // DECERR
            else
                resp_lat <= resp_pslverr ? 2'b10 : 2'b00; // SLVERR / OKAY
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) txn_complete <= 1'b0;
        else        txn_complete <= resp_valid;
    end

    assign txn_id    = id_lat;
    assign txn_resp  = resp_lat;
    assign txn_rdata = rdata_lat;

endmodule

//==============================================================================
// 4. READ TRANSACTION ENGINE (top of this file — instantiates the above three)
//==============================================================================

module read_transaction_engine #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter NUM_SLAVES = 4,

    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_BASE_ADDR = {
        32'h4000_0000,
        32'h3000_0000,
        32'h2000_0000,
        32'h1000_0000
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

    // From Module 1: Command Input
    input  logic                    cmd_valid,
    output logic                    cmd_ready,
    input  logic [ADDR_WIDTH-1:0]   cmd_addr,
    input  logic [ID_WIDTH-1:0]     cmd_id,
    input  logic [7:0]              cmd_len,      // unused for single-beat; kept for future

    // To Module 3: Transaction Completion
    output logic                    txn_complete,
    output logic [ID_WIDTH-1:0]     txn_id,
    output logic [1:0]              txn_resp,
    output logic [DATA_WIDTH-1:0]   txn_rdata,

    // From Module 3: Backpressure
    input  logic                    rdata_fifo_full,

    // APB Master Interface
    output logic [NUM_SLAVES-1:0]   psel,
    output logic                    penable,
    output logic [ADDR_WIDTH-1:0]   paddr,
    output logic                    pwrite,       // always 0 for reads
    input  logic                    pready,
    input  logic [DATA_WIDTH-1:0]   prdata,
    input  logic                    pslverr
);

    localparam STRB_W = DATA_WIDTH / 8;

    // FSM — identical encoding to write_transaction_engine
    typedef enum logic [3:0] {
        IDLE       = 4'b0000,
        SETUP      = 4'b0001,
        DECODE     = 4'b0010,
        ENABLE     = 4'b0011,
        ACCESS     = 4'b0100,
        WAIT       = 4'b0101,
        RESP_STALL = 4'b0110,
        ERROR      = 4'b0111
    } apb_state_t;

    apb_state_t apb_state, apb_state_next;

    // Capture registers
    logic [ADDR_WIDTH-1:0]  txn_addr;
    logic [ID_WIDTH-1:0]    txn_id_reg;

    // Internal wires
    logic [NUM_SLAVES-1:0]  slave_sel;
    logic                   decode_error;
    logic                   txn_start;

    logic                   oreg_load_en;
    logic                   oreg_clear_en;
    logic                   oreg_enable_set;

    logic                   resp_valid;
    logic                   resp_is_decerr;

    // pwrite = 0 always for reads
    assign pwrite = 1'b0;

    // Handshake: accept new command only when IDLE
    assign txn_start = (apb_state == IDLE) && cmd_valid;
    assign cmd_ready = txn_start;

    // Capture registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            txn_addr   <= '0;
            txn_id_reg <= '0;
        end else if (txn_start) begin
            txn_addr   <= cmd_addr;
            txn_id_reg <= cmd_id;
        end
    end

    // Address Decoder
    rd_address_decoder #(
        .ADDR_WIDTH     (ADDR_WIDTH),
        .NUM_SLAVES     (NUM_SLAVES),
        .SLAVE_BASE_ADDR(SLAVE_BASE_ADDR),
        .SLAVE_SIZE     (SLAVE_SIZE)
    ) u_addr_decoder (
        .addr_in      (txn_addr),
        .slave_sel    (slave_sel),
        .decode_error (decode_error)
    );

    // FSM state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            apb_state <= IDLE;
        else
            apb_state <= apb_state_next;
    end

    // FSM next-state
    always @(*) begin
        apb_state_next = apb_state;
        case (apb_state)
            IDLE:
                if (txn_start) apb_state_next = SETUP;

            // txn_addr written this edge; decoder still sees old value.
            SETUP:
                apb_state_next = DECODE;

            // Decoder settled; branch on decode_error.
            DECODE: begin
                if (decode_error)
                    apb_state_next = ERROR;
                else
                    apb_state_next = ENABLE;
            end

            // APB SETUP phase: PSEL=1, PENABLE=0.
            ENABLE:
                apb_state_next = ACCESS;

            // APB ACCESS phase: PSEL=1, PENABLE=1.
            ACCESS: begin
                if (pready) begin
                    if (rdata_fifo_full)
                        apb_state_next = RESP_STALL;
                    else
                        apb_state_next = IDLE;
                end else
                    apb_state_next = WAIT;
            end

            WAIT: begin
                if (pready) begin
                    if (rdata_fifo_full)
                        apb_state_next = RESP_STALL;
                    else
                        apb_state_next = IDLE;
                end
            end

            // rdata FIFO full after APB transfer; APB outputs held stable.
            RESP_STALL:
                if (!rdata_fifo_full) apb_state_next = IDLE;

            // Decode error; generate DECERR, no APB activity.
            ERROR:
                if (!rdata_fifo_full) apb_state_next = IDLE;

            default:
                apb_state_next = IDLE;
        endcase
    end

    // Control signals
    assign oreg_load_en    = (apb_state == ENABLE);
    assign oreg_clear_en   = (apb_state == IDLE);
    assign oreg_enable_set = (apb_state == ACCESS) || (apb_state == WAIT);

    // APB Output Regs
    rd_apb_output_regs #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_SLAVES (NUM_SLAVES)
    ) u_apb_output_regs (
        .clk          (clk),
        .rst_n        (rst_n),
        .load_en      (oreg_load_en),
        .clear_en     (oreg_clear_en),
        .enable_set   (oreg_enable_set),
        .slave_sel_in (slave_sel),
        .addr_in      (txn_addr),
        .psel         (psel),
        .penable      (penable),
        .paddr        (paddr)
    );

    // resp_valid: fires when result is available and FIFO has room
    assign resp_valid =
        (((apb_state == ACCESS) || (apb_state == WAIT)) && pready && !rdata_fifo_full)
      || ((apb_state == RESP_STALL) && !rdata_fifo_full)
      || ((apb_state == ERROR)      && !rdata_fifo_full);
    assign resp_is_decerr = (apb_state == ERROR);

    // Read Response Controller
    read_response_ctrl #(
        .DATA_WIDTH (DATA_WIDTH),
        .ID_WIDTH   (ID_WIDTH)
    ) u_read_resp_ctrl (
        .clk           (clk),
        .rst_n         (rst_n),
        .resp_valid    (resp_valid),
        .resp_is_decerr(resp_is_decerr),
        .resp_pslverr  (pslverr),
        .resp_prdata   (prdata),
        .resp_id       (txn_id_reg),
        .txn_complete  (txn_complete),
        .txn_id        (txn_id),
        .txn_resp      (txn_resp),
        .txn_rdata     (txn_rdata)
    );

endmodule
