#!/bin/sh

# Destinations you don't want routed through Tor
NON_TOR="192.168.0.0/16 172.16.0.0/12"

# The UID Tor runs as
TOR_UID="debian-tor"

# Tor's TransPort
TRANS_PORT="9040"

# Make sure only root can run this script
check_root() {
	if [ $(id -u) -ne 0 ]; then
		echo "\n[!] This script must be run as root\n" >&2
		exit 1
	fi
}

# Check Tor configs
check_configs() {

	grep -q -x 'RUN_DAEMON="yes"' /etc/default/tor
	if [ $? -ne 0 ]; then
		echo "\n[!] Please add the following to your '/etc/default/tor' and restart service:\n"
		echo ' RUN_DAEMON="yes"\n'
		exit 1
	fi		

	grep -q -x 'VirtualAddrNetwork 10.192.0.0/10' /etc/tor/torrc
	VAR1=$?
	
	grep -q -x 'TransPort 9040' /etc/tor/torrc
	VAR2=$?
	
	grep -q -x 'DNSPort 53' /etc/tor/torrc
	VAR3=$?

	grep -q -x 'AutomapHostsOnResolve 1' /etc/tor/torrc
	VAR4=$?

	if [ $VAR1 -ne 0 ] || [ $VAR2 -ne 0 ] || [ $VAR3 -ne 0 ] || [ $VAR4 -ne 0 ]; then
		echo "\n[!] Please add the following to your '/etc/tor/torrc' and restart service:\n"
		echo ' VirtualAddrNetwork 10.192.0.0/10'
		echo ' TransPort 9040'
		echo ' DNSPort 53'
		echo ' AutomapHostsOnResolve 1\n'
		exit 1
	fi
}

iptables_flush() {
	iptables -F
	iptables -t nat -F
	echo " * Deleted all iptables rules"
}

do_start() {

	check_configs
	
	if [ ! -e /var/run/tor/tor.pid ]; then
		echo "\n[!] Tor is not running! Quitting...\n"
		exit 1
	fi
	
	check_root

	echo "\n[i] Starting anonymous mode:\n"
		
	if ! [ -f /etc/network/iptables.rules ]; then
		iptables-save > /etc/network/iptables.rules
		echo " * Saved iptables rules"
	fi
		
	iptables_flush
		
	echo -n " * Service "
	service resolvconf stop 2>/dev/null || echo "resolvconf already stopped"

	echo 'nameserver 127.0.0.1' > /etc/resolv.conf
	echo " * Modified resolv.conf to use Tor"

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
		
	echo " * Redirected all traffic throught Tor\n"	
	
}

do_stop() {

	check_root

	echo "\n[i] Stopping anonymous mode:\n"
	
	iptables_flush
		
	if [ -f /etc/network/iptables.rules ]; then
		iptables-restore < /etc/network/iptables.rules
		rm /etc/network/iptables.rules
		echo " * Restored iptables rules"
	fi
		
	echo -n " * Service "
	service resolvconf start 2>/dev/null || echo "resolvconf already started"
		
	echo " * Stopped anonymous mode\n"

}

do_check() {
	HTML=$(curl -s https://check.torproject.org/?lang=en_US)
	IP=$(echo $HTML | egrep -m1 -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')

	echo $HTML | grep -q "Congratulations. This browser is configured to use Tor."
	if [ $? -ne 0 ]; then
		echo "\n[!] Sorry. You are not using Tor: $IP\n"
	else
		echo "\n[i] Congratulations. This browser is configured to use Tor: $IP\n"
	fi
}

case "$1" in
	start)
		do_start
	;;
	stop)
		do_stop
	;;
	check)
		do_check
	;;
	*)
		echo "Usage: $0 {start|stop|check}" >&2
		exit 1
	;;
esac

exit 0
