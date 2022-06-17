#!/bin/bash

# Lets define some variables.
export HOST="zabbix.example.com"
# export EMAIL="hello@example.com" ## MODIFY CERTBOT AT THE BOTTOM OF THIS SCRIPT ##
export PROXY_CONTAINER="proxy"
export ZABBIX_CONTAINER="zabbix"
export DB_NAME="zabbix"
export DB_USER="zabbix"
export DB_PASS="zabbix"

# Check if root
if [ "$(whoami)" != "root" ]
then
  echo "Script must be executed as root. Aborting!"
  exit 1
fi

echo "Root privilege test passed"

if command -v lxd &> /dev/null 2>&1 || { echo >&2 "LXD/LXC not installed. Aborting!" ; exit 1; }
then

echo "LXD/LXC installation test passed"

lxd init --dump | grep "networks: \[]" &> /dev/null
if [ $? == 0 ]; then
   echo "LXD not initialize. Aborting!"
   exit 1
else

echo "LXD initialization test passed"

if ! command lxc info ${PROXY_CONTAINER} &> /dev/null 2>&1 || { echo >&2 "${PROXY_CONTAINER} container namespace exists. Aborting!" ; exit 1; }
then
    echo "${PROXY_CONTAINER} namespace test passed"
    # Create a proxy Ubuntu:20.04 container.
    lxc launch 'ubuntu:20.04' ${PROXY_CONTAINER}
fi

if ! command lxc info ${ZABBIX_CONTAINER} &> /dev/null 2>&1 || { echo >&2 "${ZABBIX_CONTAINER} container namespace exists. Aborting!" ; exit 1; }
then
    echo "${ZABBIX_CONTAINER} namespace test passed"
    # Create a proxy Ubuntu:20.04 container.
    lxc launch 'ubuntu:20.04' ${ZABBIX_CONTAINER}
fi
fi
fi

lxc config device add ${PROXY_CONTAINER} myport80 proxy listen=tcp:0.0.0.0:80 connect=tcp:127.0.0.1:80
lxc config device add ${PROXY_CONTAINER} myport443 proxy listen=tcp:0.0.0.0:443 connect=tcp:127.0.0.1:443

# Run a script in the proxy container to pull in the required packages
cat <<EOF| lxc exec ${PROXY_CONTAINER} bash
echo "Updating Proxy Container"
apt-get update
echo "Installing Nginx"
# Install Nginx
apt-get install nginx -y
cat <<\EOF_C >/etc/nginx/sites-available/zabbix
server {
        listen 80;
        listen [::]:80;
        server_name ${HOST};
        location / {
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-Proto \$scheme;
                proxy_pass http://${ZABBIX_CONTAINER}.lxd;
        }
}
EOF_C
rm /etc/nginx/sites-available/default
rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/zabbix /etc/nginx/sites-enabled/
systemctl restart nginx
EOF
# Run a script in the Zabbix container to pull in the required packages
cat <<EOF| lxc exec ${ZABBIX_CONTAINER} bash
echo "Updating Zabbix Container"
apt-get update
echo "Installing MariaDB"
apt-get install mariadb-server mariadb-client -y
echo "Configuring MariaDB"
mysql <<EOF_C
create database ${DB_NAME} character set utf8 collate utf8_bin;
create user '${DB_USER}'@'localhost' identified by '${DB_PASS}';
grant all privileges on ${DB_NAME}.* to '${DB_USER}'@'localhost';
flush privileges;
EOF_C
echo "Installing Zabbix"
wget https://repo.zabbix.com/zabbix/5.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.2-1+ubuntu20.04_all.deb -P /tmp
dpkg -i /tmp/zabbix-release_5.2-1+ubuntu20.04_all.deb
apt-get update
apt-get install zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-agent -y
echo "Creating Zabbix Tables"
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME}
echo "Configuring Nginx"
rm /etc/zabbix/nginx.conf
cat <<\EOF_C >/etc/zabbix/nginx.conf
server {
        listen 80;
        server_name ${HOST};
        root    /usr/share/zabbix;
        index   index.php;
        location = /favicon.ico {
                log_not_found   off;
        }
        location / {
                try_files       \$uri \$uri/ =404;
        }
        location /assets {
                access_log      off;
                expires         10d;
        }
        location ~ /\.ht {
                deny            all;
        }
        location ~ /(api\/|conf[^\.]|include|locale|vendor) {
                deny            all;
                return          404;
        }
        location ~ [^/]\.php(/|$) {
                fastcgi_pass    unix:/var/run/php/zabbix.sock;
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_index   index.php;
                fastcgi_param   DOCUMENT_ROOT   /usr/share/zabbix;
                fastcgi_param   SCRIPT_FILENAME /usr/share/zabbix\$fastcgi_script_name;
                fastcgi_param   PATH_TRANSLATED /usr/share/zabbix\$fastcgi_script_name;
                include fastcgi_params;
                fastcgi_param   QUERY_STRING    \$query_string;
                fastcgi_param   REQUEST_METHOD  \$request_method;
                fastcgi_param   CONTENT_TYPE    \$content_type;
                fastcgi_param   CONTENT_LENGTH  \$content_length;
                fastcgi_intercept_errors        on;
                fastcgi_ignore_client_abort     off;
                fastcgi_connect_timeout         60;
                fastcgi_send_timeout            180;
                fastcgi_read_timeout            180;
                fastcgi_buffer_size             128k;
                fastcgi_buffers                 4 256k;
                fastcgi_busy_buffers_size       256k;
                fastcgi_temp_file_write_size    256k;
        }
}
EOF_C
rm /etc/nginx/sites-available/default
rm /etc/nginx/sites-enabled/default
ln -s /etc/zabbix/nginx.conf /etc/nginx/sites-enabled/zabbix
mv /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server.conf.bak

echo "Configuring Zabbix Server"
cat <<\EOF_C >/etc/zabbix/zabbix_server.conf
LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=0
PidFile=/run/zabbix/zabbix_server.pid
SocketDir=/run/zabbix
DBName=${DB_NAME}
DBUser=${DB_USER}
DBPassword=${DB_PASS}
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
Timeout=4
FpingLocation=/usr/bin/fping
Fping6Location=/usr/bin/fping6
LogSlowQueries=3000
StatsAllowedIP=127.0.0.1
EOF_C

echo "Restarting Services"
systemctl restart zabbix-server zabbix-agent nginx php7.4-fpm
EOF

## Testing ##

echo "Testing if services are up"
lxc list "${PROXY_CONTAINER}" -c 4 | awk '!/IPV4/{ if ( $2 != "" ) print $2}' > PROXY
lxc list "${ZABBIX_CONTAINER}" -c 4 | awk '!/IPV4/{ if ( $2 != "" ) print $2}' > ZABBIX
export PROXY=$(cat PROXY)
export ZABBIX=$(cat ZABBIX)
curl --fail ${PROXY} || exit 1
curl --fail ${ZABBIX} || exit 1
echo "${PROXY} ${HOST}" >> /etc/hosts
curl --fail ${HOST} || exit 1
curl ${HOST} -v
echo "Services are up"

# Let's Encrypt
# echo 'Installing Certbot'
# cat <<EOF| lxc exec ${PROXY_CONTAINER} bash
# snap install certbot --classic
# echo 'Generating Certificates'
# certbot --nginx -d ${HOST} -m ${EMAIL} --agree-tos -n
# systemctl restart nginx
# EOF
