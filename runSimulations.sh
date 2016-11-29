#!/bin/bash

nsPath=~/ns-allinone-2.35/ns-2.35/ns
protocols=("tcp" "dctcp" "dccp")
durations=("1s" "10ms")
nSenders=(05 10 15 20)
nSamples=5

for protocol in "${protocols[@]}"
do
  for duration in "${durations[@]}"
  do
    for n in "${nSenders[@]}"
    do
      # For every scenario, run a simulation and create a trace file
      i=0
      outDir=out/$protocol/$duration/${n}Senders
      while [ $((i+=1)) -le $nSamples ]
      do
        ${nsPath} script-protocols-background.tcl --duration $duration --protocol $protocol --senders $n --outDir $outDir --traceFileName trace$i.tr
      done
    done
    # Extract throughput from those traces
    csvFile=out/$protocol/$duration/throughput.csv
    touch $csvFile
    truncate -s 0 $csvFile
    for n in "${nSenders[@]}"
    do
      i=0
      outDir=out/$protocol/$duration/${n}Senders
      echo -n "${n}, " >> $csvFile
      while [ $((i+=1)) -le $nSamples ]
      do
        awk -f throughput.awk $outDir/trace$i.tr >> $csvFile
        echo -n ", " >> $csvFile
      done
      echo "" >> $csvFile
    done
    # Compute Mean and confidence interval
    # gnuplot -e "dataFile='out_$protocol/throughput.data'; outPath='out_$protocol/throughput.png'" throughput.gpi
  done
done

