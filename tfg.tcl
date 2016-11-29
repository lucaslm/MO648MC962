#
# Copyright (c) GTA/UFRJ 2002. All rights reserved.
#
# License is granted to copy, to use, and to make and to use derivative
# works for research and evaluation purposes, provided that GTA/UFRJ is
# acknowledged in all documentation pertaining to any such copy or
# derivative work. GTA/UFRJ grants no other licenses expressed or
# implied.
#
# GTA/UFRJ MAKES NO REPRESENTATIONS CONCERNING EITHER THE
# MERCHANTABILITY OF THIS SOFTWARE OR THE SUITABILITY OF THIS SOFTWARE
# FOR ANY PARTICULAR PURPOSE.  The software is provided "as is" without
# express or implied warranty of any kind.
#
# These notices must be retained in any copies of any part of this
# software. 
#
# This test suite reproduces the tests from the following note:
# Cardoso, K.V., Ns Simulator Tests for Evaluating (Active) Queue 
# Management, March 2001.
# ** Important note: Drop Tail is NOT an ACTIVE queue management, 
# instead of it is a kind of "passive" queue management. However, 
# it is important to evaluate Drop Tail because it is still widelly used.
# URL http://www.gta.ufrj.br/~kleber/<missing page>
#
# Contributed by Rezende, J.F., http://www.gta.ufrj.br/~rezende
# Modified by Cardoso, K.V., http://www.gta.ufrj.br/~kleber
#
# The procedures in this file deal specially with traffic generation.

Class TrafficGen

TrafficGen instproc init {ns inode enode bbw rho {tracefilename tfg.tr} } {

    $self instvar ns_ inode_ enode_ bbw_ rng_
    $self instvar MAXINT
    $self instvar tracefilename_ rho_

    set ns_ $ns
    set inode_ $inode
    set enode_ $enode
    set bbw_ $bbw
    set rho_ $rho
    set tracefilename_ $tracefilename

    set MAXINT 2147483648.0
    set rng_ [new RNG]
    $rng_ seed 0
}

TrafficGen instproc start {} {
    global param
    $self instvar transfer_count_ ;# transfer count
    $self instvar client_count_   ;# number of created clients
    $self instvar client_onduty_  ;# number of not yet finished clients
    $self instvar ns_ rng_ rho_ ecnsupport_ windowsize_ tcppsize_ limittransmit_
    $self instvar tracefilefd_ tracefilename_ node_ #post_ 
    $self instvar dist_
    $self instvar windowOption_h overhead_h
#max_ssthresh_h 
    #low_window_h high_window_h high_p_h high_decrease_h max_ssthresh_h    
    
    # if no trace file was set, redirect output to null device
    if {$tracefilename_ eq ""} {
      set tracefilefd_ [open /dev/null w]
    } else {
      set tracefilefd_ [open $param(dir)/$tracefilename_ w] ;# file used to write events
    }

    # set TCP agents parameters
    Agent/TCP set window_ $windowsize_;# disable flow control
    Agent/TCP set packetSize_ $tcppsize_;
    Agent/TCP set ecn_ $ecnsupport_;
    Agent/TCP set singledup_ $limittransmit_;
    Agent/TCP set useHeaders_ false;
    Agent/TCP set tcpTick_ 0.1 ;# timer tick = 100ms
    Agent/TCP set syn_ false;
    #Agent/TCP set windowOption_ $windowOption_h
    #Agent/TCP set low_window_ $low_window_h
    #Agent/TCP set high_window_ $high_window_h
    #Agent/TCP set high_p_ $high_p_h 
    #Agent/TCP set max_ssthresh_ $max_ssthresh_h
    #Agent/TCP set high_decrease_ $high_decrease_h
    Agent/TCP set overhead_ $overhead_h


    set transfer_count_ 0      ;# transfer count
    set client_count_ 0        ;# number of created clients
    
    puts stderr "rho  => $rho_"
    puts stderr "distribution => $dist_"

    # launch traffic generation
    $self schedule_initial_traffic

}

TrafficGen instproc schedule_initial_traffic {} {
    $self instvar ns_ rng_
    $self instvar idle_clients_       ;# array of idle clients
    $self instvar client_onduty_
    $self instvar finished_           ;# number of finished clients

    set idle_clients_ ""
    set client_onduty_ 0;   # number of active clients
    set finished_ 0;        # number of finished transfers
		
    #flows start randomly between 0 and 1 secs
    set startt [$rng_ uniform 0 1]
    $ns_ at $startt "$self schedule_continuing_traffic 0"
}

TrafficGen instproc schedule_continuing_traffic {delay} {
    global param 
    $self instvar MAXINT
    $self instvar ns_ rng_ bbw_ rho_
    $self instvar dist_ body_dist_
    $self instvar avg_len_b_
    $self instvar std_dev_ avg_len_t_
    $self instvar avg_len_ mshape_

    switch $dist_ {
	mixed {
	    set part_ [ns-random]
	    set chosen_part_ [expr round ([expr $part_/$MAXINT*100])]
	    if {$chosen_part_ <= $body_dist_} {
		set model [new RandomVariable/LogNormal]
		$model use-rng $rng_
		$model set avg_ $avg_len_b_
		$model set std_ $std_dev_
		set L [expr round ([$model value])]
		while {$L == 0} {
		    set L [expr round ([$model value])]
		}	
		delete $model
	    } else {
		set model [new RandomVariable/Pareto]
		$model use-rng $rng_
            	$model set avg_ $avg_len_t_
		$model set shape_ $mshape_
		set L [expr round ([$model value])]
		while {$L == 0} {
		    set L [expr round ([$model value])]
		}	
		delete $model
	    }
	}
	fixed {
	    set L $avg_len_
	}
	expo {
	    set model [new RandomVariable/Exponential]
	    $model use-rng $rng_
	    $model set avg_ $avg_len_b_
	    set L [expr round ([$model value])]
	    while {$L == 0} {
		set L [expr round ([$model value])]
	    }
	    delete $model
	}
	lognormal {
	    set model [new RandomVariable/LogNormal]
	    $model use-rng $rng_
	    $model set avg_ $avg_len_b_
	    $model set std_ $std_dev_
	    set L [expr round ([$model value])]
	    while {$L == 0} {
		set L [expr round ([$model value])]
	    }	
	    delete $model
	}
	pareto {
	    set model [new RandomVariable/Pareto]
	    $model use-rng $rng_
	    $model set avg_ $avg_len_b_
	    $model set shape_ $mshape_
	    set L [expr round ([$model value])]
	    while {$L == 0} {
		set L [expr round ([$model value])]
	    }	
	    delete $model
	}
    }
    $self start_a_client $delay $L
    #6-> 1035
    set inter_delay [expr (1.0/($rho_*$bbw_/(1.0*$L)/8.0))*9]
   #set inter_delay [expr (1.0/($rho_*$bbw_/(1.0*$L)/8.0))]
    set next [expr ([$ns_ now]+$inter_delay)]
    $ns_ at $next "$self schedule_continuing_traffic $inter_delay"
}

TrafficGen instproc start_a_client {inter_delay L} {
    global param 
    $self instvar idle_clients_ sources_ app_ tracefilefd_
    $self instvar ns_ rng_ 
    $self instvar transfer_count_ client_onduty_

    set now [$ns_ now]
	
    # Do we still have available clients?
    set x [llength $idle_clients_]	
    if {$x < 5} {
	set i [$self create_a_client]
    } else {
	set i [lindex $idle_clients_ 0]
	set idle_clients_ [lrange $idle_clients_ 1 end]
    }
    # Reset the connection.
    $sources_($i) reset
    [$sources_($i) set dst_agent_] reset
    
    incr transfer_count_
    $sources_($i) set transfer_count_ $transfer_count_
    $sources_($i) set fid_ 1
    $sources_($i) set startt_ $now
    $sources_($i) set inter_delay_ $inter_delay
    
    # start traffic for that client.
    #$sources_($i) set transfer_size_ $L
    #num 6
    $sources_($i) set transfer_size_ [expr $L*9]
    set size [expr $L*9]
    set len $size
    #set len $L
    $app_($i) send $len
    
    set now [$ns_ now]
    
    # Write a trace
    ###############
    puts $tracefilefd_ "t: [format %.8f $now ] sc: $i tid: $transfer_count_"
    
    # increment number of unfinished clients
    incr client_onduty_
}

TrafficGen instproc finish_a_client {clid} {
    global param
    $self instvar ns_ bbw_
    $self instvar client_onduty_ 
    $self instvar idle_clients_ sources_
    $self instvar tracefilefd_ finished_

    # decrement number of unfinished clients
    incr client_onduty_ -1
    
    set now [$ns_ now]
    
    # transfer duration
    #set delta [expr ($now - [$sources_($clid) set startt_])*9]
    set delta [expr ($now - [$sources_($clid) set startt_])]
    
    puts $tracefilefd_ "t: [format %.8f $now] fc: $clid tid: [$sources_($clid) set transfer_count_] len: [$sources_($clid) set transfer_size_] dur: [format %.8f $delta] act: $client_onduty_"

    # add specific information bandwidth
    set bw [expr [$sources_($clid) set transfer_size_]*8.0 /$delta]
    if { $bw >= $bbw_ } {
		puts $tracefilefd_  "ERROR: Wrong throughtput $bw"
    }
    # normalized (in percentage of the bottleneck bw) bandwidth
    set bwn [expr $bw*100.0/$bbw_]

    set throughput [expr [$sources_($clid) set ndatabytes_]*8/$delta]
    set throughputn [expr $throughput*100.0/$bbw_]

    set goodput_t [expr ([$sources_($clid) set ndatabytes_] - [$sources_($clid) set nrexmitbytes_] )*8.0 /$delta]
    set goodput_tn [expr $goodput_t*100.0/$bbw_]

    set goodput_p [expr ([$sources_($clid) set ndatabytes_] - [$sources_($clid) set nrexmitbytes_] )/[$sources_($clid) set ndatabytes_]]
    set goodput_pn [expr $goodput_p*100.0]

    set ecn [$sources_($clid) set ecn_]

 if {$ecn} {
        puts $tracefilefd_ "t: [format %.8f $now] bw: [format %.8f $bwn] throughput: [format %.8f $throughputn] goodput_t: [format %.8f $goodput_tn] goodput_p: [format %.8f $goodput_pn] rtt: [expr ([$sources_($clid) set srtt_] >> 3) * 0.1] to: [$sources_($clid) set nrexmit_] cwnd: [$sources_($clid) set cwnd_] delta: [format %.8f $delta] ecnresponses: [$sources_($clid) set necnresponses_] ncwndcuts: [$sources_($clid) set ncwndcuts_]"
    } else {
    #   puts "t: [format %.8f $now]\tcwnd: [$sources_($clid) set cwnd_]"
    #    puts $tracefilefd_ "t: [format %.8f $now]\t [$sources_($clid) set cwnd_]"
        puts $tracefilefd_ "t: [format %.8f $now] bw: [format %.8f $bwn] throughput: [format %.8f $throughputn] goodput_t: [format %.8f $goodput_tn] goodput_p: [format %.8f $goodput_pn] rtt: [expr ([$sources_($clid) set srtt_] >> 3) * 0.1] to: [$sources_($clid) set nrexmit_] cwnd: [$sources_($clid) set cwnd_] delta: [format %.8f $delta]"

    }
#    set goodput [expr ([$sources_($clid) set ndatabytes_] - [$sources_($clid) set nrexmitbytes_] )*8.0 /$delta]
#    set goodputn [expr $goodput*100.0/$bbw_]

 #   set ecn [$sources_($clid) set ecn_]

#    if {$ecn} {
#    	puts $tracefilefd_ "t: [format %.8f $now] bw: [format %.8f $bwn] throughput: [format %.8f $throughputn] goodput: [format %.8f $goodputn] rtt: [expr ([$sources_($clid) set srtt_] >> 3) * 0.1] to: [$sources_($clid) set nrexmit_] cwnd: [$sources_($clid) set cwnd_] ecnresponses: [$sources_($clid) set necnresponses_] ncwndcuts: [$sources_($clid) set ncwndcuts_]"
#    } else {
# 	puts $tracefilefd_ "t: [format %.8f $now] bw: [format %.8f $bwn] throughput: [format %.8f $throughputn] goodput: [format %.8f $goodputn] rtt: [expr ([$sources_($clid) set srtt_] >> 3) * 0.1] to: [$sources_($clid) set nrexmit_] cwnd: [$sources_($clid) set cwnd_]"
#    }
    
    # insert this client in the idle_clients list
    lappend idle_clients_ $clid
    incr finished_

    set now [$ns_ now]
}

#
# create a tcp source/dst connection with an attached ftp application
#
TrafficGen instproc create_a_client {} {
    global param
    $self instvar sources_ app_
    $self instvar ns_ client_count_
    $self instvar tracefilefd_ inode_ enode_
    $self instvar tcp_flavor_
    
    set now [$ns_ now]

    set client_id [incr client_count_]

    if {$tcp_flavor_=="TCP/Sack1"} {
	set clients [$ns_ create-connection-list $tcp_flavor_ $inode_ TCPSink/Sack1 $enode_ 0]
    } else {
    	set clients [$ns_ create-connection-list $tcp_flavor_ $inode_ TCPSink $enode_ 0]
    }
    set sources_($client_id) [lindex $clients 0]
    set dst_agent [lindex $clients 1]
    
    $sources_($client_id) set dst_agent_ $dst_agent
    
    # Set up a callback when this client ends.
    $sources_($client_id) proc done {} "$self finish_a_client $client_id"
    
    set app_($client_id) [new Application/FTP]
    $app_($client_id) attach-agent $sources_($client_id)
    
    return $client_id
}
