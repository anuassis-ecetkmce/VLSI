`ifndef AXI_TRANSACTION_SV
`define AXI_TRANSACTION_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_transaction extends uvm_sequence_item;


  rand bit [3:0]  id;
  rand bit [31:0] addr;
  rand bit [7:0]  len;
  rand bit [2:0]  size;
  rand bit [1:0]  burst;

  rand bit is_write;

  rand bit [31:0] data_ary[];

  bit [1:0] resp;



  rand int unsigned pre_addr_delay;
  rand int unsigned addr_to_data_gap;
  rand int unsigned inter_beat_delay;
  rand int unsigned wait_for_bresp_delay;



  `uvm_object_utils_begin(axi_transaction)

    `uvm_field_int(id,UVM_ALL_ON)
    `uvm_field_int(addr,UVM_ALL_ON)
    `uvm_field_int(len,UVM_ALL_ON)
    `uvm_field_int(size,UVM_ALL_ON)
    `uvm_field_int(burst,UVM_ALL_ON)
    `uvm_field_int(is_write,UVM_ALL_ON)

    `uvm_field_array_int(data_ary,UVM_ALL_ON)

    `uvm_field_int(resp,UVM_ALL_ON)

  `uvm_object_utils_end



  constraint c_len { len inside {[0:15]}; }

  constraint c_size { size inside {0,1,2}; }

  constraint c_burst { burst inside {0,1}; }

  constraint c_addr_align { addr % (1<<size) == 0; }

  constraint c_data_size { data_ary.size() == (len+1); }



  constraint c_default_delays {

    soft pre_addr_delay       dist {0:/70,[1:5]:/20,[6:20]:/10};
    soft addr_to_data_gap     dist {0:/70,[1:5]:/20,[6:20]:/10};
    soft inter_beat_delay     dist {0:/80,[1:3]:/20};
    soft wait_for_bresp_delay dist {0:/90,[1:5]:/10};

  }



  function new(string name="axi_transaction");
    super.new(name);
  endfunction



  function void alloc_data_array();

    data_ary.delete();

    data_ary = new[len+1];

    foreach(data_ary[i])
      data_ary[i] = $urandom;

  endfunction



  function void do_copy(uvm_object rhs);

    axi_transaction rhs_t;

    if(!$cast(rhs_t,rhs))
      `uvm_fatal("COPY","Cast failed")

    super.do_copy(rhs);

    id = rhs_t.id;
    addr = rhs_t.addr;
    len = rhs_t.len;
    size = rhs_t.size;
    burst = rhs_t.burst;
    is_write = rhs_t.is_write;
    resp = rhs_t.resp;

    pre_addr_delay = rhs_t.pre_addr_delay;
    addr_to_data_gap = rhs_t.addr_to_data_gap;
    inter_beat_delay = rhs_t.inter_beat_delay;
    wait_for_bresp_delay = rhs_t.wait_for_bresp_delay;

    data_ary = new[rhs_t.data_ary.size()];

    foreach(data_ary[i])
      data_ary[i] = rhs_t.data_ary[i];

  endfunction


endclass

`endif
