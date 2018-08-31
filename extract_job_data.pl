#!/usr/bin/perl

use DBI;

$datasrc = 'mysql:database=CQtaches:udem-stat.calculquebec.ca';
$dbhandle = eval { DBI->connect("dbi:$datasrc","CQadmin","xxxx") };

#$sthandle = $dbhandle->prepare("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Tache_briaree';");
#$sthandle = $dbhandle->prepare("SELECT COLUMN_NAME,COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Tache_briaree';");
#$sthandle = $dbhandle->prepare("SELECT NCPU,(UNIX_TIMESTAMP(T_Completion)-UNIX_TIMESTAMP(T_Demarrage))/3600.0 FROM Tache WHERE Job_ID LIKE '%briaree%' AND Usager='ossokine' AND T_Demarrage >= '2015-02-01' AND T_Completion <= '2015-02-28';");
#$sthandle = $dbhandle->prepare("SELECT Usager,Job_ID,NCPU,(UNIX_TIMESTAMP(T_Demarrage)-UNIX_TIMESTAMP(T_Soumission))/3600.0 FROM Tache WHERE ehost LIKE 'node-f2%';");
#$sthandle = $dbhandle->prepare("SELECT Job_ID FROM Tache WHERE T_Demarrage >= '2014-02-20';");
$sthandle = $dbhandle->prepare("SELECT Job_ID,NCPU,Usager FROM Tache WHERE T_Demarrage >= '2017-10-15' AND Job_ID LIKE '%briaree%';");
$sthandle->execute();
$sum = 0;
$njobs = 0;
while(@row = $sthandle->fetchrow_array) {
    print "$row[0] $row[2]\n";
    $njobs += 1;
    #$sum += $row[0]*$row[1];
    #$ncpu = 12*($row[1]/8);
    #$jobs[$i] = $row[0];
    #$jobs[$i+1] = $ncpu;
    #$i=$i+2;
}
$sthandle->finish();
print "The number of jobs $njobs\n";
#$sum = $sum/24.0;
#print "The user had $njobs jobs that consumed $sum CPU days\n";
#$N = $i;
#print $N;
#$sthandle2 = $dbhandle->prepare("UPDATE Tache SET NCPU = ? WHERE Job_ID = ?;");
#for($i=0; $i<$N; $i=$i+2) {
#    $jid = $jobs[$i];
#    $ncpu = $jobs[$i+1];
#    print "$N $i $jid $ncpu\n";
#    $sthandle2->execute($ncpu,$jid);
#    $sthandle2->finish;
#}

