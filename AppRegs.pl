#! /usr/bin/perl

use strict;
use LWP;
use HTTP::Request;
use Data::Dumper;
use JSON;
use DateTime;
use Template;
use MIME::Lite;
use FindBin;

my $Now = DateTime->now;
my $Warning = 35;
my $Critical = 14;
my $All = 0;
if ($ARGV[0]){
  $All = 1;
}
my %Report;

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

my $data = "client_id=$app_id&scope=$scope&client_secret=$client_secret&grant_type=$grant_type" ;

my $req=HTTP::Request->new('POST', $url);
$req->header('Content-Type','application/x-www-form-urlencoded');
$req->content($data);

my $ua = LWP::UserAgent->new;
my $response = $ua->request($req);
#print Dumper($$response{'_content'});

my $credentials = decode_json($$response{'_content'});

#print Dumper($credentials);

#print $$credentials{'access_token'};

$ua->default_header(Authorization => $$credentials{'access_token'});
$response = $ua->get('https://graph.microsoft.com/v1.0/applications?$select=appId,displayName,passwordCredentials,keyCredentials&$top=999');
my $content = decode_json($$response{'_content'});
my @Apps = @{$$content{'value'}};

#print "Dumper:\n";
#print Dumper(\@Apps);
#print "End Dumper:\n";
#exit 1;

# Itterate the Apps in the result
foreach my $App  (@Apps){

	# Check app passwords
	my $passwordCredentials = $$App{'passwordCredentials'};
	foreach my $Password (@{$passwordCredentials}){
	  my $Diff = getDiff($$Password{'endDateTime'});
	  if (($Diff < $Warning)|| $All){
	    my $Status = getStatus($Diff);
	    $Report{ $$App{'displayName'} }{ $$Password{'displayName'} }{'displayNameKey'} = $$Password{'displayName'};
	    $Report{ $$App{'displayName'} }{ $$Password{'displayName'} }{'type'}           = 'Password';
	    $Report{ $$App{'displayName'} }{ $$Password{'displayName'} }{'endDateTime'}    = $$Password{'endDateTime'};
	    $Report{ $$App{'displayName'} }{ $$Password{'displayName'} }{'Diff'}           = $Diff;
	    $Report{ $$App{'displayName'} }{ $$Password{'displayName'} }{'Status'}         = $Status;
	  }
	}
	
# Check app keys
	my $keyCredentials = $$App{'keyCredentials'};
	foreach my $Key (@{$keyCredentials}){
		my $Diff = getDiff($$Key{'endDateTime'});
		if (($Diff < $Warning)|| $All){
			my $Status = getStatus($Diff);
			$Report{ $$App{'displayName'} }{ $$Key{'keyId'} }{'displayName'}    = $$Key{'displayName'};
			$Report{ $$App{'displayName'} }{ $$Key{'keyId'} }{'type'}           = 'Key';
			$Report{ $$App{'displayName'} }{ $$Key{'keyId'} }{'endDateTime'}    = $$Key{'endDateTime'};
			$Report{ $$App{'displayName'} }{ $$Key{'keyId'} }{'Diff'}           = $Diff;
			$Report{ $$App{'displayName'} }{ $$Key{'keyId'} }{'Status'}         = $Status;
		}
	}
        
}

# Report results if found
if (%Report){
  #print Dumper(\%Report);
  my $tt = Template->new(
  	INCLUDE_PATH => "$FindBin::Bin/",
	INTERPOLATE => 1
  ) or die($!) ;
  my %data = (
  	all => $All,
	payload => \%Report
  );
  my $mail_body;
  $tt->process('mail.tt', \%data, \$mail_body) or die $tt->error(), "\n";
  my $msg = MIME::Lite->new(
    To     => "ict-service\@atlascollege.nl",
    From   => "smtp.kali\@atlascollege.nl",
    Subject=> "App registraties",
    Type   => "text/html",
    Data   => $mail_body
  );
  $msg->send();
}
