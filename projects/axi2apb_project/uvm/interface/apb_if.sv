// APB Interface Definition with Clocking Blocks
interface apb_if (
	input logic pclk,
	input logic presetn
);

	// APB Protocol Signals (APB3/APB4 compatible)
	logic [31:0] paddr;      // Address bus
	logic [2:0]  pprot;      // Protection type
	logic        psel;       // Slave select
	logic        penable;    // Enable (ACCESS phase indicator)
	logic        pwrite;     // Write enable (1=write, 0=read)
	logic [31:0] pwdata;     // Write data
	logic [3:0]  pstrb;      // Write strobe (byte lane enables)
	logic        pready;     // Slave ready
	logic [31:0] prdata;     // Read data
	logic        pslverr;    // Slave error response

	// Clocking Block for Driver (APB Master perspective)
	// - Outputs are driven at clock edge
	// - Inputs are sampled with appropriate skew
	clocking drv_cb @(posedge pclk);
		default input #1ns output #1ns;  // Setup/hold times
	
		// Outputs: Signals driven by master
		output paddr;
		output pprot;
		output psel;
		output penable;
		output pwrite;
		output pwdata;
		output pstrb;

		// Inputs: Signals received from slave
		input  pready;
		input  prdata;
		input  pslverr;
	endclocking

	// Clocking Block for Monitor (Passive observation)
	// - All signals are inputs from monitor's perspective
	clocking mon_cb @(posedge pclk);
		default input #1ns;
    
		input paddr;
		input pprot;
		input psel;
		input penable;
		input pwrite;
		input pwdata;
		input pstrb;
		input pready;
		input prdata;
		input pslverr;
	endclocking

	// Modports for Driver and Monitor
	modport driver (
		clocking drv_cb,
		input    presetn
	);

	modport monitor (
		clocking mon_cb,
		input    presetn
	);

	// Protocol Assertions for APB Compliance
	// synthesis translate_off
	
	// Check: SETUP phase must be followed by ACCESS phase
	property apb_setup_access;
		@(posedge pclk) disable iff (!presetn)
		(psel && !penable) |=> (psel && penable);
	endproperty
	
	assert_setup_access: assert property(apb_setup_access)
		else $error("APB Protocol Violation: SETUP must be followed by ACCESS");

	// Check: penable cannot be high without psel
	property apb_penable_requires_psel;
		@(posedge pclk) disable iff (!presetn)
		penable |-> psel;
	endproperty

	assert_penable_psel: assert property(apb_penable_requires_psel)
		else $error("APB Protocol Violation: PENABLE high without PSEL");

	// Check: Address and control signals stable during ACCESS
	property apb_stable_during_access;
		@(posedge pclk) disable iff (!presetn)
		(psel && penable && !pready) |=> $stable(paddr) && $stable(pwrite) && $stable(psel);
	endproperty

	assert_stable_access: assert property(apb_stable_during_access)
		else $error("APB Protocol Violation: Signals must be stable during ACCESS until PREADY");

	// Check: Write data stable during write ACCESS
	property apb_wdata_stable;
		@(posedge pclk) disable iff (!presetn)
		(psel && penable && pwrite && !pready) |=> $stable(pwdata) && $stable(pstrb);
	endproperty

	assert_wdata_stable: assert property(apb_wdata_stable)
		else $error("APB Protocol Violation: Write data must be stable during ACCESS");

	// synthesis translate_on

endinterface : apb_if
