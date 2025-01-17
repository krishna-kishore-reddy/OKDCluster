# Setting Up DNS and DHCP Servers: Step-by-Step Guide

This guide provides detailed steps to build and configure DNS and DHCP servers, ensuring seamless network functionality. The setup uses **BIND** for DNS and **ISC DHCP Server** for DHCP.

---

## Prerequisites

### 1. **System Requirements**
- **Operating System**: RHEL, CentOS, Ubuntu, or any Linux distribution.
- **Root Access**: Ensure you have sudo privileges.
- **Static IP Address**: Assign a static IP to the server.

### 2. **Packages to Install**
- DNS Server: `bind` or `bind9`
- DHCP Server: `isc-dhcp-server`
- Network Utilities: `net-tools`, `dnsutils` (optional for testing)

Install these packages:
```bash
sudo apt update && sudo apt install bind9 isc-dhcp-server net-tools dnsutils -y  # For Ubuntu
sudo yum install bind bind-utils dhcp -y  # For RHEL/CentOS
```

---

## Step 1: Configure the DNS Server

### 1. **Set the Hostname**
Ensure the server has a hostname:
```bash
sudo hostnamectl set-hostname dns-server
```

### 2. **Edit DNS Configuration Files**

#### Main Configuration File: `/etc/named.conf` or `/etc/bind/named.conf`

Create RNDC Key 

```bash
   rndc-confgen -a -k "rndc-key"
```
value will be stored under /etc as rndc.key i.e /etc/rndc.key 

1. Open the configuration file for editing:
   ```bash
   sudo nano /etc/named.conf  # RHEL/CentOS
   sudo nano /etc/bind/named.conf  # Ubuntu
   ```
2. Add or modify the following settings:
   ```
   options {
        listen-on port 53 { 127.0.0.1; 192.168.0.20; };
        listen-on-v6 port 53 { ::1; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        secroots-file   "/var/named/data/named.secroots";
        recursing-file  "/var/named/data/named.recursing";
        allow-query     { any; 192.168.0.0/24; 8.8.8.8; 8.8.4.4; };
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
   
   
   key "rndc-key" {
           algorithm hmac-sha256;
           secret "smLqZ7l7b4ep25cfZYZXhjKwu3Qq5Crk4hJTdUE7j4Q=";
   };
   
   zone "inarm.in" IN {
           type master;
           file "inarm.in.zone";
           allow-update { key rndc-key; };
   };
   
   zone "0.168.192.in-addr.arpa"   IN {
           type master;
           file "reverse.zone";
           allow-update { key rndc-key; };
   };
   
   include "/etc/named.rfc1912.zones";
   include "/etc/named.root.key";
   
   logging {
       channel update_debug {
           file "/var/log/named-update.log";
           severity debug 3;
       };
       category update { update_debug; };
       category security { update_debug; };
   };
   ```

   - To check whether the configuration is correct or not you have to use the command #named-checkconf

#### Create Forward Zone File

1. Define the forward zone in `/etc/named.conf` or `/etc/bind/named.conf.local`:   
   ```
   zone "example.com" IN {
       type master;
       file "/var/named/example.com.zone";  # Adjust path for your distribution   #this is already created in the named.conf file no need to create any file.
   };
   ```
2. Create the zone file:
   ```bash
   sudo nano /var/named/example.com.zone
   ```
3. Add the following content:
   ```
   $TTL 86400
   @    IN    SOA   dnsmaster.inarm.in. krishnakishore@inarm.in. (   #Like this Simillarly we have to generate for the reverse lookup also.
                2025011301 ; Serial
                3600       ; Refresh
                1800       ; Retry
                604800     ; Expire
                86400      ; Minimum TTL
   )
   @    IN    NS    dnsmaster.inarm.in.
   dnsmaster IN    A     192.168.0.20
   
   ```

   ```
   $TTL 86400
   @    IN    SOA   dnsmaster.inarm.in. krishnakishore@inarm.in. (   #Like this Simillarly we have to generate for the reverse lookup also.
                2025011301 ; Serial
                3600       ; Refresh
                1800       ; Retry
                604800     ; Expire
                86400      ; Minimum TTL
   )
   @    IN    NS    dnsmaster.inarm.in.
   20   IN    PTR     dnsmaster.inarm.in.
   dnsmaster IN    A     192.168.0.20

   ```
   - To check whether configuration is correct or not you have to use the below commands.
   - named-checkzone inarm.in /var/named/inarm.in.zone
   - named-checkzone 0.168.192.in-addr.arpa /var/named/reverse.zone

#### Restart DNS Service

Restart and enable the DNS server:
```bash
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo systemctl restart named  # RHEL/CentOS
sudo systemctl restart bind9  # Ubuntu
sudo systemctl enable --now named   # Ensure it starts on boot
```

#### Test DNS Configuration

Use `dig` or `nslookup` to test:
```bash
dig @192.168.1.1 example.com
```

---

## Step 2: Configure the DHCP Server

### 1. **Edit DHCP Configuration File**

1. Open `/etc/dhcp/dhcpd.conf`:
   ```bash
   sudo nano /etc/dhcp/dhcpd.conf
   ```
2. Configure the DHCP server settings:
   ```
   key "rndc-key" {
        algorithm hmac-sha256;
        secret "smLqZ7l7b4ep25cfZYZXhjKwu3Qq5Crk4hJTdUE7j4Q=";
   };
   ddns-updates on;
   ddns-update-style interim;
   update-static-leases on;
   use-host-decl-names on;
   
   zone inarm.in. {
           primary 192.168.0.20;
           key rndc-key;
   }
   
   zone 0.168.192.in-addr.arpa. {
           primary 192.168.0.20;
           key rndc-key;
   }
   
   subnet 192.168.0.0 netmask 255.255.255.0 {
           range 192.168.0.100 192.168.0.200;
           option routers 192.168.0.1;
           option domain-name-servers 192.168.0.20;
           option domain-name "inarm.in";
           ddns-domainname "inarm.in";
           ddns-rev-domainname "in-addr.arpa";
           send host-name = gethostname();
           default-lease-time 600;
           max-lease-time 7200;
           send host-name "client-hostname";
           use-host-decl-names on;
           host clientone {
           hardware ethernet 08:00:27:77:1F:8D;
           fixed-address 192.168.0.100;
        }
           host clienttwo {
           hardware ethernet 08:00:27:D4:E9:F7;
           fixed-address 192.168.0.101;
        }
   }
   ```


### 3. **Restart DHCP Service**

Restart and enable the DHCP service:
```bash
sudo systemctl restart isc-dhcp-server  # Ubuntu
sudo systemctl restart dhcpd           # RHEL/CentOS
sudo systemctl enable isc-dhcp-server
```

### 4. **Test DHCP Server**

1. On a client machine, configure the network interface to use DHCP.
2. Check the assigned IP address:
   ```bash
   ip addr show
   ```
3. Verify leases:
   ```bash
   sudo cat /var/lib/dhcp/dhcpd.leases
   ```

---

## Step 3: Integrate DNS and DHCP (Optional)

### 1. **Enable DDNS Updates**

1. Modify `/etc/named.conf`:
   ```
   allow-update { key "dhcp_update"; };
   ```

2. Add the key definition:
   ```
   key "dhcp_update" {
       algorithm hmac-md5;
       secret "YOUR_SECRET_KEY";
   };
   ```

3. Add the corresponding key to `/etc/dhcp/dhcpd.conf`:
   ```
   key "dhcp_update" {
       algorithm hmac-md5;
       secret "YOUR_SECRET_KEY";
   };

   zone example.com. {
       primary 192.168.1.1;
       key "dhcp_update";
   }
   ```

4. Restart both services:
   ```bash
   sudo systemctl restart named
   sudo systemctl restart isc-dhcp-server
   ```

---

## Troubleshooting

### Common Commands
- **Check DNS Logs**:
  ```bash
  sudo tail -f /var/log/named/named.log  # RHEL
  sudo tail -f /var/log/syslog  # Ubuntu
  ```
- **Check DHCP Leases**:
  ```bash
  sudo cat /var/lib/dhcp/dhcpd.leases
  ```

### Common Issues
1. **DNS Not Resolving**:
   - Verify zone files and restart the service.
   - Test with `dig`.

2. **DHCP Not Assigning IPs**:
   - Ensure the subnet and range match the server’s network.
   - Check interface configuration in `/etc/default/isc-dhcp-server`.
  
3. **KEY Files to check**
   - /var/named/inarm.in.zone #this is forward zone file, Permission for this file is -rw-r--r--. 1 named named  605 Jan 17 09:30 inarm.in.zone
   - /var/named/reverse.zon #reverse lookup zone, -rw-r--r--. 1 named named  605 Jan 17 09:30 reverse.zone
   - /etc/named.conf #DNS Configuration file. -rw-rw----. 1 root named 2210 Jan 16 21:39 /etc/named.conf
   - /etc/dhcp/dhcpd.conf #DHCP Configuration file. -rw-r--r--. 1 root root 1034 Jan 17 09:01 /etc/dhcp/dhcpd.conf
   - /var/lib/dhcpd/dhcpd.leases #This file will help to check the IP's assigned by the DHCP server, leases.
   - Make sure SELinux is disabled. Otherwise you have to set the permession to the files accordingly, if SELinux is enabled you may see the error in creating a file for logs of named service.
   - 210  chown named:named /var/log/named-update.log
  211  chmod 640 /var/log/named-update.log
  214  semanage fcontext -a -t named_log_t "/var/log/named-update.log"
  215  restorecon -v /var/log/named-update.log

---

This guide provides a complete walkthrough of building and configuring DNS and DHCP servers. Ensure proper backups and testing at every stage to avoid disruptions.

