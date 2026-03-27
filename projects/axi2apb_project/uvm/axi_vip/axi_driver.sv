`ifndef AXI_DRIVER_SV
`define AXI_DRIVER_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_driver extends uvm_driver #(axi_transaction);

  axi_agent_config axi_cfg;

  `uvm_component_utils(axi_driver)

  virtual axi_if axi_vif;

  function new(string name = "axi_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual axi_if)::get(this,"","axi_vif",axi_vif))
      `uvm_fatal("NOVIF","axi_if not set for axi_driver")

  endfunction


  task reset_phase(uvm_phase phase);

    phase.raise_objection(this);

    axi_vif.reset_signals();

    phase.drop_objection(this);

  endtask


  task run_phase(uvm_phase phase);

    axi_transaction tr;

    forever begin

      seq_item_port.get_next_item(tr);

      if(tr.is_write)
        drive_write(tr);
      else
        drive_read(tr);

      seq_item_port.item_done();

    end

  endtask



  // =========================================
  // WRITE TRANSACTION
  // =========================================

  task drive_write(axi_transaction tr);

    int beats = tr.len + 1;

    // delay before address
    repeat(tr.pre_addr_delay) @(axi_vif.cb);


    //--------------------------------
    // WRITE ADDRESS CHANNEL
    //--------------------------------

    @(axi_vif.cb);

    axi_vif.cb.AWID    <= tr.id;
    axi_vif.cb.AWADDR  <= tr.addr;
    axi_vif.cb.AWLEN   <= tr.len;
    axi_vif.cb.AWSIZE  <= tr.size;
    axi_vif.cb.AWBURST <= tr.burst;

    axi_vif.cb.AWVALID <= 1;

    do @(axi_vif.cb);
    while(!axi_vif.cb.AWREADY);

    axi_vif.cb.AWVALID <= 0;



    // delay between address and data
    repeat(tr.addr_to_data_gap) @(axi_vif.cb);



    //--------------------------------
    // WRITE DATA CHANNEL
    //--------------------------------

    for(int i=0;i<beats;i++) begin

      repeat(tr.inter_beat_delay) @(axi_vif.cb);

      @(axi_vif.cb);

      axi_vif.cb.WDATA  <= tr.data_ary[i];
      axi_vif.cb.WSTRB  <= '1;
      axi_vif.cb.WLAST  <= (i == beats-1);

      axi_vif.cb.WVALID <= 1;

      do @(axi_vif.cb);
      while(!axi_vif.cb.WREADY);

      axi_vif.cb.WVALID <= 0;

    end


    @(axi_vif.cb);
    axi_vif.cb.WLAST <= 0;



    //--------------------------------
    // WRITE RESPONSE CHANNEL
    //--------------------------------

    repeat(tr.wait_for_bresp_delay) @(axi_vif.cb);

    @(axi_vif.cb);
    axi_vif.cb.BREADY <= 1;

    do @(axi_vif.cb);
    while(!(axi_vif.cb.BVALID));

    tr.resp = axi_vif.cb.BRESP;

    @(axi_vif.cb);
    axi_vif.cb.BREADY <= 0;

  endtask




  // =========================================
  // READ TRANSACTION
  // =========================================

  task drive_read(axi_transaction tr);

    int beats = tr.len + 1;

    tr.alloc_data_array();

    repeat(tr.pre_addr_delay) @(axi_vif.cb);


    //--------------------------------
    // READ ADDRESS CHANNEL
    //--------------------------------

    @(axi_vif.cb);

    axi_vif.cb.ARID    <= tr.id;
    axi_vif.cb.ARADDR  <= tr.addr;
    axi_vif.cb.ARLEN   <= tr.len;
    axi_vif.cb.ARSIZE  <= tr.size;
    axi_vif.cb.ARBURST <= tr.burst;

    axi_vif.cb.ARVALID <= 1;

    do @(axi_vif.cb);
    while(!axi_vif.cb.ARREADY);

    axi_vif.cb.ARVALID <= 0;



    //--------------------------------
    // READ DATA CHANNEL
    //--------------------------------

    @(axi_vif.cb);
    axi_vif.cb.RREADY <= 1;

    for(int i=0;i<beats;i++) begin

      do @(axi_vif.cb);
      while(!axi_vif.cb.RVALID);

      tr.data_ary[i] = axi_vif.cb.RDATA;

      if(axi_vif.cb.RLAST)
        break;

    end

    @(axi_vif.cb);
    axi_vif.cb.RREADY <= 0;

  endtask


endclass

`endif
