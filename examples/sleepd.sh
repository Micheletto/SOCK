#!/bin/sh

# The sleep daemon- it sleeps.  
# Probably the most useless daemon of all time, but safe(ish).

# Sleep for like a days worth of seconds, then do it again, for infinity days.
while true ; do 
	sleep 86400
done &
