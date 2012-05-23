#!/usr/bin/perl

# Libraries
use DBI;
use DBD::SQLite;
use Getopt::Std;

# Parse Command Line Arguments
getopts ( "Cf:", \%opt ) || usage();

if($opt{'f'}){
	$yum_conf = $opt{'f'};
} else {
	# For the purposes of SOCK setting default to distributed.
	$yum_conf = "yum.d/sl62.mrepo";
}

# Regenerate yum cache if requested.
if($opt{'C'}){ clean_yum(); }

# Load our yum_conf repo names and baseurls.
open(REPOFILE, "<$yum_conf") || die("Couldn't open $yum_conf.\n");
while(<REPOFILE>){
	chop;
	if(m/\[([\w-]+)\]/){
		$mrepo=$1
	}
	if(m/baseurl=(.+)/){
		$repos{$mrepo} = $1;
	}
}
close(REPOFILE);


# Load hints file to map cache dirs to mrepo names
open(HINTS, "<etc/mrepogrep.hints"); # No need to die if no hints file.
while(<HINTS>){
	next if m/^#/;
	chop;
	($dir, $name) = split(/,/, $_);
	$hints{$dir} = $name;
}
close(HINTS);

# Main

# Look in all relevant directories under /var/cache/yum
opendir(my $dh, "/var/cache/yum") || die("Can't opendir /var/cache/yum\n");
while(my $f = readdir($dh)){
	next if($f =~ /^\./);  	# Ignore dot files.
	next if($f eq "base" | $f eq "extras"); # Ignore these dirs.

	# Annoyingly the sqlite files end up with unique names sometimes.
	# So, they have to be "found" by looking for a file that ends
	# in .sqlite.
	opendir(my $ydh, "/var/cache/yum/$f") || die("Can't opendir $f\n");
	($sql) = grep { m/\.sqlite$/ } readdir($ydh);
	closedir($ydh);

	# Check for all packages listed on command line.  getopt removes
	# option paramaters from @ARGV so only packages should remain.
	foreach $pkg (@ARGV){

		# Check to see if our $pkg is contained in the sqlite db.
		if(sqlgrep("/var/cache/yum/$f/$sql", "$pkg.rpm")){

			# Now that there is a match, attempt to list the
			# URL by adding the packagename to the baseurl
			# known to be associated with the repo.
			if($hints{$f}){
				$repo = $hints{$f};
			} else {
				$repo = $f;
			}

			# Put it all together.
			print "$repos{$repo}$pkg.rpm\n";
		}
	}
}
closedir($dh);


# Subroutines

# Usage Statement
sub usage {
	print "$0: [ -C ] -f yum_configuration pkg ... \n";
	print "\t-C Clean and regenerate yum cache.\n";
	print "\t-f Yum configuration file to parse.\n";
	exit(1);
}

sub sqlgrep {
	my $file = shift;
	my $pkg = shift;

	# Open database handle.
	my $dbh = DBI->connect("dbi:SQLite:dbname=$file");

	# Full package names are kept in the location_href field of the 
	# packages table.
	my $sth = $dbh->prepare("SELECT name from packages where location_href=\"$pkg\";");
	$sth->execute();

	# If found return true.
	if($sth->fetch()){
		return(1);
	}
}

sub clean_yum {
	print "Regenerating yum cache.\n";
	system("yum clean all");
	# Run a bogus name through list, so all repo caches are created.
	if($yum_conf){
		system("yum --config=$yum_conf list asdfasdf");
	}
}
