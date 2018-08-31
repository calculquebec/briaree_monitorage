#!/usr/bin/perl -w

use strict;
use DBI;
use Scalar::Util qw(looks_like_number);

my (@fields,@resources,@temp,@rname,$i,$today,$jid,$usager,$ncpu,$ts,$td,$tc,$pcpu,$mem,$runtime,$nextname,$eh);
my ($sec,$min,$hour,$year,$yday,$wday,$isdist,$mon,$mday,$t1,$raw_cpu,$raw_wall,$walltime,$cputime,@t1,@ehost);
my (@tbreak,$wtime);
my $datasrc = 'mysql:database=CQtaches:udem-stat.calculquebec.ca';
my $dbhandle = DBI->connect("dbi:$datasrc","CQadmin","xxxx") or die DBI->errstr;
#my $p_command = $dbhandle->prepare('DELETE FROM Tache WHERE Job_ID LIKE \'%.briaree\';');
#$p_command->execute();
#$p_command->finish();
my $sthandle = $dbhandle->prepare('INSERT INTO Tache VALUES(?,?,?,FROM_UNIXTIME(?),FROM_UNIXTIME(?),FROM_UNIXTIME(?),?,?,?,?);') or die "Couldn't prepare statement\n";

# Subtract one day from the current date: 86400 seconds = 1 day
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdist) = localtime(time-86400);
$today = sprintf "%4d%02d%02d",$year+1900,$mon+1,$mday;

chdir("/var/spool/pbs/server_priv/accounting") || die "Cannot cd to PBS directory!\n";
while (defined($nextname = <*>)) {
    if ($nextname ne $today) {
    #if ($nextname !~ /^2013/) {
    	next;
    }
    open(PBShandle,$nextname) or die "Unable to open PBS accounting file!\n";
    while (<PBShandle>) {
	chomp;
	@fields = split(/;/,$_);
        if ($#fields < 2) {
	    next;
	}
	if ($fields[1] eq "E") {
	    @temp = split(/\./,$fields[2]);
	    $jid = $temp[0] . ".briaree";
	    @resources = split(/\s+/,$fields[3]);
	    for($i=0; $i<=$#resources; ++$i) {
		@temp = split(/=/,$resources[$i]);
		if ($temp[0] eq "user") {
                    # username
		    $usager = $temp[1];
		}
		elsif ($temp[0] eq "ctime") {
                    # submission time
		    $ts = 1*$temp[1];
		}
		elsif ($temp[0] eq "exec_host") {
		    @ehost = split(/\//,$temp[1]);
		    $eh = $ehost[0];
		}
		elsif ($temp[0] eq "start") {
                    # start time
		    $td = 1*$temp[1];
		}
		elsif ($temp[0] eq "end") {
                    # completion time
		    $tc = 1*$temp[1];
		}
		else {
		    @rname = split(/\./,$temp[0]);
		    if ($rname[0] eq "resources_used") {
			if ($rname[1] eq "mem") {
			    $mem = $temp[1];
			    $mem =~ s/kb//;
			}
			elsif ($rname[1] eq "cput") {
			    $cputime = $temp[1];
			}
                        elsif ($rname[1] eq "walltime") {
			    $walltime = $temp[1];
			}
		    }
		    elsif ($rname[0] eq "Resource_List") {
			if ($rname[1] eq "nodes") {
                            @tbreak = split(/:/,$temp[1]);
                            if (looks_like_number($temp[2]) && looks_like_number($tbreak[0])) {
                                $ncpu = $temp[2]*$tbreak[0];
                            }
                            elsif (looks_like_number($tbreak[0])) {
                                $ncpu = 12*$tbreak[0];
                            }
                            else {
                                #print "Mangled node string for $usager $jid\n";
                                $ncpu = 12;
                            }
			}
			elsif ($rname[1] eq "walltime") {
			    @tbreak = split(/:/,$temp[1]);
			    $wtime = $tbreak[0] + (60.0*$tbreak[1] + $tbreak[2])/3600.0;
			}
		    }
		}
	    }
            # Compute the real percent utilization
            @t1 = split(/:/,$walltime);
	    $raw_wall = 3600*$t1[0] + 60*$t1[1] + $t1[2];
            # Ignore jobs that lasted less than 10 seconds - these 
            # are just noise...
            if ($raw_wall < 10) {
		next;
	    }
            @t1 = split(/:/,$cputime);
            $raw_cpu = 3600*$t1[0] + 60*$t1[1] + $t1[2];
            $pcpu = ($raw_cpu/$ncpu)/$raw_wall;
            # Rescale the memory consumption in terms of megabytes
	    $mem = $mem/1024.0;
            # Now write these quantities to the database
	    $sthandle->execute($jid,$usager,$ncpu,$ts,$td,$tc,$pcpu,$mem,$eh,$wtime);
	    $sthandle->finish;
	}
    }
}

$dbhandle->disconnect or die DBI->errstr;

