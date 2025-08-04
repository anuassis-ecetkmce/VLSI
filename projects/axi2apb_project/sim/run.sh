TEST=$1
if[-z "$TEST"]; then
TEST="basic_test"
fi
xrun -sv -64bit -uvmhome $UVM_HOME \
     -f sim/filelist.f \
     +UVM_TESTNAME=$TEST \
     -access +rw \
     -coverage all \
     -l logs/$TEST.log

