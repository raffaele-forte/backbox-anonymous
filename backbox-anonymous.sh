#!/bin/sh

# Copyright(c) 2011-2013 BackBox Developers
# http://www.backbox.org/
#
# This file is part of backbox-default-settings
#
# backbox-anonymous is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as 
# published by the Free Software Foundation, either version 3 of the 
# License, or (at your option) any later version.
#
# backbox-anonymous is distributed in the hope that it will be 
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with backbox-anonymous. If not, see <http://www.gnu.org/licenses/>.

export BLUE='\033[1;94m'
export GREEN='\033[1;92m'
export RED='\033[1;91m'
export ENDC='\033[1;00m'

# Destinations you don't want routed through Tor
NON_TOR="192.168.0.0/16 172.16.0.0/12 10.0.0.0/8"

# The UID Tor runs as
TOR_UID="debian-tor"

# Tor's TransPort
TRANS_PORT="9040"

case "$1" in
    start)
		# Make sure only root can run this script
		if [ $(id -u) -ne 0 ]; then
		  echo "\n$RED[!] This script must be run as root$ENDC\n" >&2
		  exit 1
		fi
		
		# Check defaults for Tor
		grep -q -x 'RUN_DAEMON="yes"' /etc/default/tor
		if [ $? -ne 0 ]; then
			echo "\n$RED[!] Please add the following to your /etc/default/tor and restart service:$ENDC\n" >&2
			echo "$BLUE#----------------------------------------------------------------------#$ENDC"
			echo 'RUN_DAEMON="yes"'
			echo "$BLUE#----------------------------------------------------------------------#$ENDC\n"
			exit 1
		fi		
		
		# Check torrc config file
		grep -q -x 'VirtualAddrNetwork 10.192.0.0/10' /etc/tor/torrc
		if [ $? -ne 0 ]; then
			echo "\n$RED[!] Please add the following to your /etc/tor/torrc and restart service:$ENDC\n" >&2
			echo "$BLUE#----------------------------------------------------------------------#$ENDC"
			echo 'VirtualAddrNetwork 10.192.0.0/10'
			echo 'AutomapHostsOnResolve 1'
			echo 'TransPort 9040'
			echo 'DNSPort 53'
			echo "$BLUE#----------------------------------------------------------------------#$ENDC\n"
			exit 1
		fi
		grep -q -x 'AutomapHostsOnResolve 1' /etc/tor/torrc
		if [ $? -ne 0 ]; then
			echo "\n$RED[!] Please add the following to your /etc/tor/torrc and restart service:$ENDC\n" >&2
			echo "$BLUE#----------------------------------------------------------------------#$ENDC"
			echo 'VirtualAddrNetwork 10.192.0.0/10'
			echo 'AutomapHostsOnResolve 1'
			echo 'TransPort 9040'
			echo 'DNSPort 53'
			echo "$BLUE#----------------------------------------------------------------------#$ENDC\n"
			exit 1
		fi
		grep -q -x 'TransPort 9040' /etc/tor/torrc
		if [ $? -ne 0 ]; then
			echo "\n$RED[!] Please add the following to your /etc/tor/torrc and restart service:$ENDC\n" >&2
			echo "$BLUE#----------------------------------------------------------------------#$ENDC"
			echo 'VirtualAddrNetwork 10.192.0.0/10'
			echo 'AutomapHostsOnResolve 1'
			echo 'TransPort 9040'
			echo 'DNSPort 53'
			echo "$BLUE#----------------------------------------------------------------------#$ENDC\n"
			exit 1
		fi
		grep -q -x 'DNSPort 53' /etc/tor/torrc
		if [ $? -ne 0 ]; then
			echo "\n$RED[!] Please add the following to your /etc/tor/torrc and restart service:$ENDC\n" >&2
			echo "$BLUE#----------------------------------------------------------------------#$ENDC"
			echo 'VirtualAddrNetwork 10.192.0.0/10'
			echo 'AutomapHostsOnResolve 1'
			echo 'TransPort 9040'
			echo 'DNSPort 53'
			echo "$BLUE#----------------------------------------------------------------------#$ENDC\n"
			exit 1
		fi

		echo "\n$BLUE[i] Starting anonymous mode:$ENDC\n"
		
		if [ ! -e /var/run/tor/tor.pid ]; then
			echo " $RED*$ENDC Tor is not running! Quitting...\n" >&2
			exit 1
		fi
		
		if ! [ -f /etc/network/iptables.rules ]; then
			iptables-save > /etc/network/iptables.rules
			echo " $GREEN*$ENDC Saved iptables rules"
		fi

		iptables -F
		iptables -t nat -F
		echo " $GREEN*$ENDC Deleted all iptables rules"
	
		echo -n " $GREEN*$ENDC Service "
		service resolvconf stop 2>/dev/null || echo "resolvconf already stopped"

		echo 'nameserver 127.0.0.1' > /etc/resolv.conf
		echo " $GREEN*$ENDC Modified resolv.conf to use Tor"

		iptables -t nat -A OUTPUT -m owner --uid-owner $TOR_UID -j RETURN
		iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 53
		for NET in $NON_TOR 127.0.0.0/9 127.128.0.0/10; do
			iptables -t nat -A OUTPUT -d $NET -j RETURN
		done
		iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports $TRANS_PORT
		iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
		for NET in $NON_TOR 127.0.0.0/8; do
				iptables -A OUTPUT -d $NET -j ACCEPT
		done
		iptables -A OUTPUT -m owner --uid-owner $TOR_UID -j ACCEPT
		iptables -A OUTPUT -j REJECT
		echo "$GREEN *$ENDC Redirected all traffic throught Tor\n"

		echo "$BLUE[i] Are you using Tor?$ENDC\n"
		echo "$GREEN *$ENDC Please refer to https://check.torproject.org\n"
	;;
    stop)
		# Make sure only root can run our script
		if [ $(id -u) -ne 0 ]; then
		  echo "\n$RED[!] This script must be run as root$ENDC\n" >&2
		  exit 1
		fi
		
		echo "\n$BLUE[i] Stopping anonymous mode:$ENDC\n"
		
		iptables -F
		iptables -t nat -F
		echo " $GREEN*$ENDC Deleted all iptables rules"
		
		if [ -f /etc/network/iptables.rules ]; then
			iptables-restore < /etc/network/iptables.rules
			rm /etc/network/iptables.rules
			echo " $GREEN*$ENDC Restored iptables rules"
		fi
		
		echo -n " $GREEN*$ENDC Service "
		service resolvconf start 2>/dev/null || echo "resolvconf already started"
		
		echo " $GREEN*$ENDC Stopped anonymous mode\n"
	;;
    restart)
		$0 stop
		$0 start
	;;
    *)
	echo "Usage: $0 {start|stop|restart}"
	exit 1
	;;
esac

exit 0
