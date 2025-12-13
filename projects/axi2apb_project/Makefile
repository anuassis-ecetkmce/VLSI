#DESIGN (RTL first)
DESIGN_SRCS = \
design/rtl/axi_if.sv \
design/rtl/apb_if.sv \
design/rtl/axi2apb_fsm.sv \
design/rtl/axi2apb_ctrl.sv \
design/rtl/axi2apb_top.sv

#INTERFACES
IF_SRCS = \
uvm/interfaces/axi_if.sv \
uvm/interfaces/apb_if.sv

#UVM PACKAGES (ALWAYS BEFORE COMPONENTS)
UVM_PKG_SRCS = \
uvm/pkg/axi_pkg.sv \
uvm/pkg/apb_pkg.sv \
uvm/pkg/env_pkg.sv

#UVM COMPONENTS
UVM_COMP_SRCS = \
uvm/agent/axi/axi_driver.sv \
uvm/agent/axi/axi_monitor.sv \
uvm/agent/axi/axi_sequencer.sv \
uvm/agent/apb/apb_driver.sv \
uvm/agent/apb/apb_monitor.sv \
uvm/env/axi2apb_env.sv \
uvm/env/axi2apb_scoreboard.sv

# 5. UVM TESTS
UVM_TEST_SRCS = \
uvm/tests/base_test.sv \
uvm/tests/sanity_test.sv

#TB TOP (LAST)
TB_SRCS = \
testbench/seq_tb.sv

# FINAL ORDERED SOURCE LIST
ALL_SRCS = \
$(DESIGN_SRCS) \
$(IF_SRCS) \
$(UVM_PKG_SRCS) \
$(UVM_COMP_SRCS) \
$(UVM_TEST_SRCS) \
$(TB_SRCS)

# ---- Directories ----
#DESIGN_DIR = design
#TB_DIR = testbench
#UVM_DIR = uvm

# ---- Source file lists (auto-expand as you add files) ----
#DESIGN_SRCS 	= $(wildcard $(DESIGN_DIR)/*.v $(DESIGN_DIR)/*.sv)
#TB_SRCS	= $(wildcard $(TB_DIR)/*.v $(TB_DIR)/*.sv)
#UVM_SRCS 	= $(wildcard $(UVM_DIR)/*.v $(UVM_DIR)/*.sv)

# If you have uvm_pkg.sv / macros.svh etc, you can also add them explicitly:
# UVM_SRCS += $(UVM_DIR)/uvm_pkg.sv

#ALL_SRCS = \
#$(DESIGN_SRCS) \
#$(TB_SRCS) \
#$(UVM_SRCS)



# ---- Testbench top module name (EDIT THIS) ----
# Change tb_top to your actual top module, e.g. seq_tb or axi2apb_tb
TB_TOP = seq_tb

# ---- Xcelium binary & options ----
XRUN = xrun
XRUN_COMMON = -64bit -access +rwc -licqueue
XRUN_UVM = -uvm # xcelium UVM switch (adjust if your version differs)

# Extra arguments you might want:
# -gui : start in GUI
# -linedebug : better debug info
# -timescale : set global timescale if needed

# Work library
WORKLIB = sim

# ==========================================
# Targets
# ==========================================

.PHONY: all compile run gui clean show_files

all: run

# Just compile & elaborate, no run
compile:
	$(XRUN) $(XRUN_COMMON) $(XRUN_UVM) \
	-work $(WORKLIB) \
	-top $(TB_TOP) \
	$(ALL_SRCS) \
	-elaborate

# Compile + run in console mode
run: compile
	$(XRUN) $(XRUN_COMMON) $(XRUN_UVM) \
	     -work $(WORKLIB) \
	     -R

# Compile + run with GUI
gui: compile
	$(XRUN) $(XRUN_COMMON) $(XRUN_UVM) \
	-work $(WORKLIB) \
	-R -gui

# Show what files the Makefile will compile (good for debugging)
show_files:
	@echo "Design files:"
	@echo " $(DESIGN_SRCS)"
	@echo ""
	@echo "Testbench/UVM files:"
	@echo " $(TB_SRCS) $(UVM_SRCS)"

# Remove simulation outputs
clean:
	rm -rf $(WORKLIB) xrun.history xrun.log waves.shm *.shm *.key *.err
