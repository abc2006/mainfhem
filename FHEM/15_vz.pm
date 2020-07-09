##############################################
# $Id: 15_vz.pm 2016-01-14 09:25:24Z stephanaugustin $
package main;

use strict;
use warnings;

#####################################
sub
vz_Initialize($)
{
  my ($hash) = @_;
  require "$attr{global}{modpath}/FHEM/DevIo.pm";

  $hash->{DefFn}     = "vz_Define";
  $hash->{UndefFn}   = "vz_Undef";
  $hash->{SetFn}     = "vz_Set";
  $hash->{ReadFn}    = "vz_read";
  $hash->{ReadyFn}   = "vz_Ready";
  $hash->{AttrList}  = "Anschluss ".
                        $readingFnAttributes;

}

#####################################
sub
vz_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
	
if(@a < 3 || @a > 5){
	my $msg = "wrong syntax: define <name> vz <device>";
	return $msg;
}	
	my $name = $a[0];
	my $device = $a[2];
 
  $hash->{name} = $name;
  ## $hash->DeviceName keeps the name of the io-Device. Without this, DevIO does not work.
  $hash->{DeviceName} = $device;
	

  my $ret = DevIo_OpenDev($hash, 0, "vz_DoInit" );
  Log3($name, 1, "vz DevIO_OpenDev_Define $ret Line: " . __LINE__); 
  return $ret;
}


sub vz_DoInit($) {
 Log3(undef, 2, "DoInitfkt Line: " . __LINE__);
}
###########################################
#_ready-function for reconnecting the Device
# function is called, when connection is down.
sub vz_Ready($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
  my $ret = DevIo_OpenDev($hash, 1, "vz_DoInit" );
  Log3($name, 5, "vz DevIO_OpenDev_Ready $ret Line: " . __LINE__); 
  return $ret;
}
#####################################
sub vz_Undef($$) {
  my ($hash, $name) = @_;
  DevIo_CloseDev($hash);         
##  RemoveInternalTimer($hash);
  return undef;
}
####################################
sub vz_Set($@){
 my ($hash, @a) = @_;
 my $name = $hash->{NAME};
 my $usage = "Unknown argument $a[1], choose one of reopen:noArg ";
 my $ret;
	Log3($name,3, "vz argument $a[1] _Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "vz argument fragezeichen" . __LINE__);
	return $usage;
	}

	if($a[1] eq "reopen"){
		if(DevIo_IsOpen($hash)){
			Log3($name,1, "vz Device is open, closing ... Line: " . __LINE__);
			DevIo_CloseDev($hash);
			Log3($name,1, "vz Device closed Line: " . __LINE__);
		} 
		Log3($name,3, "vz_Set  Device is closed, trying to open Line: " . __LINE__);
		$ret = DevIo_OpenDev($hash, 1, "vz_DoInit" );
		while(!DevIo_IsOpen($hash)){
			Log3($name,1, "vz_Set  Device is closed, opening failed, retrying" . __LINE__);
			$ret = DevIo_OpenDev($hash, 1, "vz_DoInit" );
			#sleep 1;
		}
		##return "device opened";
	} 
}
#####################################
sub vz_read($$) {

	my ($hash) = @_;
	my $name = $hash->{NAME};
	Log3($name,4,"vz read _Line: " . __LINE__);
	$hash->{CONNECTION} = "reading";
	# read from serial device
	my $readbuf = DevIo_SimpleRead($hash);
        my $buf = unpack ('H*', $readbuf);	
	Log3($name,5, "vz buffer: $buf Line: " . __LINE__);
	
	if(!defined($buf) || $buf eq ""){
	# wird beim versuch, Daten zu lesen, eine geschlossene Verbindung erkannt, wird *undef* zurückgegeben. Es erfolgt ein neuer Verbindungsversuch?
	$hash->{CONNECTION} = "failed";
	Log3($name,2,"vz SimpleRead fehlgeschlagen, was soll ich jetzt tun? _Line: " . __LINE__);
	return "error";
	}

	############################ neues vorgehen
	# gelesene Daten an den Speicher anhängen
	$hash->{helper}{BUFFER} .= $buf;
        Log3($name,5, "vz buffer: $hash->{helper}{BUFFER} _Line: ". __LINE__);

	# extract a full frame?
	if ($hash->{helper}{BUFFER} =~ s/^.*(1b1b1b1b01010101(.*)1b1b1b1b1a)// )## && length($hash->{helper}{BUFFER} gt 572)) 
	{
		Log3($name,4,"vz Full Frame content: $1 _Line: " . __LINE__);
  		$hash->{helper}{fullframe_hex} = $1; 	
		vz_analyzeAnswer($hash);
	}
    	return;


}

sub vz_analyzeAnswer{

#	##Analyze des Antwortstringes: ohne header 
#Header byte 1-8
#1b 1b 1b 1b 01 01 01 01
#
#Byte 9-25
#760512d4996b6200620072630101760101
#Byte 26-50
#050646ddcd0b090149534b0003d1ebf9010163539a00760512
#Byte 51-75
#d4996c620062007263070177010b090149534b0003d1ebf907
#Byte 76-98
#0100620affff7262016509ad243d7a77078181c78203ff
############################
#Byte 99-102
#01 01 01 01 
#Byte 103-106
#04 49 53 4b 
#Byte 107-109 das hier ist irgendwie prüfsumme oder Abschluss
#01 77 07
#################################
#Byte 110-115 OBIS-Kennzahl 0.0.9  Geräteeinzelidentifikation
#01 00 00 00 09 ff 
#Byte 116-125
#01 01 01 01 0b 09 01 49 53 4b 
#Byte 126-130 das hier ist die Geräteidentifikationsnummer
#00 03 d1 eb f9 
#Byte 131-133 das hier ist irgendwie prüfsumme oder Abschluss
#01 77 07
#########################
#
#Byte 134-139 OBIS-Kennzahl 1.8.0
#01 00 01 08 00 ff
#Byte 140-150
#65 00 00 01 80 01 62 1e 52 ff 59
#Byte 151-175
#00 00 00 00
#Byte 154-158 Zählerstand 1.8.0 (19620,9235kWh)
#0b b1 ea 53 
#Byte 159-161
#01 77 07 
#
##############################
#Byte 162-167 OBIS-Kennzahl 1.8.1 
#01 00 01 08 01 ff 
#Byte 168-175
#01 01 62 1e 52 ff 59 00
#Byte 176-178
#00 00 00
#Byte 179-182 Zählerstand 1.8.1 (19618,9105kWh)
#0b b1 9b b1 
#Byte 183-185
#01 77 07
##############################
#Byte 186-191 OBIS-Kennzahl 1.8.2
#01 00 01 08 02 ff
#Byte 190-201
#01 01 62 1e 52 ff 59 00 00 00 00
#Byte 202-206 Zählerstand 1.8.2 (2,0130kWh)
#00 00 4e a2
#Byte 207-209
#01 77 07
############################
#Byte 210-215 OBIS-Kennzahl 16.7.0 Leistung momentan
#01 00 10 07 00 ff 
#Byte 216-226
#01 01 62 1b 52 00 55 00 00 00 12
#Byte 227-229
#01 77 07
#################################
#Byte 230-235 OBIS-Kennzahl 36.7.0 Leistung momentan L1
#01 00 24 07 00 ff 
#Byte 236-242
#01 01 62 1b 52 00 55
#Byte 243-246
#ff ff ff fe
#Byte 247-249
#01 77 07
##################################
#Byte 250-255 OBIS-Kennzahl 56.7.0 Leistung momentan L2
#01 00 38 07 00 ff 
#Byte 256-262
#01 01 62 1b 52 00 55 
#Byte 263-266
#00 00 00 06
#Byte 267-269
#01 77 07
#################################
#Byte 270-75 OBIS-Kennzahl 76.7.0 Leistung momentan L3
#01 00 4c 07 00 ff
#Byte 276-282
#01 01 62 1b 52 00 55
#Byte 283-286
#00 00 00 0d 
#Byte 287-289
#01 77 07 
##################################
#Byte 290-295 OBIS-Kennzahl 129-129:199.130.5 PublicKey
#81 81 c7 82 05 ff 
#Byte 296-300
#01 01 01 01 83 
#Byte 301-325
#02cca882937d9d97ec5c735888960ac69e218782d16e2a8f05
#Byte 326-350
#4e66fe6e85780ce9e54e03ec5b5240c8f58e5663b8c1e9d201
#Byte 351-375
#010163a64300760512d4996d6200620072630201710163cf76
#Byte 401-406  End of Transmit
#00 1b 1b 1b 1b 1a




	my ($hash) = @_;
	my $name = $hash->{NAME};
	Log3($name,4,"vz analyzeAnswer _Line: " . __LINE__);
	
  	$hash->{helper}{fullframe_ascii} = pack ('H*', $hash->{helper}{fullframe_hex});	
	Log3($name,5,"vz Current hex frame: $hash->{helper}{fullframe_hex} Line: " . __LINE__);
	Log3($name,5,"vz Current ascii frame: $hash->{helper}{fullframe_ascii} Line: " . __LINE__);
	my $fullframe= $hash->{helper}{fullframe_hex}; 	
	my %readings; 
	
	$readings{total_energy}   = hex(substr($fullframe,308,8))/10000;
	Log3($name,4,"vz total_energy: $readings{total_energy} _Line: " . __LINE__);
	$readings{total_energy_1} = hex(substr($fullframe,356,8))/10000;
	$readings{total_energy_2} = hex(substr($fullframe,404,8))/10000;
	$readings{total_power}    = hex(substr($fullframe,448,4));
	$readings{total_power_L1} = hex(substr($fullframe,488,4));
	Log3($name,4,"vz total Power L1 $readings{total_power_L1} _Line: " . __LINE__);
	$readings{total_power_L2} = hex(substr($fullframe,528,4));
	Log3($name,4,"vz total Power L2 $readings{total_power_L2} _Line: " . __LINE__);
	$readings{total_power_L3} = hex(substr($fullframe,568,4));
	Log3($name,4,"vz total Power L3 $readings{total_power_L3} _Line: " . __LINE__);
	

	if($readings{total_power} > 32767){
		$readings{total_power}     = $readings{total_power}-65534;
	}
	if($readings{total_power_L1} > 32767){
		$readings{total_power_L1}     = $readings{total_power_L1}-65534;
	}
	if($readings{total_power_L2} > 32767){
		$readings{total_power_L2}     = $readings{total_power_L2}-65534;
	}
	if($readings{total_power_L3} > 32767){
		$readings{total_power_L3}     = $readings{total_power_L3}-65534;
	}

	readingsBeginUpdate($hash);
	foreach my $k (keys %readings) {
      		readingsBulkUpdate($hash, $k, $readings{$k});
    	}
    	readingsEndUpdate($hash, 1);
}




1;


=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
