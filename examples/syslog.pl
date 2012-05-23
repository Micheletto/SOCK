#!/usr/bin/perl

# Libraries, specify setlogsock, because it contains the magic
# to allow us to use UDP over localhost.
use Sys::Syslog qw (:DEFAULT setlogsock);

# Specify using UDP connection to localhost.
setlogsock("udp", "localhost");

# Open and send a message.  See perldoc in Sys::Syslog for more information.
openlog("TEST", "nofatal", "local0");
syslog("local0.emerg", "Syslog message to localhost from chroot.");
