XRUN = xrun
UVM_HOME = $(shell echo ${UVM_HOME})
TEST ?= basic_test

all: sim

sim:
    $(XRUN) -sv -64bit -uvmhome ${UVM_HOME} -f sim/filelist.f \
           +UVM_TESTNAME=$(TEST) -coverage all -access +rw

cov:
    $(XRUN) -sv -64bit -uvmhome ${UVM_HOME} -f sim/filelist.f \
           +UVM_TESTNAME=$(TEST) -coverage all -access +rw \
           -covoverwrite

clean:
    rm -rf xrun.key xrun.log ucli.key waves cov_report/ simv* *.ucdb

regression: all
   
    @echo "Run 'make TEST=<testname>' for other tests."
