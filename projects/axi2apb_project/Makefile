
# ---- Directories ----
DESIGN_DIR = design
TB_DIR = testbench
UVM_DIR = uvm

# ---- Source file lists (auto-expand as you add files) ----
DESIGN_SRCS 	= $(wildcard $(DESIGN_DIR)/*.v $(DESIGN_DIR)/*.sv)
TB_SRCS		= $(wildcard $(TB_DIR)/*.v $(TB_DIR)/*.sv)
UVM_SRCS 	= $(wildcard $(UVM_DIR)/*.v $(UVM_DIR)/*.sv)

# If you have uvm_pkg.sv / macros.svh etc, you can also add them explicitly:
# UVM_SRCS += $(UVM_DIR)/uvm_pkg.sv

ALL_SRCS = \
$(DESIGN_SRCS) \
$(TB_SRCS) \
$(UVM_SRCS)

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
WORKLIB = INCA_libs

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
