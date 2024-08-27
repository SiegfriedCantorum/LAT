#!/usr/bin/perl
#
# ---------------------------------------------------------
# lat.pl                           
# Autor: shad
# Version: 1.3 'facelift' (2024-06-19 build)
# Neuerungen:
#       
#   - Allgemeine Ueberarbeitung des Codes: Vereinfachung, streamlining, De-Spaghettifizierung 
#
# --------------------------------------------------------- 
# Kommandozeilentool zur graphisch aufbereiteten Anzeige von .ldt-Dateien 
# 
# "lat" liest die Eingabedatei(en) Zeilenweise aus, bereitet Sie entsprechend der Eingabeparameter auf und gibt das Ergebniss nach STDOUT aus.
#        
#       - Standardeinstellungen:
#           - Ausgabe: FELDZIFFER - FELDINHALT (Rest jeder Zeile wird entfernt)
#           - LDT-Standard: LDT 2 gemaess KBV-Feldtabelle (Referenztabellen fuer Bedeutungen von Feldziffern liegen auf der laborsrv unter /laborsrv/parameterdateien/ldt_feldtabellen/)
#           - LAT blendet Objektidentifier (nur in LDT3 vorhanden) automatisch aus
#       
# ---------------------------------------------------------
# Optimierungsmoeglichkeiten:
#   
#   - Vereinfachung des Codes: "lat" ist mein erstes perl-tool ueberhaupt und kann bestimmt mit der Haelfte an Zeilen geschrieben werden ;)
#   
# ---------------------------------------------------------
#   GEPLANTE UPDATES:                                                               
#
#       - 1.X ('Troyes')       - Anpassung des Check-Moduls an LDT3 Standards
#                 
#       - 1.X ('springclean')  - Ueberarbeitung der Verarbeitungsablaeufe des Tools: Streamlining, Entfernen von redunanten loops, Vereinheitlichungen von Variablen, Funktionen etc
#                              - Modularisierung / Packaging erforderlicher libraries -> nach Moeglichkeit keine statische Adresse der Referenztabellen auf Server, sondern in tool hinterlegt
#
#       - 1.X ('tbd')          - Neuer Parser ?
#                              - Allgemeine Vereinfachungen ? 
#                              - Updates der Referenztabellen ?
#        
######################################################################################

use strict;
use Config::Tiny;
use Getopt::Mixed 1.006, 'getOptions'; #Aktuellere Module wie Getopt::Long liegen nicht auf der linuxsrv!
use File::Find;
use vars qw($opt_bytecount $opt_feld $opt_objektid $opt_verbose $opt_switch $opt_check $opt_help $opt_version $opt_dynamic);

getOptions("bytecount b>bytecount feld f>feld objektid o>objektid verbose v>verbose switch w>switch check c>check help h>help version dynamic d>dynamic "); #Eingabeparameter Kommandozeile

my @arbeitsdateien;             #liste eingabedateien
my @fehlermeldungen;            #liste Fehlermeldungen
my @ListeBedingungen;           #liste an Bedingungen f. Abrechnungstypen
my @feldkennungen_vorhanden;    #liste vorhandene Feldkennungen in Datei

sub hilfe { #Ausgabe Hilfstext bei -h /--help
    print "\nVerwendung: lat [Optionen] Datei_1 [Datei_2 ...]\n\n";
    print "Analysetool zur Aufbereitung und inhaltlicher Pruefung von .ldt-Dateien.\n\n";
    print "Optionen:\n\n";
    print "  -b, --bytecount       Ausgabe Bytecount Zeilen\n";
    print "  -c, --check           Inhaltliche Pruefung der Datei auf Vollständigkeit und Syntaxfehler\n";
    print "  -d, --dynamic         EXPERIMENTELLES FEATURE! Dynamische Erkennung der LDT-Version einer Datei \n";
    print "  -f, --feld            Ausgabe Feldbedeutung\n";
    print "  -h, --help            Zeige diese Hilfsmeldung\n";
    print "  -o, --objektid        Ausgabe Objekt-Identifier (in LDT3)\n";
    print "  -v, --verbose         Verbose-Modus\n";
    print "  -w, --switch          Wechsel der Referenz-LDT-Version auf LDT3 (Standard: LDT2)\n\n";
    print "      --version         Zeige vorhandene Version von lat\n";
    print "\n";  
}

sub version{#Ausgabe Version --version
    print "\nLDT-AnalyseTool Version 1.3 'facelift' (2024-06-19 build)\n\n";
    print "Tool zur grafisch aufbereiteten Ausgabe und Analyse von Dateien des LDT-Standards \n";
    print "Geschrieben von Siegfried Hadatsch (-shad)\n\nAnregungen, Anmerkungen und Bugs an s.hadatsch(at)volkmann.de - Merci! :D \n";
    print "\n";  
}
if($opt_help){hilfe;exit(0)}        #aufruf hilfe bei -h
if($opt_version){version;exit(0)}   #aufruf version bei --version

die "\nVerwendung: lat [Optionen] Datei_1 [Datei_2 ...]\n\n" unless @ARGV;

foreach my $input_datei (@ARGV) { #Erstelle Liste aller eingegebenen Dateien
    push @arbeitsdateien, $input_datei;
}

if($opt_verbose){$opt_bytecount = 1, $opt_feld = 1, $opt_objektid = 1, $opt_verbose = 1}  #Setze verbose-modus auf aktiv

foreach my $input_datei (@arbeitsdateien){ #Hier beginnt der loop fuer die Batch-Verarbeitung

open my $datei, '<', $input_datei or die "Datei '$input_datei' konnte nicht geöffnet werden.\n";
my @zeilen = <$datei>;
close $datei;

#### Bestimmung Version des Datensatzes #####

my $ver_satzbeschreibung = "Unbekannt! (Wechsel zu default: LDT2)";
my $ldt_tabelle_geladen;
my $ldt_tabelle; 
                    
for my $z (@zeilen){ #Wir bestimmen die Version des LDT-Datensatzes basierend auf der Feldkennung, die die Datei verwendet    
    my $feldkennung = substr($z, 3, 4);
    
    if ($feldkennung == 9212){ #LDT1 + LDT2 : Version in Feldkennung 9212 
        $ldt_tabelle = '/c/Users/hadatsch/Desktop/Projects/enw/lat/Releases/00_lib/lib/ldt2.pl'; #Auf linuxsrv auskommentieren!!!
        #$ldt_tabelle = '/laborsrv/parameterdateien/ldt_feldtabellen/ldt2.pl'; #In IDE auskommentieren!! #PFADE STATISCH FUER linuxsrv
        $ver_satzbeschreibung = substr($z,7);
    } elsif ($feldkennung == 0001){ #LDT3 : Version in Feldkennung 0001 hinterlegt
        $ldt_tabelle = '/c/Users/hadatsch/Desktop/Projects/enw/lat/Releases/00_lib/lib/ldt3.pl';#Auf linuxsrv auskommentieren!!!
        #my $ldt_tabelle = '/laborsrv/parameterdateien/ldt_feldtabellen/ldt3.pl'; #In IDE auskommentieren!! #PFADE STATISCH FUER linuxsrv
        $ver_satzbeschreibung = substr($z,7);
    }

    if (defined $ldt_tabelle){
        $ldt_tabelle_geladen = do $ldt_tabelle;
    } else {
        $ldt_tabelle = '/c/Users/hadatsch/Desktop/Projects/enw/lat/Releases/00_lib/lib/ldt2.pl';
        #my $ldt_tabelle = '/laborsrv/parameterdateien/ldt_feldtabellen/ldt2.pl'; #In IDE auskommentieren!! #PFADE STATISCH FUER linuxsrv
        $ldt_tabelle_geladen = do $ldt_tabelle; #default-pfad
        }
    }

#### Bestimmung Datensatz Version Ende ####

############# Block zur regulaeren Ausgabe von Datei ##############
$ver_satzbeschreibung =~ s/^\s+|\s+$//g; #Whitespace entfernen
print"\n\n+--+--+--+--+--+--+--+--+--+--+--+--+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+\n"; #Wir bauen einen Header fuer jede neue Datei
print "\nVerarbeitung: $input_datei (Version $ver_satzbeschreibung)\n\n\n";

my $feldname = "";
my $zn = "";                                  #Zeilencounter
my @obj_idents = qw(8001 8002 8003);          #Feldnummern von Objektidents zum Ausblenden (LDT3)

    foreach my $zeile (@zeilen){ #Iteriere durch jede zeile in @zeilen und teile sie auf 
        $zn ++;
        my $zeilennummer = !$opt_verbose ? "" : "Z.$zn \t"; #definiere Zeilennummer

        my $bytecount =  !$opt_bytecount ? "" : substr($zeile, 0, 3) . "\t";    #Bytecount + Flag Ausgabe
        my $feldkennung = substr($zeile, 3, 4) . "\t";                          #Feldname
        my $feldinhalt = substr($zeile, 7);                                     #Feldinhalt
        my $bytecount_int = $bytecount +0;      #setze zeileninhalt auf int
        my $feldkennung_int = $feldkennung +0;  #          --||--

        if (!$opt_objektid && grep{ $_ eq $feldkennung_int} @obj_idents) {next;} #Skippe Objekt_IDs
        
        my $feldname = "";
        if ($opt_feld){ #Flag zur Ausgabe von Feldnamen
            $feldname = $ldt_tabelle_geladen->{$feldkennung_int} || "------- Feldkennung unbekannt -------"; # lade feldname aus referenztabelle
            $feldname = sprintf("%-70s", $feldname)} #vereinheitliche Whitespaces in der ausgabe nach STDOUT

        my $ausgabe = "$zeilennummer$bytecount$feldkennung$feldname$feldinhalt"; 
        print "$ausgabe";
    }

############## Anfang Block inhaltlicher Check von Datei ################

if($opt_check){
    print"\n--------------------- Vollständigkeitspruefung ($input_datei) --------------------- \n\n"; #Wir bauen eine Kopfzeile

#### hier beginnt der check-marathon #### TODO : Hier wird irgendwann mal auch der switch basierend auf Satzversion stehen!

    my @adressen_fk = qw(3107 8321 8607); #Feldkennungen von Adressfeldern
    my @LANR_BSNR_fk = qw(0201 4217 4218 4241 4242 4248 4249); #Feldkennungen von LANR o. BSNR mit Laenge NEUN
    my @datumsfelder_fk = qw(0227 3103 3424 3425 3471 4102 4109 4110 4115 4133 4206 4214 4235 4247 4264 4265 4266 4268 4276 4277 4278 5000 5025 5026 5034 9103 9115 9116 9122); #Feldkennungen von Datumsfeldern mit Laenge ACHT
    my $zeilennummer = 0; #Counter fuer zeilennummer

    for my $zeile (@zeilen){# Pruefe 'einfache' Fehlerbedingungen wie Bytecount, invalid characters, falsche laenge von BSNR / LANR
        $zeilennummer +=1;
        $zeile =~ s/^\s+|\s+$//g; #Entferne Whitespace vor und nach Zeileninhalt
        my $bytecount = substr($zeile, 0,3);
        my $feldkennung = substr($zeile, 3, 4);
        my $feldinhalt = substr($zeile, 7);
        my $feldname = $ldt_tabelle_geladen->{int($feldkennung)} || "------- Feldkennung unbekannt -------";

        #Lasst uns nach non-ints in Feldkennung und Bytecount suchen und Fehlermeldungen generieren
        if ($bytecount =~ /\D/) {
           push @fehlermeldungen, "$zeilennummer '$zeile': Bytecount ($bytecount) enthält ungueltige Zeichen.\n";
            }
        if ($feldkennung =~ /\D/) {         
            push @fehlermeldungen, "$zeilennummer '$zeile': Feldkennung ($feldkennung) enthält ungueltige Zeichen.\n";
            }              
        if (grep {$_ eq $feldkennung} @adressen_fk) { #Pruefe ob Adressfelder Zahlen enthalten        
            if ($feldinhalt =~ /\d/){
                push @fehlermeldungen, "$zeilennummer '$zeile': Adressefeld '$feldinhalt' enthält Zahlen.\n"}
                }
        if (grep {$_ eq $feldkennung} @LANR_BSNR_fk){ #Suche Feldkennung in Liste von LANR/BSNR

            if ($feldinhalt =~ /\D/) {#Unerlaubte Zeichen in Nr.
                push @fehlermeldungen, "$zeilennummer '$zeile': $feldname ('$feldinhalt') enthält ungueltige Zeichen.\n";}
            if (length($feldinhalt) != 9 && $feldinhalt !~ /\D/){ #Längenberechnung von Nr; Nr mit falschen Zeichen wird nicht als Fehler ausgegeben
                push @fehlermeldungen, "$zeilennummer '$zeile': $feldname ('$feldinhalt') hat die falsche Länge. $feldname muss immer neunstellig sein. \n";
                }
            }

        if (grep {$_ eq $feldkennung} @datumsfelder_fk){ #Suche Feldkennung in Liste von Datumsfeldern

            if ($feldinhalt =~ /\D/) {#Unerlaubte Zeichen in Feld ()
                push @fehlermeldungen, "$zeilennummer '$zeile': $feldname ('$feldinhalt') enthält ungueltige Zeichen.\n";}
            if (length($feldinhalt) != 8 && $feldinhalt !~ /\D/){ #Längenberechnung von Nr; Nr mit falschen Zeichen wird nicht als Fehler ausgegeben
                push @fehlermeldungen, "$zeilennummer '$zeile': $feldname ('$feldinhalt') hat die falsche Länge. $feldname muss immer achtstellig sein. \n";
                }
            }

        if (substr($zeile, 3, 4) == 4125 ||substr($zeile, 3, 4) == 4233){ #Check Feld Laenge 16 zeichen
            if ($feldinhalt =~ /\D/) {#Unerlaubte Zeichen in Feld ()
                push @fehlermeldungen, "$zeilennummer '$zeile': $feldname ('$feldinhalt') enthält ungueltige Zeichen.\n";}
            if (length($feldinhalt) != 16 && $feldinhalt !~ /\D/){ #Längenberechnung von Nr; Nr mit falschen Zeichen wird nicht als Fehler ausgegeben
                push @fehlermeldungen, "$zeilennummer '$zeile': $feldname ('$feldinhalt') hat die falsche Länge. $feldname muss immer sechzehnstellig sein. \n";
                }
        }
          
        my $bytecount_errechnet = length($feldinhalt)+9; # Berechne Bytecount gemäß KBV-Formel
        if ($bytecount_errechnet != $bytecount && $bytecount !~ /\D/){ #Keine Berechnung, wenn Falsche Zeichen in Bytelänge vorhanden
            push @fehlermeldungen, "$zeilennummer '$zeile': Falsche Bytelänge ('$bytecount') angegeben (Errechnet: $bytecount_errechnet - Sonderzeichen können zu Problemen bei Berechnung fuehren.) \n";  
        }
    } #Hier endet der Check fuer "einfache" Fehler
    
    my $abrechnungstyp = "";
    my $gebuehrenordnung = "";

    for my $z (@zeilen){ #Wir holen uns Abrechnungstyp und Gebuehrenordnung der Datei
       if (substr($z, 3, 4) == 8609){
            $abrechnungstyp = substr($z,7);
            }
        if (substr($z, 3, 4) == 8403){
            $gebuehrenordnung = substr($z,7);
            }
        }
    #print "GEBO: $gebuehrenordnung!\n";
    #print "ABR: $abrechnungstyp!\n";
    if ($abrechnungstyp eq 'X') { # Regel 399: Falls 8609 = X, dann muessen 8601, 8602, 8606, 8607 vorhanden sein
        @ListeBedingungen = ('8601', '8602', '8606', '8607');
    }
    if ($abrechnungstyp eq 'E' || $abrechnungstyp eq 'P') {# Standardfall: abrechnungstyp E oder P
        @ListeBedingungen = ('8601', '8602', '8606', '8607', '8610');
    }  
    if ($abrechnungstyp eq 'K') { # Sonderfall: abrechnungstyp K
        @ListeBedingungen = ('8403');
    } 
    foreach my $zeile (@zeilen){push @feldkennungen_vorhanden, substr($zeile, 3, 4);} #Lege Liste aller Feldkennungen in Datei an

    #### Hier kommt der Big Boy Check ####
    
    my @abrechnungstypen = qw(K E P X Q); #valide Abrechungstypen
    my @Gebuehrenordnungen = qw(1 2 3 4); #valide Gebuehrenordnungen
    $zeilennummer = 0; #Reset der Zeilennummer fuer Fehlermeldungen
    my @fehlende_fk; #Initiiere Liste an Feldkennungen, die bei bestimmten abrechnungstypen gefordert sind
    
    foreach my $zeile (@zeilen){
        $zeile =~ s/^\s+|\s+$//g; #Entferne Whitespace vor und nach Zeileninhalt
        $zeilennummer +=1;
        my $bytecount = substr($zeile, 0,3);
        my $feldkennung = substr($zeile, 3, 4);
        my $feldinhalt = substr($zeile, 7);
        my $feldname = $ldt_tabelle_geladen->{int($feldkennung)} || "------- Feldkennung unbekannt -------";

        if ($feldkennung == 8000 && $feldinhalt == 8219 && $abrechnungstyp eq "K"){ #Regel 433: Bei Satzart 8219 (Auftrag) ist abrechnungstyp K verboten
            push @fehlermeldungen, "$zeilennummer '$zeile': Bei Satzart 8219 ist der Abrechnungstyp K nicht zulässig.\n"}        
        if($feldkennung == 8609){ #opt_Checks in Zusammenhang mit Feld 8609 (abrechnungstyp)
            
            if (!$abrechnungstyp){ #Kein AT in Feld
                push @fehlermeldungen, "$zeilennummer '$zeile': In Feld 8609 ist ein kein Abrechnungstyp hinterlegt.\n"}        
            elsif (!grep {$_ eq $abrechnungstyp} @abrechnungstypen){ #AT nicht in liste valider ATs vorhanden
                push @fehlermeldungen, "$zeilennummer '$zeile': In Feld 8609 ist ein ungueltiger Abrechnungstyp ('$abrechnungstyp') hinterlegt.\n";
                }
            foreach my $fk (@ListeBedingungen){ #Iteriere durch liste an Feldkennungen, die der abrechnungstyp der Datei gemaess Regeltabelle fordert
                if(not grep {$_ eq $fk}@feldkennungen_vorhanden){ #Falls Bedingung nicht in Liste vorhandener FKs, wird entsprechende Bedingung in neuer Liste hinterlegt
                push @fehlende_fk, $fk; 
                        }
                }
            foreach my $e (@fehlende_fk){ #Iterierte durch Liste von fehlenden Feldkennungen fur AT
                my $feldname = $ldt_tabelle_geladen->{int($e)}; #lade feldname
                push @fehlermeldungen, "$zeilennummer '$zeile': Fuer Abrechnungstyp '$abrechnungstyp' fehlt Feld $e: $feldname.\n";
            }
        }
        if($feldkennung == 8403){ #opt_Checks in Zusammenhang mit Feld 8403 (Gebuehrenordnung)
                unless(grep {$_ eq $gebuehrenordnung} @Gebuehrenordnungen){ #opt_check, ob gebuehrenordnung valide ist (1-4)
                    if(!$gebuehrenordnung){
                        push @fehlermeldungen, "$zeilennummer '$zeile': In Feld 8403 ist keine Gebuehrenordnung hinterlegt.\n"}
                    else{
                        push @fehlermeldungen, "$zeilennummer '$zeile': In Feld 8403 ist eine ungueltige Gebuehrenordnung ('$gebuehrenordnung') hinterlegt.\n";}   

                if($abrechnungstyp eq "K"){
                    unless ($gebuehrenordnung == 1 || $gebuehrenordnung == 2 ||$gebuehrenordnung == 3){
                    push @fehlermeldungen, "$zeilennummer '$zeile': Bei Abrechnungstyp '$abrechnungstyp' ist die Gebuehrenordnung '$gebuehrenordnung' nicht zulaessig (erlaubte GOs: 1 / 2 / 3).\n";
                        }
                    }   
                if($abrechnungstyp eq "X"){
                    unless ($gebuehrenordnung == 4){
                    push @fehlermeldungen, "$zeilennummer '$zeile': Bei Abrechnungstyp '$abrechnungstyp' ist die Gebuehrenordnung '$gebuehrenordnung' nicht zulaessig (erlaubte GO: 4).\n";

                    }
                } 
            }
        } 
    } #ende des checks inhaltlicher bedingungen

####### Handling Fehlermeldungen #######
    foreach my $fehlermeldung (sort {$a <=> $b} @fehlermeldungen){#Ausgabe gesammelter Fehlermeldungen
        print "Zeile $fehlermeldung"}
    my $fehlermenge = scalar @fehlermeldungen;    
    print "\n$fehlermenge Fehler in $input_datei gefunden.";
    }#ende loop check
    undef @fehlermeldungen;  #Liste Bedingungen fuer naechste Datei leeren
    undef @ListeBedingungen; #Liste der Fehlermeldungen fuer nächste Datei leeren
    undef @feldkennungen_vorhanden; #Liste der feldkennungen in Datei leeren
}#ende loop batch

print"\n\n+--+--+--+--+--+--+--+--+--+--+--+--+---+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+\n"