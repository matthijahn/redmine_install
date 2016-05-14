#!/bin/bash

echo "Download Ruby from Git"
"git clone git://github.com/sstephenson/rbenv.git .rbenv"
"git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build"

echo "Export PATH Variables and restart the shell"

(
cat <<EOF
export PATH="/home/$s_user_alias/.rbenv/bin:$PATH"
eval "\$(rbenv init -)"
EOF
) > .bash_profile
exec $SHELL -l
#cat  bash_conf.part1 bash_conf.part > /home/$s_user_alias/.bash_profile
#chown $s_user_alias:$s_user_alias /home/$s_user_alias/.bash_profile
#su - $s_user_alias -c "exec $SHELL -l"

read -p "Do you want to check the bash configuration? (y/n) " c_check_bash

if [ $c_check_puma = "y" ]; then
	nano .bash_profile
fi

echo "install Ruby and set it global"

rbenv install 2.1.2

rbenv global 2.1.2

ruby -v #may build a Structure to check if ruby is correctly installed before proceeding

sleep 5

clear
echo "Download Redmine and set permissions "
svn co http://svn.redmine.org/redmine/branches/2.5-stable redmine
mkdir -p redmine/tmp/pids redmine/tmp/sockets redmine/public/plugin_assets
chmod -R 755 redmine/files redmine/log redmine/tmp redmine/public/plugin_assets

clear

echo "writing puma config"
(cat <<'EOF'
#!/usr/bin/env puma

# https://gist.github.com/jbradach/6ee5842e5e2543d59adb

# start puma with:
# RAILS_ENV=production bundle exec puma -C ./config/puma.rb
application_path = '/home/redmine/redmine'
directory application_path
environment 'production'
daemonize true 
pidfile "#{application_path}/tmp/pids/puma.pid"
state_path "#{application_path}/tmp/pids/puma.state"
stdout_redirect "#{application_path}/log/puma.stdout.log", "#{application_path}/log/puma.stderr.log" 
bind "unix://#{application_path}/tmp/sockets/redmine.sock" 
EOF
) > redmine/config/puma.rb


read -p "Do you want to check the puma configuration? (y/n) " c_check_puma

if [ $c_check_puma = "y" ]; then
	nano redmine/config/puma.rb
fi

clear
echo "MariaDB configuration"
read -p "Name of database: " s_db_name
read -p "Database username: " s_db_username
s_db_usrpw="ChangeMe"
s_db_usrpw_check="ChangeMeCheck"
while [ $s_db_usrpw != $s_db_usrpw_check ]; do
	read -p "Enter new user password" s_db_usrpw
	clear
	read -p "Confirm new user password" s_db_usrpw_check
	clear
	
	echo $s_db_usrpw
	echo $s_db_usrpw_check
	
	if [ $s_db_usrpw != $s_db_usrpw_check ]; then
		echo "Passwords dont match. Reenter!"
	fi
done

(cat <<EOF
CREATE DATABASE $s_db_name CHARACTER SET utf8;
CREATE USER '$s_db_username'@'localhost' IDENTIFIED BY '$s_db_usrpw';
GRANT ALL PRIVILEGES ON $s_db_name.* TO '$s_db_username'@'localhost';
EOF
) > rmdbconf.sql

read -p "Check your MariaDB config? (y/n) " c_check_mariadb

if [ $c_check_mariadb = "y" ]; then
	nano rmdbconf.sql
fi

echo "Creating new database"

cat rmdbconf.sql | mysql -u root -p

rm rmdbconf.sql

echo "Cofiguring Database"

(cat <<EOF
production:
  adapter: mysql2
  database: $s_db_name
  host: localhost
  username: $s_db_username
  password: \"$s_db_usrpw\"
  encoding: utf8
EOF
) > redmine/config/database.yml

read -p "Check DB config? (y/n) " c_check_db_config

if [ $c_check_db_config = "y" ]; then
	nano redmine/config/database.yml
fi

clear

echo "install Gems"

echo "gem: --no-ri --no-rdoc" >> ~/.gemrc
cd redmine

echo -e "\# Gemfile.local\ngem 'puma'" >> Gemfile.local #not correct generated
read -p "Check Gemfile config? (y/n) " c_check_gem_config

if [ $c_check_gem_config = "y" ]; then
	nano Gemfile.local
fi

#cp Gemfile.local /home/$s_user_alias/redmine
#chown $s_user_alias:$s_user_alias /home/$s_user_alias/redmine/Gemfile.local

gem install bundler
rbenv rehash
bundle install --without development test

echo "generate Token"

rake generate_secret_token
RAILS_ENV=production rake db:migrate
RAILS_ENV=production rake redmine:load_default_data

#cd /home/$s_user_alias/redmine && rake generate_secret_token && RAILS_ENV=production rake db:migrate && RAILS_ENV=production rake redmine:load_default_data ##fehler
