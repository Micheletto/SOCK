#!/bin/sh
# Uses sockdiff.pl and mrepogrep.pl to create potential TOENAIL output
# by identifying RPMs that have been installed into a SOCK _after_ 
# it has been assembled from running sew.sh.

# Check for command line arguments
if [[ $3 ]] ; then

	for RPM in $(sockdiff.pl -t $1 $2) ; do
		echo Rpm $(mrepogrep.pl -f $3 ${RPM})
	done

else
	echo $0: TOENAIL SOCK YUMCONF

fi
