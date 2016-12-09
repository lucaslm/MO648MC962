proc convertPrefix {value prefix {prefixBase 1000}} {
    if {[string is double $value]} {
        set value [expr double($value)]
        switch $prefix {
            "p" { return [expr $value*pow($prefixBase, -4)] }
            "n" { return [expr $value*pow($prefixBase, -3)] }
            "m" { return [expr $value*pow($prefixBase, -1)] }
            "K" { return [expr $value*pow($prefixBase,  1)] }
            "M" { return [expr $value*pow($prefixBase,  2)] }
            "G" { return [expr $value*pow($prefixBase,  3)] }
        }
    }
    return $value
}

# This procedure expects a value, representing a bandwidth and converts it to
# bits per second. SInce this is a rate, any positive racional number is valid.
# It assumes the unity prefixes have the usual meaning, such as ns does.
# See http://nsnam.sourceforge.net/wiki/index.php/Manual:_OTcl_Linkage#Variable_Bindings
proc toBitsPerSecond {value {prefixBase 1000}} {
    if {[string is double $value]} {
        # bps is a positive measure
        if {$value >= 0} {
            return $value
        }
    } else {
        regexp {([0-9]*\.?[0-9]+(e[0-9]+)?)([GMmKk])?([Bb])?} $value fullMatch n expo prefix unity
        if {[string equal $fullMatch $value]} {
            set prefix [string toupper $prefix]
            set n [convertPrefix $n $prefix $prefixBase]
            if {[string equal $unity "B"]} {
                set n [expr 8*$n]
            }
            return $n
        }
    }
    return -code error "Could not convert $value to bits per second"
}

# This procedure expects a value representing a storage capacity and converts
# it to bytes.
# It assumes the unity prefixes have the usual meaning
proc toBytes {value {prefixBase 1000}} {
    if {[string is double $value]} {
        if {8*$value == floor(8*$value) && $value >= 0} {
            return $value
        }
    } else {
        regexp {([0-9]*\.?[0-9]+(e[0-9]+)?)([GMmKk])?([Bb])?} $value fullMatch n expo prefix unity
        if {[string equal $fullMatch $value]} {
            set prefix [string toupper $prefix]
            set n [convertPrefix $n $prefix $prefixBase]
            if {[string equal $unity "b"]} {
                return [toBytes [expr double($n)/8]]
            }
            return [toBytes $n]
        }
    }
    return -code error "Could not convert $value to bytes"
}


proc toSeconds {t} {
    if {[string is double $t]} {
        return $t
    } else {
        regexp {([0-9]*\.?[0-9]+(e[0-9]+)?)([mnp])?s?} $t fullMatch n expo prefix
        if {[string equal $fullMatch $t]} {
          set n [convertPrefix $n $prefix]
          return $n
        }
        return 0
    }
}

proc isOptionSet {optionName} {
    global argv
    set index [lsearch $argv $optionName]
    return [expr $index > -1]
}

proc getOptionValue {optionName defaultValue} {
    global argv
    set index [lsearch $argv $optionName]
    if {$index > -1} {
        return [lindex $argv [expr $index + 1]]
    } else {
        return $defaultValue
    }
}

proc sourceAgentByProtocol {protocol} {
    switch $protocol {
        "TCP" {
            return [new Agent/TCP/Newreno]
        }
        "DCTCP" {
            return [new Agent/TCP/FullTcp/Sack]
        }
        "DCCP" {
            return [new Agent/DCCP/TFRC]
        }
    }
}

proc sinkAgentByProtocol {protocol} {
    global ns
    switch $protocol {
        "TCP" {
            return [new Agent/TCPSink]
        }
        "DCTCP" {
            set sinkAgent [new Agent/TCP/FullTcp/Sack]
            $ns at 0 "$sinkAgent listen"
            return $sinkAgent
        }
        "DCCP" {
            set sinkAgent [new Agent/DCCP/TFRC]
            $ns at 0 "$sinkAgent listen"
            return $sinkAgent
        }
    }
}

# Setup of several parameters, such as links bandwidths, numbers of nodes and
# simulation time.
set senderBw    [getOptionValue "--sendersBandwidth"  10Gb]
set receiverBw  [getOptionValue "--receiverBandWidth"  1Gb]
set pckgSize    [getOptionValue "--pckgSize"          1460]
set bufferSize  [getOptionValue "--bufferSize"         4MB]
set connections [getOptionValue "--connections"          1]
set nSenders    [getOptionValue "--senders"             10]
set nReceivers  [getOptionValue "--receivers"            1]
set endTime     [getOptionValue "--duration"           150]
set traceTime   [getOptionValue "--traceDuration"        1]
set bgTraffic   [isOptionSet    "--bgTraffic"]

# Trace Files Names
set traceFile      [getOptionValue "--traceFileName" trace.tr]
set queueFile      [getOptionValue "--queueFileName" queue.%.tr]
set throughputFile [getOptionValue "--throughputFileName" queue.%.throughput.tr]
set tfgTraceFile   [getOptionValue "--tfgTraceFileName" ""]

# Diretory in which traces will be written
set param(dir) [getOptionValue "--outDir" "."]
# Makes sure output directory exists
file mkdir $param(dir)

# Protocol to use
set protocol [getOptionValue "--protocol" "TCP"]
set protocol [string toupper $protocol]

# This section can be used for defining protocol parameters

if {$protocol eq "DCTCP"} {
    Agent/TCP set ecn_ 1
    Agent/TCP set old_ecn_ 1
    Agent/TCP set dctcp_g_ 0.3;
    Agent/TCP set minrto_ 0.2 ; # minRTO = 200ms
    Agent/TCP set dctcp_ true
    Agent/TCP set tcpTick_ 0.01
    Agent/TCP set windowOption_ 0
    Agent/TCP set slow_start_restart_ false

    Agent/TCP/FullTcp set segsperack_ 1;
    Agent/TCP/FullTcp set spa_thresh_ 3000;
    Agent/TCP/FullTcp set interval_ 0.04 ; #delayed ACK interval = 40ms

}

# Window size should have no max bound
# puts "biggest int is [expr {[regsub F [format "0x%X" -1] 7]}]"
Agent/TCP set window_ [expr pow(2,28)-1]
Agent/TCP set ssthresh_ 10

set pckgSize [toBytes $pckgSize 1024]
Agent/TCP  set packetSize_ $pckgSize
Agent/DCCP set packetSize_ $pckgSize
Agent/TCP/FullTcp set segsize_ $pckgSize

set K 10
Queue/RED set bytes_ false
Queue/RED set queue_in_bytes_ true
Queue/RED set mean_pktsize_ $pckgSize
Queue/RED set setbit_ true
Queue/RED set gentle_ false
Queue/RED set q_weight_ 1.0
Queue/RED set mark_p_ 1.0
Queue/RED set thresh_ [expr $K]
Queue/RED set maxthresh_ [expr $K]

DelayLink set avoidReordering_ true

Agent/DCCP/TFRC set ccid_ 3
Agent/DCCP/TFRC set use_ecn_local_ 0
Agent/DCCP/TFRC set use_ecn_remote_ 0

#
# Initialize Global Variables
#
set ns		 [new Simulator]
set tracefd      [open $param(dir)/$traceFile w]
$ns trace-all $tracefd

# ns scheduler only supports time in seconds
set endTime [toSeconds $endTime]
set traceTime [toSeconds $traceTime]

#
# Node declarations
#

set e [$ns node]

# ns queues only support size in number of packages
set bufferSize [toBytes $bufferSize 1024]
set bufferSize [expr int($bufferSize/$pckgSize)]

set interval [expr double($traceTime)/10]

for {set i 0} {$i < $nSenders}   {incr i} {
    set node_s($i) [$ns node]
    $ns duplex-link $node_s($i) $e $senderBw 0.025m DropTail
    set id "[$e id]-[$node_s($i) id]"
    set throughputfd($id) [open $param(dir)/[string map "% $id" $throughputFile] w]
    set queuefd($id)      [open $param(dir)/[string map "% $id" $queueFile] w]
    set qmon($id)         [$ns monitor-queue $e $node_s($i) [open /dev/null w] $interval]
    puts $queuefd($id) "# Queue limit is [Queue set limit_] packages or [expr [Queue set limit_]*$pckgSize] bytes"

}

set switchAlg [expr { $protocol eq "DCTCP" } ? {"RED"} : {"DropTail"}]
for {set i 0} {$i < $nReceivers} {incr i} {
    set node_r($i) [$ns node]
    $ns duplex-link $node_r($i) $e $receiverBw 0.025m $switchAlg
    $ns queue-limit $node_r($i) $e $bufferSize
    $ns queue-limit $e $node_r($i) $bufferSize
    set id "[$e id]-[$node_r($i) id]"
    set throughputfd($id) [open $param(dir)/[string map "% $id" $throughputFile] w]
    set queuefd($id)      [open $param(dir)/[string map "% $id" $queueFile] w]
    set qmon($id)         [$ns monitor-queue $e $node_r($i) [open /dev/null w] $interval]
    #[$ns link $e $node_r($i)] queue-sample-timeout
    puts $queuefd($id) "# Queue limit is $bufferSize packages or [expr $bufferSize*$pckgSize] bytes"
}

# Prints node ids on trace file
puts $tracefd "NODES IDS"
puts $tracefd "e -> [$e id]"
for {set i 0} {$i < $nSenders}   {incr i} {
    puts $tracefd "node_s_$i -> [$node_s($i) id]"
}
for {set i 0} {$i < $nReceivers} {incr i} {
    puts $tracefd "node_r_$i -> [$node_r($i) id]"
}
puts $tracefd "\n"

################################################
# Background Traffic

if {$bgTraffic} {

  source [file dirname $argv0]/tfg.tcl

  #set taxa [expr [toBitsPerSecond $senderBw] * 0.2]
  set taxa 0.4

  #######################################################
  # Generating background traffic
  #######################################################
  set rho_ftp [expr  $taxa * 0.80]
  #set rho_web [expr $taxa * 0.56]
  set rho_udp [expr  [toBitsPerSecond $senderBw] * 0.20]

  #######################################################
  ### FTP background traffic (24%)
  #######################################################
  set s_ftp_rv [$ns node]
  set d_ftp_rv [$ns node]

  # links
  $ns duplex-link $s_ftp_rv $e $senderBw   10ms DropTail
  $ns duplex-link $e $d_ftp_rv $receiverBw 10ms DropTail

  set senderBw   [toBitsPerSecond $senderBw]
  set receiverBw [toBitsPerSecond $receiverBw]
  set bw [expr { $senderBw < $receiverBw } ? $senderBw : $receiverBw]
  # declaring traffic generator
  set tfg_ftp_rv [new TrafficGen $ns $s_ftp_rv $d_ftp_rv $bw $rho_ftp $tfgTraceFile]

  $tfg_ftp_rv set dist_       	expo
  $tfg_ftp_rv set avg_len_b_ 	524288

  $tfg_ftp_rv set tcp_flavor_ 	TCP/Sack1 
  $tfg_ftp_rv set tcppsize_   	1500
  $tfg_ftp_rv set windowsize_   	1000
  $tfg_ftp_rv set ecnsupport_	0
  $tfg_ftp_rv set limittransmit_ 	0
  $tfg_ftp_rv set overhead_h 0.000008
  # inicia geracao de trafego
  $tfg_ftp_rv start

  #######################################################
  ### UDP background traffic (20%)
  #######################################################
  set u(1) [$ns node]

  set udp_rv [new Agent/UDP]

  $ns attach-agent $u(1) $udp_rv

  set cbr_rv [new Application/Traffic/CBR]


  $cbr_rv attach-agent $udp_rv
  $cbr_rv set packetSize_ 1500
  $cbr_rv set rate_ $rho_udp

  set n(1) [$ns node]
  set null_rv [new Agent/Null]

  $ns attach-agent $n(1) $null_rv
  $ns connect $udp_rv $null_rv

  $ns duplex-link $u(1) $e $senderBw   11ms DropTail
  $ns duplex-link $n(1) $e $receiverBw 11ms DropTail

  $ns at 0.01 "$cbr_rv start"
  $ns at $endTime "$cbr_rv stop"

}

################################################

#
# Creating connections for the experiment
#

for {set i 0} {$i < $nSenders} {incr i} {
    for {set j 0} {$j < $connections} {incr j} {
      set k [expr $i * $connections + $j]
      set sourceAgent($k) [sourceAgentByProtocol $protocol]
      $ns attach-agent $node_s($i) $sourceAgent($k)
    }
}

for {set i 0} {$i < $nReceivers} {incr i} {
    for {set j 0} {$j < $connections} {incr j} {
      set k [expr $i * $connections + $j]
      set sinkAgent($k) [sinkAgentByProtocol $protocol]
      $ns attach-agent $node_r($i) $sinkAgent($k)
    }
}

# Connect all senders to one receiver
for {set i 0} {$i < $nSenders} {incr i} {
    for {set j 0} {$j < $connections} {incr j} {
        set k [expr $i * $connections + $j]
        set l [expr $i % $nReceivers  + $j]
        $ns connect $sourceAgent($k) $sinkAgent($l)
    }
}

Tracefile set debug_ 0

for {set i 0} {$i < $nSenders} {incr i} {
    for {set j 0} {$j < $connections} {incr j} {
        set k [expr $i * $connections + $j]
        set cbr($k) [new Application/Traffic/CBR] 
        $cbr($k) set rate_ 1.6Gb
        $cbr($k) attach-agent $sourceAgent($k)
    }
}

#
# Connections Start and Stop
#

for {set i 0} {$i < [expr $nSenders * $connections]} {incr i} {
    $ns at 0 "$cbr($i) start"
    $ns at $endTime "$cbr($i) stop"
}

for {set i 0} {$i < $nSenders} {incr i} {
    $ns at $endTime "$node_s($i) reset"
}
for {set i 0} {$i < $nReceivers} {incr i} {
    $ns at $endTime "$node_r($i) reset"
}

array set relayedAmount {}
set startMeasurementTime [expr $endTime - $traceTime]

$ns at $startMeasurementTime "traceQueues"
$ns at $startMeasurementTime "traceThroughputStart"
$ns at $endTime "traceThroughputFinish"

$ns at $endTime "$e reset"
$ns at $endTime "stop" 

proc traceQueues {} {
  global ns qmon queuefd interval startMeasurementTime sourceAgent
  set now [$ns now]
  foreach {id mon} [array get qmon] {
    $mon instvar size_
    $mon instvar pkts_
    puts $queuefd($id) "[expr $now - $startMeasurementTime] $size_ $pkts_"
  }
  $ns at [expr $now+$interval] "traceQueues"
}

proc traceThroughputStart {} {
    global qmon relayedAmount 
    foreach {id mon} [array get qmon] {
       $mon instvar bdepartures_
       set relayedAmount($id) $bdepartures_
    }

}

proc traceThroughputFinish {} {
    global qmon throughputfd relayedAmount traceTime
    foreach {id mon} [array get qmon] {
       $mon instvar bdepartures_
       set relayedAmount($id) [expr $bdepartures_ - $relayedAmount($id)]
       puts $throughputfd($id) [expr (double($relayedAmount($id))*8)/(double($traceTime)*1000000)]
    }
}

proc stop {} {
    global ns tracefd throughputfd queuefd
    $ns flush-trace
    close $tracefd
    foreach {id file} [array get queuefd] {
        close $file
    }
    foreach {id file} [array get throughputfd] {
        close $file
    }
    exit 0
}

$ns run
