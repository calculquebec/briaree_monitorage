#!/usr/bin/perl

use DBI qw(:sql_types);
use CGI qw(:standard);

my ($uid,@row,$datasrc,$dbhandle,$sthandle);

#$uid = param('usager');
#$date = param('date');
$uid = "zjanda";
$date = "";
$datasrc = 'mysql:database=CQtaches:udem-stat.calculquebec.ca';
$dbhandle = DBI->connect("dbi:$datasrc","CQadmin","xxxx") or die DBI->errstr;
$mf_handle = $dbhandle->prepare("SELECT MAX(Megaflops),AVG(Megaflops),AVG(MIPS) FROM Tache_courante WHERE Job_ID=?;");
if ($date eq "") {
    $sthandle = $dbhandle->prepare("SELECT Job_ID,PCPU,NCPU,Memoire,T_Demarrage,T_Completion,NCPU*(UNIX_TIMESTAMP(T_Completion)-UNIX_TIMESTAMP(T_Demarrage))/3600.0,Ehost FROM Tache WHERE Usager=\'$uid\' ORDER BY T_Completion;") or die "Couldn't prepare statement!\n";
    $today = sprintf "%4d-%02d-%02d",2004,01,01;
}
else {
    @data = split(/\//,$date);
    $jour = $data[0];
    $mois = $data[1];
    $annee = $data[2];
    $today = sprintf "%4d-%02d-%02d",$annee,$mois,$jour;
    $sthandle = $dbhandle->prepare("SELECT Job_ID,PCPU,NCPU,Memoire,T_Demarrage,T_Completion,NCPU*(UNIX_TIMESTAMP(T_Completion)-UNIX_TIMESTAMP(T_Demarrage))/3600.0,Ehost FROM Tache WHERE Usager=\'$uid\' AND T_Completion >= (\' $today 00:00:01\') ORDER BY T_completion;") or die "Couldn't prepare statement!\n";
}
$sthandle->execute();
$n = 0;
while(@row = $sthandle->fetchrow_array) {
    $jid[$n] = $row[0];
    $pcpu[$n] = $row[1];
    $ncpu[$n] = $row[2];
    $mem[$n] = $row[3];
    $sdate[$n] = $row[4];
    $date[$n] = $row[5];
    $tconsumed[$n] = $row[6];
    $ehost[$n] = $row[7];
    $n += 1;
}
$sthandle->finish();

for($i=0; $i<$n; $i++) {
    $mf_handle->bind_param(1,$jid[$i],SQL_VARCHAR);
    $mf_handle->execute();
    $mf_handle->bind_columns(undef,\$mf_max,\$mf_avg,\$mips_avg);
    while($mf_handle->fetch()) {
	$mfm[$i] = sprintf("%.2f",$mf_max);
	$mfa[$i] = sprintf("%.2f",$mf_avg);
	$ipc[$i] = sprintf("%.2f",$mips_avg/1500.0);
    }
}
$mf_handle->finish();
$dbhandle->disconnect();

$sum = 0.0;
print STDOUT "Content-type: text/html", "\n\n";
print STDOUT "<HTML>";
print STDOUT "<H1 align=center>";
print STDOUT "Historique de t&acirc;ches pour l'usager $uid depuis le $today";
print STDOUT "</H1>";
print STDOUT "<BODY>";
print STDOUT "<HR>";
print STDOUT "<TABLE BORDER CELLSPACING=0 CELLPADDING=5>";
print STDOUT "<TR>";
print STDOUT "<TD COLSPAN=12 ROWSPAN=1+$n></TD>";
print STDOUT "</TR>";
print STDOUT "<TR>";
print STDOUT "<TH>Job ID</TH>";
print STDOUT "<TH>Pourcentage CPU</TH>";
print STDOUT "<TH>Nombre de CPUs</TH>";
print STDOUT "<TH>Consommation de m&eacute;moire par CPU (en Mo)</TH>";
print STDOUT "<TH>D&eacute;marr&eacute;e le<?TH>";
print STDOUT "<TH>Termin&eacute;e le</TH>";
print STDOUT "<TH>Machine d'ex&eacute;cution</TH>";
print STDOUT "<TH>Maximum de MFLOP/s (par CPU)</TH>";
print STDOUT "<TH>Moyenne de MFLOP/s (par CPU)</TH>";
print STDOUT "<TH>Nombre moyen d'instructions par cycle</TH>";
print STDOUT "<TH>Temps CPU consomm&eacute; (en heures)</TH>";
print STDOUT "<TH>Somme des temps CPU consomm&eacute;s (en heures)</TH>";
print STDOUT "</TR>";
for($i=0; $i<$n; $i++) {
    print STDOUT "<TR ALIGN=CENTER>";
    if ($mfm[$i] > 0.0 && $ipc[$i] > 0.0) {
	print STDOUT "<TD><a href=\"showall.pl?jobid=$jid[$i]&cpus=$ncpu[$i]\">$jid[$i]</a></TD>";
    }
    else {
	print STDOUT "<TD>$jid[$i]</TD>";
    }
    $temp = sprintf("%.2f",100.0*$pcpu[$i]);
    print STDOUT "<TD>$temp</TD>";
    print STDOUT "<TD>$ncpu[$i]</TD>";
    $temp = sprintf("%.2f",$mem[$i]/$ncpu[$i]);
    print STDOUT "<TD>$temp</TD>";
    print STDOUT "<TD>$sdate[$i]</TD>";
    print STDOUT "<TD>$date[$i]</TD>";
    print STDOUT "<TD>$ehost[$i]</TD>";
    if ($mfm[$i] > 0.0 && $ipc[$i] > 0.0) {    
	$t1 = sprintf("%.2f",100.0*$mfm[$i]/6000.0);
	print STDOUT "<TD>$mfm[$i] ($t1%)</TD>";
	$t1 = sprintf("%.2f",100.0*$mfa[$i]/6000.0);
	print STDOUT "<TD>$mfa[$i] ($t1%)</TD>";
	print STDOUT "<TD>$ipc[$i]</TD>";
    }
    else {
	print STDOUT "<TD>---</TD>";
	print STDOUT "<TD>---</TD>";
	print STDOUT "<TD>---</TD>";
    }
    print STDOUT "<TD>$tconsumed[$i]</TD>";
    $sum = $sum + $tconsumed[$i];
    $rsum = sprintf("%.3f",$sum);
    print STDOUT "<TD>$rsum</TD>";
    print STDOUT "</TR>";
}
print STDOUT "</TABLE>";
print STDOUT "</BODY>";
print STDOUT "</HTML>";

