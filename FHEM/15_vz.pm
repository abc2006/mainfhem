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
  Log3($name, 1, "vz DevIO_OpenDev_Define $ret"); 
  return $ret;
}


sub
vz_DoInit($)
{
 Log3 undef, 2, "DoInitfkt";
}
###########################################
#_ready-function for reconnecting the Device
# function is called, when connection is down.
sub
vz_Ready($)
{
	my ($hash) = @_;
  my $ret = DevIo_OpenDev($hash, 1, "vz_DoInit" );
  Log3($hash->{name}, 1, "vz DevIO_OpenDev_Ready $ret"); 
  return $ret;


}



#####################################
sub
vz_Undef($$)
{
  my ($hash, $name) = @_;
  DevIo_CloseDev($hash);         
  RemoveInternalTimer($hash);
  return undef;
}

#####################################
sub vz_read($$)
{

	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	# read from serial device
	my $buf = DevIo_SimpleRead($hash);
	my $data = $buf; ## kompatibilität bewahren
	if(!defined($buf) || $buf eq ""){
	# wird beim versuch, Daten zu lesen, eine geschlossene Verbindung erkannt, wird *undef* zurückgegeben. Es erfolgt ein neuer Verbindungsversuch?
	Log3($name,1, "vz SimpleRead fehlgeschlagen, was soll ich jetzt tun?");

	return "";
	}

	############################ neues vorgehen
	my $buffer = $hash->{helper}{PARTIAL};
	Log3 $name, 5, "$name - received $data (buffer contains: $buffer)";
	# concat received data to $buffer
	$buffer .= $data;

	# as long as the buffer contains newlines (complete datagramm)
	while($buffer =~ m/1b1b1b1b1a/)
	{
	  my $msg;
    
	  Log3 $name, 5, "$name - buffer contains: $buffer";
	  Log3 $name, 5, "$name - msg contains: $msg)";
	  # extract the complete message ($msg), everything else is assigned to $buffer
	  ($msg, $buffer) = split("1b1b1b1b1a", $buffer, 2);
    
	  Log3 $name, 5, "$name - after split, buffer now contains: $buffer";
	  Log3 $name, 5, "$name - after split, msg now contains: $msg)";

	  # remove trailing whitespaces
	  chomp $msg;
    
	  Log3 $name, 5, "$name - after chomp (maybe obsolete), msg now contains: $msg)";

	# did we really get a full frame?
	if ($msg =~ "(1b1b1b1b01010101(.*)1b1b1b1b1a)" && length($msg gt 572)) 
	{
	my $fullframe= $1;
	Log3($name, 5, "Full Frame content: " . $fullframe);
	#$hash->{total_energy_pos} = index($hash->{buffer},"070100010800ff");
#	$hash->{total_energy}   = substr($fullframe,308,8);
	my $temp   = substr($fullframe,308,8);
	Log3 $name, 5, "$name - total_energy: $temp )";
#	$hash->{total_energy_1} = substr($fullframe,356,8);
#	$hash->{total_energy_2} = substr($fullframe,404,8);
#	$hash->{total_power}    = substr($fullframe,448,4);
#	$hash->{total_power_L1} = substr($fullframe,488,4);
#	$hash->{total_power_L2} = substr($fullframe,528,4);
#	$hash->{total_power_L3} = substr($fullframe,568,4);

	  # parse the extracted message
	  #MY_MODULE_ParseMessage($hash, $msg);
  	}

	Log3($name, 5, "save buffer to PARTIAL");
	  # update $hash->{PARTIAL} with the current buffer content
	  $hash->{helper}{PARTIAL} = $buffer; 	
	}

	######################################################





	# convert to hex string to make parsing with regex easier
	#$hash->{buffer} .= $buf;	
	$hash->{buffer} .= unpack ('H*', $buf);	
	Log3($name, 5, "Current buffer content: " . $hash->{buffer});
	

	# did we already get a full frame?
	if ($hash->{buffer} =~ "(1b1b1b1b01010101(.*)1b1b1b1b1a)") 
	{
	my $fullframe= $1;
	Log3($name, 5, "Full Frame content: " . $fullframe);
	#$hash->{total_energy_pos} = index($hash->{buffer},"070100010800ff");
	$hash->{helper}{total_energy}   = substr($fullframe,308,8);
	Log3($name, 5, "total_energy: " . $hash->{helper}{total_energy});
	$hash->{helper}{total_energy_1} = substr($fullframe,356,8);
	$hash->{helper}{total_energy_2} = substr($fullframe,404,8);
	$hash->{helper}{total_power}    = substr($fullframe,448,4);
	$hash->{helper}{total_power_L1} = substr($fullframe,488,4);
	Log3($name, 5, "total Power L1 " . $hash->{helper}{total_power_L1});
	$hash->{helper}{total_power_L2} = substr($fullframe,528,4);
	Log3($name, 5, "total Power L2 " . $hash->{helper}{total_power_L2});
	$hash->{helper}{total_power_L3} = substr($fullframe,568,4);
	Log3($name, 5, "total Power L3 " . $hash->{helper}{total_power_L3});

	my %readings; 
	
	readingsBeginUpdate($hash);
 	#readingsBulkUpdate($hash, "state", $val);

    	$readings{total_energy}    = hex($hash->{helper}{total_energy})/10000;
    	$readings{total_energy_1}  = hex($hash->{helper}{total_energy_1})/10000;
    	$readings{total_energy_2}  = hex($hash->{helper}{total_energy_2})/10000;
    	$readings{total_power}     = hex($hash->{helper}{total_power});
    	$readings{total_power_L1}  = hex($hash->{helper}{total_power_L1});
    	$readings{total_power_L2}  = hex($hash->{helper}{total_power_L2});
    	$readings{total_power_L3}  = hex($hash->{helper}{total_power_L3});
##	my $old_tot_ene = ReadingsVal("Stromzaehler","total_energy",0);
##	my $old_tot_ene_1 = ReadingsVal("Stromzaehler","total_energy_1",0);
##	my $old_tot_ene_2 = ReadingsVal("Stromzaehler","total_energy_2",0);
##
##	if($readings{total_energy} < $old_tot_ene){
##		$readings{total_energy} = $old_tot_ene;
##	}
##	if($readings{total_energy_1} < $old_tot_ene_1){
##		$readings{total_energy_1} = $old_tot_ene_1;
##	}
##	if($readings{total_energy_2} < $old_tot_ene_2){
##		$readings{total_energy_2} = $old_tot_ene_2;
##	}




#	if($old_tot_ene = 0)
#	{
#	 $readings{ERR_tot_ene} =  "Fehler ReadingsVal";
#	}
#	elsif(abs($old_tot_ene - $readings{total_energy}) > 2 &&)
#	{
#         $readings{total_energy} = $old_tot_ene;
#	 $readings{ERR_tot_ene} =  "Fehler Difference";
#	}
#	else {
#	 $readings{ERR_tot_ene} = "Fehlerfrei";
#	}
#
#	if($old_tot_ene = 0)
#	{
#	 $readings{ERR_tot_ene_1} =  "Fehler ReadingsVal";
# 	}
#	elsif(abs($old_tot_ene_1 - $readings{total_energy_1}) > 2)
#	{
#         $readings{total_energy_1} = $old_tot_ene_1;
#	 $readings{ERR_tot_ene_1} = "Fehler Difference";
#	}	
#	else {
#	 $readings{ERR_tot_ene_1} = "Fehlerfrei";
#	}
#
#	if($old_tot_ene = 0)
#	{
#	 $readings{ERR_tot_ene_2} = "Fehler ReadingsVal";
#	}
#	elsif(abs($old_tot_ene_2 - $readings{total_energy_2}) > 2)
#	{
#         $readings{total_energy_2} = $old_tot_ene_2;
#	 $readings{ERR_tot_ene_2} = "Fehler Difference";
#	}	
#	else {
#	 $readings{ERR_tot_ene_2} = "Fehlerfrei";
#	}
#
#	$readings{nAME} = $name;
##	$readings{dEVICE} = $device;
#	$readings{hASH} = $hash;

	    foreach my $k (keys %readings) {
      readingsBulkUpdate($hash, $k, $readings{$k});
    }
    	readingsEndUpdate($hash, 1);
	undef $hash->{buffer};
	undef $hash->{pack};

    return $hash->{NAME};


	}
}




1;


=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
