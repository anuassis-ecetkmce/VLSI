`timescale 1ns/1ps
`include "cfs_bridge_test_pkg.sv"

module axi2apb_tb_top;

//Imports / Includes
import uvm_pkg::*;
import cfs_test_pkg::*;
`include "uvm_macro.svh";


//Clock & Reset signals
logic axi_aclk;
logic axi_aresetn;
logic apb_pclk;
logic apb_presetn;
//Interface instances
axi4_if	axi_if(.aclk(axi_clk), .aresetn(axi_resetn));
apb_if	apb_if(.pclk(apb_pclk), .presetn(apb_presetn));

// DUT instantiation
axi_apb_bridge #(
	.AXI_ADDR_WIDTH(32),
	.AXI_DATA_WIDTH(32),
	.AXI_ID_WIDTH(4)
 ) DUT (
	// AXI clocks & resets
	.axi_aclk    (axi_aclk),
	.axi_aresetn (axi_aresetn),

	// AXI write address channel
	.axi_awid    (axi_if.awid),
	.axi_awaddr  (axi_if.awaddr),
	.axi_awlen   (axi_if.awlen),
	.axi_awsize  (axi_if.awsize),
	.axi_awburst (axi_if.awburst),
	.axi_awlock  (axi_if.awlock),
	.axi_awcache (axi_if.awcache),
	.axi_awprot  (axi_if.awprot),
	.axi_awqos   (axi_if.awqos),
	.axi_awregion(axi_if.awregion),
	.axi_awuser  (axi_if.awuser),
	.axi_awvalid (axi_if.awvalid),
	.axi_awready (axi_if.awready),

// AXI write data channel
	.axi_wdata   (axi_if.wdata),
	.axi_wstrb   (axi_if.wstrb),
	.axi_wlast   (axi_if.wlast),
	.axi_wuser   (axi_if.wuser),
	.axi_wvalid  (axi_if.wvalid),
	.axi_wready  (axi_if.wready),

// AXI write response channel
	.axi_bid     (axi_if.bid),
	.axi_bresp   (axi_if.bresp),
	.axi_buser   (axi_if.buser),
	.axi_bvalid  (axi_if.bvalid),
	.axi_bready  (axi_if.bready),

// AXI read address channel
	.axi_arid    (axi_if.arid),
	.axi_araddr  (axi_if.araddr),
	.axi_arlen   (axi_if.arlen),
	.axi_arsize  (axi_if.arsize),
	.axi_arburst (axi_if.arburst),
	.axi_arlock  (axi_if.arlock),
	.axi_arcache (axi_if.arcache),
	.axi_arprot  (axi_if.arprot),
	.axi_arqos   (axi_if.arqos),
	.axi_arregion(axi_if.arregion),
	.axi_aruser  (axi_if.aruser),
	.axi_arvalid (axi_if.arvalid),
	.axi_arready (axi_if.arready),

// AXI read data channel
	.axi_rid     (axi_if.rid),
	.axi_rdata   (axi_if.rdata),
	.axi_rresp   (axi_if.rresp),
	.axi_rlast   (axi_if.rlast),
	.axi_ruser   (axi_if.ruser),
	.axi_rvalid  (axi_if.rvalid),
	.axi_rready  (axi_if.rready),

// APB clocks & resets
	.apb_pclk    (apb_pclk),
	.apb_presetn (apb_presetn),

// APB interface signals (DUT is APB master)
	.apb_paddr   (apb_if.paddr),
	.apb_pprot   (apb_if.pprot),
	.apb_psel    (apb_if.psel),
	.apb_penable (apb_if.penable),
	.apb_pwrite  (apb_if.pwrite),
	.apb_pwdata  (apb_if.pwdata),
	.apb_pstrb   (apb_if.pstrb),
	.apb_pready  (apb_if.pready),
	.apb_prdata  (apb_if.prdata),
	.apb_pslverr (apb_if.pslverr)
);

// Clock generation
initial begin
	axi_aclk = 0;
	forever #5 axi_aclk = ~axi_aclk; // 100 MHz
end

initial begin
	apb_pclk = 0;
	forever #5 apb_pclk = ~apb_pclk; // 100 MHz (can differ if needed)
end

// Reset generation
initial begin
	// Active-low resets
	axi_aresetn = 0;
	apb_presetn = 0;

	// Hold reset for N cycles
	repeat (20) @(posedge axi_aclk);
	// release resets synchronously
	axi_aresetn = 1;
	apb_presetn = 1;
end

// Simple behavioral APB slave (testbench slave)
// - Responds to DUT APB master operations.
// - Replace with a full UVM slave agent later.

initial begin : tb_apb_responder
	// local memory for slave
	bit [31:0] mem [0:1023];
	// initialize memory (optional)
	for (int i=0; i<1024; i++)
		mem[i] = 32'hDEAD_BEEF ^ i;

	// default outputs
	apb_if.pready = 0;
	apb_if.prdata = 0;
	apb_if.pslverr = 0;

	forever @(posedge apb_pclk) begin
		if (!apb_presetn) begin
			apb_if.pready  <= 0;
			apb_if.prdata  <= 0;
			apb_if.pslverr <= 0;
			continue;
		end

		// Detect SETUP phase: psel asserted and penable low
		if (apb_if.psel && !apb_if.penable) begin
			// Move to ACCESS next cycle
			@(posedge apb_pclk);
			if (apb_if.psel && apb_if.penable) begin
				// For simple model assert pready after one cycle and respond
				apb_if.pready <= 1;
				if (apb_if.pwrite) begin
					// write (word-address based)
					mem[apb_if.paddr[11:2]] <= apb_if.pwdata;
					apb_if.pslverr <= 0;
				end else begin
					// read
					apb_if.prdata <= mem[apb_if.paddr[11:2]];
					apb_if.pslverr <= 0;
				end
				// keep pready for one cycle then deassert
				@(posedge apb_pclk);
				apb_if.pready <= 0;
				// optionally clear prdata after a cycle
				apb_if.prdata <= 0;
			end
		end
	end
end

// UVM configuration: register virtual interfaces and basic config
initial begin
	// Register interfaces so UVM components can get them via uvm_config_db in build_phase
	uvm_config_db#(virtual apb_if)::set(null, "*", "apb_vif", apb_if);
	uvm_config_db#(virtual axi4_if)::set(null, "*", "axi_vif", axi_if);

	// Let APB agent be active (driver present). Set to 0 if monitor-only.
	uvm_config_db#(bit)::set(null, "*", "apb_active", 1);

	// Example: set driver timeout (if your driver reads this)
	// uvm_config_db#(int)::set(null, "uvm_top.env.agt.drv", "timeout_cycles", 500);

	// Run the UVM test (test name must match your test class string)
	// You can change the test name to any test implemented in uvm/tests/
	#200ns; // allow reset to settle
	run_test("apb_smoke_test");
end

// Top-level simulation timeout: avoid infinite runs
initial begin
	#100ms;
	`uvm_fatal("TIMEOUT", "Top-level timeout: simulation exceeded 100 ms")
end

// Waveform dumping - selective to keep file small
initial begin
	`ifdef DUMP_VCD
		$dumpfile("axi_apb_bridge_tb.vcd");
		// dump the DUT, AXI and APB interface signals
		$dumpvars(0, axi_apb_bridge_tb_top);
		`endif
	end

endmodule
