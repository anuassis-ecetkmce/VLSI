// apb_driver.sv
import uvm_pkg::*;
`include "uvm_macros.svh"
`include "../sequences/apb_trans.sv"

class apb_driver extends uvm_driver#(apb_trans);
	`uvm_component_utils(apb_driver)

	virtual apb_if apb_vif;

	function new(string name="apb_driver", uvm_component parent=null);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", apb_vif))
		`uvm_fatal("NOVIF", "apb_vif not set in config_db for driver")
	endfunction

	virtual task run_phase(uvm_phase phase); // optional debug hook
	endtask

	// Main driver loop: get sequence item and perform APB transaction
	virtual task main_phase(uvm_phase phase); // not required; use run() below
	endtask

	virtual task run();
		apb_trans tr;
		forever begin
			seq_item_port.get_next_item(tr);

			// SETUP phase: drive psel=1, penable=0 and other signals
			apb_vif.slave_cb.psel <= 1;
			apb_vif.slave_cb.pwrite <= (tr.op == apb_trans::WRITE);
			apb_vif.slave_cb.paddr <= tr.addr;
			apb_vif.slave_cb.pwdata <= tr.data;
			apb_vif.slave_cb.pstrb <= 4'hF;
			apb_vif.slave_cb.penable <= 0;
			@(posedge apb_vif.pclk);

			// ACCESS phase: assert penable and wait for pready
			apb_vif.slave_cb.penable <= 1;
			// wait with a timeout to avoid permanent deadlock
			int timeout = 1000;
			int cnt = 0;
			while (!apb_vif.pready && cnt < timeout) begin
				@(posedge apb_vif.pclk);
				cnt++;
			end
			if (cnt >= timeout) begin
				`uvm_error("APB_DRV", "PREADY timeout")
				tr.err = 1;
			end else begin
				// capture read responses
				if (tr.op == apb_trans::READ) begin
					tr.resp_data = apb_vif.prdata;
					tr.err = apb_vif.pslverr;
				end else begin
					tr.err = apb_vif.pslverr;
				end
			end

			// Deassert
			apb_vif.slave_cb.psel <= 0;
			apb_vif.slave_cb.penable <= 0;
			apb_vif.slave_cb.paddr <= '0;
			apb_vif.slave_cb.pwdata <= '0;
			apb_vif.slave_cb.pwrite <= 0;
			apb_vif.slave_cb.pstrb <= '0;

			seq_item_port.item_done();
		end
	endtask
endclass
