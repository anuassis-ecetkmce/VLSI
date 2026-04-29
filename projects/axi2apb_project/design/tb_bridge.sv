`timescale 1ns/1ps


module tb_integrated_bridge;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam ID_WIDTH   = 4;
    localparam NUM_SLAVES = 4;
    localparam STRB_W     = DATA_WIDTH / 8;
    localparam CLK_PERIOD = 10;
    localparam MAX_WR_CONSEC = 4;
    localparam [NUM_SLAVES*ADDR_WIDTH-1:0] SB = {
        32'h4000_0000, 32'h3000_0000, 32'h2000_0000, 32'h1000_0000};
    localparam [NUM_SLAVES*ADDR_WIDTH-1:0] SS = {
        32'h1000_0000, 32'h1000_0000, 32'h1000_0000, 32'h1000_0000};

    logic clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    logic rst_n;

    logic awvalid,awready; logic [ADDR_WIDTH-1:0] awaddr;
    logic [2:0] awsize; logic [7:0] awlen; logic [1:0] awburst; logic [ID_WIDTH-1:0] awid;
    logic wvalid,wready; logic [DATA_WIDTH-1:0] wdata; logic [STRB_W-1:0] wstrb; logic wlast;
    logic bvalid,bready; logic [1:0] bresp; logic [ID_WIDTH-1:0] bid;
    logic arvalid,arready; logic [ADDR_WIDTH-1:0] araddr;
    logic [2:0] arsize; logic [7:0] arlen; logic [1:0] arburst; logic [ID_WIDTH-1:0] arid;
    logic rvalid,rready; logic [DATA_WIDTH-1:0] rdata; logic [1:0] rresp;
    logic [ID_WIDTH-1:0] rid; logic rlast;
    logic [NUM_SLAVES-1:0] psel; logic penable; logic [ADDR_WIDTH-1:0] paddr;
    logic [DATA_WIDTH-1:0] pwdata; logic [STRB_W-1:0] pstrb;
    logic pwrite,pready; logic [DATA_WIDTH-1:0] prdata; logic pslverr;

    axi_apb_bridge_top #(.ADDR_WIDTH(ADDR_WIDTH),.DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),.NUM_SLAVES(NUM_SLAVES),
        .ADDR_FIFO_DEPTH(8),.DATA_FIFO_DEPTH(8),.RESP_FIFO_DEPTH(8),.RDATA_FIFO_DEPTH(8),
        .MAX_WR_CONSEC(MAX_WR_CONSEC),.SLAVE_BASE_ADDR(SB),.SLAVE_SIZE(SS)) u_dut (.*);

    // Debug probes
    wire [3:0] fsm_state    = u_dut.u_engine.apb_state;
    wire       dbg_wr_grant = u_dut.wr_grant;
    wire       dbg_rd_grant = u_dut.rd_grant;
    wire       dbg_idle     = u_dut.engine_idle;

    // Latency
    integer wr_latency_start, wr_latency, rd_latency_start, rd_latency;
    always @(posedge clk) begin
        if(awvalid&&awready) wr_latency_start=$time;
        if(bvalid&&bready) begin wr_latency=($time-wr_latency_start)/CLK_PERIOD;
            $display("  [TIMING] Write latency = %0d cycles",wr_latency); end
        if(arvalid&&arready) rd_latency_start=$time;
        if(rvalid&&rready) begin rd_latency=($time-rd_latency_start)/CLK_PERIOD;
            $display("  [TIMING] Read  latency = %0d cycles",rd_latency); end
    end

    // Utilisation
    integer cyc_total=0,cyc_idle=0,cyc_busy=0; real engine_busy_pct;
    always @(posedge clk) if(rst_n) begin cyc_total++; if(fsm_state==0)cyc_idle++;else cyc_busy++; end

    // Arbiter stats
    integer arb_wr_cnt=0,arb_rd_cnt=0,arb_wr_streak=0,arb_wr_streak_max=0;
    always @(posedge clk) if(rst_n&&dbg_idle) begin
        if(dbg_wr_grant) begin arb_wr_cnt++;arb_wr_streak++;
            if(arb_wr_streak>arb_wr_streak_max)arb_wr_streak_max=arb_wr_streak; end
        else if(dbg_rd_grant) begin arb_rd_cnt++;arb_wr_streak=0; end
    end

    // APB Slave Model
    logic [DATA_WIDTH-1:0] smem [0:NUM_SLAVES-1][0:15];
    integer pready_delay; logic inject_pslverr; integer pready_cnt; logic sl_busy;

    function automatic integer sidx(input [NUM_SLAVES-1:0] s);
        integer i;sidx=0;for(i=0;i<NUM_SLAVES;i++)if(s[i])sidx=i;
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin pready<=0;prdata<=0;pslverr<=0;pready_cnt<=0;sl_busy<=0; end
        else begin
            if(pready&&(!penable||!(|psel))) begin pready<=0;pslverr<=0;prdata<=0; end
            if(!sl_busy) begin
                if(|psel&&penable&&!pready) begin
                    if(pready_delay==0) begin pready<=1;pslverr<=inject_pslverr;
                        if(!pwrite)prdata<=smem[sidx(psel)][paddr[5:2]];
                        else smem[sidx(psel)][paddr[5:2]]<=pwdata;
                    end else begin pready_cnt<=pready_delay-1;sl_busy<=1; end
                end
            end else begin
                if(pready_cnt==0) begin pready<=1;pslverr<=inject_pslverr;
                    if(!pwrite)prdata<=smem[sidx(psel)][paddr[5:2]];
                    else smem[sidx(psel)][paddr[5:2]]<=pwdata;
                    sl_busy<=0;
                end else pready_cnt<=pready_cnt-1;
            end
        end
    end

    integer pass_cnt=0, fail_cnt=0;

    task automatic axi_write(input[ADDR_WIDTH-1:0]a,input[DATA_WIDTH-1:0]d,
                             input[STRB_W-1:0]s,input[ID_WIDTH-1:0]id);
        @(posedge clk);
        awvalid<=1;awaddr<=a;awsize<=3'b010;awlen<=0;awburst<=2'b01;awid<=id;
        wvalid<=1;wdata<=d;wstrb<=s;wlast<=1;
        fork
            begin @(posedge clk);while(!awready)@(posedge clk);awvalid<=0; end
            begin @(posedge clk);while(!wready)@(posedge clk);wvalid<=0;wlast<=0; end
        join
    endtask

    task automatic axi_read(input[ADDR_WIDTH-1:0]a,input[ID_WIDTH-1:0]id);
        @(posedge clk);arvalid<=1;araddr<=a;arsize<=3'b010;arlen<=0;arburst<=2'b01;arid<=id;
        @(posedge clk);while(!arready)@(posedge clk);arvalid<=0;
    endtask

    task automatic chk_b(input[1:0]er,input[ID_WIDTH-1:0]eid,input string nm);
        logic[1:0]gr;logic[ID_WIDTH-1:0]gi;
        bready<=1;@(posedge clk);while(!bvalid)@(posedge clk);
        gr=bresp;gi=bid;@(posedge clk);bready<=0;
        if(gr!==er||gi!==eid)begin $display("  [FAIL] %s bresp=%0b bid=%0h",nm,gr,gi);fail_cnt++;end
        else begin $display("  [PASS] %s bresp=%0b bid=%0h",nm,gr,gi);pass_cnt++;end
    endtask

    task automatic chk_r(input[DATA_WIDTH-1:0]ed,input[1:0]er,
                         input[ID_WIDTH-1:0]eid,input string nm);
        logic[DATA_WIDTH-1:0]gd;logic[1:0]gr;logic[ID_WIDTH-1:0]gi;
        rready<=1;@(posedge clk);while(!rvalid)@(posedge clk);
        gd=rdata;gr=rresp;gi=rid;@(posedge clk);rready<=0;
        if(gd!==ed||gr!==er||gi!==eid)begin
            $display("  [FAIL] %s rdata=%08h rresp=%0b rid=%0h",nm,gd,gr,gi);fail_cnt++;
        end else begin $display("  [PASS] %s rdata=%08h rresp=%0b rid=%0h",nm,gd,gr,gi);pass_cnt++;end
    endtask

    task automatic do_reset();
        integer i,j; rst_n<=0;awvalid<=0;wvalid<=0;arvalid<=0;bready<=0;rready<=0;wlast<=0;
        awaddr<=0;awsize<=0;awlen<=0;awburst<=0;awid<=0;wdata<=0;wstrb<=0;
        araddr<=0;arsize<=0;arlen<=0;arburst<=0;arid<=0;
        pready_delay=0;inject_pslverr=0;
        for(i=0;i<NUM_SLAVES;i++)for(j=0;j<16;j++)smem[i][j]=0;
        repeat(5)@(posedge clk);rst_n<=1;repeat(3)@(posedge clk);
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(1, tb_integrated_bridge);
        $dumpvars(1, tb_integrated_bridge.u_dut);

        // T1: Write + Read round-trip
        $display("\n===== T1: Write + read =====");
        do_reset();
        fork axi_write(32'h1000_0000,32'hA001_0001,4'hF,4'h1); chk_b(2'b00,4'h1,"T1-wr"); join
        repeat(5)@(posedge clk);
        fork axi_read(32'h1000_0000,4'h2); chk_r(32'hA001_0001,2'b00,4'h2,"T1-rd"); join
        repeat(3)@(posedge clk);

        // T2: RAW ordering
        $display("\n===== T2: RAW =====");
        do_reset();
        fork
            axi_write(32'h2000_0000,32'hA002_0002,4'hF,4'h3);
            begin repeat(1)@(posedge clk); axi_read(32'h2000_0000,4'h4); end
            chk_b(2'b00,4'h3,"T2-wr");
            chk_r(32'hA002_0002,2'b00,4'h4,"T2-rd");
        join
        repeat(3)@(posedge clk);

        // T3: Simultaneous W+R
        $display("\n===== T3: Simultaneous =====");
        do_reset(); smem[2][0]=32'hA003_0003;
        fork
            axi_write(32'h1000_0004,32'hA004_0004,4'hF,4'h5);
            axi_read(32'h3000_0000,4'h6);
            chk_b(2'b00,4'h5,"T3-wr");
            chk_r(32'hA003_0003,2'b00,4'h6,"T3-rd");
        join
        repeat(3)@(posedge clk);

        // T4: Starvation protection
        $display("\n===== T4: Starvation =====");
        do_reset(); smem[3][0]=32'hA005_0005;
        fork
            begin
                axi_write(32'h1000_0000,32'h0000_0001,4'hF,4'h1);
                axi_write(32'h1000_0004,32'h0000_0002,4'hF,4'h2);
                axi_write(32'h1000_0008,32'h0000_0003,4'hF,4'h3);
                axi_write(32'h1000_000C,32'h0000_0004,4'hF,4'h4);
                axi_write(32'h1000_0010,32'h0000_0005,4'hF,4'h5);
            end
            begin repeat(1)@(posedge clk); axi_read(32'h4000_0000,4'hA); end
            begin
                chk_b(2'b00,4'h1,"T4-w1");chk_b(2'b00,4'h2,"T4-w2");
                chk_b(2'b00,4'h3,"T4-w3");chk_b(2'b00,4'h4,"T4-w4");
            end
            chk_r(32'hA005_0005,2'b00,4'hA,"T4-rd");
        join
        chk_b(2'b00,4'h5,"T4-w5");
        repeat(3)@(posedge clk);

        // T5: Interleaved W-R-W-R with slow PREADY
        $display("\n===== T5: Interleaved =====");
        do_reset(); pready_delay=1; smem[0][1]=32'hA006_0006;
        fork begin
            axi_write(32'h1000_0000,32'hA007_0007,4'hF,4'h1);
            axi_read(32'h1000_0004,4'h2);
            axi_write(32'h1000_0008,32'hA008_0008,4'hF,4'h3);
            axi_read(32'h1000_0000,4'h4);
        end begin
            chk_b(2'b00,4'h1,"T5-w1");
            chk_r(32'hA006_0006,2'b00,4'h2,"T5-r1");
            chk_b(2'b00,4'h3,"T5-w2");
            chk_r(32'hA007_0007,2'b00,4'h4,"T5-r2");
        end join
        repeat(3)@(posedge clk);

        // T6: Decode error
        $display("\n===== T6: DECERR =====");
        do_reset();
        fork axi_read(32'hFFFF_0000,4'hD); chk_r(32'h0,2'b11,4'hD,"T6"); join
        repeat(3)@(posedge clk);

        // T7: Slave error
        $display("\n===== T7: SLVERR =====");
        do_reset(); inject_pslverr=1;
        fork axi_write(32'h1000_0000,32'h00E0_0009,4'hF,4'hE); chk_b(2'b10,4'hE,"T7"); join
        inject_pslverr=0; repeat(3)@(posedge clk);

        // T8: Back-to-back reads
        $display("\n===== T8: B2B reads =====");
        do_reset();
        smem[0][0]=32'h0010_000A; smem[1][0]=32'h0020_000B;
        smem[2][0]=32'h0030_000C; smem[3][0]=32'h0040_000D;
        fork begin
            axi_read(32'h1000_0000,4'h1);axi_read(32'h2000_0000,4'h2);
            axi_read(32'h3000_0000,4'h3);axi_read(32'h4000_0000,4'h4);
        end begin
            chk_r(32'h0010_000A,2'b00,4'h1,"T8-s0");chk_r(32'h0020_000B,2'b00,4'h2,"T8-s1");
            chk_r(32'h0030_000C,2'b00,4'h3,"T8-s2");chk_r(32'h0040_000D,2'b00,4'h4,"T8-s3");
        end join
        repeat(3)@(posedge clk);

        // T9: Back-to-back writes + memory verify
        $display("\n===== T9: B2B writes =====");
        do_reset();
        fork begin
            axi_write(32'h1000_0000,32'h0010_000E,4'hF,4'h1);
            axi_write(32'h2000_0000,32'h0020_000F,4'hF,4'h2);
            axi_write(32'h3000_0000,32'h0030_0010,4'hF,4'h3);
            axi_write(32'h4000_0000,32'h0040_0011,4'hF,4'h4);
        end begin
            chk_b(2'b00,4'h1,"T9-s0");chk_b(2'b00,4'h2,"T9-s1");
            chk_b(2'b00,4'h3,"T9-s2");chk_b(2'b00,4'h4,"T9-s3");
        end join
        repeat(5)@(posedge clk);
        if(smem[0][0]!==32'h0010_000E||smem[1][0]!==32'h0020_000F||
           smem[2][0]!==32'h0030_0010||smem[3][0]!==32'h0040_0011) begin
            $display("  [FAIL] T9-mem");fail_cnt++;
        end else begin $display("  [PASS] T9-mem");pass_cnt++; end
        repeat(3)@(posedge clk);

        // T10: Simultaneous W+R, slow PREADY
        $display("\n===== T10: Sim W+R slow =====");
        do_reset(); pready_delay=2; smem[3][2]=32'hA009_0012;
        fork
            axi_write(32'h1000_0000,32'hA00A_0013,4'hF,4'h7);
            axi_read(32'h4000_0008,4'h8);
            chk_b(2'b00,4'h7,"T10-wr");
            chk_r(32'hA009_0012,2'b00,4'h8,"T10-rd");
        join
        repeat(3)@(posedge clk);

        // T11: Backpressure — hold bready and rready low
        $display("\n===== T11: Backpressure =====");
        do_reset(); smem[1][0]=32'hA00B_0014;
        fork begin
            axi_write(32'h1000_0000,32'hA00C_0015,4'hF,4'h1);
            axi_read(32'h2000_0000,4'h2);
        end begin
            repeat(15)@(posedge clk);
            chk_b(2'b00,4'h1,"T11-wr");
            chk_r(32'hA00B_0014,2'b00,4'h2,"T11-rd");
        end join
        repeat(3)@(posedge clk);

        // T12: Error recovery — DECERR → SLVERR → normal W → normal R
        $display("\n===== T12: Error recovery =====");
        do_reset();
        fork axi_read(32'hFFFF_0000,4'hD); chk_r(32'h0,2'b11,4'hD,"T12-decerr"); join
        repeat(5)@(posedge clk);
        inject_pslverr=1;
        fork axi_write(32'h1000_0000,32'h00D0_0016,4'hF,4'hE); chk_b(2'b10,4'hE,"T12-slverr"); join
        inject_pslverr=0; repeat(5)@(posedge clk);
        fork axi_write(32'h1000_0000,32'h00D1_0017,4'hF,4'h1); chk_b(2'b00,4'h1,"T12-wr-ok"); join
        repeat(5)@(posedge clk);
        fork axi_read(32'h1000_0000,4'h2); chk_r(32'h00D1_0017,2'b00,4'h2,"T12-rd-ok"); join
        repeat(3)@(posedge clk);

        // Design effectiveness report
        engine_busy_pct = 100.0 * cyc_busy / cyc_total;
        $display("\n============================================");
        $display("  INTEGRATED BRIDGE RESULTS");
        $display("============================================");
        $display("  Tests:   %0d passed / %0d failed",pass_cnt,fail_cnt);
        $display("--------------------------------------------");
        $display("  Engine busy:       %0.1f%%",engine_busy_pct);
        $display("  Write grants:      %0d",arb_wr_cnt);
        $display("  Read grants:       %0d",arb_rd_cnt);
        $display("  Max consec writes: %0d (limit: %0d)",arb_wr_streak_max,MAX_WR_CONSEC);
        $display("============================================\n");
        if(fail_cnt==0) $display("  >>> ALL TESTS PASSED <<<\n");
        else            $display("  >>> SOME TESTS FAILED <<<\n");
        #20;$finish;
    end

    initial begin #80000;$display("[TIMEOUT]");$finish; end
    always @(posedge clk) if(rst_n&&penable&&!(|psel)) $display("[APB-MON] t=%0t PENABLE w/o PSEL",$time);
endmodule