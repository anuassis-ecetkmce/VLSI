
# XM-Sim Command File
# TOOL:	xmsim(64)	22.09-s003
#

set tcl_prompt1 {puts -nonewline "xcelium> "}
set tcl_prompt2 {puts -nonewline "> "}
set vlog_format %h
set vhdl_format %v
set real_precision 6
set display_unit auto
set time_unit module
set heap_garbage_size -200
set heap_garbage_time 0
set assert_report_level note
set assert_stop_level error
set autoscope yes
set assert_1164_warnings yes
set pack_assert_off {}
set severity_pack_assert_off {note warning}
set assert_output_stop_level failed
set tcl_debug_level 0
set relax_path_name 1
set vhdl_vcdmap XX01ZX01X
set intovf_severity_level ERROR
set probe_screen_format 0
set rangecnst_severity_level ERROR
set textio_severity_level ERROR
set vital_timing_checks_on 1
set vlog_code_show_force 0
set assert_count_attempts 1
set tcl_all64 false
set tcl_runerror_exit false
set assert_report_incompletes 0
set show_force 1
set force_reset_by_reinvoke 0
set tcl_relaxed_literal 0
set probe_exclude_patterns {}
set probe_packed_limit 4k
set probe_unpacked_limit 16k
set assert_internal_msg no
set svseed 1
set assert_reporting_mode 0
set vcd_compact_mode 0
alias . run
alias quit exit
stop -create -name Randomize -randomize
database -open -vcd -into axi_apb_bridge_tb.vcd _axi_apb_bridge_tb.vcd1 -timescale fs
database -open -evcd -into axi_apb_bridge_tb.vcd _axi_apb_bridge_tb.vcd -timescale fs
database -open -shm -into waves.shm waves -default
probe -create -database waves axi_apb_bridge_tb_top.DUT.bid axi_apb_bridge_tb_top.DUT.awaddr axi_apb_bridge_tb_top.DUT.awburst axi_apb_bridge_tb_top.DUT.awid axi_apb_bridge_tb_top.DUT.awlen axi_apb_bridge_tb_top.DUT.awready axi_apb_bridge_tb_top.DUT.awsize axi_apb_bridge_tb_top.DUT.awvalid axi_apb_bridge_tb_top.DUT.bready axi_apb_bridge_tb_top.DUT.bresp axi_apb_bridge_tb_top.DUT.bvalid axi_apb_bridge_tb_top.DUT.clk axi_apb_bridge_tb_top.DUT.paddr axi_apb_bridge_tb_top.DUT.penable axi_apb_bridge_tb_top.DUT.pready axi_apb_bridge_tb_top.DUT.psel axi_apb_bridge_tb_top.DUT.pslverr axi_apb_bridge_tb_top.DUT.pstrb axi_apb_bridge_tb_top.DUT.pwdata axi_apb_bridge_tb_top.DUT.pwrite axi_apb_bridge_tb_top.DUT.rst_n axi_apb_bridge_tb_top.DUT.wdata axi_apb_bridge_tb_top.DUT.wlast axi_apb_bridge_tb_top.DUT.wready axi_apb_bridge_tb_top.DUT.wstrb axi_apb_bridge_tb_top.DUT.wvalid

simvision -input /home/rhel/Documents/VLSI/projects/axi2apb_project/.simvision/6840_rhel_vlsilab1.tkmce.ac.in_autosave.tcl.svcf
