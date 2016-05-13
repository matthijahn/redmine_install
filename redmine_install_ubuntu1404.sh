#!/bin/bash


# Need to be root to use this Skript

# This Scripts installs an configures a Redmine standard Server on Ubuntu 14.04 with nginx and MariaDB

# check for root user 

clear

if (( $(id -u) != 0 )); then
	echo "This script mus be run as root"
	exit 1
fi

# Install the latest updates

clear

read -p "Install latest Ubuntu updates? (y/n) " c_install_updates

#echo $c_install_updates

if [ $c_install_updates = "y" ]; then
	apt-get update
	apt-get upgrade
else
	exit 2
fi

clear

# Install all dependencies

echo "Installing following Dependencies:"
echo "autoconf"
echo "git"
echo "subversion"
echo "curl"
echo "bison"
echo "imagemagick"
echo "libmagickwand-dev"
echo "build-essential"
echo "libmariadbclient-dev"
echo "libssl-dev"
echo "libreadline-dev"
echo "libyaml-dev"
echo "zlib1g-dev"
echo "python-software-properties"

read -p "Do you want to install these Packages? (y/n) " c_install_packages

if [ $c_install_packages = "y" ]; then
	apt-get -y install autoconf git subversion curl bison imagemagick libmagickwand-dev build-essential libmariadbclient-dev libssl-dev libreadline-dev libyaml-dev zlib1g-dev python-software-properties
else
	clear
	echo "Spezialexperte"
	exit 1
fi 

clear

# create an new User

read -p "Create a new User 'Redmine' (y)es (n)o (o)ther: " c_create_user

if [ $c_create_user = "y" ]; then
	s_user_name="Redmine"
	s_user_alias="redmine"
elif [ $c_create_user = "o" ]; then
	c_user_correct="n"
	while [ $c_user_correct != "y" ]; do
		read -p "Enter full Name of new user: " s_user_name
		read -p "Enter alias of the new user: " s_user_alias
		clear
		echo "Name: $s_user_name"
		echo "Alias: $s_user_alias"
		read -p "Is this correct? Do you want to create the new user? (y/n)" c_user_correct
	done
else
	echo "Idiot"
	exit 1

fi

adduser --disabled-login --gecos '$s_user_name' $s_user_alias

clear

echo "Download Ruby from Git"
su - $s_user_alias -c "git clone git://github.com/sstephenson/rbenv.git .rbenv"
su - $s_user_alias -c "git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build"

echo "Export PATH Variables and restart the shell"

su - $s_user_alias -c "echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile"
su - $s_user_alias -c "echo 'eval "$(rbenv init -)"' >> ~/.bash_profile"
su - $s_user_alias -c "exec $SHELL -l"

echo "install Ruby and set it global"


su - $s_user_alias -c "rbenv install 2.1.2"

su - $s_user_alias -c "rbenv global 2.1.2"

su - $s_user_alias -c "ruby -v" #may build a Structure to check if ruby is correctly installed before proceeding

sleep 5

clear
echo "Download Redmine and set permissions "
su - $s_user_alias -c "svn co http://svn.redmine.org/redmine/branches/2.5-stable redmine"
su - $s_user_alias -c "mkdir -p redmine/tmp/pids redmine/tmp/sockets redmine/public/plugin_assets"
su - $s_user_alias -c "chmod -R 755 redmine/files redmine/log redmine/tmp redmine/public/plugin_assets"

clear

echo "writing puma config"
su - $s_user_alias -c "(cat <<'EOF'
#!/usr/bin/env puma

# https://gist.github.com/jbradach/6ee5842e5e2543d59adb

# start puma with:
# RAILS_ENV=production bundle exec puma -C ./config/puma.rb
EOF
) > /redmine/config/puma.rb"
su - $s_user_alias -c "echo application_path = '/home/$s_user_alias/redmine' >> /redmine/config/puma.rb"
su - $s_user_alias -c "(cat <<'EOF'
directory application_path
environment 'production'
daemonize true 
pidfile "#{application_path}/tmp/pids/puma.pid"
state_path "#{application_path}/tmp/pids/puma.state"
stdout_redirect "#{application_path}/log/puma.stdout.log", "#{application_path}/log/puma.stderr.log" 
bind "unix://#{application_path}/tmp/sockets/redmine.sock" 
EOF
) >> /redmine/config/puma.rb"


read -p "Do you want to check the puma configuration? (y/n) " c_check_puma

if [ $c_check_puma = "y" ]; then
	su - $s_user_alias -c "nano /redmine/config/puma.rb"
fi

clear
echo "MariaDB configuration"
read -p "Name of database: " s_db_name
read -p "Database username: " s_db_username
s_db_usrpw="ChangeMe"
s_db_usrpw_check="ChangeMeCheck"
while [ $s_db_userpw != $s_db_userpw_check]; do
	read -p "Enter new user password" s_db_usrpw
	clear
	read -p "Confirm new user password" s_db_usrpw_check
	clear
	if [ $s_db_userpw != $s_db_userpw_check]; then
		echo "Passwords dont match. Reenter!"
done

su - $s_user_alias -c "echo "CREATE DATABASE $s_db_name CHARACTER SET utf8;\r
CREATE USER '$s_db_username'@'localhost' IDENTIFIED BY '$s_db_userpw';\r
GRANT ALL PRIVILEGES ON $s_db_name.* TO '$s_db_username'@'localhost';" > rmdbconf.sql"

read "Check your MariaDB config? (y/n) " c_check_mariadb

if [ $c_check_mariadb = "y" ]; then
	su - $s_user_alias -c "nano rmdbconf.sql"
fi

echo "Creating new database"

su - $s_user_alias -c "cat rmdbconf.sql | mysql -u root -p"

echo "Cofiguring Database"

su - $s_user_alias -c "echo "production:\r
  adapter: mysql2\r
  database: $s_db_name\r
  host: localhost\r
  username: $s_db_username\r
  password: "$s_db_userpw"\r
  encoding: utf8" > redmine/config/database.yml"
read -p "Check DB config? (y/n) " c_check_db_config

if [ $c_check_db_config = "y" ]; then
	su - $s_user_alias -c "nano redmine/config/database.yml"
fi

clear

echo "install Gems"

su - $s_user_alias -c "echo "gem: --no-ri --no-rdoc" >> ~/.gemrc"
su - $s_user_alias -c "cd redmine && echo -e "# Gemfile.local\ngem 'puma'" >> Gemfile.local"
su - $s_user_alias -c "cd redmine && gem install bundler"
su - $s_user_alias -c "cd redmine && rbenv rehash"
su - $s_user_alias -c "cd redmine && bundle install --without development test"

echo "generate Token"

su - $s_user_alias -c "cd redmine && rake generate_secret_token"
su - $s_user_alias -c "cd redmine && RAILS_ENV=production rake db:migrate"
su - $s_user_alias -c "cd redmine && RAILS_ENV=production rake redmine:load_default_data"

echo "Configure Initscript"
(
cat <<'EOF'
#! /bin/sh
### BEGIN INIT INFO
# Provides:          redmine
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Starts redmine with puma
# Description:       Starts redmine from /home/redmine/redmine.
### END INIT INFO

# Do NOT "set -e"

EOF
) > /etc/init.d/redmine

echo "APP_USER=$s_user_alias" >> /etc/init.d/redmine

(
cat <<'EOF'
APP_NAME=redmine
APP_ROOT="/home/$APP_USER/$APP_NAME"
RAILS_ENV=production

RBENV_ROOT="/home/$APP_USER/.rbenv"
PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"
SET_PATH="cd $APP_ROOT; rbenv rehash"
DAEMON="bundle exec puma"
DAEMON_ARGS="-C $APP_ROOT/config/puma.rb -e $RAILS_ENV"
CMD="$SET_PATH; $DAEMON $DAEMON_ARGS"
NAME=redmine
DESC="Redmine Service"
PIDFILE="$APP_ROOT/tmp/pids/puma.pid"
SCRIPTNAME="/etc/init.d/$NAME"

cd $APP_ROOT || exit 1

sig () {
        test -s "$PIDFILE" && kill -$1 `cat $PIDFILE`
}

case $1 in
  start)
        sig 0 && echo >&2 "Already running" && exit 0
        su - $APP_USER -c "$CMD"
        ;;
  stop)
        sig QUIT && exit 0
        echo >&2 "Not running"
        ;;
  restart|reload)
        sig USR2 && echo "Restarting" && exit 0
        echo >&2 "Couldnt restart"
        ;;
  status)
        sig 0 && echo >&2 "Running " && exit 0
        echo >&2 "Not running" && exit 1
        ;;
  *)
        echo "Usage: $SCRIPTNAME {start|stop|restart|status}" >&2
        exit 1
        ;;
esac

:
EOF
) >> /etc/init.d/redmine

read -p "Do you want to check the redmine init configuration? (y/n) " c_check_redmine_init

if [ $c_check_redmine_init = "y" ]; then
	nano /etc/init.d/redmine
fi

chmod +x /etc/init.d/redmine
update-rc.d redmine defaults

clear

echo "server Configuration"
read -p "Enter Servername: " s_server_name

(
cat <<'EOF'
upstream puma_redmine {
EOF
) > /etc/nginx/sites-available/redmine

echo "server unix:/home/$s_user_alias/redmine/tmp/sockets/redmine.sock fail_timeout=0;" >> /etc/nginx/sites-available/redmine

(
cat <<'EOF'
  #server 127.0.0.1:3000;
}

server {
EOF
) >> /etc/nginx/sites-available/redmine

echo server_name $s_server_name;
(
cat <<'EOF'
  listen 80;
 EOF
) >> /etc/nginx/sites-available/redmine

 echo "root /home/$s_user_alias/redmine/public;" >> /etc/nginx/sites-available/redmine
 
 (
 cat <<'EOF'
   location / {
    try_files $uri/index.html $uri.html $uri @ruby;
  }

  location @ruby {
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP  $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_redirect off;
    proxy_read_timeout 300;
    proxy_pass http://puma_redmine;
  }
}
EOF
) >> /etc/nginx/sites-available/redmine

read -p "Do you want to check your nginx config? (y/n) " c_check_nginx_config

if [ $c_check_ngingx_config = "y" ]; then
	nano /etc/nginx/sites-available/redmine
fi

ln -s /etc/nginx/sites-available/redmine /etc/nginx/sites-enabled/redmine
service nginx restart

echo "Setup finished"

exit 0
