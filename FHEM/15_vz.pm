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
	my $name = $hash->{NAME}
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
	# read from serial device
	my $buf = DevIo_SimpleRead($hash);
	my $data = $buf; ## kompatibilität bewahren
	if(!defined($buf) || $buf eq ""){
	# wird beim versuch, Daten zu lesen, eine geschlossene Verbindung erkannt, wird *undef* zurückgegeben. Es erfolgt ein neuer Verbindungsversuch?
	Log3($name,2,"vz SimpleRead fehlgeschlagen, was soll ich jetzt tun? _Line: " . __LINE__);
	return;
	}

	############################ neues vorgehen
	my $buffer = $hash->{helper}{PARTIAL};
	Log3($name,4,"$name - received $data (buffer contains: $buffer) _Line: " . __LINE__);
	# concat received data to $buffer
	$buffer .= $data;

	# as long as the buffer contains newlines (complete datagramm)
	while($buffer =~ m/1b1b1b1b1a/)
	{
	  my $msg;
    
	  Log3($name,5,"$name - buffer contains: $buffer Line: " . __LINE__);
	  Log3($name,5,"$name - msg contains: $msg) Line: " . __LINE__);
	  # extract the complete message ($msg), everything else is assigned to $buffer
	  ($msg, $buffer) = split("1b1b1b1b1a", $buffer, 2);
    
	  Log3($name,5,"$name - after split, buffer now contains: $buffer _Line: " . __LINE__);
	  Log3($name,5,"$name - after split, msg now contains: $msg) _Line: " . __LINE__);

	  # remove trailing whitespaces
	  chomp $msg;
    
	  Log3($name,5,"$name - after chomp (maybe obsolete), msg now contains: $msg) _Line: " . __LINE__);

	# did we really get a full frame?
	if ($msg =~ "(1b1b1b1b01010101(.*)1b1b1b1b1a)" && length($msg gt 572)) 
	{
		my $fullframe= $1;
		Log3($name,4,"Full Frame content: $fullframe _Line: " . __LINE__);
		my $temp   = substr($fullframe,308,8);
		Log3($name,4,"$name - total_energy: $temp ) _Line: " . __LINE__);
  	}

	Log3($name,4,"save buffer to PARTIAL _Line: " . __LINE__);
	  # update $hash->{PARTIAL} with the current buffer content
	  $hash->{helper}{PARTIAL} = $buffer; 	
	}

	######################################################
	# convert to hex string to make parsing with regex easier
	#$hash->{buffer} .= $buf;	
	$hash->{buffer} .= unpack ('H*', $buf);	
	Log3($name,5,"Current buffer content: $hash->{buffer} Line: " . __LINE__);
	

	# did we already get a full frame?
	if ($hash->{buffer} =~ "(1b1b1b1b01010101(.*)1b1b1b1b1a)") 
	{
	my $fullframe= $1;
	Log3($name,4,"Full Frame content: $fullframe _Line: " . __LINE__);
	#$hash->{total_energy_pos} = index($hash->{buffer},"070100010800ff");
	$hash->{helper}{total_energy}   = substr($fullframe,308,8);
	Log3($name,4,"total_energy: $hash->{helper}{total_energy} _Line: " . __LINE__);
	$hash->{helper}{total_energy_1} = substr($fullframe,356,8);
	$hash->{helper}{total_energy_2} = substr($fullframe,404,8);
	$hash->{helper}{total_power}    = substr($fullframe,448,4);
	$hash->{helper}{total_power_L1} = substr($fullframe,488,4);
	Log3($name,4,"total Power L1 $hash->{helper}{total_power_L1} _Line: " . __LINE__);
	$hash->{helper}{total_power_L2} = substr($fullframe,528,4);
	Log3($name,4,"total Power L2 $hash->{helper}{total_power_L2} _Line: " . __LINE__);
	$hash->{helper}{total_power_L3} = substr($fullframe,568,4);
	Log3($name,4,"total Power L3 $hash->{helper}{total_power_L3} _Line: " . __LINE__);

	my %readings; 
	
	readingsBeginUpdate($hash);
 	#readingsBulkUpdate($hash, "state", $val);

    	$readings{total_energy}    = hex($hash->{helper}{total_energy})/10000;
    	$readings{total_energy_1}  = hex($hash->{helper}{total_energy_1})/10000;
    	$readings{total_energy_2}  = hex($hash->{helper}{total_energy_2})/10000;

	if(hex($hash->{helper}{total_power}) < 32767){
		$readings{total_power}     = hex($hash->{helper}{total_power});
	} else{ 
		$readings{total_power}     = hex($hash->{helper}{total_power})-65534;
	}

	if( hex($hash->{helper}{total_power_L1}) < 32767){
	    	$readings{total_power_L1}  = hex($hash->{helper}{total_power_L1});
	} else { 
	    	$readings{total_power_L1}  = hex($hash->{helper}{total_power_L1})-65534;
	}

	if( hex($hash->{helper}{total_power_L2}) < 32767){
	    	$readings{total_power_L2}  = hex($hash->{helper}{total_power_L2});
	} else { 
	    	$readings{total_power_L2}  = hex($hash->{helper}{total_power_L2})-65534;
	}
	
	if( hex($hash->{helper}{total_power_L3}) < 32767){
		$readings{total_power_L3}  = hex($hash->{helper}{total_power_L3});
	} else {
		$readings{total_power_L3}  = hex($hash->{helper}{total_power_L3})-65534;
	}	

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
