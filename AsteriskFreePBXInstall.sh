#!/usr/bin/bash
#this script is to install and configure Asterisk18 + FreePBX

#check to see if the user is the root user
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Exiting..."
  exit 1
fi

#install dependencies and upgrade
add-apt-repository -y ppa:ondrej/php ppa:universe
apt update -y
apt install -y 'git curl wget libnewt-dev libssl-dev libncurses5-dev subversion libsqlite3-dev build-essential libjansson-dev libxml2-dev uuid-dev software-properties-common php7.4 subversion apache2 mariadb-server php7.4-cli php7.4-json php7.4-common php7.4-mysql php7.4-zip php7.4-gdphp7.4-mbstring php7.4-curl php7.4-xml php7.4-bcmath nodejs npm subversion' &&
apt upgrade -y

#download and estract asterisk archive
cd /usr/src/
curl -O http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-18-current.tar.gz
tar xvf asterisk-18-current.tar.gz

#Default config for asterisk
cd asterisk-18*/
contrib/scripts/install_prereq -y install
./configure

#specifying make options
make menuselect.makeopts
ENABLE_CATEGORIES="MENUSELECT_ADDONS"
for cat in $ENABLE_CATEGORIES ; do
menuselect/menuselect --enable-category $cat menuselect.makeopts
done
DISABLE_CATEGORIES="MENUSELECT_CORE_SOUNDS MENUSELECT_EXTRA_SOUNDS MENUSELECT_MOH"
for cat in $DISABLE_CATEGORIES ; do
menuselect/menuselect --disable-category $cat menuselect.makeopts
done
ENABLE_OPTIONS=""
ENABLE_OPTIONS+=" app_adsiprog app_alarmreceiver app_amd app_attended_transfer app_blind_transfer"
ENABLE_OPTIONS+=" app_chanisavail app_dictate app_externalivr app_festival app_getcpeid app_ices"
ENABLE_OPTIONS+=" app_image app_jack app_macro app_meetme app_minivm app_morsecode app_mp3"
ENABLE_OPTIONS+=" app_nbscat app_page app_sms app_test app_url app_waitforring app_waitforsilence"
ENABLE_OPTIONS+=" app_zapateller"
ENABLE_OPTIONS+=" cdr_csv cdr_radius cel_radius"
ENABLE_OPTIONS+=" chan_console chan_mgcp chan_motif chan_oss chan_phone chan_sip chan_skinny chan_unistim"
ENABLE_OPTIONS+=" codec_opus codec_silk codec_siren14 codec_siren7"
ENABLE_OPTIONS+=" format_ogg_speex format_vox"
ENABLE_OPTIONS+=" func_frame_trace func_pitchshift"
ENABLE_OPTIONS+=" pbx_ael pbx_dundi pbx_lua pbx_realtime"
ENABLE_OPTIONS+=" res_adsi res_ael_share res_calendar res_calendar_caldav res_calendar_ews"
ENABLE_OPTIONS+=" res_calendar_exchange res_calendar_icalendar res_chan_stats res_config_ldap"
ENABLE_OPTIONS+=" res_endpoint_stats res_monitor res_phoneprov res_pjsip_history"
ENABLE_OPTIONS+=" res_pjsip_phoneprov_provider res_pktcops res_smdi res_snmp res_srtp"
ENABLE_OPTIONS+=" res_timing_pthread"
ENABLE_OPTIONS+=" DONT_OPTIMIZE"
%if "%{debug_mode}" == "1"
ENABLE_OPTIONS+=" BETTER_BACKTRACES"
%endif
for option in $ENABLE_OPTIONS ; do
menuselect/menuselect --enable $option menuselect.makeopts
done
DISABLE_OPTIONS=""
DISABLE_OPTIONS+=" BUILD_NATIVE"
for option in $DISABLE_OPTIONS ; do
menuselect/menuselect --disable $option menuselect.makeopts
done
make
make install
make samples
make config
ldconfig

#add asterisk user
cd /root/
groupadd asterisk
useradd -r -d /var/lib/asterisk -g asterisk asterisk
usermod -aG audio,dialout asterisk
chown -R asterisk.asterisk /etc/asterisk
chown -R asterisk.asterisk /var/{lib,log,spool}/asterisk
chown -R asterisk.asterisk /usr/lib/asterisk

#configure /etc/default/asterisk and asterisk.conf
sed '/#AST_USER="asterisk"/s/^#//' -i /etc/default/asterisk
sed '/#AST_GROUP="asterisk"/s/^#//' -i /etc/default/asterisk
sed '/runuser = asterisk ; The user to run as./s/^#//' -i /etc/asterisk/asterisk.conf
sed '/rungroup = asterisk ; The group to run as./s/^#//' -i /etc/asterisk/asterisk.conf

#restart asterisk daemon
systemctl restart asterisk
systemctl enable asterisk

#configure apache config and store default
cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig
sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
rm -f /var/www/html/index.html
unlink /etc/apache2/sites-enabled/000-default.conf
sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/apache2/php.ini
sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/cli/php.ini
sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/7.4/apache2/php.ini

#download FreePBX 16 archive
cd /root/
wget http://mirror.freepbx.org/modules/packages/freepbx/7.4/freepbx-16.0-latest.tgz
tar xfz freepbx-16.0-latest.tgz
rm -f freepbx-16.0-latest.tgz
cd freepbx
systemctl stop asterisk
./start_asterisk start
./install -n
fwconsole ma disablerepo commercial
fwconsole ma installall
fwconsole ma delete firewall
fwconsole reload
fwconsole restart

#finish apache config
a2enmod rewrite
systemctl restart apache2

#enable isp ssh http https and ssh
ufw enable
ufw allow 5060
ufw allow 5061
ufw allow ssh
ufw allow http
ufw allow https
apt -y update

#install and configure fail2ban
apt -y install fail2ban
systemctl status fail2ban.service
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i 's/\/var\/log\/asterisk\/messages/\/var\/log\/asterisk\/full/g' /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban