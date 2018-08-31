#!/usr/bin/perl

use DBI;
 
while(1==1) {
    $flag = 0;
    $kount = 0;
    while($flag == 0) {
        $kount = $kount + 1;
	system("/opt/torque/x86_64/bin/qstat -ft1 > /tmp/briaree_data.txt");
	$fsize = (stat("/tmp/briaree_data.txt"))[7];
	if ($fsize == 0) {
	    sleep(10);
	}
	else {
	    $flag = 1;
	}
        if ($kount > 3) {
	    $flag = 1;
	}
    }
    $ntache = 0;
    $search = 0;
    open(qs_handle,"/tmp/briaree_data.txt");
    while(<qs_handle>) {
	chomp;
	if ($search == 1) {
	    @data = split(/\=/,$_);
	    $data[0] = trimwhitespace($data[0]);
	    if ($data[0] eq "Job_Owner") {
		@userid = split(/\@/,trimwhitespace($data[1]));
		$user[$ntache] = $userid[0];
		$mem_demanded[$ntache] = 0.0;
		next;
	    }
	    elsif ($data[0] eq "Job_Name") {
                $jname = trimwhitespace($data[1]);
                if ($jname eq "boot_cpuset") {
                    $search = 0;
                    next;
                }
            }
	    elsif ($data[0] eq "exec_host") {
	        @node_list = split(/\+/,trimwhitespace($data[1]));
		@node_cpu = split(/\//,$node_list[0]);
		$dnodes[0] = $node_cpu[0];
		$k = 1;
		for($i=1; $i<$#node_list; $i++) {
		    @node_cpu = split(/\//,$node_list[$i]);
		    $found = 0;
		    for($j=0; $j<$k; $j++) {
		        if ($dnodes[$j] eq $node_cpu[0]) {
			    $found = 1;
			    last;
			}
		    }
		    if ($found == 0) {
		      $dnodes[$k] = $node_cpu[0];
		      $k++;
		    }
		}
		if ($k == 1) {
		  $ns = $dnodes[0];
		}
		else {
		    $ns = $dnodes[0] . ":";
		    for($i=1; $i<$k-1; $i++) {
		      $ns = $ns . $dnodes[$i] . ":";
		    }
		    $ns = $ns . $dnodes[$k-1];
		}  
		$nstring[$ntache] = $ns;
		next;
	    }
	    elsif ($data[0] eq "resources_used.mem") {
		$mem[$ntache] = trimwhitespace($data[1]);
		$mem[$ntache] =~ s/kb//;
		next;
	    }
	    elsif ($data[0] eq "resources_used.cput") {
		$rtime = trimwhitespace($data[1]);
		@btime = split(/\:/,$rtime);
		$seconds = 3600*$btime[0] + 60*$btime[1] + $btime[2];
		$cput[$ntache] = trimwhitespace($seconds);
		next;
	    }
	    elsif ($data[0] eq "resources_used.walltime") {
		$rtime = trimwhitespace($data[1]);
		@btime = split(/\:/,$rtime);
		$seconds = 3600*$btime[0] + 60*$btime[1] + $btime[2];
		$wtime[$ntache] = trimwhitespace($seconds);
		next;
	    }
            elsif ($data[0] eq "qtime") {
		$tqueue[$ntache] = parse_time(trimwhitespace($data[1]));
		next;
	    }
	    elsif ($data[0] eq "job_state") {
		$state[$ntache] = trimwhitespace($data[1]);
		next;
	    }
	    elsif ($data[0] eq "queue") {
		$queue = trimwhitespace($data[1]);
		if ($queue ne "normale" && $queue ne "hp" && $queue ne "speciale" && $queue ne "hpcourte" && $queue ne "courte" && $queue ne "test" && $queue ne "longue") {
		    $search = 0;
		}
		next;
	    }
           elsif ($data[0] eq "Resource_List.mem") {                
                $mem1 = trimwhitespace($data[1]);                    
                # Now we need to parse the memory unit here: kb, mb or gb
		#print "$user[$ntache] $jname $mem1\n";
                if ($mem1 =~ /(\d{1,})(\D\D)$/) {
                    $val = $1;
                    $units = $2;
                    if ($units eq "gb") {
                        $mem_demanded[$ntache] = 1024.0*$val;
                    }
                    elsif ($units eq "kb") {
                        $mem_demanded[$ntache] = $val/1024.0;
                    }
                    elsif ($units eq "mb") {
                        $mem_demanded[$ntache] = $val;
                    }
                    next;
                }
            }
	    elsif ($data[0] eq "Resource_List.nodes") {
		$ndata = trimwhitespace($data[1]);
		@node_data = split(/\:/,$ndata);
		if ($#data < 2) {
		    $ppn = 12;
		}
		else {
		    @ppn_data = split(/\:/,trimwhitespace($data[2]));
		    $ppn = $ppn_data[0];
		}
		$nnodes = trimwhitespace($node_data[0]);
		if ($nnodes =~ m/node/) {
		    $nnodes = 1;
		}
		$ncpus[$ntache] = $ppn*$nnodes; 
		if ($ncpus[$ntache] == 0) {
		    print "$ndata $ppn $nnodes\n";
		    die;
		}
		next;
	    }
	    elsif ($data[0] eq "Resource_List.walltime") {
		$rtime = trimwhitespace($data[1]);
                @btime = split(/\:/,$rtime);
                $seconds = 3600*$btime[0] + 60*$btime[1] + $btime[2];
                $wtime_demanded[$ntache] = trimwhitespace($seconds);
		$search = 0;
		$ntache += 1;
		next;
	    }
	}
	@data = split(/\:/,$_);
	if ($data[0] eq "Job Id") {
	    $jid[$ntache] = trimwhitespace($data[1]);
	    $search = 1;
	}
    }
    close(qs_handle);
    system("rm -f /tmp/briaree_data.txt");
    $now = time;
    $datasrc = 'DBI:mysql:database=CQtaches;host=udem-stat.calculquebec.ca;mysql_connect_timeout=120';
    $dbhandle = eval { DBI->connect("$datasrc","CQadmin","xxxx") };
    if ($@) {
      sleep(180);
      next;
    }
    $sthandle1 = $dbhandle->prepare("DELETE FROM Etat_actuel WHERE arch='x86-64/briaree';");
    $sthandle1->execute();
    $sthandle1->finish();
    $sthandle2 = $dbhandle->prepare("INSERT INTO Etat_actuel(Job_ID,Usager,NCPU,exec_host,T_Soumission,T_Demarrage,Etat,PCPU,Memoire,Memoire_demandee,temps_demande,ctime,arch) VALUES(?,?,?,?,?,FROM_UNIXTIME(?),'R',?,?,?,?,FROM_UNIXTIME(?),'x86-64/briaree');"); 
    $sthandle3 = $dbhandle->prepare("INSERT INTO Etat_actuel(Job_ID,Usager,NCPU,T_Soumission,Etat,Memoire_demandee,temps_demande,ctime,arch) VALUES(?,?,?,?,'Q',?,?,FROM_UNIXTIME(?),'x86-64/briaree');");     
    for($i=0; $i<$ntache; $i=1+$i) {
        $tsubmitted = $tqueue[$i];
	$wt_req = sprintf("%8.3f",$wtime_demanded[$i]/3600.0);
	if ($ncpus[$i] == 0) {
	    print "Error $jid[$i]  $ncpus[$i]\n";
	}
	else {
	    $mem_req = sprintf("%8.3f",$mem_demanded[$i]/$ncpus[$i]);
	}
	#print "$jid[$i] $user[$i] $mem_demanded[$i] $mem_req\n";
	if ($state[$i] eq "R") {
	    $stime = $now-$wtime[$i];
	    if ($wtime[$i] == 0) {
		$pcpu = 0.01;
	    }
	    else {
		$pcpu = $cput[$i]/($ncpus[$i]*$wtime[$i]);
	    }
	    $pcpu = sprintf("%.1f",100.0*$pcpu);
	    $mem[$i] = sprintf("%8.3f",$mem[$i]/(1024.0*$ncpus[$i]));
	    $sthandle2->execute($jid[$i],$user[$i],$ncpus[$i],$nstring[$i],$tsubmitted,$stime,$pcpu,$mem[$i],$mem_req,$wt_req,$now);
	    $sthandle2->finish;
	}
	else {
	    $sthandle3->execute($jid[$i],$user[$i],$ncpus[$i],$tsubmitted,$mem_req,$wt_req,$now);
	    $sthandle3->finish;
	}
    }
    $dbhandle->disconnect;
    sleep(180);
}

sub trimwhitespace($)
{
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

sub parse_time()
{
    my @parms = @_;
    @data = split(/\s+/,$parms[0]);
    $data[4] = trimwhitespace($data[4]);
    $data[1] = trimwhitespace($data[1]);
    $data[2] = trimwhitespace($data[2]);
    $data[3] = trimwhitespace($data[3]);
    if ($data[1] eq "Jan") {
	$mnumber = "01";
    }
    elsif ($data[1] eq "Feb") {
	$mnumber = "02";
    }
    elsif ($data[1] eq "Mar") {
	$mnumber = "03";
    }
    elsif ($data[1] eq "May") {
	$mnumber = "04";
    }
    elsif ($data[1] eq "Apr") {
	$mnumber = "05";
    }
    elsif ($data[1] eq "Jun") {
	$mnumber = "06";
    }
    elsif ($data[1] eq "Jul") {
	$mnumber = "07";
    }
    elsif ($data[1] eq "Aug") {
	$mnumber = "08";
    }
    elsif ($data[1] eq "Sep") {
	$mnumber = "09";
    }
    elsif ($data[1] eq "Oct") {
	$mnumber = "10";
    }
    elsif ($data[1] eq "Nov") {
	$mnumber = "11";
    }
    elsif ($data[1] eq "Dec") {
	$mnumber = "12";
    }
    if ($data[2] < 10) {
	$data[2] = "0".$data[2];
    }
    $tstring = $data[4] . "-" . $mnumber . "-" . $data[2] . " " . $data[3];
    return $tstring;
}
