#!/usr/bin/perl
# Attempts to identify RPMs installed in a SOCK that are not part of a
# TOENAIL File, for assistance building a new TOENAIL File after a yum
# rpm dependancy chain has been resolved into the SOCK.

# Libraries
use Getopt::Std;
use FileHandle; # Needed for local file handles

# Globals
%alreadyOpened = (); # Hash to keep from getting caught in cyclical 
		     # Include arguments.
%rpms = ();	     # List of RPMs declared in TOENAIL file, if declared

# Parse Command line arguments
getopt( "t:", \%opt ) || usage();

# If there's a TOENAIL file listed, get a list of the RPMs included.
if($opt{'t'}){
	loadNail($opt{'t'});
}

# Make sure there's a SOCK listed in @ARGV
unless($ARGV[0]){
	usage();
}

# Main
open(RPM, "rpm --root=$ARGV[0] -qa|") || die("Couldn't run rpm.\n");
while(<RPM>){
	next if m/gpg-pubkey/;
	next if m/sl-relase/; # Skipping this for now.
	chop;
	unless($rpms{"$_.rpm"}){
		print "$_\n";
	}
}
close(RPM);


# Subroutines
sub usage { 
	print "$0: [ -t TOENAIL ] SOCK_CHROOT_DIR\n";
}

sub loadNail {
	my $file = shift;

	# Avoid loading bases for now.
	if($file =~ m/-base/){
		return();
	}
	
	# Check for cyclical includes, and return if found.
	if($alreadyOpened{$file}) {
		return();
	} else {
	   # Mark it as opened.
	   $alreadyOpened{$file} = 1;
	}

	# Create local file handle to avoid trampling on the handle
	# during recusion.
	my $fh = FileHandle->new();

	open($fh, "$file") || die("Couldn't open $file\n");
	while(<$fh>){

		# Recursively load TOENAIL Files.
		if(m/^Include (.+)/){
			loadNail($1);
		}

		# Add RPMs listed to the %rpms array
		# The regex here assigns the RPM file name to $1
		if(m/^Rpm (.+)/){
		
			# Split the RPM File name using '/' as the IFS
			# Treat that as a list stored in the special @_
			# variable, and then slice the last element off
			# that list by referring to the last item with
			# the, admittedly oddlooking, $#_ special var.

			# And then assign it to local variable $rpm
			my $rpm = (split(/\//, $1))[$#_];

			# This could have been lumped in with the above, but
			# it's convoluted looking enough :)
			$rpms{$rpm} = 1;

			# Warn if special characters in RPM name.
			if($rpm =~ m/[\$\{\}]/) {
				warn("POTENTIAL ERROR: RPM $rpm");
			}

		}
	}
	close($fh);
}

sub warn {
	print STDERR $_."\n";
}
