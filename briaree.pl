#!/usr/bin/perl

use CGI qw(:standard);
use DBI qw(:sql_types);

# La grande question qui me reste, c'est comment recolter toutes ces donnees dont j'ai 
# besoin: for chaque tache dans PBSPro, il faut que je sache les suivants:
# Job ID
# NCPUs
# Username
# State
# Wall time consumed
# CPU time consumed
# Memory consumed
# Le 2 aout: Finalement, je crois que la meilleure solution, c'est de rouler ce script 
# de CGI sur frontal01

$datasrc = 'mysql:database=CQtaches:udem-stat.calculquebec.ca';
$dbhandle = DBI->connect("dbi:$datasrc","CQadmin","xxxx") or die DBI->errstr;
$sthandle = $dbhandle->prepare("SELECT Job_ID,Usager,NCPU,Unix_Timestamp(T_Demarrage),Etat,PCPU,Memoire,Memoire_demandee,Temps_demande,ctime FROM Etat_actuel WHERE arch=\'x86-64/briaree\';") or die "Couldn't prepare statement!\n";
$simd_handle = $dbhandle->prepare("SELECT MAX(gflops),AVG(gflops),AVG(IPC) FROM Tache_briaree WHERE Job_ID=?;");
$ntache = 0;
$now = time;
$sthandle->execute();
while(@row = $sthandle->fetchrow_array) {
    $jid[$ntache] = $row[0];
    $user[$ntache] = $row[1];
    $ncpus[$ntache] = $row[2];
    $stime[$ntache] = $row[3];
    $state[$ntache] = $row[4];
    $pcpu[$ntache] = $row[5];
    $mem[$ntache] = $row[6];
    $mem_req[$ntache] = $row[7];
    $wt_req[$ntache] = $row[8];
    $dtime = $row[9];
    if ($state[$ntache] eq "R") {
	$cput[$ntache] = $pcpu[$ntache]*$ncpus[$ntache]*($now - $stime[$ntache])/(360000.0);	    
    }
    else {
	$cput[$ntache] = 0.0;
    }
    $stime[$ntache] = sprintf("%3.2f",($now - $stime[$ntache])/3600.0);
    $ntache += 1;
}
$sthandle->finish();
for($i=0; $i<$ntache; $i=1+$i) {
    if ($state[$i] eq "R") {
        @temp = split(/\./,$jid[$i]);
	#print "$temp[0]\n";
	$simd_handle->bind_param(1,$temp[0],SQL_VARCHAR);
	$simd_handle->execute();
	$simd_handle->bind_columns(undef,\$gflops_max,\$gflops_avg,\$mips_avg);
	while($simd_handle->fetch()) {
	    $s_max[$i] = sprintf("%.2f",$gflops_max);
	    $s_avg[$i] = sprintf("%.2f",$gflops_avg);
	    $ipc[$i] = sprintf("%.2f",$mips_avg);
	}
    }
}
$simd_handle->finish();
$dbhandle->disconnect();

$nserial = 0;
$nactif = 0;
$ntache_r = 0;
$wness = 0;
$biggest = 0;
for($i=0; $i<$ntache; $i=1+$i) {
    $cput[$i] = sprintf("%.2f",$cput[$i]);
    if ($state[$i] eq "R") {
	$nactif = $nactif + $ncpus[$i];
	$ntache_r = $ntache_r + 1;
	$wness = $wness + $ncpus[$i];
	if ($ncpus[$i] == 1) {
	    $nserial = $nserial + 1;
	}
	if ($biggest < $ncpus[$i]) {
	    $biggest = $ncpus[$i];
	}
    }
}

$ntache_q = $ntache-$ntache_r;
# There are 7932 CPUs on briaree
$nidle = 7932-$nactif;
if ($ntache_r > 0) {
    $wness = sprintf("%.2f",$wness/$ntache_r);
    $pcent = sprintf("%.2f",100.0*($nserial/$ntache_r));
}
print header("text/html");
print STDOUT "<HTML>";
print STDOUT "<TITLE>&Eacute;tat actuel de Briar&eacute;e</TITLE>";
print STDOUT "<BODY>";
print STDOUT "Les donn&eacute;es ici ont &eacute;t&eacute actualis&eacute;es &agrave; $dtime";
print STDOUT "<H1>Indices globaux</H1>";
print STDOUT "<ul>";
print STDOUT "<li>Il y a $nidle (de 7932) processeur(s) inactif(s), et $ntache_q t&acirc;che(s) en attente<br>";
print STDOUT "<li>Le degr&eacute; de parall&eacute;lisme est $wness, et la plus grande t&acirc;che parall&egrave;le ";
print STDOUT "utilise $biggest processeur(s)<br>";
print STDOUT "<li>Il y a $nserial t&acirc;che(s) mono-processeur, $pcent % de la somme";
print STDOUT "</ul>";
print STDOUT "<HR>";
print STDOUT "<H1>Les t&acirc;ches particuli&egrave;res:</H1>";
print STDOUT "<TABLE BORDER CELLSPACING=0 CELLPADDING=5>";
print STDOUT "<TR>";
print STDOUT "<TD COLSPAN=13 ROWSPAN=1+$ntache></TD>";
print STDOUT "</TR>";
print STDOUT "<TR>";
print STDOUT "<TH>Job ID</TH>";
print STDOUT "<TH>Usager</TH>";
print STDOUT "<TH>Nombre de CPUs</TH>";
print STDOUT "<TH>&Eacute;tat</TH>";
print STDOUT "<TH>Pourcentage CPU</TH>";
print STDOUT "<TH>M&eacute;moire consomm&eacute;e par CPU (en Mo)</TH>";
print STDOUT "<TH>M&eacute;moire demand&eacute;e par CPU (en Mo)</TH>";
print STDOUT "<TH>Temps r&eacute;el demand&eacute (en heures)</TH>";
print STDOUT "<TH>Temps r&eacute;el &eacute;coul&eacute; (en heures)</TH>";
print STDOUT "<TH>Temps CPU consomm&eacute; (en heures)</TH>";
print STDOUT "<TH>Maximum de GFLOP/s (par coeur)</TH>";
print STDOUT "<TH>Moyenne de GFLOP/s (par coeur)</TH>";
print STDOUT "<TH>Nombre moyen d'instructions par cycle</TH>";
print STDOUT "</TR>";
for($i=0; $i<$ntache; $i=1+$i) {
    if ($state[$i] eq "R") {
	print STDOUT "<TR ALIGN=CENTER>";
        if ($ipc[$i] < 0.1) {
            $colour = "color:#FF0000";
        }
        elsif ($ipc[$i] < 0.5) {
            $colour = "color:#F87531";
        }
        else {
            $colour = "color:#000000";
        }
	print STDOUT "<TD><a style=$colour href=\"display_briaree_stats.pl?jobid=$jid[$i]\">$jid[$i]</a></TD>";
        print STDOUT "<TD style=$colour>$user[$i]</TD>";
        print STDOUT "<TD style=$colour>$ncpus[$i]</TD>";
        print STDOUT "<TD style=$colour>R</TD>";
        print STDOUT "<TD style=$colour>$pcpu[$i]</TD>";
        print STDOUT "<TD style=$colour align=right>$mem[$i]</TD>";
        print STDOUT "<TD style=$colour align=right>$mem_req[$i]</TD>";
        print STDOUT "<TD style=$colour>$wt_req[$i]</TD>";
        print STDOUT "<TD style=$colour>$stime[$i]</TD>";
        print STDOUT "<TD style=$colour>$cput[$i]</TD>";
	print STDOUT "<TD style=$colour>$s_max[$i]</TD>";
	print STDOUT "<TD style=$colour>$s_avg[$i]</TD>";
	print STDOUT "<TD style=$colour>$ipc[$i]</TD>";
	print STDOUT "</TR>";
    }
}
for($i=0; $i<$ntache; $i=$i+1) {
    if ($state[$i] ne "R") {
	print STDOUT "<TR ALIGN=CENTER>";
	print STDOUT "<TD>$jid[$i]</TD>";
	print STDOUT "<TD>$user[$i]</TD>";
	print STDOUT "<TD>$ncpus[$i]</TD>";
	print STDOUT "<TD>Q</TD>";
        print STDOUT "<TD>---</TD>";
        print STDOUT "<TD>---</TD>";
	print STDOUT "<TD align=right>$mem_req[$i]</TD>";
        print STDOUT "<TD>$wt_req[$i]</TD>";
	print STDOUT "<TD>---</TD>";
        print STDOUT "<TD>---</TD>";
	print STDOUT "<TD>---</TD>";
	print STDOUT "<TD>---</TD>";
	print STDOUT "<TD>---</TD>";
	print STDOUT "</TR>";
    }
}
print STDOUT "</TABLE>";
print STDOUT "</BODY>";
print STDOUT "</HTML>";

sub parse_time()
{
    my @parms = @_;
    ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$DST) = localtime($parms[0]);
    $rmonth = 1 + $month;
    if ($day < 10) {
        $day = "0".$day;
    }
    if ($rmonth < 10) {
        $rmonth = "0".$rmonth;
    }
    $t1 = sprintf("%04d-%02d-%02d ",1900+$year,$rmonth,$day);
    $t2 = sprintf("%02d:%02d:%02d",$hour,$min,$sec);
    $output = $t1.$t2;
    return $output;
}
