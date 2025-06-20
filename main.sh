#!/bin/bash

source /root/variables.conf

# This sceript is used to run the DDNS server
set -x
yum install -y bind bind-utils *dhcp* &> /dev/null

# Create RNDC Key Pair for secure communication between DHCP and DNS server

   rndc-confgen -a -k "rndc-key"

# Removing the contents of the named.conf file

> /etc/named.conf
> /etc/dhcp/dhcpd.conf

set +x

# Configure the DHCP server

set -x

cat /etc/rndc.key > /etc/dhcp/dhcpd.conf

cat >> /etc/dhcp/dhcpd.conf << EOF

ddns-updates on;
ddns-update-style interim;
update-static-leases on;
use-host-decl-names on;

zone ${domain}. {
        primary ${primarydnsip};
        key rndc-key;
}

zone ${subnetinreverse}.in-addr.arpa. {
        primary ${primarydnsip};
        key rndc-key;
}

subnet ${subnet} netmask ${subnetmask} {
        range ${dhcpiprange};
        option routers ${gateway};
        option domain-name-servers ${primarydnsip};
        option domain-name "${domain}";
        ddns-domainname "${domain}.";
        ddns-rev-domainname "in-addr.arpa";
        send host-name = gethostname();
        default-lease-time 600;
        max-lease-time 7200;
        send host-name "client-hostname";
        use-host-decl-names on;
        #host clientone {
        #hardware ethernet 08:00:27:77:1F:8D;
        #fixed-address 192.168.0.100;
        #}
}
EOF

cat /etc/rndc.key > /etc/dhcp/dhcpd.conf

set +x

# Configure the DNS server

set -x

cat > /etc/named.conf << EOF
options {
        listen-on port 53 { 127.0.0.1; ${primarydnsip}; };
        listen-on-v6 port 53 { ::1; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        secroots-file   "/var/named/data/named.secroots";
        recursing-file  "/var/named/data/named.recursing";
        allow-query     { any; ${subnet}/24; 8.8.8.8; 8.8.4.4; };
        forwarders {
        8.8.8.8;  # Google DNS
        8.8.4.4;  # Google DNS
        };
        forward only;

        /* 
         - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
         - If you are building a RECURSIVE (caching) DNS server, you need to enable 
           recursion. 
         - If your recursive DNS server has a public IP address, you MUST enable access 
           control to limit queries to your legitimate users. Failing to do so will
           cause your server to become part of large scale DNS amplification 
           attacks. Implementing BCP38 within your network would greatly
           reduce such attack surface 
        */
        recursion yes;

        dnssec-validation no;

        managed-keys-directory "/var/named/dynamic";
        geoip-directory "/usr/share/GeoIP";

        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";

        /* https://fedoraproject.org/wiki/Changes/CryptoPolicy */
        include "/etc/crypto-policies/back-ends/bind.config";
};

zone "${domain}" IN {
        type master;
        file "${fwdzone}";
        allow-update { key rndc-key; };
};

zone "${subnetinreverse}.in-addr.arpa"   IN {
        type master;
        file "${revzone}";
        allow-update { key rndc-key; };
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
/*
logging {
    channel update_debug {
        file "/var/log/named-update.log";
        severity debug 3;
    };
    category update { update_debug; };
    category security { update_debug; };
};
*/
EOF

cat /etc/rndc.key >> /etc/named.conf

set +x

# Create the forward zone file

set -x

cat > /var/named/${fwdzone} << EOF
\$TTL 86400
@    IN    SOA   ${HOSTNAME}. krishnakishore@inarm.in. (   
             2025011301 ; Serial
             3600       ; Refresh
             1800       ; Retry
             604800     ; Expire
             86400      ; Minimum TTL
)
@    IN    NS    ${HOSTNAME}.
$(hostname -s) IN    A     ${primarydnsip}
EOF

set +x

# Create the reverse zone file

set -x

cat > /var/named/${revzone} << EOF
\$TTL 86400
@    IN    SOA   ${HOSTNAME}. krishnakishore@inarm.in. (  
             2025011301 ; Serial
             3600       ; Refresh
             1800       ; Retry
             604800     ; Expire
             86400      ; Minimum TTL
)
@    IN    NS    ${HOSTNAME}.
20   IN    PTR     ${HOSTNAME}.
$(hostname -s) IN    A     ${primarydnsip}
EOF

set +x

# Set the permissions for the zone files

set -x

chown -R named:named /var/named
chown -R named:named /etc/named.conf

set +x

# Start the DNS and DHCP services

set -x

systemctl start named
systemctl enable named --now
systemctl start dhcpd
systemctl enable dhcpd --now

set +x

# Open the firewall ports


set -x

firewall-cmd --permanent --add-service=dns
firewall-cmd --permanent --add-service=dhcp
firewall-cmd --reload


