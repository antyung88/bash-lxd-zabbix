# lxd-zabbix
Install Zabbix in LXC behind Nginx Reverse Proxy

```
+--------+---------+---------------------+-----------------------------------------------+-----------+-----------+
|  NAME  |  STATE  |        IPV4         |                     IPV6                      |   TYPE    | SNAPSHOTS |
+--------+---------+---------------------+-----------------------------------------------+-----------+-----------+
| proxy  | RUNNING | 10.54.193.63 (eth0) | fd42:8b30:78e5:d434:216:3eff:feb3:a35f (eth0) | CONTAINER | 0         |
+--------+---------+---------------------+-----------------------------------------------+-----------+-----------+
| zabbix | RUNNING | 10.54.193.49 (eth0) | fd42:8b30:78e5:d434:216:3eff:fe2b:c40b (eth0) | CONTAINER | 0         |
+--------+---------+---------------------+-----------------------------------------------+-----------+-----------+
```

# Prerequisites
- Ubuntu 20.04 (Recommended)
- Sudo Privilieges
- LXD/LXC Initialized
- FQDN

# Installation
- Proxy Container (Nginx Reverse Proxy)
- Zabbix Container 
- Let's Encrypt

# Usage
```
git clone https://github.com/antyung88/bash-lxd-zabbix.git && cd bash-lxd-zabbix
```
Edit variables
```
nano zabbix.sh
```
Deploy
```
chmod +x zabbix.sh
./zabbix.sh
```
