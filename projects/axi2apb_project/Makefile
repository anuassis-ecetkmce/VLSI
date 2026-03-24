DESIGN_DIR    = design
TB_DIR        = testbench
UVM_DIR       = uvm
APB_VIP_DIR   = $(UVM_DIR)/apb_vip
AXI_VIP_DIR   = $(UVM_DIR)/axi_vip
PKG_DIR       = $(UVM_DIR)/packages
ENV_DIR       = $(UVM_DIR)/env
TESTS_DIR     = $(UVM_DIR)/tests

#DESIGN (RTL first)
DESIGN_SRCS = \
$(DESIGN_DIR)/common/axi_hold_reg.sv \
$(DESIGN_DIR)/common/sync_fifo.sv \
$(DESIGN_DIR)/axi_interface/axi_input_stage.sv \
$(DESIGN_DIR)/apb_interface/write_transaction_engine.sv \
$(DESIGN_DIR)/response/axi_response_stage.sv \
$(DESIGN_DIR)/top/axi_apb_write_bridge_top.sv \

#Add other design files here

#INTERFACES
IF_SRCS = \
    $(AXI_VIP_DIR)/axi_if.sv \
    $(APB_VIP_DIR)/cfs_apb_if.sv \

#UVM PACKAGES (ALWAYS BEFORE COMPONENTS)
# UVM Packages
PKG_SRCS = \
    $(PKG_DIR)/cfs_apb_pkg.sv \
    $(PKG_DIR)/cfs_bridge_pkg.sv \
    $(PKG_DIR)/cfs_bridge_test_pkg.sv \

#TB TOP (LAST)
TB_SRCS = \
    $(TB_DIR)/axi_apb_bridge_tb_top.sv

# FINAL ORDERED SOURCE LIST
ALL_SRCS = \
    $(DESIGN_SRCS) \
    $(IF_SRCS) \
    $(PKG_SRCS) \
    $(TB_SRCS)

# ---- Testbench top module name (EDIT THIS) ----
# Change tb_top to your actual top module, e.g. seq_tb or axi2apb_tb
TB_TOP = axi_apb_bridge_tb_top

#UVM test name
UVM_TEST ?= cfs_bridge_test_reg_access

# Work library
WORKLIB = worklib

# ---- Xcelium binary & options ----
XRUN = xrun
XRUN_COMMON = -64bit -access +rwc -licqueue -timescale 1ns/1ps -coverage all -covoverwrite
XRUN_UVM = -uvm -uvmhome CDNS-1.2 # xcelium UVM switch (adjust if your version differs)

# We tell xrun to look inside these folders when it sees an `include "file.sv"
INCDIRS = \
    +incdir+$(UVM_DIR) \
    +incdir+$(APB_VIP_DIR) \
    +incdir+$(PKG_DIR) \
    +incdir+$(ENV_DIR) \
    +incdir+$(TESTS_DIR) \
    +incdir+$(TB_DIR) \
    +incdir+$(DESIGN_DIR) \
    +incdir+$(AXI_VIP_DIR) \


# Extra arguments you might want:
# -gui : start in GUI
# -linedebug : better debug info
# -timescale : set global timescale if needed

# ==========================================
# Targets
# ==========================================

.PHONY: all compile run gui clean show_files

all: run

# Compile Only
compile:
	$(XRUN) $(XRUN_COMMON) $(XRUN_UVM) \
	-work $(WORKLIB) \
	-top $(TB_TOP) \
	$(INCDIRS) \
	$(ALL_SRCS) \
	-elaborate

# Run (Simulate the snapshot created by compile)
run: compile
	$(XRUN) -R \
	-work $(WORKLIB) \
	$(XRUN_COMMON) \
	+UVM_TESTNAME=$(UVM_TEST)

# GUI Mode
gui: compile
	$(XRUN) -R -gui \
	-work $(WORKLIB) \
	$(XRUN_COMMON) \
	+UVM_TESTNAME=$(UVM_TEST)

# Show what files the Makefile will compile (good for debugging)
show_files:
	@echo "Design files:"
	@echo " $(DESIGN_SRCS)"
	@echo ""
	@echo "Testbench/UVM files:"
	@echo " $(TB_SRCS) $(UVM_SRCS)"

# Remove simulation outputs
clean:
	rm -rf $(WORKLIB) xcelium.d xrun.history xrun.log waves.shm *.shm *.key *.err cov_work


#commands to run the makefile
# make clean - to clean the previous run output and log files
# make complie - to compile the code the files
# make run - to compile, elaborate and open the gui of the xcelium
# make show_files - Design files, Testbench/UVM file, Useful for debugging compile order and 			    missing files.
