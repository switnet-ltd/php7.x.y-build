#!/bin/bash
#  php-7.x.y installer for Trisquel 8
#  SwITNet Ltd © - 2019, https://switnet.net/
#
#  This script installs the build dependancies for php-7.x.y and looks
#  for previous installations it's intended to be used with ISPConfig3.
#
#  This program is under the GNU GPLv3 license.
#  It is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# Reset
Color_Off='\e[0m'       # Text Reset
# Regular Colors
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan

clear
printf "${Green}
########################################################################
                 Welcome to the \"PHP 7.x.y\" compiler
########################################################################
                    by Software, IT & Networks Ltd
${Color_Off}\n"

install_ifnot() {
if [ "$(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed")" == "1" ]; then
	echo " $1 is installed, skipping..."
    else
    	echo -e "\n---- Installing $1 ----"
		apt -yqq install $1
fi
}

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi

#System requiments
DIST=$(lsb_release -sc)
if [ $DIST = flidas ]; then
	DIST="xenial"
fi
if [ "$DIST" = "xenial" ]; then
	printf "OS: ${Blue} $(lsb_release -sd) ${Color_Off}
Good, this is a supported platform!\n"
else
	printf "OS: ${Blue} $(lsb_release -sd) ${Color_Off}
Sorry, this platform is not supported... exiting\n"
exit 1
fi
apt update -q2
install_ifnot autoconf
install_ifnot build-essential
install_ifnot bison
install_ifnot curl
install_ifnot dialog
install_ifnot nano
install_ifnot re2c
install_ifnot wget

#Selector
HEIGHT=15
WIDTH=65
CHOICE_HEIGHT=4
BACKTITLE="PHP 7.x.y selector"
TITLE="Select PHP 7 version to compile."
MENU="
Choose one of the following supported PHP releases:"

OPTIONS=(1 "7.1.X"
         2 "7.2.X"
         3 "7.3.X"
         )

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                3>&1 1>&2 2>&3 3>&- )

case $CHOICE in
        1)
            printf "We'll schedule build of: ${Green} 7.1.X ${Color_Off}\n"
            rel="7.1"
            ;;
        2)
            printf "We'll schedule build of: ${Green} 7.2.X ${Color_Off}\n"
            rel="7.2"
            ;;
        3)
            printf "We'll schedule build of: ${Green} 7.3.X ${Color_Off}\n"
            rel="7.3"
            ;;
        *)
            printf "Operation canceled, exiting...\n"
            exit
            ;;
esac
if [ "$rel" = "7.3" ]; then
dialog --stdout --title "PHP Build Mode" \
  --backtitle "PHP 7" \
  --yesno "Is this a Nextcloud instance?" 7 60
response=$?
case $response in
   0) NC_BUILD=yes ;;
   1) NC_BUILD=no ;;
   255) echo "[ESC] key pressed.";;
esac
fi
dialog --stdout --title "PHP Extension" \
  --backtitle "PHP 7" \
  --yesno "Do you need support for MaxMind?" 7 60
response=$?
case $response in
   0) MXMIND=yes ;;
   1) MXMIND=no ;;
   255) echo "[ESC] key pressed.";;
esac
dialog --stdout --title "PHP Extension" \
  --backtitle "PHP 7" \
  --yesno "Do you need support for APCu?" 7 60
response=$?
case $response in
   0) APCU=yes ;;
   1) APCU=no ;;
   255) echo "[ESC] key pressed.";;
esac
# Set variables for standar behavior
php_release=$(curl -s https://www.php.net/downloads.php | grep "php-${rel}" | cut -d\> -f2 | grep ${rel} | head -n1 | cut -d "<" -f1 | awk -F '.tar.bz2' '{print $1}')
# $rel var set by dialog
brel="${rel}.X${man_build}"
php_path=/opt/php-${brel}
cpv="$php_path/current-php"
libc=/usr/lib/x86_64-linux-gnu/libc-client.a
clibc=/usr/lib/libc-client.a
redis_path=$php_path/phpredis-${brel}
imagick_path=$php_path/imagick-${brel}
memc_path=$php_path/php-memcached-${brel}
mxmd_path=$php_path/php-maxmind-${brel}
apcu_path=$php_path/php-acpu-${brel}
php_bin=$php_path/bin
srv_run="$(ps aux | grep -v color | grep php-fpm | grep php-${brel} | cut -d "(" -f2 | cut -d ")" -f1)"

if [ -s $cpv ]; then
printf "\nCurrent installed php-${brel}: ${Yellow} $(<$cpv)${Color_Off}\n"
printf "Latest php ${brel} release available: ${Green} $php_release ${Color_Off}\n"
else
printf "${Yellow}Seems there is no php-${brel} production installed.${Color_Off}\n"
fi
# Main fork question
if [ -z "$srv_run" ]; then
	echo 'Do you wanna continue? (yes o no)'
	while [[ $cont != yes && $cont != no ]]
	do
	read cont
	if [ $cont = no ]; then
	echo "Ok, come back when you are ready."
	exit
	elif [ $cont = yes ]; then
	echo "Let's get to it ..."
	fi
	done
else
	printf "\nAlso seems to be a service(s) already running:\n"
	printf "${Green}$srv_run ${Color_Off}\n"
	printf "\nPlease be advice that overwriting the ${Cyan}php-${brel}${Color_Off} build will set those sites using it ${Yellow}unavailable${Color_Off}!!\n"
	echo "Do you wanna overwrite the current php-${brel}? (yes o no)"
		while [[ "$cont" != "yes" && "$cont" != "no" ]]
		do
		read cont
		if [ "$cont" = "no" ]; then
			printf " --> Do you want compile a maintenance build ( ${Blue}_mbuild ${Color_Off} )? (yes o no)\n"
			while [[ "$mbuild" != "yes" && "$mbuild" != "no" ]]
			do
			read mbuild
			if [ "$mbuild" = "yes" ]; then
				cont="yes"
				man_build="_mbuild"
				echo "Building php-${brel}"
			elif [ "$mbuild" = "no" ]; then
				echo "No build resolved, see you next time."
				exit
			exit
			fi
			done
		elif [ "$cont" = "yes" ]; then
		echo "Let's get to it ..."
		fi
		done
fi
#Reset variables after selection.
brel=${rel}.X${man_build}
php_path=/opt/php-${brel}
cpv="$php_path/current-php"
libc=/usr/lib/x86_64-linux-gnu/libc-client.a
clibc=/usr/lib/libc-client.a
redis_path=$php_path/phpredis-${brel}
imagick_path=$php_path/imagick-${brel}
memc_path=$php_path/php-memcached-${brel}
mxmd_path=$php_path/php-maxmind-${brel}
apcu_path=$php_path/php-acpu-${brel}
php_bin=$php_path/bin

printf "${Yellow}# Installing dependencies...${Color_Off}\n"
apt -yqq install libfcgi-dev libfcgi0ldbl libjpeg62-dbg libmcrypt-dev \
libssl-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev \
libjpeg-dev libpng12-dev libfreetype6-dev libreadline-dev \
libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libzip-dev libmemcached-dev \
libcurl4-openssl-dev &>/dev/null
if [ -d /usr/include/curl ]; then
echo "CURL symlink in place"
else
echo "Creating CURL symlink"
ln -s  /usr/include/x86_64-linux-gnu/curl  /usr/include/curl
fi

if [ -f $libc ]; then
echo "The c-client symbolic link already exists"
else
echo "Creating missing c-client symbolic link"
ln -s $clibc $libc
fi

if [ "$cont" = "yes" ]; then
printf "${Yellow}Removing previous ${brel} release..${Color_Off}\n"
/etc/init.d/php-${brel}-fpm force-quit 2>/dev/null
update-rc.d php-${brel}-fpm disable 2>/dev/null
systemctl stop php-${brel}-fpm 2>/dev/null
systemctl disable php-${brel}-fpm 2>/dev/null
rm -rf /usr/local/src/php5-build/php-${brel} 2>/dev/null
rm -rf $php_path 2>/dev/null
rm -rf /etc/init.d/php-${brel}-fpm 2>/dev/null
rm -rf /usr/local/src/php5-build/php-${brel}.tar.bz2 2>/dev/null
fi

#Build env
mkdir -p $php_path/var/run/php
if [ -d /usr/local/src/php5-build ]; then
	echo ""
else
	mkdir /usr/local/src/php5-build
fi
cd /usr/local/src/php5-build
#Download
wget --limit-rate=5m -c https://www.php.net/distributions/$php_release.tar.bz2 -O php-${brel}.tar.bz2
tar jxf php-${brel}.tar.bz2
rm -rf php-${brel}.tar.bz2
mv $php_release php-${brel}
cd php-${brel}/

./configure --prefix=$php_path --with-pdo-pgsql --with-zlib-dir \
--with-freetype-dir --enable-mbstring --with-libxml-dir=/usr --enable-soap \
--enable-calendar --with-curl --with-libzip --with-gd --enable-intl \
--with-pgsql --disable-rpath --enable-inline-optimization --with-bz2 \
--with-zlib --enable-sockets --enable-sysvsem --enable-sysvshm --enable-pcntl \
--enable-mbregex --enable-exif --enable-bcmath --with-mhash --enable-zip \
--with-pcre-regex --with-pdo-mysql --with-mysqli \
--with-mysql-sock=/var/run/mysqld/mysqld.sock --with-jpeg-dir=/usr \
--with-png-dir=/usr --with-openssl --with-readline \
--with-fpm-user=www-data --with-fpm-group=www-data \
--with-libdir=/lib/x86_64-linux-gnu --enable-ftp --with-imap \
--with-imap-ssl --with-kerberos --with-gettext --with-xmlrpc --with-xsl \
--enable-opcache --enable-fpm | grep "Thank you for using PHP."

if [ $? == 0 ]; then
    printf "\n${Green}Configuration has succesfully finished, now let's do \`make\`. \
    \nThis can take several minutes...${Color_Off}\n"
    make -s
else
    printf "\n${Red}Configure failed, check log. Exiting...${Color_Off}\n"
    exit 1
fi

printf "\n${Yellow}...and finally let us install :) ${Color_Off}\n"
make install

cp /usr/local/src/php5-build/php-${brel}/php.ini-production $php_path/lib/php.ini
cp $php_path/etc/php-fpm.conf.default $php_path/etc/php-fpm.conf
cp $php_path/etc/php-fpm.d/www.conf.default $php_path/etc/php-fpm.d/www.conf
echo $php_release > $php_path/current-php

#SO - PHP - 7.0.X =>  9000
if [ ${brel} = "7.3.X_mbuild" ]; then
	sed -i 's|listen = 127.0.0.1:9000|listen = 127.0.0.1:8992|g' $php_path/etc/php-fpm.d/www.conf
	#PHP Build 7.3.X_mbuild => 8992
elif [ ${brel} = "7.2.X_mbuild" ]; then
	sed -i 's|listen = 127.0.0.1:9000|listen = 127.0.0.1:8993|g' $php_path/etc/php-fpm.d/www.conf
	#PHP Build 7.2.X_mbuild => 8993
elif [ ${brel} = "7.1.X_mbuild" ]; then
	sed -i 's|listen = 127.0.0.1:9000|listen = 127.0.0.1:8994|g' $php_path/etc/php-fpm.d/www.conf
	#PHP Build 7.1.X_mbuild => 8994
elif [ ${brel} = "7.3.X" ] && [ ${NC_BUILD} = "yes" ]; then
	sed -i 's|listen = 127.0.0.1:9000|listen = 127.0.0.1:8995|g' $php_path/etc/php-fpm.d/www.conf
	#PHP Build 7.3.X => 8995
elif [ ${brel} = "7.3.X" ]; then
	sed -i 's|listen = 127.0.0.1:9000|listen = 127.0.0.1:8996|g' $php_path/etc/php-fpm.d/www.conf
	#PHP Build 7.3.X => 8996
elif [ ${brel} = "7.2.X" ]; then
	sed -i 's|listen = 127.0.0.1:9000|listen = 127.0.0.1:8997|g' $php_path/etc/php-fpm.d/www.conf
	#PHP Build 7.2.X => 8997
elif [ ${brel} = "7.1.X" ]; then
	sed -i 's|listen = 127.0.0.1:9000|listen = 127.0.0.1:8998|g' $php_path/etc/php-fpm.d/www.conf
	#PHP Build 7.1.X => 8998
##PHP Build 5.6.X => 8999 - Deprecated
else
	echo "No compatible version exiting.."
	echo "Please report any issue to: https://switnet.net"
	#exit
fi

sed -i "s|;pid = run/php-fpm.pid|pid = run/php/php-fpm-${brel}.pid|g" $php_path/etc/php-fpm.conf
sed -i "s|;include=etc/fpm.d/\*.conf|include=/opt/php-${brel}/etc/php-fpm.d/\*.conf|g" $php_path/etc/php-fpm.conf
sed -i "s|memory_limit = 128M|memory_limit = 256M|" $php_path/lib/php.ini
kill $(ps aux | grep "[p]hp${brel}-fpm.conf" | awk '{print $2}')

cat  << SYSTEMD > /lib/systemd/system/php-${brel}-fpm.service
[Unit]
Description=The PHP ${brel} FastCGI Process Manager
After=network.target

[Service]
Type=simple
PIDFile=$php_path/var/run/php-fpm.pid
ExecStart=$php_path/sbin/php-fpm --nodaemonize --fpm-config $php_path/etc/php-fpm.conf
ExecReload=/bin/kill -USR2 \$MAINPID

[Install]
WantedBy=multi-user.target
SYSTEMD
chmod 755 /lib/systemd/system/php-${brel}-fpm.service
systemctl enable php-${brel}-fpm.service
systemctl start php-${brel}-fpm.service

#Redis
printf "\n${Yellow}Adding Redis Support${Color_Off}\n
Deleting previous builds"
rm -rf $redis_path
apt-get install -yqq redis-server
git clone -b develop https://github.com/phpredis/phpredis.git $redis_path
cd $redis_path ; $php_bin/phpize
PATH=$php_bin:$PATH ./configure -q
make -s
make install
cat  << PHP_RS >> $php_path/lib/php.ini
;;; Redis ;;;
extension=redis.so
;;; OPCache ;;;
zend_extension=opcache.so
PHP_RS

#IMagick
printf "\n${Yellow}Adding IMagick Support${Color_Off}\n
Deleting previous builds"
rm -rf $imagick_path
apt-get install -yqq libmagickwand-dev
git clone -b master https://github.com/mkoppanen/imagick.git $imagick_path
cd $imagick_path ; $php_bin/phpize
PATH=$php_bin:$PATH ./configure -q
make -s
make install
echo \
';;; Imagick ;;;
extension=imagick.so' >> $php_path/lib/php.ini

# Memcache
printf "\n${Yellow}Adding IMagick Support${Color_Off}\n
Deleting previous builds"
rm -rf $memc_path
git clone -b master https://github.com/php-memcached-dev/php-memcached $memc_path
cd $memc_path ; $php_bin/phpize
PATH=$php_bin:$PATH ./configure --with-php-config=$php_bin/php-config -q
make -s
make install
echo \
';;; Memcached ;;;
extension=memcached.so' >> $php_path/lib/php.ini

if [ "$APCU" = "yes" ]; then
# APCu
printf "\n${Yellow}Adding ACPU Support${Color_Off}\n
Deleting previous builds"
rm -rf $apcu_path
git clone -b master https://github.com/krakjoe/apcu $apcu_path
cd $apcu_path ; $php_bin/phpize
PATH=$php_bin:$PATH ./configure --with-php-config=$php_bin/php-config -q
make -s
make install
cat  << PHP_AU >> $php_path/lib/php.ini
;;; APCu ;;;
extension=apcu.so
apc.enabled=1
apc.enable_cli=1
apc.shm_size=128M
apc.ttl=7200
PHP_AU
fi

# -xDebug
#cd /opt/php-7.3.X/etc
#pecl -C ./pear.conf update-channels
#pecl -C ./pear.conf install xdebug
#echo "zend_extension=/opt/php-7.3.X/lib/php/extensions/no-debug-non-zts-20160303/xdebug.so" | tee -a /opt/php-7.3.X/lib/php.ini

if [ "$MXMIND" = "yes" ]; then
# -MaxMind
install_ifnot libmaxminddb-dev
git clone https://github.com/maxmind/MaxMind-DB-Reader-php $mxmd_path
cd $mxmd_path/ext ; $php_bin/phpize
PATH=$php_bin:$PATH ./configure --with-php-config=$php_bin/php-config -q
make -s
make install
echo \
';;; MaxmindDB ;;;
extension=maxminddb.so' >> $php_path/lib/php.ini
fi

cd $php_bin
printf "\n${Blue}$(./php -v)${Color_Off}\n"
printf "${Red}$(./php --ri redis | head -n 7)${Color_Off}\n"
printf "${Yellow}$(./php --ri imagick | head -n 10)${Color_Off}\n"
printf "${Green}$(./php --ri memcached | head -n 6)${Color_Off}\n"
printf "${Blue}$(./php --ri apcu | head -n 6)${Color_Off}\n"
if [ "$MXMIND" = "yes" ]; then
printf "${Purple}$(./php --ri maxminddb | head -n 6)${Color_Off}\n"
fi

service php-${brel}-fpm restart && \
service apache2 restart

########################################################################
#                 Nextcloud configuration                              #
########################################################################
if [ "${NC_BUILD}" = "yes" ]; then

dialog --title "PHP 7.3.X services active" --msgbox \
"$(netstat -lp | grep 899 | awk '{print $4}'| sed -e "s|localhost:8992|php-7.3.X_mbuild - Maintenance Build|" -e "s|localhost:8995|php-7.3.X - Production Build|")" \
7 50
#printf "${Cyan}$(netstat -lp | grep 899 | awk '{print $4}'| \
#		sed -e "s|localhost:8992|php-7.3.X_mbuild - Maintenance Build|" -e \
#		"s|localhost:8995|php-7.3.X - Production Build|")${Color_Off}\n"

#Selector
HEIGHT=15
WIDTH=65
CHOICE_HEIGHT=4
BACKTITLE="PHP 7.3.X - Nextcloud"
TITLE="PHP 7 - Selector"
MENU="
Select the PHP 7 you have previously build to use Nextcloud:"

OPTIONS=(1 "7.3.X (Production)"
         2 "7.3.X_mbuild (Maintenance)"
         )

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                3>&1 1>&2 2>&3 3>&- )

case $CHOICE in
        1)
            printf "We'll schedule setup of: ${Green} 7.3.X ${Color_Off}\n"
            nrel="7.3.X"
            ;;
        2)
            printf "We'll schedule setup of: ${Green} 7.3.X_mbuild ${Color_Off}\n"
            nrel="7.3.X_mbuild"
            ;;
        *)
            printf "Operation canceled, exiting...\n"
            exit
            ;;
esac

PHP_POOL_DIR=/opt/php-${nrel}/etc/php-fpm.d
PHP_INI=/opt/php-${nrel}/lib/php.ini
NC_SYSTEM_FILE=/lib/systemd/system/nc_php-${nrel}-fpm.service
mkdir /run/php
average_php_memory_requirement=50
available_memory=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
PHP_FPM_MAX_CHILDREN=$((available_memory/average_php_memory_requirement))
if [ "$nrel" = "7.3.X" ]; then
UPORT=8995
elif [ "$nrel" = "7.3.X_mbuild" ]; then
UPORT=8992
else
echo "Port not defined"
echo "Please report any issue to: https://switnet.net"
fi

calculate_max_children() {
# Calculate max_children depending on RAM
# Tends to be between 30-50MB
printf "${Cyan}Automatically configures pm.max_children for php-fpm...${Color_Off}\n"
if [ $PHP_FPM_MAX_CHILDREN -lt 8 ]
then
msg_box "The current max_children value available to set is $PHP_FPM_MAX_CHILDREN, and with that value PHP-FPM won't function properly.
The minimum value is 8, and the value is calculated depening on how much RAM you have left to use in the system."
exit 1
else
    printf "${Green}pm.max_children was set to $PHP_FPM_MAX_CHILDREN${Color_Off}\n"
fi
}
calculate_max_children
systemctl stop php-${nrel}-fpm.service
systemctl disable php-${nrel}-fpm.service
a2enmod proxy proxy_fcgi

# Set up a php-fpm pool with a unixsocket
cat << POOL_CONF > "$PHP_POOL_DIR/nextcloud_${nrel}.conf"
[Nextcloud ${nrel} ]
user = www-data
group = www-data
listen = 127.0.0.1:$UPORT
listen.owner = www-data
listen.group = www-data
pm = dynamic
;; max_children is set dynamically with calculate_max_children()
pm.max_children = $PHP_FPM_MAX_CHILDREN
pm.start_servers = 3
pm.min_spare_servers = 2
pm.max_spare_servers = 3
pm.max_requests = 500
env[HOSTNAME] = $(hostname -f)
env[PATH] = /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
security.limit_extensions = .php
php_admin_value [cgi.fix_pathinfo] = 1
POOL_CONF

cat << NC_PHP >> "$PHP_INI"
; Nextcloud custom php configurations
opcache.enable=1
opcache.enable_cli=1
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.memory_consumption=128
opcache.save_comments=1
opcache.revalidate_freq=1
NC_PHP
sed -i "s|memory_limit = .*|memory_limit = 512M|" $PHP_INI

cat << NC_SYSTEM_PHP > "$NC_SYSTEM_FILE"
[Unit]
Description=The PHP 7.3 FastCGI Process Manager
After=network.target

[Service]
Type=simple
PIDFile=/opt/php-${nrel}/var/run/nc_php-fpm_${nrel}.pid
ExecStart=/opt/php-${nrel}/sbin/php-fpm --nodaemonize --fpm-config $PHP_POOL_DIR/nextcloud_${nrel}.conf
ExecReload=/bin/kill -USR2 \$MAINPID

[Install]
WantedBy=multi-user.target
NC_SYSTEM_PHP

chmod 755 /lib/systemd/system/nc_php-${nrel}-fpm.service
systemctl enable nc_php-${nrel}-fpm.service
systemctl start nc_php-${nrel}-fpm.service

##Set Apache2 file
echo "We have found the following Nextcloud instances using PHP 7.3:"
NC_INST="$(grep -r "Dav off" /etc/apache2/sites-enabled/* | cut -d ":" -f1 | xargs -L1 grep -le 8995 -le 8992)"
printf "${Green}$NC_INST${Color_Off}\n"

if [ "$nrel" = "7.3.X" ]; then
	NC_2PROD="$(grep -r "Dav off" /etc/apache2/sites-enabled/* | cut -d ":" -f1 | xargs -L1 grep -le 8992)"
	echo "We'll only configure:"
	printf "${Blue}$NC_2PROD${Color_Off}\n"
	read -p "Please confirm they are the ones to be configured, once you're ready presss [Enter] to complete the setup..."
	grep -r "Dav off" /etc/apache2/sites-enabled/* | cut -d ":" -f1 | xargs -L1 grep -le 8992 | xargs -L1 sed -i "s|8992|$UPORT|"
elif [ "$nrel" = "7.3.X_mbuild" ]; then
	NC_2MANT="$(grep -r "Dav off" /etc/apache2/sites-enabled/* | cut -d ":" -f1 | xargs -L1 grep -le 8995)"
	echo "We'll only configure:"
	printf "${Blue}$NC_2MANT${Color_Off}\n"
	read -p "Please confirm they are the ones to be configured, once you're ready presss [Enter] to complete the setup..."
	grep -r "Dav off" /etc/apache2/sites-enabled/* | cut -d ":" -f1 | xargs -L1 grep -le 8995 | xargs -L1 sed -i "s|8995|$UPORT|"
else
	echo "Apache not configured."
	echo "Please report any issue to: https://switnet.net"
fi

service nc_php-${nrel}-fpm restart && \
service apache2 restart
fi

echo "Creating symlinks..."
create_symlink() {
	if [ -f $1 ]; then
		ln -s $1 $2
	fi
}
clear_name {
	pbin=$(echo ${brel} | awk '{print tolower($0)}' | sed 's|[^0-9^Aa-Az]*||g' | sed 's|build||')
}

clear_name
create_symlink /opt/php-${brel}/bin/php /usr/bin/php${pbin}

ls -l /usr/bin/php${pbin}

printf "${Blue}
########################################################################
                    Installation complete!!
           for customized support: http://switnet.net
########################################################################
${Color_Off}\n"
