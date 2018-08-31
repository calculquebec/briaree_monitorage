#!/usr/bin/perl

use DBI;
use POSIX;
use CGI qw(:standard);
use GD::Graph::lines;

my ($jid,@row,$datasrc,$dbhandle,$sthandle,$i,@data,@rcount,@mflops,$largest,$smallest,@donnees,$avg_mflops,$avg_mips,$nrow);

@temp = split(/\./,param('jobid'));
$jid = $temp[0];

@titles = ("IPC","GFLOP/s","x87 Instructions","Load Instructions","Store Instructions","Stalled Instructions","Branch Instructions","Missed Branches","L3 Cache Misses","SSE Double","SSE Single","SSE Integer");
$datasrc = 'mysql:database=CQtaches:localhost';
$dbhandle = DBI->connect("dbi:$datasrc","CQadmin","xxxx") or die DBI->errstr;

$sthandle = $dbhandle->prepare("SELECT IPC,gflops,x87_instr,pload,pstore,pstall,pbranch,mis_branch,l3_misses,sse_double,sse_single,sse_int FROM Tache_briaree WHERE Job_ID=\'$jid\';") or die "Couldn't prepare statement!\n";

$nrow = 0;
$sthandle->execute();
while(@row = $sthandle->fetchrow_array) {
    $rcount[$nrow] = $nrow;
    for($k=0; $k<12; $k = 1+$k) {
	$donnees[$k][$nrow] = $row[$k];
    }
    $nrow = $nrow + 1;
}
$sthandle->finish;

$sthandle2 = $dbhandle->prepare("SELECT exec_host FROM Etat_actuel WHERE arch=\'x86-64/briaree\' and Job_ID like \'$jid%\';");
$sthandle2->execute();
while(@row = $sthandle2->fetchrow_array) {
    $exec_host = $row[0];
}
$sthandle2->finish;

if ($nrow == 0) {
    print header("text/html");
    print STDOUT "<HTML>";
    print STDOUT "<TITLE>S&eacute;rie de donn&eacute;es</TITLE>";
    print STDOUT "<BODY>";
    print STDOUT "D&eacute;sol&eacute;, il n'y a pas de donn&eacute;es pour cette t&acirc;che.";
    print STDOUT "</BODY>";
    print STDOUT "</HTML>";
    exit(1);
}

$timeref = \@rcount;

$largest = $donnees[0][0];
for($l=0; $l<$#rcount; $l=$l+1) {
   $mflops[$l] = $donnees[0][$l];
   if ($mflops[$l] > $largest) {
       $largest = $mflops[$l];
   }
}

$flopsref = \@mflops;
@data = ($timeref,$flopsref);

$i = $#rcount;
if ($i <= 20) {
  $xls = 1;
}
elsif ($i <= 50) {
  $xls = 2;
}
elsif ($i <= 100) {
  $xls = 5;
}
elsif ($i <= 500) {
  $xls = 20;
}
elsif ($i <= 1000) {
  $xls = 50;
}
else {
  $xls = 100;
}
    
$graph = GD::Graph::lines->new(600,500);
$graph->set(
       x_label => 'Estampille temporelle',
       y_label => "IPC",
       title   => "Instructions par cycle",
       x_labels_vertical => 1,
       x_label_skip => $xls
) or die $graph->error;


$image = $graph->plot(\@data);
$pngimage = $image->png();
$filename = "/var/www/html/cqum/images/$jid" . "_0.png";
$fname[0] = "$jid" . "_0.png";
open(OUT,">$filename");
binmode OUT;
print OUT $pngimage;
close OUT;

$largest = $donnees[1][0];
for($l=0; $l<$#rcount; $l=$l+1) {
    $mflops[$l] = $donnees[1][$l];
    if ($mflops[$l] > $largest) {
	$largest = $mflops[$l];
    }
}

$flopsref = \@mflops;
@data = ($timeref,$flopsref);

$graph = GD::Graph::lines->new(600,500);
$graph->set(
       x_label => 'Estampille temporelle',
       y_label => "GFLOP/s",
       title   => "GigaFLOP/s",
       x_labels_vertical => 1,
       x_label_skip => $xls
) or die $graph->error;

$image = $graph->plot(\@data);
$pngimage = $image->png();
$filename = "/var/www/html/cqum/images/$jid" . "_1.png";
$fname[1] = "$jid" . "_1.png";

open(OUT,">$filename");
binmode OUT;
print OUT $pngimage;
close OUT;

for($k=2; $k<12; $k = 1+$k) {
    $largest = $donnees[$k][0];
    for($l=0; $l<$#rcount; $l=$l+1) {
    	$mflops[$l] = $donnees[$k][$l];
        if ($mflops[$l] > $largest) {
    	    $largest = $mflops[$l];
        }
    }
    if ($largest == 0) {
    	next;
    }

    $flopsref = \@mflops;
    @data = ($timeref,$flopsref);

    $i = $#rcount;
    if ($i <= 20) {
	$xls = 1;
    }
    elsif ($i <= 50) {
	$xls = 2;
    }
    elsif ($i <= 100) {
	$xls = 5;
    }
    elsif ($i <= 500) {
	$xls = 20;
    }
    elsif ($i <= 1000) {
	$xls = 50;
    }
    else {
	$xls = 100;
    }
    
    $graph = GD::Graph::lines->new(600,500);
    $graph->set(
       x_label => 'Estampille temporelle',
       y_label => "Pourcentage",
       title   => "$titles[$k]",
       x_labels_vertical => 1,
       x_label_skip => $xls,
       y_max_value => 100.0,
       y_min_value => 0.0
    ) or die $graph->error;


    $image = $graph->plot(\@data);
    $pngimage = $image->png();
    $filename = "/var/www/html/cqum/images/$jid" . "_$k.png";
    $fname[$k] = "$jid" . "_$k.png";
    open(OUT,">$filename");
    binmode OUT;
    print OUT $pngimage;
    close OUT;
}
@nodes = split(/:/,$exec_host);

print header("text/html");
print STDOUT "<HTML>";
print STDOUT "<TITLE>S&eacute;rie de donn&eacute;es</TITLE>";
print STDOUT "<BODY>";
print STDOUT "Cette t&acirc;che roule sur les noeuds suivants:<br>";
foreach $n (@nodes) {
    print STDOUT "<a href=\"http://egeon1.calculquebec.ca/ganglia/?m=load_one&r=hour&s=descending&c=rqchp&h=$n&sh=1&hc=4&z=small\">$n</a><br>";
}
print STDOUT "<br><hr>";
print STDOUT "<img src=\"http://udem-stat.calculquebec.ca/cqum/images/$fname[0]\">";
print STDOUT "<br><br><br>";
print STDOUT "<img src=\"http://udem-stat.calculquebec.ca/cqum/images/$fname[1]\">";
print STDOUT "<br><br><br>";
print STDOUT "<img src=\"http://udem-stat.calculquebec.ca/cqum/images/$fname[2]\">";
print STDOUT "<br><br><br>";
print STDOUT "<img src=\"http://udem-stat.calculquebec.ca/cqum/images/$fname[3]\">";
print STDOUT "<br><br><br>";
print STDOUT "<img src=\"http://udem-stat.calculquebec.ca/cqum/images/$fname[4]\">";
print STDOUT "<br><br><br>";
print STDOUT "<img src=\"http://udem-stat.calculquebec.ca/cqum/images/$fname[5]\">";
print STDOUT "<br><br><br>";
print STDOUT "<img src=\"http://udem-stat.calculquebec.ca/cqum/images/$fname[6]\">";
print STDOUT "<br><br><br>";
print STDOUT "<img src=\"http://udem-stat.calculquebec.ca/cqum/images/$fname[7]\">";
print STDOUT "<br><br><br>";
print STDOUT "<img src=\"http://udem-stat.calculquebec.ca/cqum/images/$fname[8]\">";
print STDOUT "<br><br><br>";
print STDOUT "<img src=\"http://udem-stat.calculquebec.ca/cqum/images/$fname[9]\">";
print STDOUT "<br><br><br>";
print STDOUT "<img src=\"http://udem-stat.calculquebec.ca/cqum/images/$fname[10]\">";
print STDOUT "<br><br><br>";
print STDOUT "<img src=\"http://udem-stat.calculquebec.ca/cqum/images/$fname[11]\">";
print STDOUT "<br>";
print STDOUT "</BODY>";
print STDOUT "</HTML>";

