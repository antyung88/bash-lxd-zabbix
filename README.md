# lxd-zabbix
Install Zabbix in LXC behind Nginx Reverse Proxy

# Prerequisites
- Ubuntu 20.04 (Recommended)
- LXD init
- FQDN
- Sudo Privilieges

# Installation
- Proxy Container (Nginx Reverse Proxy)
- Zabbix Container 
- Let's Encrypt

# Usage
```
git clone https://github.com/antyung88/lxd-zabbix.git && cd lxd-zabbix
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
