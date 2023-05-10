#!/usr/bin/bash

#install dependencies and upgrade
sudo add-apt-repository -y ppa:ondrej/php 
sudo add-apt-repository -y universe 
sudo apt update -y 
sudo apt install -y libedit-dev nodejs npm libapache2-mod-php7.4 php7.4 php7.4-{mysql,cli,common,imap,ldap,xml,fpm,curl,mbstring,zip,gd,gettext,xml,json,snmp} lsb-release ca-certificates apt-transport-https software-properties-common gnupg2 git curl wget libnewt-dev libssl-dev libncurses5-dev subversion libsqlite3-dev build-essential libjansson-dev libxml2-dev  uuid-dev mariadb-server apache2
sudo apt upgrade -y 

#download and extract asterisk archive 
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
sudo systemctl enable asterisk 
sudo systemctl start asterisk

#configure apache config and store default
sudo cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig 
sudo sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf 
sudo sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf 
sudo rm -f /var/www/html/index.html 
sudo unlink /etc/apache2/sites-enabled/000-default.conf 
sudo sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/apache2/php.ini 
sudo sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/cli/php.ini 
sudo sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/7.4/apache2/php.ini 

#download FreePBX 16 archive
cd /usr/src/
sudo wget http://mirror.freepbx.org/modules/packages/freepbx/7.4/freepbx-16.0-latest.tgz
sudo tar xzf ./freepbx-16.0-latest.tgz 
cd /usr/src/freepbx/
sudo ./start_asterisk start 
sudo ./install -n 
sudo fwconsole ma disablerepo commercial 
sudo fwconsole ma installall 
sudo fwconsole ma delete firewall 
sudo fwconsole reload 
sudo fwconsole restart 

#finish apache config
sudo a2enmod rewrite 
sudo systemctl restart apache2 

#open ports for ssh http https and SIP
sudo ufw enable 
sudo ufw allow 5060
sudo ufw allow 5061
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo apt update

#install and configure fail2ban
sudo apt -y install fail2ban 
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo sed -i 's/\/var\/log\/asterisk\/messages/\/var\/log\/asterisk\/full/g' /etc/fail2ban/jail.local
sudo sed -i '/\[asterisk\]/ { n; s/.*/enabled = true/ }' /etc/fail2ban/jail.local
sudo systemctl enable fail2ban 
sudo systemctl start fail2ban 
