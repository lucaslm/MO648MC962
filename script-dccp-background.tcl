# Setup da banda do enlace, numero de conexoes e tempo de simulacao

set banda 1000Mb
set conexoes 16

set banda1 1000000000

set endTime 600

source tfg.tcl

# diretorio onde sera gerado o trace.tr
set param(dir)        "."

#
# Initialize Global Variables
#
set ns		[new Simulator]
set tracefd     [open simple.tr w]
$ns trace-all $tracefd

set tfg_trace_file [open tfg.tr w]

# Geracao de numeros aleatorios para atraso de propagacao nas conexoes Dccp

set rng1 [new RNG]
$rng1 seed 0

set delay_prop [new RandomVariable/Uniform]
$delay_prop set min_ 0.0
$delay_prop set max_ 0.9
$delay_prop use-rng $rng1

for {set i 0} {$i < 2} {incr i} {
	set delay($i) [expr [$delay_prop value]]
}

# Declarar nos

set r(0) [$ns node]
set r(1) [$ns node]
set buffer_size 2500

for {set i 0} {$i < 2} {incr i} {
	set dccp_s($i) [$ns node]
	set dccp_r($i) [$ns node]
	
	$ns duplex-link $dccp_s($i) $r(0) $banda [expr $delay($i)]ms DropTail
	$ns duplex-link $r(1) $dccp_r($i) $banda [expr $delay($i)]ms DropTail
}
	$ns duplex-link $r(0) $r(1) $banda 100ms DropTail
	$ns queue-limit $r(0) $r(1) $buffer_size
	$ns queue-limit $r(1) $r(0) $buffer_size


# Agent/DCCP/TFRC - Esta secao nao eh necessaria, pode ser utilizada para definicoes indicadas para o DCTCP ou DCUDP

#Agent/DCCP/TFRC set ccid_ 3
#Agent/DCCP/TFRC set use_ecn_local_ 0
#Agent/DCCP/TFRC set use_ecn_remote_ 0

################################################
#Trafego Background

#set taxa [expr $banda1 * 0.2]
set taxa 0.4

#######################################################
# Gerando o trafego background
#######################################################
set rho_ftp [expr  $taxa * 0.80]
#set rho_web [expr $taxa * 0.56]
set rho_udp [expr  $banda1 * 0.20]

#######################################################
### Trafego background FTP (24%)
#######################################################
set s_ftp_rv [$ns node]
set d_ftp_rv [$ns node]

# enlaces
$ns duplex-link $s_ftp_rv $r(1) $banda 10ms DropTail
$ns duplex-link $r(0) $d_ftp_rv $banda 10ms DropTail

# criacao do gerador de trafego
set tfg_ftp_rv [new TrafficGen $ns $s_ftp_rv $d_ftp_rv $banda1 $rho_ftp $tfg_trace_file]

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
### Trafego background UDP (20%)
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

$ns duplex-link $u(1) $r(1) $banda 11ms DropTail
$ns duplex-link $n(1) $r(0) $banda 11ms DropTail

$ns at 0.01 "$cbr_rv start"
$ns at $endTime "$cbr_rv stop"

################################################

# Gerador de numeros aleatorios para inicio das transmissoes nos emissores
set rng0 [new RNG]
$rng0 seed 0

set random_start [new RandomVariable/Uniform]
$random_start set min_ 0
$random_start set max_ 9
$random_start use-rng $rng0

for {set i 0} {$i < $conexoes} {incr i} {
	set starttime($i) [expr [$random_start value]]
}


# Criacao das conexoes para o experimento - Substituir as conexoes aqui pelas respectivas conexoes DCTCP/DCUDP. IMPORTANTE: mantenham o nome do agente dccp_s, dccp_r e dccp, pois isto evitara mudancas no restante do script. Exemplo: basta mudar [new Agent/DCCP/TFRC] para algo como [new Agent/DCTCP] - considerando que o agente do DCTCP seja este.

for {set i 0} {$i < 2} {incr i} {
	set dccp($i) [new Agent/DCCP/TFRC]

	set sink($i) [new Agent/DCCP/TFRC]

	$ns attach-agent $dccp_s($i) $dccp($i)

	$ns attach-agent $dccp_r($i) $sink($i)

	$ns connect $dccp($i) $sink($i)

	$ns at 0.1 "$sink($i) listen"
}

# Mantenham o restante do script

Tracefile set debug_ 0

for {set i 0} {$i < $conexoes} {incr i} {

	set cbr($i) [new Application/Traffic/CBR] 
	$cbr($i) set rate_ 10000Mb
	$cbr($i) set packetSize_ 100000
	$cbr($i) attach-agent $dccp(0)
}


# Start e Stop das conexoes 

for {set i 0} {$i < $conexoes} {incr i} {
	$ns at $starttime($i) "$cbr($i) start"
	$ns at $endTime "$cbr($i) stop"
}


for {set i 0} {$i < 2} {incr i} {
	$ns at $endTime  "$dccp_s($i) reset"
	$ns at $endTime "$dccp_r($i) reset"
}

$ns at $endTime "$r(0) reset"
$ns at $endTime "$r(1) reset"
$ns at $endTime "stop" 

proc stop {} {
    global ns tracefd
    $ns flush-trace
    close $tracefd
    exit 0

}

$ns run
