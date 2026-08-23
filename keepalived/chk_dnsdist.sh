#!/bin/sh
# keepalived health check: exit 0 = dnsdist is running
# Deploy target: /etc/keepalived/chk_dnsdist.sh on BOTH nodes (dns-ha + Pi Zero).
# Replaces the broken default pidof check (on Ubuntu /usr/bin/pidof is a
# symlink to killall5 -> keepalived calls it incorrectly -> false failover).
/usr/bin/systemctl is-active --quiet dnsdist
