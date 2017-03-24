#!/bin/bash -e

#Maintainer: Suraj Nair

if [ $(id -u) -ne 0 ]; then
	echo "Run this script as a Root user only" >&2
	exit 1
fi

read -p "Please insert the new MySQL Password for root: " MYSQLPASSWORD

read -p "Enter Wordpress Database name: " WPDBNAME

read -p "Enter Wordpress Mysql user : " WPUSER

read -p "Enter Wordpress Mysql password for above user: " WPPWD


#
#Check Error at any place and exit
#

checkerror() {

RESULT=$1

if [ $RESULT != 0 ];then
echo "Errors occured while installing Apache package, Check $LOGFILE"
exit 127
fi

}

LOGFILE=/root/installlog.txt

apt-get update >> $LOGFILE

#
#Installing Apache2 package
#

echo "Installing Apache package now...\n"

apt-get -y install apache2 >> $LOGFILE 2>&1

checkerror $?

#
#Installing MySQL 5.7 which is available in default repo for Ubuntu 16.06
#

echo " Installing MySQL 5.7 now...\n"

echo "mysql-server-5.7 mysql-server/root_password password root" | sudo debconf-set-selections
echo "mysql-server-5.7 mysql-server/root_password_again password root" | sudo debconf-set-selections
apt-get -y install mysql-server-5.7 mysql-client >> $LOGFILE 2>&1

mysql -u root -proot -e "use mysql; UPDATE user SET authentication_string=PASSWORD('$MYSQLPASSWORD') WHERE User='root'; flush privileges;" >> $LOGFILE 2>&1

checkerror $?


#
#Installing PHP 7.0 
#

echo "Installing PHP 7.0 now...\n"

apt-get install php7.0-mysql php7.0-curl php7.0-json php7.0-cgi  php7.0 libapache2-mod-php7.0 -y >> $LOGFILE 2>&1

checkerror $?

#
#Creating Wordpress DB User and passwords with privileges.
#

echo "Creating Wordpress DB Users and grating privileges with already collected information...\n"

mysql -u root -p$MYSQLPASSWORD <<MYSQL_SCRIPT 
CREATE DATABASE $WPDBNAME DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
GRANT ALL ON $WPDBNAME.* TO '$WPUSER'@'localhost' IDENTIFIED BY '$WPPWD';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

checkerror $?


#
# Installing additional PHP plugins required by Wordpress as a default set
#

echo "Installing additional PHP plugins as a default set which might be required by Wordpress...
NOTE: Each WordPress plugin has its own set of requirements. Some may require additional PHP packages to be installed. Check your plugin documentation to discover its PHP requirements "

apt-get install php-curl php-gd php-mbstring php-mcrypt php-xml php-xmlrpc -y >> $LOGFILE 2>&1

checkerror $?


#
# Restarting Apache to take new additions into effect
#

echo "Restarting Apache to get the new additions into effect..\n"

systemctl restart apache2

checkerror $?


#
# Enabling mod_rewrite and .htaccess overwrites in Apache2
#

echo "Enabling mod_rewrite and .htaccess overwrites in Apache2...\n"

cat >> /etc/apache2/apache2.conf <<EOF
<Directory /var/www/html/>
    AllowOverride All
</Directory>
EOF


a2enmod rewrite >> $LOGFILE 2>&1
checkerror $?

systemctl restart apache2 >> $LOGFILE 2>&1
checkerror $?


#
# Downloading latest Wordpress tarall and extraction
#

if [ ! -d /tmp ];then
mkdir /tmp
fi

cd /tmp

echo "Dowloading latest wordpress to tmp directory \n"

curl -O  https://wordpress.org/latest.tar.gz >> $LOGFILE 2>&1

checkerror $?

tar xzvf /tmp/latest.tar.gz >> $LOGFILE 2>&1

checkerror $?

touch /tmp/wordpress/.htaccess

chmod 660 /tmp/wordpress/.htaccess

cp /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php

mkdir /tmp/wordpress/wp-content/upgrade

cp -a /tmp/wordpress/. /var/www/html

cd -

rm -f /var/www/html/index.html

echo "Setting reasonable file and directory permissions..\n"

chown -R www-data:www-data /var/www/html

find /var/www/html -type d -exec chmod g+s {} \;

chmod g+w /var/www/html/wp-content

chmod -R g+w /var/www/html/wp-content/themes

chmod -R g+w /var/www/html/wp-content/plugins


#
# Writing Wordpress config file with proper config data
#

echo "Writing Wordpress config file with proper config data...\n"

sed -i "s/database_name_here/$WPDBNAME/" /var/www/html/wp-config.php

sed -i "s/username_here/$WPUSER/" /var/www/html/wp-config.php

sed -i "s/password_here/$WPPWD/" /var/www/html/wp-config.php


echo "----------------------------------------------

Wordpress Installation has been completed successfully

Log file is at $LOGFILE

You may need to add the ServerName directive as required in the sites-enabled and sites-available conf files with DNS working properly for that servername.

Please browse to http://your_IP to complete the installation through web interface

The information you'll need are as follows:

1) Wordpress Database Name: $WPDBNAME

2) Wordpress Database User: $WPUSER

3) Wordpress Database User Password: $WPPWD

Keep this handy with you............

Thank you!!

--------------------------------------------\n "
