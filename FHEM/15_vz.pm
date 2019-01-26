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
	Log3 $hash, 2, $msg;
	return $msg;
}	
	my $name = $a[0];
	my $device = $a[2];

  $hash->{name} = $name;
  $hash->{DeviceName} = $device;


  my $ret = DevIo_OpenDev($hash, 0, "vz_DoInit" );
  return $ret;
}


sub
vz_DoInit($)
{
 Log3 undef, 2, "DoInitfkt";
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
	return "" if ( !defined($buf) );

	# convert to hex string to make parsing with regex easier
	#$hash->{buffer} .= $buf;	
	$hash->{buffer} .= unpack ('H*', $buf);	
	#Log3 $name, 5, "Current buffer content: " . $hash->{buffer};
	

	# did we already get a full frame?
	if ($hash->{buffer} =~ "(1b1b1b1b01010101(.*)1b1b1b1b1a)") 
	{
	#my $pos[1] = 
	$hash->{pack} = $1;
	
	#$hash->{total_energy_pos} = index($hash->{buffer},"070100010800ff");
	$hash->{total_energy}   = substr($hash->{pack},308,8);
	$hash->{total_energy_1} = substr($hash->{pack},356,8);
	$hash->{total_energy_2} = substr($hash->{pack},404,8);
	$hash->{total_power}    = substr($hash->{pack},448,4);
	$hash->{total_power_L1} = substr($hash->{pack},488,4);
	$hash->{total_power_L2} = substr($hash->{pack},528,4);
	$hash->{total_power_L3} = substr($hash->{pack},568,4);

	my %readings; 
	
    		readingsBeginUpdate($hash);
	 	#readingsBulkUpdate($hash, "state", $val);

    	$readings{total_energy}    = hex($hash->{total_energy})/10000;
    	$readings{total_energy_1}  = hex($hash->{total_energy_1})/10000;
    	$readings{total_energy_2}  = hex($hash->{total_energy_2})/10000;
    	$readings{total_power}     = hex($hash->{total_power});
    	$readings{total_power_L1}  = hex($hash->{total_power_L1});
    	$readings{total_power_L2}  = hex($hash->{total_power_L2});
    	$readings{total_power_L3}  = hex($hash->{total_power_L3});
	
	my $old_tot_ene = ReadingsVal("Stromzaehler","total_energy",0);
	my $old_tot_ene_1 = ReadingsVal("Stromzaehler","total_energy_1",0);
	my $old_tot_ene_2 = ReadingsVal("Stromzaehler","total_energy_2",0);

	if($readings{total_energy} < $old_tot_ene){
		$readings{total_energy} = $old_tot_ene;
	}
	if($readings{total_energy_1} < $old_tot_ene_1){
		$readings{total_energy_1} = $old_tot_ene_1;
	}
	if($readings{total_energy_2} < $old_tot_ene_2){
		$readings{total_energy_2} = $old_tot_ene_2;
	}




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