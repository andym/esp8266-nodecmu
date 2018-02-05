use strict;
use warnings;

use feature ":5.10";

use Net::TFTP;
use File::Find::Rule;
use File::Basename;

# mqtt request for ip addresses
#my @hosts = ("192.168.1.214","192.168.1.186","192.168.1.223");
my @hosts = ("192.168.1.186");
# glob for homedir expansion
my $source_dir = glob('~/projects/esp8266-nodecmu/lua_install/');

foreach my $host_addr (@hosts) {
	my $tftp = Net::TFTP->new($host_addr);
	my $err = $tftp->error;
	die "$err" if $err;
	say "Connected to host : $host_addr";

	$tftp->binary;

	my @files = File::Find::Rule->file()
                                ->name( '*.lua' )
                                ->in( $source_dir );

    foreach my $path (@files) {
    	say "Uploading : $path";
    	my $filename  = fileparse($path, ('lua'));
    	$tftp->put($path, $filename.'lua');
		$err = $tftp->error;
		die "$err" if $err;
	}
	# mqtt restart host
}

