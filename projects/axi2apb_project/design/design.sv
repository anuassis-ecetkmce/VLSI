`timescale 1ns/1ps

//##############################################################################
//  AXI4-to-APB Unified Bridge — Single-File Design for EDA Playground
//
//  Module order (bottom-up to satisfy dependencies):
//    1. sync_fifo
//    2. axi_hold_reg
//    3. address_decoder
//    4. write_response_ctrl
//    5. read_response_ctrl
//    6. unified_apb_output_regs
//    7. axi_input_stage          (write AW+W input)
//    8. axi_read_input_stage     (read AR input)
//    9. axi_response_stage       (write B channel output)
//   10. axi_read_data_stage      (read R channel output)
//   11. apb_arbiter              (write-priority + starvation guard)
//   12. unified_transaction_engine
//   13. axi_apb_bridge_top       (integrated top)
//##############################################################################

//==============================================================================
// 1. SYNC FIFO
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
        else if (wr_en && !full)
            wr_ptr <= wr_ptr + 1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (rd_en && !empty)
            rd_ptr <= rd_ptr + 1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DEPTH; i++)
                mem[i] <= '0;
        end
        else begin
            if (wr_en && !full)
                mem[wr_ptr[PTR_W-1:0]] <= wr_data;
            if (rd_en && !empty)
                mem[rd_ptr[PTR_W-1:0]] <= '0;
        end
    end

    assign rd_data = mem[rd_ptr[PTR_W-1:0]];
endmodule

//==============================================================================
// 2. AXI HOLD REGISTER
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
    assign push = occupied && !fifo_full;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            occupied <= 1'b0;
            data_out <= '0;
        end
        else begin
            if (push && !(in_valid && in_ready)) begin
                occupied <= 1'b0;
                data_out <= '0;
            end
            else if (!push && (in_valid && in_ready)) begin
                data_out <= data_in;
                occupied <= 1'b1;
            end
            else if (push && (in_valid && in_ready)) begin
                data_out <= data_in;
                occupied <= 1'b1;
            end
        end
    end
endmodule

//==============================================================================
// 3. ADDRESS DECODER
//==============================================================================
module address_decoder #(
    parameter ADDR_WIDTH  = 32,
    parameter NUM_SLAVES  = 4,
    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_BASE_ADDR = {
        32'h4000_0000, 32'h3000_0000, 32'h2000_0000, 32'h1000_0000
    },
    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_SIZE = {
        32'h1000_0000, 32'h1000_0000, 32'h1000_0000, 32'h1000_0000
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
// 4. WRITE RESPONSE CONTROLLER
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
// 5. READ RESPONSE CONTROLLER
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
    input  logic [DATA_WIDTH-1:0]   resp_prdata,
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
                resp_lat <= 2'b11;
            else
                resp_lat <= resp_pslverr ? 2'b10 : 2'b00;
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
// 6. UNIFIED APB OUTPUT REGISTERS
//==============================================================================
module unified_apb_output_regs #(
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
    input  logic                        write_not_read,
    output logic [NUM_SLAVES-1:0]       psel,
    output logic                        penable,
    output logic [ADDR_WIDTH-1:0]       paddr,
    output logic [DATA_WIDTH-1:0]       pwdata,
    output logic [DATA_WIDTH/8-1:0]     pstrb,
    output logic                        pwrite
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)        psel <= '0;
        else if (load_en)  psel <= slave_sel_in;
        else if (clear_en) psel <= '0;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)                    penable <= 1'b0;
        else if (clear_en || load_en)  penable <= 1'b0;
        else if (enable_set)           penable <= 1'b1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)       paddr <= '0;
        else if (load_en) paddr <= addr_in;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)       pwdata <= '0;
        else if (load_en) pwdata <= wdata_in;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)       pstrb <= '0;
        else if (load_en) pstrb <= strb_in;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)                    pwrite <= 1'b0;
        else if (clear_en && !load_en) pwrite <= 1'b0;
        else if (load_en)              pwrite <= write_not_read;
    end
endmodule

//==============================================================================
// 7. AXI WRITE INPUT STAGE
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
    input  logic                      awvalid,
    output logic                      awready,
    input  logic [ADDR_WIDTH-1:0]     awaddr,
    input  logic [2:0]                awsize,
    input  logic [7:0]                awlen,
    input  logic [1:0]                awburst,
    input  logic [ID_WIDTH-1:0]       awid,
    input  logic                      wvalid,
    output logic                      wready,
    input  logic [DATA_WIDTH-1:0]     wdata,
    input  logic [DATA_WIDTH/8-1:0]   wstrb,
    input  logic                      wlast,
    output logic                      cmd_valid,
    input  logic                      cmd_ready,
    output logic [ADDR_WIDTH-1:0]     cmd_addr,
    output logic [ID_WIDTH-1:0]       cmd_id,
    output logic [7:0]                cmd_len,
    output logic                      wdata_valid,
    input  logic                      wdata_ready,
    output logic [DATA_WIDTH-1:0]     wdata_out,
    output logic [DATA_WIDTH/8-1:0]   wstrb_out,
    output logic                      wdata_last
);
    localparam STRB_W = DATA_WIDTH / 8;
    localparam AW_W   = ADDR_WIDTH + ID_WIDTH + 8;
    localparam W_W    = DATA_WIDTH + STRB_W + 1;

    logic              aw_push, cmd_full, cmd_empty;
    logic [AW_W-1:0]   aw_packed, cmd_out;
    logic              w_push, wdat_full, wdat_empty;
    logic [W_W-1:0]    w_packed, wdat_out;

    axi_hold_reg #(.WIDTH(AW_W)) u_aw_hold (
        .clk(clk), .rst_n(rst_n),
        .in_valid(awvalid), .in_ready(awready),
        .data_in({awaddr, awid, awlen}),
        .fifo_full(cmd_full), .push(aw_push), .data_out(aw_packed)
    );

    sync_fifo #(.WIDTH(AW_W), .DEPTH(ADDR_FIFO_DEPTH)) u_cmd_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(aw_push), .wr_data(aw_packed), .full(cmd_full),
        .rd_en(cmd_valid && cmd_ready), .rd_data(cmd_out), .empty(cmd_empty)
    );

    axi_hold_reg #(.WIDTH(W_W)) u_w_hold (
        .clk(clk), .rst_n(rst_n),
        .in_valid(wvalid), .in_ready(wready),
        .data_in({wdata, wstrb, wlast}),
        .fifo_full(wdat_full), .push(w_push), .data_out(w_packed)
    );

    sync_fifo #(.WIDTH(W_W), .DEPTH(DATA_FIFO_DEPTH)) u_wdat_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(w_push), .wr_data(w_packed), .full(wdat_full),
        .rd_en(wdata_valid && wdata_ready), .rd_data(wdat_out), .empty(wdat_empty)
    );

    assign cmd_valid  = !cmd_empty;
    assign cmd_addr   = cmd_out[AW_W-1      : 8+ID_WIDTH];
    assign cmd_id     = cmd_out[8+ID_WIDTH-1 : 8];
    assign cmd_len    = cmd_out[7:0];

    assign wdata_valid = !wdat_empty;
    assign wdata_out   = wdat_out[W_W-1  : STRB_W+1];
    assign wstrb_out   = wdat_out[STRB_W : 1];
    assign wdata_last  = wdat_out[0];
endmodule

//==============================================================================
// 8. AXI READ INPUT STAGE
//==============================================================================
module axi_read_input_stage #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter ID_WIDTH        = 4,
    parameter ADDR_FIFO_DEPTH = 8
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      arvalid,
    output logic                      arready,
    input  logic [ADDR_WIDTH-1:0]     araddr,
    input  logic [2:0]                arsize,
    input  logic [7:0]                arlen,
    input  logic [1:0]                arburst,
    input  logic [ID_WIDTH-1:0]       arid,
    output logic                      cmd_valid,
    input  logic                      cmd_ready,
    output logic [ADDR_WIDTH-1:0]     cmd_addr,
    output logic [ID_WIDTH-1:0]       cmd_id,
    output logic [7:0]                cmd_len
);
    localparam AR_W = ADDR_WIDTH + ID_WIDTH + 8;

    logic             ar_push, cmd_full, cmd_empty;
    logic [AR_W-1:0]  ar_packed, cmd_out;

    axi_hold_reg #(.WIDTH(AR_W)) u_ar_hold (
        .clk(clk), .rst_n(rst_n),
        .in_valid(arvalid), .in_ready(arready),
        .data_in({araddr, arid, arlen}),
        .fifo_full(cmd_full), .push(ar_push), .data_out(ar_packed)
    );

    sync_fifo #(.WIDTH(AR_W), .DEPTH(ADDR_FIFO_DEPTH)) u_cmd_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(ar_push), .wr_data(ar_packed), .full(cmd_full),
        .rd_en(cmd_valid && cmd_ready), .rd_data(cmd_out), .empty(cmd_empty)
    );

    assign cmd_valid = !cmd_empty;
    assign cmd_addr  = cmd_out[AR_W-1     : ID_WIDTH+8];
    assign cmd_id    = cmd_out[ID_WIDTH+7 : 8];
    assign cmd_len   = cmd_out[7:0];
endmodule

//==============================================================================
// 9. AXI WRITE RESPONSE STAGE (B Channel)
//==============================================================================
module axi_response_stage #(
    parameter ID_WIDTH        = 4,
    parameter RESP_FIFO_DEPTH = 8
)(
    input  logic                clk,
    input  logic                rst_n,
    input  logic                txn_complete,
    input  logic [ID_WIDTH-1:0] txn_id,
    input  logic [1:0]          txn_resp,
    output logic                resp_fifo_full,
    output logic                bvalid,
    input  logic                bready,
    output logic [1:0]          bresp,
    output logic [ID_WIDTH-1:0] bid
);
    localparam FIFO_WIDTH = 2 + ID_WIDTH;

    logic                    resp_fifo_empty;
    logic [FIFO_WIDTH-1:0]   resp_fifo_rd_data;

    sync_fifo #(.WIDTH(FIFO_WIDTH), .DEPTH(RESP_FIFO_DEPTH)) u_response_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(txn_complete), .wr_data({txn_resp, txn_id}), .full(resp_fifo_full),
        .rd_en(bvalid && bready), .rd_data(resp_fifo_rd_data), .empty(resp_fifo_empty)
    );

    assign bvalid = !resp_fifo_empty;
    assign bresp  = resp_fifo_rd_data[FIFO_WIDTH-1 : ID_WIDTH];
    assign bid    = resp_fifo_rd_data[ID_WIDTH-1   : 0];
endmodule

//==============================================================================
// 10. AXI READ DATA STAGE (R Channel)
//==============================================================================
module axi_read_data_stage #(
    parameter DATA_WIDTH       = 32,
    parameter ID_WIDTH         = 4,
    parameter RDATA_FIFO_DEPTH = 8
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    txn_complete,
    input  logic [ID_WIDTH-1:0]     txn_id,
    input  logic [1:0]              txn_resp,
    input  logic [DATA_WIDTH-1:0]   txn_rdata,
    output logic                    rdata_fifo_full,
    output logic                    rvalid,
    input  logic                    rready,
    output logic [DATA_WIDTH-1:0]   rdata,
    output logic [1:0]              rresp,
    output logic [ID_WIDTH-1:0]     rid,
    output logic                    rlast
);
    localparam FIFO_W = DATA_WIDTH + ID_WIDTH + 2;

    logic            rdata_fifo_empty;
    logic [FIFO_W-1:0] rdata_fifo_rd;

    sync_fifo #(.WIDTH(FIFO_W), .DEPTH(RDATA_FIFO_DEPTH)) u_rdata_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(txn_complete), .wr_data({txn_resp, txn_id, txn_rdata}), .full(rdata_fifo_full),
        .rd_en(rvalid && rready), .rd_data(rdata_fifo_rd), .empty(rdata_fifo_empty)
    );

    assign rvalid = !rdata_fifo_empty;
    assign rresp  = rdata_fifo_rd[FIFO_W-1            : DATA_WIDTH+ID_WIDTH];
    assign rid    = rdata_fifo_rd[DATA_WIDTH+ID_WIDTH-1 : DATA_WIDTH];
    assign rdata  = rdata_fifo_rd[DATA_WIDTH-1         : 0];
    assign rlast  = 1'b1;
endmodule

//==============================================================================
// 11. APB ARBITER — Write-Priority with Starvation Protection
//==============================================================================
module apb_arbiter #(
    parameter MAX_WR_CONSEC = 4
)(
    input  logic clk,
    input  logic rst_n,
    input  logic wr_req,
    input  logic rd_req,
    input  logic engine_idle,
    output logic wr_grant,
    output logic rd_grant,
    output logic grant_valid
);
    localparam CNT_W = $clog2(MAX_WR_CONSEC + 1);

    logic [CNT_W-1:0] wr_consec_cnt;
    logic wr_grant_r, rd_grant_r;
    logic txn_active;
    logic new_wr_grant, new_rd_grant;

    logic wr_starving_rd;
    assign wr_starving_rd = (wr_consec_cnt >= MAX_WR_CONSEC[CNT_W-1:0]);

    always @(*) begin
        new_wr_grant = 1'b0;
        new_rd_grant = 1'b0;
        if (wr_req && rd_req) begin
            if (wr_starving_rd) new_rd_grant = 1'b1;
            else                new_wr_grant = 1'b1;
        end
        else if (wr_req) new_wr_grant = 1'b1;
        else if (rd_req) new_rd_grant = 1'b1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_grant_r <= 1'b0;
            rd_grant_r <= 1'b0;
            txn_active <= 1'b0;
        end
        else begin
            if (engine_idle) begin
                wr_grant_r <= new_wr_grant;
                rd_grant_r <= new_rd_grant;
                txn_active <= new_wr_grant || new_rd_grant;
            end
            else begin
                txn_active <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_consec_cnt <= '0;
        else if (engine_idle && (new_wr_grant || new_rd_grant)) begin
            if (new_wr_grant)
                wr_consec_cnt <= (wr_consec_cnt >= MAX_WR_CONSEC[CNT_W-1:0])
                                 ? wr_consec_cnt : wr_consec_cnt + 1'b1;
            else
                wr_consec_cnt <= '0;
        end
    end

    assign wr_grant    = wr_grant_r;
    assign rd_grant    = rd_grant_r;
    assign grant_valid = wr_grant_r || rd_grant_r;
endmodule

//==============================================================================
// 12. UNIFIED TRANSACTION ENGINE
//==============================================================================
module unified_transaction_engine #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter NUM_SLAVES = 4,
    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_BASE_ADDR = {
        32'h4000_0000, 32'h3000_0000, 32'h2000_0000, 32'h1000_0000
    },
    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_SIZE = {
        32'h1000_0000, 32'h1000_0000, 32'h1000_0000, 32'h1000_0000
    }
)(
    input  logic                    clk,
    input  logic                    rst_n,
    // Arbiter
    input  logic                    wr_grant,
    input  logic                    rd_grant,
    output logic                    engine_idle,
    // Write command
    input  logic                    wr_cmd_valid,
    output logic                    wr_cmd_ready,
    input  logic [ADDR_WIDTH-1:0]   wr_cmd_addr,
    input  logic [ID_WIDTH-1:0]     wr_cmd_id,
    input  logic [7:0]              wr_cmd_len,
    // Write data
    input  logic                    wr_wdata_valid,
    output logic                    wr_wdata_ready,
    input  logic [DATA_WIDTH-1:0]   wr_wdata_in,
    input  logic [DATA_WIDTH/8-1:0] wr_wstrb_in,
    input  logic                    wr_wdata_last,
    // Write response
    output logic                    wr_txn_complete,
    output logic [ID_WIDTH-1:0]     wr_txn_id,
    output logic [1:0]              wr_txn_resp,
    input  logic                    wr_resp_fifo_full,
    // Read command
    input  logic                    rd_cmd_valid,
    output logic                    rd_cmd_ready,
    input  logic [ADDR_WIDTH-1:0]   rd_cmd_addr,
    input  logic [ID_WIDTH-1:0]     rd_cmd_id,
    input  logic [7:0]              rd_cmd_len,
    // Read response
    output logic                    rd_txn_complete,
    output logic [ID_WIDTH-1:0]     rd_txn_id,
    output logic [1:0]              rd_txn_resp,
    output logic [DATA_WIDTH-1:0]   rd_txn_rdata,
    input  logic                    rd_rdata_fifo_full,
    // Shared APB
    output logic [NUM_SLAVES-1:0]   psel,
    output logic                    penable,
    output logic [ADDR_WIDTH-1:0]   paddr,
    output logic [DATA_WIDTH-1:0]   pwdata,
    output logic [DATA_WIDTH/8-1:0] pstrb,
    output logic                    pwrite,
    input  logic                    pready,
    input  logic [DATA_WIDTH-1:0]   prdata,
    input  logic                    pslverr
);
    localparam STRB_W = DATA_WIDTH / 8;

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

    logic [ADDR_WIDTH-1:0]   txn_addr;
    logic [ID_WIDTH-1:0]     txn_id_reg;
    logic [DATA_WIDTH-1:0]   txn_data;
    logic [STRB_W-1:0]       txn_strb;
    logic                    txn_is_write;

    logic [NUM_SLAVES-1:0]   slave_sel;
    logic                    decode_error;
    logic                    oreg_load_en, oreg_clear_en, oreg_enable_set;
    logic                    resp_valid, resp_is_decerr;

    logic                    resp_fifo_full_muxed;
    assign resp_fifo_full_muxed = txn_is_write ? wr_resp_fifo_full : rd_rdata_fifo_full;

    assign engine_idle = (apb_state == IDLE);

    // Transaction start
    logic wr_txn_start, rd_txn_start, txn_start;
    assign wr_txn_start = (apb_state == IDLE) && wr_grant && wr_cmd_valid && wr_wdata_valid;
    assign rd_txn_start = (apb_state == IDLE) && rd_grant && rd_cmd_valid;
    assign txn_start    = wr_txn_start || rd_txn_start;

    assign wr_cmd_ready   = wr_txn_start;
    assign wr_wdata_ready = wr_txn_start;
    assign rd_cmd_ready   = rd_txn_start;

    // Capture registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            txn_addr     <= '0;
            txn_id_reg   <= '0;
            txn_data     <= '0;
            txn_strb     <= '0;
            txn_is_write <= 1'b0;
        end
        else if (txn_start) begin
            if (wr_txn_start) begin
                txn_addr     <= wr_cmd_addr;
                txn_id_reg   <= wr_cmd_id;
                txn_data     <= wr_wdata_in;
                txn_strb     <= wr_wstrb_in;
                txn_is_write <= 1'b1;
            end else begin
                txn_addr     <= rd_cmd_addr;
                txn_id_reg   <= rd_cmd_id;
                txn_data     <= '0;
                txn_strb     <= '0;
                txn_is_write <= 1'b0;
            end
        end
    end

    // Address decoder
    address_decoder #(
        .ADDR_WIDTH(ADDR_WIDTH), .NUM_SLAVES(NUM_SLAVES),
        .SLAVE_BASE_ADDR(SLAVE_BASE_ADDR), .SLAVE_SIZE(SLAVE_SIZE)
    ) u_addr_decoder (
        .addr_in(txn_addr), .slave_sel(slave_sel), .decode_error(decode_error)
    );

    // FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) apb_state <= IDLE;
        else        apb_state <= apb_state_next;
    end

    always @(*) begin
        apb_state_next = apb_state;
        case (apb_state)
            IDLE:       if (txn_start) apb_state_next = SETUP;
            SETUP:      apb_state_next = DECODE;
            DECODE:     apb_state_next = decode_error ? ERROR : ENABLE;
            ENABLE:     apb_state_next = ACCESS;
            ACCESS: begin
                if (pready)
                    apb_state_next = resp_fifo_full_muxed ? RESP_STALL : IDLE;
                else
                    apb_state_next = WAIT;
            end
            WAIT: begin
                if (pready)
                    apb_state_next = resp_fifo_full_muxed ? RESP_STALL : IDLE;
            end
            RESP_STALL: if (!resp_fifo_full_muxed) apb_state_next = IDLE;
            ERROR:      if (!resp_fifo_full_muxed) apb_state_next = IDLE;
            default:    apb_state_next = IDLE;
        endcase
    end

    // Control signals
    assign oreg_load_en    = (apb_state == ENABLE);
    assign oreg_clear_en   = (apb_state == IDLE);
    assign oreg_enable_set = (apb_state == ACCESS) || (apb_state == WAIT);

    // APB output regs
    unified_apb_output_regs #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .NUM_SLAVES(NUM_SLAVES)
    ) u_apb_output_regs (
        .clk(clk), .rst_n(rst_n),
        .load_en(oreg_load_en), .clear_en(oreg_clear_en), .enable_set(oreg_enable_set),
        .slave_sel_in(slave_sel), .addr_in(txn_addr),
        .wdata_in(txn_data), .strb_in(txn_strb), .write_not_read(txn_is_write),
        .psel(psel), .penable(penable), .paddr(paddr),
        .pwdata(pwdata), .pstrb(pstrb), .pwrite(pwrite)
    );

    // Response valid
    assign resp_valid =
        (((apb_state == ACCESS) || (apb_state == WAIT)) && pready && !resp_fifo_full_muxed)
      || ((apb_state == RESP_STALL) && !resp_fifo_full_muxed)
      || ((apb_state == ERROR)      && !resp_fifo_full_muxed);
    assign resp_is_decerr = (apb_state == ERROR);

    // Write response controller
    write_response_ctrl #(.ID_WIDTH(ID_WIDTH)) u_write_resp_ctrl (
        .clk(clk), .rst_n(rst_n),
        .resp_valid(resp_valid && txn_is_write),
        .resp_is_decerr(resp_is_decerr), .resp_pslverr(pslverr),
        .resp_id(txn_id_reg),
        .txn_complete(wr_txn_complete), .txn_id(wr_txn_id), .txn_resp(wr_txn_resp)
    );

    // Read response controller
    read_response_ctrl #(.DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH)) u_read_resp_ctrl (
        .clk(clk), .rst_n(rst_n),
        .resp_valid(resp_valid && !txn_is_write),
        .resp_is_decerr(resp_is_decerr), .resp_pslverr(pslverr),
        .resp_prdata(prdata), .resp_id(txn_id_reg),
        .txn_complete(rd_txn_complete), .txn_id(rd_txn_id),
        .txn_resp(rd_txn_resp), .txn_rdata(rd_txn_rdata)
    );
endmodule

//==============================================================================
// 13. AXI-APB BRIDGE TOP — Integrated
//==============================================================================
module axi_apb_bridge_top #(
    parameter ADDR_WIDTH       = 32,
    parameter DATA_WIDTH       = 32,
    parameter ID_WIDTH         = 4,
    parameter NUM_SLAVES       = 4,
    parameter ADDR_FIFO_DEPTH  = 8,
    parameter DATA_FIFO_DEPTH  = 8,
    parameter RESP_FIFO_DEPTH  = 8,
    parameter RDATA_FIFO_DEPTH = 8,
    parameter MAX_WR_CONSEC    = 4,
    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_BASE_ADDR = {
        32'h4000_0000, 32'h3000_0000, 32'h2000_0000, 32'h1000_0000
    },
    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_SIZE = {
        32'h1000_0000, 32'h1000_0000, 32'h1000_0000, 32'h1000_0000
    }
)(
    input  logic                    clk,
    input  logic                    rst_n,
    // AXI Write Address
    input  logic                    awvalid,
    output logic                    awready,
    input  logic [ADDR_WIDTH-1:0]   awaddr,
    input  logic [2:0]              awsize,
    input  logic [7:0]              awlen,
    input  logic [1:0]              awburst,
    input  logic [ID_WIDTH-1:0]     awid,
    // AXI Write Data
    input  logic                    wvalid,
    output logic                    wready,
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [DATA_WIDTH/8-1:0] wstrb,
    input  logic                    wlast,
    // AXI Write Response
    output logic                    bvalid,
    input  logic                    bready,
    output logic [1:0]              bresp,
    output logic [ID_WIDTH-1:0]     bid,
    // AXI Read Address
    input  logic                    arvalid,
    output logic                    arready,
    input  logic [ADDR_WIDTH-1:0]   araddr,
    input  logic [2:0]              arsize,
    input  logic [7:0]              arlen,
    input  logic [1:0]              arburst,
    input  logic [ID_WIDTH-1:0]     arid,
    // AXI Read Data
    output logic                    rvalid,
    input  logic                    rready,
    output logic [DATA_WIDTH-1:0]   rdata,
    output logic [1:0]              rresp,
    output logic [ID_WIDTH-1:0]     rid,
    output logic                    rlast,
    // Shared APB
    output logic [NUM_SLAVES-1:0]   psel,
    output logic                    penable,
    output logic [ADDR_WIDTH-1:0]   paddr,
    output logic [DATA_WIDTH-1:0]   pwdata,
    output logic [DATA_WIDTH/8-1:0] pstrb,
    output logic                    pwrite,
    input  logic                    pready,
    input  logic [DATA_WIDTH-1:0]   prdata,
    input  logic                    pslverr
);
    // Write input → engine
    logic                      wr_cmd_valid, wr_cmd_ready;
    logic [ADDR_WIDTH-1:0]     wr_cmd_addr;
    logic [ID_WIDTH-1:0]       wr_cmd_id;
    logic [7:0]                wr_cmd_len;
    logic                      wr_wdata_valid, wr_wdata_ready;
    logic [DATA_WIDTH-1:0]     wr_wdata_out;
    logic [DATA_WIDTH/8-1:0]   wr_wstrb_out;
    logic                      wr_wdata_last;

    // Read input → engine
    logic                      rd_cmd_valid, rd_cmd_ready;
    logic [ADDR_WIDTH-1:0]     rd_cmd_addr;
    logic [ID_WIDTH-1:0]       rd_cmd_id;
    logic [7:0]                rd_cmd_len;

    // Engine → write response
    logic                      wr_txn_complete;
    logic [ID_WIDTH-1:0]       wr_txn_id;
    logic [1:0]                wr_txn_resp;
    logic                      wr_resp_fifo_full;

    // Engine → read response
    logic                      rd_txn_complete;
    logic [ID_WIDTH-1:0]       rd_txn_id;
    logic [1:0]                rd_txn_resp;
    logic [DATA_WIDTH-1:0]     rd_txn_rdata;
    logic                      rd_rdata_fifo_full;

    // Arbiter ↔ engine
    logic                      wr_grant, rd_grant, grant_valid, engine_idle;

    // Write Input Stage
    axi_input_stage #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH),
        .ADDR_FIFO_DEPTH(ADDR_FIFO_DEPTH), .DATA_FIFO_DEPTH(DATA_FIFO_DEPTH)
    ) u_wr_input (
        .clk(clk), .rst_n(rst_n),
        .awvalid(awvalid), .awready(awready), .awaddr(awaddr),
        .awsize(awsize), .awlen(awlen), .awburst(awburst), .awid(awid),
        .wvalid(wvalid), .wready(wready), .wdata(wdata), .wstrb(wstrb), .wlast(wlast),
        .cmd_valid(wr_cmd_valid), .cmd_ready(wr_cmd_ready),
        .cmd_addr(wr_cmd_addr), .cmd_id(wr_cmd_id), .cmd_len(wr_cmd_len),
        .wdata_valid(wr_wdata_valid), .wdata_ready(wr_wdata_ready),
        .wdata_out(wr_wdata_out), .wstrb_out(wr_wstrb_out), .wdata_last(wr_wdata_last)
    );

    // Read Input Stage
    axi_read_input_stage #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH),
        .ADDR_FIFO_DEPTH(ADDR_FIFO_DEPTH)
    ) u_rd_input (
        .clk(clk), .rst_n(rst_n),
        .arvalid(arvalid), .arready(arready), .araddr(araddr),
        .arsize(arsize), .arlen(arlen), .arburst(arburst), .arid(arid),
        .cmd_valid(rd_cmd_valid), .cmd_ready(rd_cmd_ready),
        .cmd_addr(rd_cmd_addr), .cmd_id(rd_cmd_id), .cmd_len(rd_cmd_len)
    );

    // Arbiter
    apb_arbiter #(.MAX_WR_CONSEC(MAX_WR_CONSEC)) u_arbiter (
        .clk(clk), .rst_n(rst_n),
        .wr_req(wr_cmd_valid && wr_wdata_valid), .rd_req(rd_cmd_valid),
        .engine_idle(engine_idle),
        .wr_grant(wr_grant), .rd_grant(rd_grant), .grant_valid(grant_valid)
    );

    // Unified Transaction Engine
    unified_transaction_engine #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH),
        .NUM_SLAVES(NUM_SLAVES), .SLAVE_BASE_ADDR(SLAVE_BASE_ADDR), .SLAVE_SIZE(SLAVE_SIZE)
    ) u_engine (
        .clk(clk), .rst_n(rst_n),
        .wr_grant(wr_grant), .rd_grant(rd_grant), .engine_idle(engine_idle),
        .wr_cmd_valid(wr_cmd_valid), .wr_cmd_ready(wr_cmd_ready),
        .wr_cmd_addr(wr_cmd_addr), .wr_cmd_id(wr_cmd_id), .wr_cmd_len(wr_cmd_len),
        .wr_wdata_valid(wr_wdata_valid), .wr_wdata_ready(wr_wdata_ready),
        .wr_wdata_in(wr_wdata_out), .wr_wstrb_in(wr_wstrb_out), .wr_wdata_last(wr_wdata_last),
        .wr_txn_complete(wr_txn_complete), .wr_txn_id(wr_txn_id), .wr_txn_resp(wr_txn_resp),
        .wr_resp_fifo_full(wr_resp_fifo_full),
        .rd_cmd_valid(rd_cmd_valid), .rd_cmd_ready(rd_cmd_ready),
        .rd_cmd_addr(rd_cmd_addr), .rd_cmd_id(rd_cmd_id), .rd_cmd_len(rd_cmd_len),
        .rd_txn_complete(rd_txn_complete), .rd_txn_id(rd_txn_id),
        .rd_txn_resp(rd_txn_resp), .rd_txn_rdata(rd_txn_rdata),
        .rd_rdata_fifo_full(rd_rdata_fifo_full),
        .psel(psel), .penable(penable), .paddr(paddr),
        .pwdata(pwdata), .pstrb(pstrb), .pwrite(pwrite),
        .pready(pready), .prdata(prdata), .pslverr(pslverr)
    );

    // Write Response Stage
    axi_response_stage #(.ID_WIDTH(ID_WIDTH), .RESP_FIFO_DEPTH(RESP_FIFO_DEPTH)) u_wr_resp (
        .clk(clk), .rst_n(rst_n),
        .txn_complete(wr_txn_complete), .txn_id(wr_txn_id), .txn_resp(wr_txn_resp),
        .resp_fifo_full(wr_resp_fifo_full),
        .bvalid(bvalid), .bready(bready), .bresp(bresp), .bid(bid)
    );

    // Read Data Stage
    axi_read_data_stage #(
        .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH), .RDATA_FIFO_DEPTH(RDATA_FIFO_DEPTH)
    ) u_rd_data (
        .clk(clk), .rst_n(rst_n),
        .txn_complete(rd_txn_complete), .txn_id(rd_txn_id),
        .txn_resp(rd_txn_resp), .txn_rdata(rd_txn_rdata),
        .rdata_fifo_full(rd_rdata_fifo_full),
        .rvalid(rvalid), .rready(rready), .rdata(rdata),
        .rresp(rresp), .rid(rid), .rlast(rlast)
    );
endmodule