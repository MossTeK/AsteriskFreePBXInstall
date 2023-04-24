#!/usr/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

#install dependencies and upgrade
sudo add-apt-repository -y ppa:ondrej/php 
sudo add-apt-repository -y universe 
sudo apt update -y 
sudo apt install -y libedit-dev nodejs npm libapache2-mod-php7.4 php7.4 php7.4-{mysql,cli,common,imap,ldap,xml,fpm,curl,mbstring,zip,gd,gettext,xml,json,snmp} lsb-release ca-certificates apt-transport-https software-properties-common gnupg2 git curl wget libnewt-dev libssl-dev libncurses5-dev subversion libsqlite3-dev build-essential libjansson-dev libxml2-dev  uuid-dev mariadb-server apache2
sudo apt upgrade -y 

#download and estract asterisk archive 
cd /usr/src/
sudo curl -O http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-18-current.tar.gz 
sudo tar -xvf asterisk-18-current.tar.gz

#Default config for asterisk 
cd /usr/src/asterisk-18.*/
sudo contrib/scripts/install_prereq install 
sudo ./configure 

#specifying make options
sudo make menuselect.makeopts  
sudo make
sudo make install 
sudo make samples
sudo make config
sudo ldconfig 

#add asterisk user
sudo groupadd asterisk 
sudo useradd -r -d /var/lib/asterisk -g asterisk asterisk 
sudo usermod -aG audio,dialout asterisk
sudo chown -R asterisk.asterisk /etc/asterisk 
sudo chown -R asterisk.asterisk /var/{lib,log,spool}/asterisk 
sudo chown -R asterisk.asterisk /usr/lib/asterisk 

#configure /etc/default/asterisk and asterisk.conf
sudo sed '/#AST_USER="asterisk"/s/^#//' -i /etc/default/asterisk 
sudo sed '/#AST_GROUP="asterisk"/s/^#//' -i /etc/default/asterisk 
sudo sed '/runuser = asterisk ; The user to run as./s/^#//' -i /etc/asterisk/asterisk.conf 
sudo sed '/rungroup = asterisk ; The group to run as./s/^#//' -i /etc/asterisk/asterisk.conf 

#restart asterisk daemon
sudo systemctl restart asterisk 
sudo systemctl enable asterisk 

#configure apache config and store default
sudo cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig 
sudo sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf 
sudo sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf 
sudo rm -f /var/www/html/index.html 
sudo unlink /etc/apache2/sites-enabled/000-default.conf 
sudo sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/apache2/php.ini 
sudo sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/cli/php.ini 
sudo sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/7.4/apache2/php.ini 

wait

#invoke FreePBX16 installation script
${DIR}/freepbx16.sh