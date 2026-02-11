module axi_apb_write_bridge_top #(
    //==========================================================================
    // Parameters
    //==========================================================================
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter NUM_SLAVES = 4,
    
    // FIFO Depths
    parameter ADDR_FIFO_DEPTH = 8,
    parameter DATA_FIFO_DEPTH = 16,
    parameter RESP_FIFO_DEPTH = 8,
    
    // APB Slave Address Map
    // Slave 0: 0x1000_0000 - 0x1FFF_FFFF (256MB)
    // Slave 1: 0x2000_0000 - 0x2FFF_FFFF (256MB)
    // Slave 2: 0x3000_0000 - 0x3FFF_FFFF (256MB)
    // Slave 3: 0x4000_0000 - 0x4FFF_FFFF (256MB)
    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_BASE_ADDR = {
        32'h4000_0000,  // Slave 3
        32'h3000_0000,  // Slave 2
        32'h2000_0000,  // Slave 1
        32'h1000_0000   // Slave 0
    },
    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_SIZE = {
        32'h1000_0000,  // 256MB per slave
        32'h1000_0000,
        32'h1000_0000,
        32'h1000_0000
    }
)(
    //==========================================================================
    // Clock and Reset
    //==========================================================================
    input  logic                    clk,
    input  logic                    rst_n,      // Active-low asynchronous reset
    
    //==========================================================================
    // AXI4 Write Address Channel
    // Note: Burst signals present but NOT validated (VIP always correct)
    //       awsize, awlen, awburst - accepted as-is, no checking
    //==========================================================================
    input  logic                    awvalid,
    output logic                    awready,
    input  logic [ADDR_WIDTH-1:0]   awaddr,
    input  logic [2:0]              awsize,     // From VIP: 3'b010 (trusted)
    input  logic [7:0]              awlen,      // From VIP: 8'h00 (trusted)
    input  logic [1:0]              awburst,    // From VIP: 2'b01 (trusted)
    input  logic [ID_WIDTH-1:0]     awid,       // Transaction ID
    
    //==========================================================================
    // AXI4 Write Data Channel
    // Note: wlast accepted but not validated (VIP always sends 1)
    //==========================================================================
    input  logic                    wvalid,
    output logic                    wready,
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [DATA_WIDTH/8-1:0] wstrb,      // Byte lane strobes
    input  logic                    wlast,      // From VIP: 1'b1 (trusted)
    
    //==========================================================================
    // AXI4 Write Response Channel
    // Response Encoding:
    //   2'b00 = OKAY   - Successful write
    //   2'b10 = SLVERR - APB slave error (PSLVERR=1)
    //   2'b11 = DECERR - Address decode error only
    //==========================================================================
    output logic                    bvalid,
    input  logic                    bready,
    output logic [1:0]              bresp,
    output logic [ID_WIDTH-1:0]     bid,        // Matches AWID
    
    //==========================================================================
    // APB Master Interface
    // One-hot slave select for multi-slave support
    //==========================================================================
    output logic [NUM_SLAVES-1:0]   psel,       // One-hot: [3]=Slave3, [0]=Slave0
    output logic                    penable,
    output logic [ADDR_WIDTH-1:0]   paddr,
    output logic [DATA_WIDTH-1:0]   pwdata,
    output logic [DATA_WIDTH/8-1:0] pstrb,      // Byte strobes for partial writes
    output logic                    pwrite,     // Always 1 (write-only bridge)
    input  logic                    pready,
    input  logic                    pslverr
);

    //==========================================================================
    // Internal Signals: Module 1 → Module 2 (Command Path)
    //==========================================================================
    
    // Address/Command from FIFO to Transaction Engine
    logic                      cmd_valid;
    logic                      cmd_ready;
    logic [ADDR_WIDTH-1:0]     cmd_addr;
    logic [ID_WIDTH-1:0]       cmd_id;
    
    // Write Data from FIFO to Transaction Engine
    logic                      wdata_valid;
    logic                      wdata_ready;
    logic [DATA_WIDTH-1:0]     wdata_out;
    logic [DATA_WIDTH/8-1:0]   wstrb_out;
    
    //==========================================================================
    // Internal Signals: Module 2 → Module 3 (Completion Path - ONLY SOURCE)
    // Note: NO burst error path (burst parameters trusted)
    //==========================================================================
    
    // Transaction completion and status
    logic                      txn_complete;
    logic [ID_WIDTH-1:0]       txn_id;
    logic [1:0]                txn_resp;       // 00=OKAY, 10=SLVERR, 11=DECERR
    
    //==========================================================================
    // MODULE 1: AXI Input Stage (SIMPLIFIED - No Validation)
    // 
    // Key Responsibilities:
    // 1. Capture AXI AW and W channels
    // 2. Buffer in Command and Data FIFOs
    // 3. Drive AWREADY and WREADY based on FIFO status
    //
    // Signal Flow:
    //   AW → Command FIFO → Module 2
    //   W  → Write Data FIFO → Module 2
    //==========================================================================
    
    axi_input_stage #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .ADDR_FIFO_DEPTH(ADDR_FIFO_DEPTH),
        .DATA_FIFO_DEPTH(DATA_FIFO_DEPTH)
    ) u_axi_input_stage (
        .clk(clk),
        .rst_n(rst_n),
        
        // AXI Write Address Channel
        .awvalid(awvalid),
        .awready(awready),
        .awaddr(awaddr),
        .awsize(awsize),        // Connected but not used
        .awlen(awlen),          // Connected but not checked
        .awburst(awburst),      // Connected but not used
        .awid(awid),
        
        // AXI Write Data Channel
        .wvalid(wvalid),
        .wready(wready),
        .wdata(wdata),
        .wstrb(wstrb),
        .wlast(wlast),          // Connected but not checked
        
        // To Module 2: Command FIFO Output
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_addr(cmd_addr),
        .cmd_id(cmd_id),
        
        // To Module 2: Write Data FIFO Output
        .wdata_valid(wdata_valid),
        .wdata_ready(wdata_ready),
        .wdata_out(wdata_out),
        .wstrb_out(wstrb_out)
        
        // NO burst_error outputs (not checking bursts)
        // NO burst_error_id outputs
    );
    
    //==========================================================================
    // MODULE 2: Write Transaction Engine
    // 
    // Key Responsibilities:
    // 1. Synchronize address and data (wait for both cmd_valid && wdata_valid)
    // 2. Decode address to determine target APB slave
    // 3. Execute APB write protocol via APB Master FSM
    // 4. Handle APB PREADY wait states
    // 5. Capture PSLVERR for error reporting
    // 6. Signal transaction completion to Module 3
    //
    // Components:
    //   - Transaction Synchronizer: Matches address with data
    //   - Address Decoder: Determines slave and detects decode errors
    //   - APB Master FSM: Executes APB protocol (SETUP → ACCESS)
    //   - Response Collector: Aggregates errors (decode + slave)
    //==========================================================================
    
    write_transaction_engine #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .NUM_SLAVES(NUM_SLAVES),
        .SLAVE_BASE_ADDR(SLAVE_BASE_ADDR),
        .SLAVE_SIZE(SLAVE_SIZE)
    ) u_write_transaction_engine (
        .clk(clk),
        .rst_n(rst_n),
        
        // From Module 1: Command Input
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_addr(cmd_addr),
        .cmd_id(cmd_id),
        
        // From Module 1: Write Data Input
        .wdata_valid(wdata_valid),
        .wdata_ready(wdata_ready),
        .wdata_in(wdata_out),
        .wstrb_in(wstrb_out),
        
        // To Module 3: Transaction Completion (ONLY source)
        .txn_complete(txn_complete),
        .txn_id(txn_id),
        .txn_resp(txn_resp),        // OKAY/SLVERR/DECERR
        
        // APB Master Interface
        .psel(psel),                // One-hot slave select
        .penable(penable),
        .paddr(paddr),
        .pwdata(pwdata),
        .pstrb(pstrb),              // Passed from WSTRB
        .pwrite(pwrite),            // Always driven to 1
        .pready(pready),
        .pslverr(pslverr)
    );
    
    //==========================================================================
    // MODULE 3: AXI Response Stage (SIMPLIFIED - Single Input Source)
    // 
    // Key Responsibilities:
    // 1. Collect responses from Module 2 only (transaction completions)
    // 2. Buffer responses in Response FIFO
    // 3. Drive AXI B channel (BVALID, BRESP, BID)
    // 4. Handle BREADY backpressure
    // Response Types:
    //   - OKAY:   Successful write
    //   - SLVERR: APB slave error
    //   - DECERR: Address decode error only
    //==========================================================================
    
    axi_response_stage #(
        .ID_WIDTH(ID_WIDTH),
        .RESP_FIFO_DEPTH(RESP_FIFO_DEPTH)
    ) u_axi_response_stage (
        .clk(clk),
        .rst_n(rst_n),
        
        // From Module 2: Transaction Completion (ONLY source)
        .txn_complete(txn_complete),
        .txn_id(txn_id),
        .txn_resp(txn_resp),
        
        // AXI Write Response Channel
        .bvalid(bvalid),
        .bready(bready),
        .bresp(bresp),
        .bid(bid)                   // Always matches AWID
        
        
    );

endmodule