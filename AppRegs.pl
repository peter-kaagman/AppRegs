#! /usr/bin/perl

use feature ":5.11";
use strict;
use LWP;
use HTTP::Request;
use Data::Dumper;
use JSON;
use DateTime;
use Template;
#use MIME::Lite;
use Data::GUID;
use FindBin;
use Config::Simple;
use lib "$FindBin::Bin/../msgraph-perl/lib";

use MsAzure;
#use MsSpoList;
# use MsGroup;
# use MsGroups;

my %config;
Config::Simple->import_from("$FindBin::Bin/config/AppRegs.cfg", \%config) or die("No config: $!");


my $azure_object = MsAzure->new(
	'app_id'        => $config{'APP_ID'},
	'app_secret'    => $config{'APP_PASS'},
	'tenant_id'     => $config{'TENANT_ID'},
	'login_endpoint'=> $config{'LOGIN_ENDPOINT'},
	'graph_endpoint'=> $config{'GRAPH_ENDPOINT'},
  'select'        => '$select=appId,displayName,passwordCredentials,keyCredentials',
);

my $Now = DateTime->now;
my $Warning = 35;
my $Critical = 14;
my $All = 0;
if ($ARGV[0]){
  $All = 1;
}
my $Report;

sub getDiff{
  my $dateString = shift;
  $dateString =~ /^(\d{4})-(\d{2})-(\d{2}).*/g;
  my $Date =  DateTime->new(
    year => $1,
    month => $2,
    day => $3
    );

  #print "Now  =>" . $Now->epoch . "\t";
  #print "Date =>" . $Date->epoch . "\t";
  my $result = int( ($Date->epoch - $Now->epoch)/ (60*60*24) );
  #print "Diff => $result\n";
  return $result;
}

sub getStatus{
  my $Diff = shift;
  my $Status;
  if ($Diff < 1){
	$Status = 'Verlopen';
  }elsif($Diff < 15){
	$Status = 'Kritisch';
  }elsif($Diff < 36){
	$Status = 'Waarschuwing';
  }else{
	$Status = 'Normaal';
  }
  return $Status;
}


my $Apps = $azure_object->azure_get_apps;
#print Dumper $Apps;

# # Itterate the Apps in the result
foreach my $App  (@{$Apps}){

  # Check app passwords
  my $passwordCredentials = $App->{'passwordCredentials'};
  foreach my $Password (@{$passwordCredentials}){
    my $Diff = getDiff($Password->{'endDateTime'});
    if (($Diff < $Warning)|| $All){
      my $Status = getStatus($Diff);
      $Report->{ $App->{'displayName'} }{ $Password->{'displayName'} }{'displayNameKey'} = $Password->{'displayName'};
      $Report->{ $App->{'displayName'} }{ $Password->{'displayName'} }{'type'}           = 'Password';
      $Report->{ $App->{'displayName'} }{ $Password->{'displayName'} }{'endDateTime'}    = $Password->{'endDateTime'};
      $Report->{ $App->{'displayName'} }{ $Password->{'displayName'} }{'Diff'}           = $Diff;
      $Report->{ $App->{'displayName'} }{ $Password->{'displayName'} }{'Status'}         = $Status;
    }
  }
	
  # Check app keys
	my $keyCredentials = $App->{'keyCredentials'};
	foreach my $Key (@{$keyCredentials}){
		my $Diff = getDiff($$Key{'endDateTime'});
		if (($Diff < $Warning)|| $All){
			my $Status = getStatus($Diff);
			$Report->{ $App->{'displayName'} }{ $Key->{'keyId'} }{'displayName'}    = $Key->{'displayName'};
			$Report->{ $App->{'displayName'} }{ $Key->{'keyId'} }{'type'}           = 'Key';
			$Report->{ $App->{'displayName'} }{ $Key->{'keyId'} }{'endDateTime'}    = $Key->{'endDateTime'};
			$Report->{ $App->{'displayName'} }{ $Key->{'keyId'} }{'Diff'}           = $Diff;
			$Report->{ $App->{'displayName'} }{ $Key->{'keyId'} }{'Status'}         = $Status;
		}
	}
        
}


#
# Leuk, maar geen tijd voor, later mee verder
#
# # Kijken of we in plaats van een chat een ticket kunnen maken
# my $list_object =  MsSpoList->new(
#     'app_id'        => $config{'APP_ID'},
#     'app_secret'    => $config{'APP_PASS'},
#     'tenant_id'     => $config{'TENANT_ID'},
#     'login_endpoint'=> $config{'LOGIN_ENDPOINT'},
#     'graph_endpoint'=> $config{'GRAPH_ENDPOINT'},
#     'acces_token'   => $azure_object->_get_access_token,
#     'token_expires' => $azure_object->_get_token_expires,
#     'site_naam'     => $config{'SPO_SITE_NAAM'},
#     'list_naam'     => $config{'SPO_LIST_NAAM'},
# );

# say "Site id is ",$list_object->_get_site_id, " en lijst id is ",$list_object->_get_list_id;

# my $result = $team_object->team_send_channel_card(
#   $config{'team'},
#   $config{'channel'},
#   $card
# );

# Report results if found
if ($Report){
  #print Dumper(\%Report);
  my $tt = Template->new(
  	INCLUDE_PATH => "$FindBin::Bin/",
	INTERPOLATE => 1
  ) or die($!) ;
  my %data = (
  	all => $All,
	payload => $Report
  );
  my $mail_body;
  $tt->process('mail.tt', \%data, \$mail_body) or die $tt->error(), "\n";
  print  $mail_body;  
  my $msg = MIME::Lite->new(
    To     => "ict-service\@atlascollege.nl",
    From   => "smtp.kali\@atlascollege.nl",
    Subject=> "App registraties",
    Type   => "text/html",
    Data   => $mail_body
  );
  $msg->send();
}
