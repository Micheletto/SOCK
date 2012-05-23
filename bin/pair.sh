#!/bin/bash
# Use sh getopt later
TOENAIL=$1

if [[ ! ${TOENAIL} ]] ; then
	echo Usage: pair.sh FOOT
	exit 1
fi

# Source the TOENAIL Files.  Treating them as bash source allows logic
# in the configurations without re-implementing the wheel.
function Include() {
	if [ -f $1 ] ; then
		source $1
	else
		die ERROR: No such file $1
	fi
}

# Currently just echoing, but will probably want to change this in the future
# and using the function allows for making that change in one place.
function log() {
	MYARGES=$*
}

# Not doing anything fancy currently, but will probably want to add some
# cleanup code in the future.
function die() {
	log $*
	exit 1
}

# Install an RPM.  To be done, add test code to make sure that the RPM
# is actually installed, and test to make sure the package has been
# properly signed.
function Rpm() {
	MYARGES=$*
}

# Initialize a repository.  Not currently cleaning the SOCK directory to 
# avoid accidentally removing files.  May add a warning to let the user
# know to remove them manually if necessary.
function  Base() {
	SOCK_DIR=$1

}

# Import GPG Key, necessary to properly install and verify RPMs.
function GpgImport() {
	
	MYARGES=$*
}

# Test to see if a package has been installed in the SOCK.
function PkgCheck() {
	MYARGES=$*
}

# Adds a user to a SOCK, using the shadow-utils package.  Does not remove
# the shadow-utils package, currently.
function UserAdd() {
	MYARGES=$*
}

# GroupAdd function for adding groups.
function GroupAdd() {
	MYARGES=$*
}

# Gecos function adds user comment.
function Gecos(){
	MYARGES=$*
}

# Check to see if shadow-utils are installed, and if not install them.
function ShadowCheck(){
	MYARGES=$*
}

# Create SCRIPTS directory and initialize it.
function Scripts() {

	# Return if already run.
	if [[ $SCRIPTED ]] ; then
		return
	fi

	# Create SCRIPTS dir if necessary
	if [ -d ${SOCK_DIR:-/var/deploy}/SCRIPTS ] ; then
		log SCRIPTS directory exists.
	else
		mkdir -p ${SOCK_DIR:-/var/deploy}/SCRIPTS
	fi

	if [ -f ${SOCK_DIR:-/var/deploy}/SCRIPTS/post ] ; then
		log The post file exists.
	else
		POST="${SOCK_DIR:-/var/deploy}/SCRIPTS/post"
		log Creating post file: ${POST}
		touch ${POST}
		echo "#!/bin/sh" >> ${POST}
		chmod +x ${POST}
	fi

	# To avoid running unnecessarily
	SCRIPTED=1
}

# Create devices takes: TYPE MAJOR MINOR DEV
function Mknod() {
	# Test for correct number of arguments.
	if [[ ! $4 ]] ; then
		die Not enough arguments supplied to Mknod: $*
	fi

	# Create and initialize Scripts if necessary
	Scripts

	# Add device, note POST is defined in Scripts()
	log Creating Device $4 Major: $2 Minor: $3
	echo mknod ${SOCK_DIR:-/var/deploy}/dev/${4} $1 $2 $3 >> ${POST}
	chmod 666 ${SOCK_DIR:-/var/deploy}/dev/${4} >> ${POST}

}

# Create symbolic links that point from outside system into SOCK.
function Symlink() {

	# Test for correct number of arguments.
	if [[ ! $2 ]] ; then
		die Not enough arguments supplied to Symlink: $*
	fi

	# Create and initialize Scripts if necessary
	Scripts
	
	# Add symbolic link, note POST is defined in Scripts()
	log Adding symbolic link: LINK: $1 TARGET: $2
	echo ln -s ${SOCK_DIR:-/var/deploy}/$2 $1 >> ${POST}
}

function PairLint() {
	# Check for fpm.
	if ! which fpm >/dev/null 2>&1 ; then
		die Effing Package Manager not found.
	fi
}

function Pair() {
	if [[ ! $VERSION ]] ;  then
		die No version number configured.
	fi

	if [[ ! $PACKAGE ]] ; then
		die No package name configured.
	fi

	# Create RPM using FPM.
	fpm -s dir -t rpm -n "${PACKAGE}" -v "${VERSION}" --post-install ${SOCK_DIR:-/var/deploy}/SCRIPTS/post -x "*/dev/*" ${SOCK_DIR:-/var/deploy}
}

# MAIN
PairLint	   # Make sure everything is needed.
Include ${TOENAIL} # Add test to allow this to be loaded as a lib instead
	           # of executed as a command.
Pair		   # Attempt to package.
