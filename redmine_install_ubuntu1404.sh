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
#	exit 2
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
	echo "Error"
	#exit 1
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

echo "writing puma config"

su - $s_user_alias -c "echo "#!/usr/bin/env puma \r
	\r
	# https://gist.github.com/jbradach/6ee5842e5e2543d59adb \r
	\r
	# start puma with: \r
	# RAILS_ENV=production bundle exec puma -C ./config/puma.rb \r
	\r
	application_path = '/home/redmine/redmine' \r
	directory application_path \r
	environment 'production' \r
	daemonize true \r
	pidfile "#{application_path}/tmp/pids/puma.pid" \r
	state_path "#{application_path}/tmp/pids/puma.state" \r
	stdout_redirect "#{application_path}/log/puma.stdout.log", "#{application_path}/log/puma.stderr.log" \r
	bind "unix://#{application_path}/tmp/sockets/redmine.sock" " > /redmine/config/puma.rb"

sleep 5

clear

exit 0
