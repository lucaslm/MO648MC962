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
# Default number of samples is 5
nSamples=$(if [ $# -gt 0 ]; then echo $1; else echo 5; fi)

for protocol in "${protocols[@]}"
do
  for duration in "${durations[@]}"
  do
    for n in "${nSenders[@]}"
    do
      # For every scenario, run a simulation and create trace files
      echo "Taking $nSamples sample(s) for protocol $protocol with $n senders during a $duration interval"
      i=-1
      outDir=out/$protocol/$duration/${n}Senders
      while [ $((i+=1)) -lt $nSamples ]
      do
        traceFileName=trace.$i.tr
        throughputFileName=throughput.$i.tr
        queueFileName=queue.$i.%.tr
        echo "Taking sample $((i+1))"
        ${nsPath} script-protocols-background.tcl --duration $duration --protocol $protocol --senders $n --outDir $outDir --traceFileName $traceFileName --throughputFileName $throughputFileName --queueFileName $queueFileName
        for dataFile in $outDir/queue.$i.*.tr
        do
          gnuplot -e "dataFile='$dataFile'; outPath='${dataFile%.*}.png';" queue.gpi
        done
      done
    done
    # Assemble all throughputs on a single data file
    echo "Creating throughput data file for protocol $protocol during a $duration interval"
    dataFile=out/$protocol/$duration/throughput.tr
    touch $dataFile
    truncate -s 0 $dataFile
    for n in "${nSenders[@]}"
    do
      echo -n "${n} " >> $dataFile
      traceDir=out/$protocol/$duration/${n}Senders
      if [ $nSamples -gt 1 ]
      then
        i=-1
        samples=()
        sampleSum=0
        while [ $((i+=1)) -lt $nSamples ]
        do
          throughputFileName=throughput.$i.tr
          sample=$(cat $traceDir/$throughputFileName)
          samples+=($sample)
          sampleSum=$(bc -l <<< "$sampleSum+$sample")
          echo -n "$sample " >> $dataFile
        done
        # Compute and print mean and 95% confidence interval for this row
        mean=$(bc -l <<< "$sampleSum/$nSamples")
        std_dev=$(sd $samples $mean)
        error=$(bc -l <<< "1.96*$std_dev/sqrt($nSamples)")
        echo -n $mean" " >> $dataFile
        echo    $error   >> $dataFile
      else
        # Print the only single value for this row
        echo $(cat $traceDir/$throughputFileName) >> $dataFile
      fi
    done
    # Plot Graphics
    if [ $nSamples -gt 1 ]
    then
      gnuplot -e "dataFile='$dataFile'; outPath='${dataFile%.*}.png'; yColumn=$(($nSamples+2)); errorColumn=$(($nSamples+3))" throughput.gpi
    else
      gnuplot -e "dataFile='$dataFile'; outPath='${dataFile%.*}.png';" throughput.gpi
    fi
  done
done

