#!/bin/bash

nsPath=~/ns-allinone-2.35/ns-2.35/ns
protocols=("tcp" "dctcp" "dccp")
nSenders=(5 10 15 20)
duration=60

for protocol in "${protocols[@]}";
do
  # Run simulations and create trace files
  i=0
  for n in "${nSenders[@]}";
  do
    ${nsPath} script-protocols-background.tcl --duration $duration --protocol $protocol --senders $n --outDir out_$protocol --traceFileName trace$i.tr
    i=$((i+1))
  done
  # Extract throughput from those traces
  truncate -s 0 out_$protocol/throughput.txt
  for f in out_$protocol/trace*.tr;
  do
    awk -f throughput.awk $f >> out_$protocol/throughput.txt
  done
done
