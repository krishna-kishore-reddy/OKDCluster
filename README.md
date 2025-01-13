# OKDCluster
How to setup the OKD cluster in OnPrem env step by step guide.


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

1. Open the configuration file for editing:
   ```bash
   sudo nano /etc/named.conf  # RHEL/CentOS
   sudo nano /etc/bind/named.conf  # Ubuntu
   ```
2. Add or modify the following settings:
   ```
   options {
       listen-on port 53 { 127.0.0.1; 192.168.1.1; }; # Replace with server's static IP
       directory "/var/named";  # Zone files directory
       allow-query { any; };
       recursion yes;  # Enable recursive queries if needed
   };
   ```

#### Create Forward Zone File

1. Define the forward zone in `/etc/named.conf` or `/etc/bind/named.conf.local`:
   ```
   zone "example.com" IN {
       type master;
       file "/var/named/example.com.zone";  # Adjust path for your distribution
   };
   ```
2. Create the zone file:
   ```bash
   sudo nano /var/named/example.com.zone
   ```
3. Add the following content:
   ```
   $TTL 86400
   @    IN    SOA   dns-server.example.com. admin.example.com. (
                2025011301 ; Serial
                3600       ; Refresh
                1800       ; Retry
                604800     ; Expire
                86400      ; Minimum TTL
   )
   @    IN    NS    dns-server.example.com.
   dns-server IN    A     192.168.1.1
   www        IN    A     192.168.1.2
   ```

#### Restart DNS Service

Restart and enable the DNS server:
```bash
sudo systemctl restart named  # RHEL/CentOS
sudo systemctl restart bind9  # Ubuntu
sudo systemctl enable named   # Ensure it starts on boot
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
   option domain-name "example.com";
   option domain-name-servers 192.168.1.1;
   default-lease-time 600;
   max-lease-time 7200;

   subnet 192.168.1.0 netmask 255.255.255.0 {
       range 192.168.1.100 192.168.1.200;
       option routers 192.168.1.1;
       option broadcast-address 192.168.1.255;
   }
   ```

### 2. **Assign Interfaces**

Edit `/etc/default/isc-dhcp-server` (Ubuntu) or `/etc/sysconfig/dhcpd` (RHEL):
```bash
sudo nano /etc/default/isc-dhcp-server  # Ubuntu
INTERFACESv4="eth0"  # Replace with your interface name
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

---

This guide provides a complete walkthrough of building and configuring DNS and DHCP servers. Ensure proper backups and testing at every stage to avoid disruptions.

