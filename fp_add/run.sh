#!/bin/csh
iverilog -g2012 -o tb_exe -f list.f
if ( $status > 0 ) then
    echo "Aborted go and debug above it"
    exit 1
endif
vvp -l sim.log tb_exe -fst +transaction=100000
