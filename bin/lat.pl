#!/usr/bin/perl
# lat.pl                           
# Autor: shad

use strict;
use Getopt::Mixed 1.006, 'getOptions';
use File::Find;
use vars qw($opt_feld $opt_objektid $opt_verbose $opt_check $opt_help);
getOptions("bytecount b>bytecount feld f>feld objektid o>objektid verbose v>verbose check c>check help h>help");

sub hilfe { #Ausgabe Hilfstext bei -h /--help
    print "\nVerwendung: lat [Optionen] Datei_1 [Datei_2 ...]\n\n";
    print "Analysetool zur Aufbereitung und inhaltlicher Pruefung von .ldt-Dateien.\n\n";
    print "Optionen:\n\n";
    print "  -c, --check           Inhaltliche Pruefung der Datei auf Vollständigkeit und Syntaxfehler\n";
    print "  -f, --feld            Ausgabe Feldbedeutung\n";
    print "  -h, --help            Zeige diese Hilfsmeldung\n";
    print "  -o, --objektid        Ausgabe Objekt-Identifier (in LDT3)\n";
    print "  -v, --verbose         Verbose-Modus\n\n";
    print "\n";  
}
if($opt_help){hilfe;exit(0)}

die "\nVerwendung: lat [Optionen] Datei_1 [Datei_2 ...]\n\n" unless @ARGV;

my @arbeitsdateien;

foreach my $input_datei (@ARGV) { #Erstelle Liste aller eingegebenen Dateien
    push @arbeitsdateien, $input_datei;}

foreach my $input_datei (@arbeitsdateien){ #Hier beginnt der loop fuer die Batch-Verarbeitung

open my $datei, '<', $input_datei or die "Datei '$input_datei' konnte nicht geöffnet werden.\n";
my @zeilen = <$datei>;
close $datei;

sub get_version{
for my $z (@zeilen){

if (substr($z, 3, 4) == 9212){
    my $ldt_version = "LDT 2";
    return $ldt_version;
}elsif(substr($z, 3, 4) == 0001){
    my $ldt_version = "LDT 3";
    return $ldt_version;}
    }
}

my $ldt_version = &get_version;


print "\n----------------------------------------------------------------";
print "\n----------- Verarbeitung: $input_datei ($ldt_version) -----------\n";
print "----------------------------------------------------------------\n\n";

my $feldname = "";
my $zn = ""; #Zeilencounter
my @obj_idents = qw(8001 8002 8003);          #Feldnummern von Objektidents zum Ausblenden (LDT3)

    foreach my $zeile (@zeilen){ #Iteriere durch jede zeile in @zeilen und teile sie auf 
        $zn +=1;
        my $zeilennummer = "Z.$zn \t"; #definiere Zeilennummer
        my $bytecount = substr($zeile, 0, 3) . "\t";          #Bytecount
        $bytecount = "";
        my $feldkennung = substr($zeile, 3, 4) . "\t";        #Feldname
        my $feldinhalt = substr($zeile, 7);                   #Feldinhalt

        my $bytecount_int = $bytecount +0;      #setze zeileninhalt auf int
        my $feldkennung_int = $feldkennung +0;  #          --||--

        if (!$opt_objektid){ # Flag Ein/Ausblendung Objektidents (LDT3)
            if (grep{ $_ eq $feldkennung_int} @obj_idents) {next}} #skippe zeile, falls Feldkennung Objektident ist
        
        if ($opt_feld){#Flag zur Ausgabe von Feldnamen
             $feldname ="------- unbekanntes Feld -------"; # lade feldname aus referenztabelle
             $feldname = sprintf("%-50s", $feldname)} #vereinheitliche Whitespaces in der ausgabe nach STDOUT
            
        if(!$opt_verbose){ #zeilennummer ist standardmaessig ausgeblendet
            $zeilennummer = ""}
        my $ausgabe = "$zeilennummer$bytecount$feldkennung$feldname$feldinhalt"; 
        print "$ausgabe";
    }
}print "\n----------------------------------------------------------------";