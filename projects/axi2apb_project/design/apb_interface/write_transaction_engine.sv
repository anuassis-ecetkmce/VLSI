`timescale 1ns/1ps

//==============================================================================
// 1. ADDRESS DECODER (leaf module — no dependencies)
//==============================================================================

module address_decoder #(
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
    // Icarus-safe: no automatic, no int — use module-scope integer + always @(*)
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
// 2. APB OUTPUT REGS (leaf module — no dependencies)
//==============================================================================

module apb_output_regs #(
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
    input  logic [DATA_WIDTH-1:0]       wdata_in,
    input  logic [DATA_WIDTH/8-1:0]     strb_in,

    output logic [NUM_SLAVES-1:0]       psel,
    output logic                        penable,
    output logic [ADDR_WIDTH-1:0]       paddr,
    output logic [DATA_WIDTH-1:0]       pwdata,
    output logic [DATA_WIDTH/8-1:0]     pstrb,
    output logic                        pwrite
);

    // PSEL -- load_en beats clear_en (back-to-back transaction fix)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)        psel <= '0;
        else if (load_en)  psel <= slave_sel_in;
        else if (clear_en) psel <= '0;
    end

    // PENABLE
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            penable <= 1'b0;
        else if (clear_en || load_en)
            penable <= 1'b0;
        else if (enable_set)
            penable <= 1'b1;
    end

    // PADDR
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            paddr <= '0;
        else if (load_en)
            paddr <= addr_in;
    end

    // PWDATA
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwdata <= '0;
        else if (load_en)
            pwdata <= wdata_in;
    end

    // PSTRB
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pstrb <= '0;
        else if (load_en)
            pstrb <= strb_in;
    end

    // PWRITE -- load_en beats clear_en
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)                    pwrite <= 1'b0;
        else if (clear_en && !load_en) pwrite <= 1'b0;
        else if (load_en)              pwrite <= 1'b1;
    end

endmodule

//==============================================================================
// 3. WRITE RESPONSE CTRL (leaf module — no dependencies)
//==============================================================================

module write_response_ctrl #(
    parameter ID_WIDTH = 4
)(
    input  logic                clk,
    input  logic                rst_n,

    input  logic                resp_valid,
    input  logic                resp_is_decerr,
    input  logic                resp_pslverr,
    input  logic [ID_WIDTH-1:0] resp_id,

    output logic                txn_complete,
    output logic [ID_WIDTH-1:0] txn_id,
    output logic [1:0]          txn_resp
);

    // FIX: latch id and resp on resp_valid. txn_complete fires one cycle
    // later (registered resp_valid). Latched values are stable by then,
    // even if the engine starts the next transaction and overwrites
    // txn_id_reg on the same edge.
    logic [ID_WIDTH-1:0] id_lat;
    logic [1:0]          resp_lat;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_lat   <= '0;
            resp_lat <= 2'b00;
        end else if (resp_valid) begin
            id_lat <= resp_id;
            if (resp_is_decerr)
                resp_lat <= 2'b11;
            else
                resp_lat <= resp_pslverr ? 2'b10 : 2'b00;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) txn_complete <= 1'b0;
        else        txn_complete <= resp_valid;
    end

    assign txn_id   = id_lat;
    assign txn_resp = resp_lat;

endmodule

//==============================================================================
// 4. WRITE TRANSACTION ENGINE (top — instantiates the above three)
//==============================================================================

module write_transaction_engine #(
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

    input  logic                    cmd_valid,
    output logic                    cmd_ready,
    input  logic [ADDR_WIDTH-1:0]   cmd_addr,
    input  logic [ID_WIDTH-1:0]     cmd_id,
    input  logic [7:0]              cmd_len,

    input  logic                    wdata_valid,
    output logic                    wdata_ready,
    input  logic [DATA_WIDTH-1:0]   wdata_in,
    input  logic [DATA_WIDTH/8-1:0] wstrb_in,
    input  logic                    wdata_last,

    output logic                    txn_complete,
    output logic [ID_WIDTH-1:0]     txn_id,
    output logic [1:0]              txn_resp,

    input  logic                    resp_fifo_full,

    output logic [NUM_SLAVES-1:0]   psel,
    output logic                    penable,
    output logic [ADDR_WIDTH-1:0]   paddr,
    output logic [DATA_WIDTH-1:0]   pwdata,
    output logic [DATA_WIDTH/8-1:0] pstrb,
    output logic                    pwrite,
    input  logic                    pready,
    input  logic                    pslverr
);

    localparam STRB_W = DATA_WIDTH / 8;

    // FSM
    // FIX-A: DECODE state — txn_addr is written on IDLE->SETUP clock edge;
    //        decoder result is stale in SETUP. DECODE gives it one cycle to settle.
    // FIX-B: RESP_STALL — waits for response FIFO room without clearing APB outputs.
    // FIX-C: ENABLE state for APB SETUP phase (PSEL=1, PENABLE=0 for one full cycle).
    typedef enum logic [3:0] {
        IDLE       = 4'b0000,
        SETUP      = 4'b0001,   // capture regs written; do NOT read decoder yet
        DECODE     = 4'b0010,   // FIX-A: decoder settles on new txn_addr
        ENABLE     = 4'b0011,   // FIX-C: APB SETUP phase — PSEL=1, PENABLE=0
        ACCESS     = 4'b0100,   // APB ACCESS phase — PSEL=1, PENABLE=1
        WAIT       = 4'b0101,   // waiting for PREADY
        RESP_STALL = 4'b0110,   // FIX-B: waiting for response FIFO room
        ERROR      = 4'b0111    // decode error
    } apb_state_t;

    apb_state_t apb_state, apb_state_next;

    // Capture registers
    logic [ADDR_WIDTH-1:0]   txn_addr;
    logic [ID_WIDTH-1:0]     txn_id_reg;
    logic [DATA_WIDTH-1:0]   txn_data;
    logic [STRB_W-1:0]       txn_strb;

    // Internal wires
    logic [NUM_SLAVES-1:0]   slave_sel;
    logic                    decode_error;
    logic                    txn_start;

    logic                    oreg_load_en;
    logic                    oreg_clear_en;
    logic                    oreg_enable_set;

    logic                    resp_valid;
    logic                    resp_is_decerr;

    // Handshake
    assign txn_start   = (apb_state == IDLE) & cmd_valid & wdata_valid;
    assign cmd_ready   = txn_start;
    assign wdata_ready = txn_start;

    // Capture registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            txn_addr   <= '0;
            txn_id_reg <= '0;
            txn_data   <= '0;
            txn_strb   <= '0;
        end
        else if (txn_start) begin
            txn_addr   <= cmd_addr;
            txn_id_reg <= cmd_id;
            txn_data   <= wdata_in;
            txn_strb   <= wstrb_in;
        end
    end

    // Address Decoder
    address_decoder #(
        .ADDR_WIDTH     (ADDR_WIDTH),
        .NUM_SLAVES     (NUM_SLAVES),
        .SLAVE_BASE_ADDR(SLAVE_BASE_ADDR),
        .SLAVE_SIZE     (SLAVE_SIZE)
    ) u_addr_decoder (
        .addr_in        (txn_addr),
        .slave_sel      (slave_sel),
        .decode_error   (decode_error)
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
        apb_state_next = apb_state;  // default: hold state
        case (apb_state)
            IDLE:
                if (txn_start) apb_state_next = SETUP;

            // FIX-A: capture regs written this edge; decoder still sees old
            // txn_addr. Go to DECODE so it has one cycle to settle.
            SETUP:
                apb_state_next = DECODE;

            // FIX-A: decoder settled on new txn_addr now
            DECODE: begin
                if (decode_error)
                    apb_state_next = ERROR;
                else
                    apb_state_next = ENABLE;
            end

            // FIX-C: APB SETUP phase (PSEL loaded here, PENABLE=0)
            ENABLE:
                apb_state_next = ACCESS;

            ACCESS: begin
                if (pready) begin
                    if (resp_fifo_full)
                        apb_state_next = RESP_STALL;
                    else
                        apb_state_next = IDLE;
                end
                else
                    apb_state_next = WAIT;
            end

            WAIT: begin
                if (pready) begin
                    if (resp_fifo_full)
                        apb_state_next = RESP_STALL;
                    else
                        apb_state_next = IDLE;
                end
            end

            // FIX-B: hold until FIFO has room; APB outputs NOT cleared here
            RESP_STALL:
                if (!resp_fifo_full) apb_state_next = IDLE;

            ERROR:
                if (!resp_fifo_full) apb_state_next = IDLE;

            default:
                apb_state_next = IDLE;
        endcase
    end

    // Control signals
    // FIX-C: load_en fires in ENABLE (decoder valid from DECODE onwards)
    // FIX-B: clear_en fires in IDLE ONLY -- not RESP_STALL
    assign oreg_load_en    = (apb_state == ENABLE);
    assign oreg_clear_en   = (apb_state == IDLE);
    assign oreg_enable_set = (apb_state == ACCESS) || (apb_state == WAIT);

    // APB Output Regs
    apb_output_regs #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_SLAVES (NUM_SLAVES)
    ) u_apb_output_regs (
        .clk            (clk),
        .rst_n          (rst_n),
        .load_en        (oreg_load_en),
        .clear_en       (oreg_clear_en),
        .enable_set     (oreg_enable_set),
        .slave_sel_in   (slave_sel),
        .addr_in        (txn_addr),
        .wdata_in       (txn_data),
        .strb_in        (txn_strb),
        .psel           (psel),
        .penable        (penable),
        .paddr          (paddr),
        .pwdata         (pwdata),
        .pstrb          (pstrb),
        .pwrite         (pwrite)
    );

    assign resp_valid =
        (((apb_state == ACCESS) || (apb_state == WAIT)) && pready && !resp_fifo_full)
      || ((apb_state == RESP_STALL) && !resp_fifo_full)
      || ((apb_state == ERROR)      && !resp_fifo_full);
    assign resp_is_decerr = (apb_state == ERROR);

    // Write Response Controller
    write_response_ctrl #(
        .ID_WIDTH   (ID_WIDTH)
    ) u_write_resp_ctrl (
        .clk            (clk),
        .rst_n          (rst_n),
        .resp_valid     (resp_valid),
        .resp_is_decerr (resp_is_decerr),
        .resp_pslverr   (pslverr),
        .resp_id        (txn_id_reg),
        .txn_complete   (txn_complete),
        .txn_id         (txn_id),
        .txn_resp       (txn_resp)
    );

endmodule