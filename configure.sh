#!/bin/bash
set -e

SVN_BASE_DIR=/var/lib/svn

# Create a directory for a dead symlink
mkdir /var/cache/websvn/tmp

# comment out apache2 config file lines that reference the environment variables
sed -ie 's/^Mutex file/#Mutex file/' /etc/apache2/apache2.conf
sed -ie 's/^PidFile /#PidFile /' /etc/apache2/apache2.conf
sed -ie 's/^User /#User /' /etc/apache2/apache2.conf
sed -ie 's/^Group /#Group /' /etc/apache2/apache2.conf
sed -ie 's/^ErrorLog /#ErrorLog /' /etc/apache2/apache2.conf
rm -f /etc/apache2/apache2.confe

# place the hard coded environment variables
cat << EOF >> /etc/apache2/apache2.conf

# hard code the environment variables
Mutex file:/var/lock/apache2 default
PidFile /var/run/apache2/apache2.pid
User www-data
Group www-data
ErrorLog /proc/self/fd/2
CustomLog /proc/self/fd/1 combined
EOF

sed -ie 's|^CustomLog.*|CustomLog /proc/self/fd/1 combined|' /etc/apache2/conf-available/other-vhosts-access-log.conf
rm -f /etc/apache2/conf-available/other-vhosts-access-log.confe

# set the SSLSessionCache directory
sed -ie 's/\$[{]APACHE_RUN_DIR[}]/\/var\/run\/apache2/' /etc/apache2/mods-available/ssl.conf
rm -f /etc/apache2/mods-available/ssl.confe

# configure SVN_BASE_DIR for the WebSVN configuration
sed -ie 's|SVN_BASE_DIR|'${SVN_BASE_DIR}'|' \
  /etc/apache2/sites-available/000-svn.conf \
  /etc/websvn/config.php
rm -f \
  /etc/apache2/sites-available/000-svn.confe \
  /etc/websvn/config.phpe

# create apache domainname config
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
a2enconf servername.conf

# enable modules
a2enmod \
  authnz_ldap \
  dav \
  dav_svn \
  ldap \
  ssl

# Enable the site
a2ensite \
  000-default-ssl.conf \
  000-default.conf \
  000-svn.conf \
  000-websvn.conf
