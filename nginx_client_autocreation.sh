#!/bin/bash
#This script will automatically create new user, create DB for users' WP site
#will create nginx.conf config file

#Set mysql root password, will be used for checking data
mysql_root="pass"

#Empty check function
function empty_check {
	if [ -z $1 ]; then
		echo "Error: Variable could not be empty"
		exit 1
	fi
}

#Input data
read -p "Type name of the new user : " username
empty_check $username
if id -u $username >/dev/null 2>&1; then
        echo "User exists, please select another username"
	exit 1
fi
read -sp "Type password of the new user (will be not displayed) : " userpass
empty_check $userpass
echo -e "\n"
read -p "Type sites' domain name e.g example.com without www : " usersitename
empty_check $usersitename
read -p "Type sites' DB name : " userdbname
empty_check $userdbname
DBCHECK=`mysql -u root -p$mysql_root --skip-column-names -e "SHOW DATABASES LIKE '${username}_${userdbname}'"`
if [ "$DBCHECK" == "$username_$userdbname" ]; then
	echo "Database exist, please select another DB name"
	exit 1
fi
read -sp "Type password of the new DB (will be not displayed) : " userdbpass 
empty_check $userdbpass
echo -e "\n"

#Creating user,directories and configs
useradd $username -d /opt/sites/$username -m
echo "$username:$userpass" | chpasswd

mkdir -p /opt/sites/$username/public_html/$usersitename
cp /etc/nginx/sites-available/wp.conf /etc/nginx/sites-enabled/$usersitename.conf
sed -i -e "s/php-cgi/$username-cgi/g" /etc/nginx/sites-enabled/$usersitename.conf
sed -i -e "s/domain.tld/$usersitename/g" /etc/nginx/sites-enabled/$usersitename.conf
sed -i -e "s/change_this_directory/$username\/public_html\/$usersitename/g" /etc/nginx/sites-enabled/$usersitename.conf
cp /etc/php5/fpm/default_pool.conf /etc/php5/fpm/pool.d/$usersitename.conf
sed -i -e "s/user_name/${username}/g" /etc/php5/fpm/pool.d/$usersitename.conf

#Installing WP and configuring
wget -O /opt/sites/$username/public_html/$usersitename/latest.tar.gz "http://wordpress.org/latest.tar.gz"
tar -C /opt/sites/$username/public_html/$usersitename/ -xzvf /opt/sites/$username/public_html/$usersitename/latest.tar.gz --strip-components 1
rm /opt/sites/$username/public_html/$usersitename/latest.tar.gz

mysql -u root -p$mysql_root -e "create database ${username}_${userdbname}; \
CREATE USER $username@localhost; \
SET PASSWORD FOR $username@localhost = PASSWORD('${userdbpass}'); \
GRANT ALL PRIVILEGES ON ${username}_${userdbname}.* TO $username@localhost IDENTIFIED BY '${userdbpass}'; \
FLUSH PRIVILEGES;"

cp /opt/sites/$username/public_html/$usersitename/wp-config-sample.php /opt/sites/$username/public_html/$usersitename/wp-config.php
echo "#Your DB username is : $username" >> /opt/sites/$username/public_html/$usersitename/wp-config.php
echo "#Your DB pass is : $userdbpass" >> /opt/sites/$username/public_html/$usersitename/wp-config.php
echo "#Your DB name is : ${username}_${userdbname}" >> /opt/sites/$username/public_html/$usersitename/wp-config.php
#Restarting Services
/usr/bin/service nginx reload
/usr/bin/service php5-fpm restart

chown -R $username.$username /opt/sites/$username/
chown root.root /opt/sites/$username/
echo "Your credentials have been added to the end of wp-config.php file"
exit 0
