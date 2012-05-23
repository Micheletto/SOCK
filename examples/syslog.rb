#!/usr/bin/ruby
# Libraries
require "socket"

# Class to make UDP connections to syslog, because the distributed
# syslog class does not have this option.
class Lsyslog

	# Open connection to host and port, and initialize the hash
	# for assigning the proper facility / priority.  Use sensible
	# defaults of localhost and port 514.
	def initialize(host="127.0.0.1", port="514")
		@usocket = UDPSocket.new
		@usocket.connect(host, port)

		@facilities = Hash.new()
		@priorities = Hash.new()

		# Syslog short hand for the syslog facilities as listed in
		# RFC 5424, though somewhat deprecated uucp and all...
		@facilities = {
			'kern' => 0,
			'user' => 1,
			'mail' => 2,
			'sys'  => 3,
			'auth' => 4,
			'log'  => 5,
			'lpr'  => 6,
			'news' => 7,
			'uucp' => 8,
			'clock' => 9,
			'secure' => 10,
			'ftp' => 11,
			'ntp' => 12,
			'audit' => 13,
			'alert' => 14,
			'clock' => 15,
			'local0' => 16,
			'local1' => 17,
			'local2' => 18,
			'local3' => 19,
			'local4' => 20,
			'local5' => 21,
			'local6' => 22,
			'local7' => 23
		}

		# Syslog priorities as listed in RFC 5424
		@priorities = {
			'emerg' => 0,
			'alert' => 1,
			'crit'  => 2,
			'err'   => 3,
			'warn'  => 4,
			'notice' => 5,
			'info'   => 6,
			'debug'  => 7
		}
	end
	
	# Deliver message to syslog locally.
	def log (facility, priority, message)

		# The format of a syslog message looks as follows:
		# < 1 to 3 DIGIT NUMBER > MESSAGE ...
		# Where the 3 digit number is the facility number multiplied
		# by 8 and added to the priority number.  See the hashes in
		# initialize for the numbers, or check RFC 5424.
		num = @facilities[facility] * 8
		num += @priorities[priority]

		# Send the message to syslog.
		@usocket.send("<" + num.to_s + ">" + message, 0)
	end
	
end

# Open syslog connection
syslog = Lsyslog.new()

# The above line defaults as if it were run like the following.
# syslog = Lsyslog.new("localhost", "514")

# Send a log message.
syslog.log("kern", "warn", "This is my message to yoooo ooooh ooh...")
