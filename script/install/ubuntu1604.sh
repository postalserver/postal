#!/bin/bash

set -e

apt install -y software-properties-common
apt-add-repository ppa:brightbox/ruby-ng -y
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirrors.coreix.net/mariadb/repo/10.1/ubuntu xenial main'
curl -sL https://www.rabbitmq.com/rabbitmq-release-signing-key.asc | apt-key add -
add-apt-repository 'deb http://www.rabbitmq.com/debian/ testing main'

apt update

export DEBIAN_FRONTEND=noninteractive
apt install -y ruby2.3 ruby2.3-dev build-essential mariadb-server libmysqlclient-dev rabbitmq-server nodejs git nginx

echo 'CREATE DATABASE `postal` CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;' | mysql -u root
echo 'GRANT ALL ON `postal`.* TO `postal`@`127.0.0.1` IDENTIFIED BY "p0stalpassw0rd";' | mysql -u root
echo 'GRANT ALL PRIVILEGES ON `postal-%` . * to `postal`@`127.0.0.1`  IDENTIFIED BY "p0stalpassw0rd";' | mysql -u root

rabbitmqctl add_vhost /postal
rabbitmqctl add_user postal p0stalpassw0rd
rabbitmqctl set_permissions -p /postal postal ".*" ".*" ".*"

useradd -r -m -d /opt/postal -s /bin/bash postal

gem install bundler procodile --no-rdoc --no-ri

sudo -i -u postal git clone https://github.com/atech/postal /opt/postal/app

ln -s /opt/postal/app/bin/postal /usr/bin/postal

postal bundle /opt/postal/app/vendor/bundle
postal initialize-config
postal initialize
postal start

cp /opt/postal/app/resource/nginx.cfg /etc/nginx/sites-available/default
mkdir /etc/nginx/ssl/
openssl req -x509 -newkey rsa:4096 -keyout /etc/nginx/ssl/postal.key -out /etc/nginx/ssl/postal.crt -days 365 -nodes -subj "/C=GB/ST=Example/L=Example/O=Example/CN=example.com"
service nginx reload
