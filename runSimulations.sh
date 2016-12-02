#!/bin/bash

sd()
{
  samples=$1
  mean=$2
  variance=0
  for sample in "${samples[@]}"
  do
    diff=$(bc -l <<< "$mean - $sample")
    variance=$(bc -l <<< "$variance + $diff*$diff")
  done
  variance=$(bc -l <<< "$variance/${#samples[@]}")
  sd=$(bc -l <<< "sqrt($variance)")
  echo $sd
}

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
    imgFile=out/$protocol/$duration/throughput.png
    touch $csvFile
    truncate -s 0 $csvFile
    for n in "${nSenders[@]}"
    do
      i=0
      samples=()
      sampleSum=0
      outDir=out/$protocol/$duration/${n}Senders
      echo -n "${n} " >> $csvFile
      while [ $((i+=1)) -le $nSamples ]
      do
        sample=$(awk -f throughput.awk $outDir/trace$i.tr)
        samples+=($sample)
        sampleSum=$(bc -l <<< "$sampleSum+$sample")
        echo -n "$sample " >> $csvFile
      done
      # Compute and print mean and 95% confidence interval for this row
      mean=$(bc -l <<< "$sampleSum/$nSamples")
      std_dev=$(sd $samples $mean)
      error=$(bc -l <<< "1.96*$std_dev/sqrt($nSamples)")
      echo -n $mean" " >> $csvFile
      echo    $error    >> $csvFile 
    done
    # Plot Graphics
    gnuplot -e "dataFile='$csvFile'; outPath='$imgFile'; yColumn=$(($nSamples+2))" throughput.gpi
  done
done

