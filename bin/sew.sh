#!/bin/bash
# Use sh getopt later
TOENAIL=$1

if [[ ! ${TOENAIL} ]] ; then
	echo Usage: $0 TOENAIL
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
	echo $*
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
	rpm --root=${SOCK_DIR:-/var/deploy} --nodeps -ivh $1 $2

	PKG=$(basename ${1%.rpm}) # Del everything but the actual package name
			          # from the URL.

	# Run package check routine instead of checking actual return code
	# from rpm because of annoying scriptlet errors.
	if PkgCheck $PKG ; then
		log $PKG successfully installed.
	else
		die Unable to install $PKG
	fi
}

# Initialize a repository.  Not currently cleaning the SOCK directory to 
# avoid accidentally removing files.  May add a warning to let the user
# know to remove them manually if necessary.
function  Base() {
	SOCK_DIR=$1

	# Create the directory
	mkdir -p $SOCK_DIR

	# Initialize RPM DB for SOCK
	rpm --root $SOCK_DIR --initdb

	# Exit if unable to initialize RPM DB.
	if [ $? -gt 0 ] ; then
		echo Failed to initialize RPM DB in $SOCK_DIR
		exit 1
	fi
}

# Import GPG Key, necessary to properly install and verify RPMs.
function GpgImport() {
	rpm --root=${SOCK_DIR:-/var/deploy} --import $1
}

# Test to see if a package has been installed in the SOCK.
function PkgCheck() {
	rpm --root=${SOCK_DIR:-/var/deploy} -q $1
	if [ $? -gt 0 ] ; then
		return 1
	else
		return 0
	fi
}

# Adds a user to a SOCK, using the shadow-utils package.  Does not remove
# the shadow-utils package, currently.
function UserAdd() {
	
	# Install if needed.
	ShadowCheck 

	# Add all users as system users because, presumably, they are 
	# application related, and do not require expiration, and probably do
	# require opening privileged ports, etc.
	
	# Useradd takes the following args, in the following order:
	# UID GID HOMEDIR SHELL NAME

	# Note the absence of GECOS.  This is on purpose to avoid cooking up
	# some fancy parsing for white space.  Use Gecos function or add 
	# manually.

	# Also, use the GroupAdd function to create necessary groups, not
	# adding a group with the username.

	# Check to see that the correct amount of arguments has been passed.
	if [[ ! $5 ]] ; then
		die Not enough arguments to UserAdd: $*
	fi

	# Add user to SOCK
	log Adding user $5
	chroot ${SOCK_DIR:-/var/deploy} useradd -u $1 -g $2 -d $3 -s $4 -m -N -r $5
	
	# Check to see if successful.
	chroot ${SOCK_DIR:-/var/deploy} getent passwd $5

	if [ $? -gt 0 ] ; then
		die Failed to add user $5
	else
		log Adding user $5 successful.
	fi
}

# GroupAdd function for adding groups.
function GroupAdd() {

	# Install shadow-utils if needed.
	ShadowCheck

	# Add Group using groupadd command.  GroupAdd takes the following args:
	# GID GROUP

	# Test to see there is the proper amount of arguments
	if [[ ! $2 ]] ; then
		die Not enough arguments to GroupAdd: $*
	fi

	# Add group
	log Adding group $2
	chroot ${SOCK_DIR:-/var/deploy} groupadd -g $1 $2

	# Test to see if the group was added successfully.
	chroot ${SOCK_DIR:-/var/deploy} getent group $2

	if [ $? -gt 0 ] ; then
		die Unable to add group $2
	else
		log Successfully added group $2
	fi

}

# Gecos function adds user comment.
function Gecos() {
	
	# Install shadow-utils if necessary.
	ShadowCheck

	# Check for proper number of arguments, which is two, and in this
	# order:
	# USER COMMENT ...

	# Add comment
	GECOS_USER=$1 ; shift
	chroot ${SOCK_DIR:-/var/deploy} usermod -c "$*" ${GECOS_USER}

	# Check to see mod was successful, log failure but don't die, it's
	# only GECOS after all.
	grep ${GECOS_USER} ${SOCK_DIR:-/var/deploy}/etc/passwd | grep "$*"
	if [ $? -gt 0 ] ; then
		log Unable to set GECOS field for ${GECOS_USER}
	else
		log Successfully modified GECOS for ${GECOS_USER}
	fi
}

# Check to see if shadow-utils are installed, and if not install them.
function ShadowCheck(){

	# Avoid Checking this if already run
	if [[ $SHADOWCHECKED ]] ; then
		return
	fi
	
	if PkgCheck shadow-utils ; then
		log The shadow-utils package is installed in SOCK.
	else
		log The shadow-utils package is not installed in SOCK.
		log Installing shadow-utils in ${SOCK_DIR}.

		# For now, the shadow-utils TOENAIL file is a hardlink to
		# the latest version of shadow-utils.
		Include TOENAILS/shadow-utils

		# Test for success.
		if PkgCheck shadow-utils ; then
			log Installation of shadow-utils successful.
			SHADOWCHECKED=1 # Set SHADOWCHECKED to avoid rerunning.
		else
			die Failed to install shadow-utils.
		fi
	fi
}

# Create devices takes: TYPE MAJOR MINOR DEV
function Mknod() {
	# Test for correct number of arguments.
	if [[ ! $4 ]] ; then
		die Not enough arguments supplied to Mknod: $*
	fi

	# Create dev if necessary
	if [ -d ${SOCK_DIR:-/var/deploy}/dev ] ; then
		log Device directory exists.
	else
		mkdir -p ${SOCK_DIR:-/var/deploy}/dev
	fi

	# Create device.
	log Creating Device $4 Major: $2 Minor: $3
	mknod ${SOCK_DIR:-/var/deploy}/dev/${4} $1 $2 $3
	chmod 666 ${SOCK_DIR:-/var/deploy}/dev/${4}

	# Test to make sure device was created.
	if [ -e ${SOCK_DIR:-/var/deploy}/dev/${4} ] ; then
		log Creation of device $4 successful.
	else
		die Unable to create device $4 Major: $2 Minor: $3
	fi
}

# Create symlinks from the system into the SOCK.
# Takes ARGS: LINK TARGET
# TARGET will get appended to SOCK_DIR
# SOURCE is expected to be inside host system.
function Symlink(){
	
	# Test for correct number of arguments.
	if [[ ! $2 ]] ; then
		die Insufficient arguments to Symlink: $*
	fi

	# Make Symbolic Link
	ln -s $2 ${SOCK_DIR:-/var/deploy}/${1}

	# Test for it.
	if [ -h $1 ] ; then
		log Created symlink $1 to $2
	else
		die Unable to create symlink $1 to $2
	fi
}

# MAIN
Include ${TOENAIL} # Add test to allow this to be loaded as a lib instead
	           # of executed as a command.
