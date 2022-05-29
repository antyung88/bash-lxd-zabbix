# lxd-zabbix
Install Zabbix in LXC behind Nginx Reverse Proxy

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
