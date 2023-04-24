#!/usr/bin/bash

#download FreePBX 16 archive
cd /usr/src/
sudo wget http://mirror.freepbx.org/modules/packages/freepbx/7.4/freepbx-16.0-latest.tgz
sudo tar xzf ./freepbx-16.0-latest.tgz 
sudo rm -f ./freepbx-16.0-latest.tgz 
cd freepbx
sudo systemctl stop asterisk 
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

#enable isp ssh http https and ssh
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