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
      echo "Taking samples for protocol $protocol with $n senders during a $duration interval"
      i=0
      outDir=out/$protocol/$duration/${n}Senders
      while [ $((i+=1)) -le $nSamples ]
      do
        echo "Taking sample $i"
        ${nsPath} script-protocols-background.tcl --duration $duration --protocol $protocol --senders $n --outDir $outDir --traceFileName trace$i.tr
      done
    done
    # Extract throughput from those traces
    echo "Computing senders/throughput for protocol $protocol during a $duration interval"
    csvFile=out/$protocol/$duration/throughput.csv
    touch $csvFile
    truncate -s 0 $csvFile
    for n in "${nSenders[@]}"
    do
      i=0
      sampleSum=0
      outDir=out/$protocol/$duration/${n}Senders
      echo -n "${n}, " >> $csvFile
      while [ $((i+=1)) -le $nSamples ]
      do
        sample=$(awk -f throughput.awk $outDir/trace$i.tr)
        sampleSum=$(bc -l <<< "$sampleSum+$sample")
        echo -n "$sample, " >> $csvFile
      done
      echo $(bc -l <<< "$sampleSum/$nSamples")", " >> $csvFile
    done
    # TODO: Compute and print confidence interval for this row
    # gnuplot -e "dataFile='out_$protocol/throughput.data'; outPath='out_$protocol/throughput.png'" throughput.gpi
  done
done

