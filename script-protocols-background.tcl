proc toBitsPerSecond {bw} {
    if {[string is double $bw]} {
        return $bw
    } else {
        regexp {([0-9]*\.?[0-9]+(e[0-9]+)?)([MmKk])?([Bb])?} $bw fullMatch n expo prefix unity
        if {[string equal $fullMatch $bw]} {
            if {[string equal [string toupper $prefix] "K"]} {
                set n [expr 1000*$n]
            } else {
                set n [expr 1000000*$n]
            }
            if {[string equal $unity "B"]} {
                set n [expr 8*$n]
            }
            return $n
        }
        return 0
    }
}

proc toSeconds {t} {
    if {[string is double $t]} {
        return $t
    } else {
        regexp {([0-9]*\.?[0-9]+(e[0-9]+)?)([mnp])?s?} $t fullMatch n expo prefix
        if {[string equal $fullMatch $t]} {
          switch $prefix {
            "m" { set n [expr double($n)/1000] }
            "n" { set n [expr double($n)/1000000000] }
            "p" { set n [expr double($n)/1000000000000] }
          }
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

proc agentByProtocol {protocol} {
    switch $protocol {
        "TCP" -
        "DCTCP" {
            return [new Agent/TCP]
        }
        "DCCP" {
            return [new Agent/DCCP/TFRC]
        }
    }
}

# Setup of several parameters, such as links bandwidths, numbers of nodes and
# simulation time.
# Bandwidth is expressed in bits per second, with optional sufixes.
# See http://nsnam.sourceforge.net/wiki/index.php/Manual:_OTcl_Linkage#Variable_Bindings
set bw           [getOptionValue "--bandwidth"           10000Mb]
set bottleneckBw [getOptionValue "--bottleneckBandWidth"  1000Mb]
set bufferSize   [getOptionValue "--bufferSize"              4MB]
set conexoes     [getOptionValue "--connections"               1]
set nSenders     [getOptionValue "--senders"                  10]
set nReceivers   [getOptionValue "--receivers"                 1]
set endTime      [getOptionValue "--duration"                  1]
set bgTraffic    [isOptionSet    "--bgTraffic"]

# Trace Files Names
set traceFile [getOptionValue "--traceFileName" trace.tr]
set tfgTraceFile [getOptionValue "--tfgTraceFileName" ""]

# Diretory in which trace.tr will be written
set param(dir) [getOptionValue "--outDir" "."]
# Makes sure output directory exists
file mkdir $param(dir)

# Protocol to use
set protocol [getOptionValue "--protocol" "TCP"]
set protocol [string toupper $protocol]
puts "Chosen Protocol is $protocol"

#
# Initialize Global Variables
#
set ns		[new Simulator]
set tracefd     [open $param(dir)/$traceFile w]
$ns trace-all $tracefd

# Random numbers generator for links propagation delay

set rng [new RNG]
$rng seed 0

set delay_prop [new RandomVariable/Uniform]
$delay_prop set min_ 0.0
$delay_prop set max_ 0.9
$delay_prop use-rng $rng

for {set i 0} {$i < $nSenders} {incr i} {
    set delay_s($i) [expr [$delay_prop value]]
}
for {set i 0} {$i < $nReceivers} {incr i} {
    set delay_r($i) [expr [$delay_prop value]]
}

# Node declarations

set r(0) [$ns node]
set r(1) [$ns node]

for {set i 0} {$i < $nSenders}   {incr i} {
    set node_s($i) [$ns node]
    $ns duplex-link $node_s($i) $r(0) $bw [expr $delay_s($i)]ms DropTail
}
for {set i 0} {$i < $nReceivers} {incr i} {
    set node_r($i) [$ns node]
    $ns duplex-link $r(1) $node_r($i) $bw [expr $delay_r($i)]ms DropTail
}

$ns duplex-link $r(0) $r(1) $bottleneckBw 100ms DropTail
$ns queue-limit $r(0) $r(1) $bufferSize
$ns queue-limit $r(1) $r(0) $bufferSize

# Prints node ids on trace file to help AWK scripts process it
puts $tracefd "NODES IDS"
puts $tracefd "r_0 -> [$r(0) id]"
puts $tracefd "r_1 -> [$r(1) id]"
for {set i 0} {$i < $nSenders}   {incr i} {
    puts $tracefd "node_s_$i -> [$node_s($i) id]"
}
for {set i 0} {$i < $nReceivers} {incr i} {
    puts $tracefd "node_r_$i -> [$node_r($i) id]"
}
puts $tracefd "\n"


# This section can be used for defining protocol parameters

if {$protocol eq "DCTCP"} {
  Agent/TCP set dctcp_ true
}

#Agent/DCCP/TFRC set ccid_ 3
#Agent/DCCP/TFRC set use_ecn_local_ 0
#Agent/DCCP/TFRC set use_ecn_remote_ 0

################################################
# Background Traffic

if {$bgTraffic} {

  source [file dirname $argv0]/tfg.tcl

  #set taxa [expr [toBitsPerSecond $bw] * 0.2]
  set taxa 0.4

  #######################################################
  # Generating background traffic
  #######################################################
  set rho_ftp [expr  $taxa * 0.80]
  #set rho_web [expr $taxa * 0.56]
  set rho_udp [expr  [toBitsPerSecond $bw] * 0.20]

  #######################################################
  ### FTP background traffic (24%)
  #######################################################
  set s_ftp_rv [$ns node]
  set d_ftp_rv [$ns node]

  # links
  $ns duplex-link $s_ftp_rv $r(1) $bw 10ms DropTail
  $ns duplex-link $r(0) $d_ftp_rv $bw 10ms DropTail

  # declaring traffic generator
  set tfg_ftp_rv [new TrafficGen $ns $s_ftp_rv $d_ftp_rv [toBitsPerSecond $bw] $rho_ftp $tfgTraceFile]

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

  $ns duplex-link $u(1) $r(1) $bw 11ms DropTail
  $ns duplex-link $n(1) $r(0) $bw 11ms DropTail

  $ns at 0.01 "$cbr_rv start"
  $ns at $endTime "$cbr_rv stop"

}

################################################

# Creating connections for the experiment

for {set i 0} {$i < $nSenders} {incr i} {
    set sourceAgent($i) [agentByProtocol $protocol]
    $ns attach-agent $node_s($i) $sourceAgent($i)
}

for {set i 0} {$i < $nReceivers} {incr i} {
    set sinkAgent($i) [agentByProtocol $protocol]
    $ns attach-agent $node_r($i) $sinkAgent($i)
    $ns at 0.1 "$sinkAgent($i) listen"
}

# Connect all senders to one receiver
for {set i 0} {$i < $nSenders} {incr i} {
    $ns connect $sourceAgent($i) $sinkAgent([expr $i % $nReceivers])
}

Tracefile set debug_ 0

for {set i 0} {$i < $nSenders} {incr i} {
    for {set j 0} {$j < $conexoes} {incr j} {
        set k [expr $i * $conexoes + $j]
        set cbr($k) [new Application/Traffic/CBR] 
        $cbr($k) set rate_ 1600Mb
        $cbr($k) attach-agent $sourceAgent($i)
    }
}

# Connections Start and Stop

for {set i 0} {$i < [expr $nSenders * $conexoes]} {incr i} {
    $ns at 0 "$cbr($i) start"
    $ns at $endTime "$cbr($i) stop"
}

for {set i 0} {$i < $nSenders} {incr i} {
    $ns at $endTime "$node_s($i) reset"
}
for {set i 0} {$i < $nReceivers} {incr i} {
    $ns at $endTime "$node_r($i) reset"
}

$ns at $endTime "$r(0) reset"
$ns at $endTime "$r(1) reset"
$ns at $endTime "stop" 

proc stop {} {
    global ns tracefd
    global endTime
    puts $tracefd "x [toSeconds $endTime] End of simulation"
    $ns flush-trace
    close $tracefd
    exit 0
}

$ns run
