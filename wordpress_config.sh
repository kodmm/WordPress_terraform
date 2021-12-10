#!/bin/sh
sudo apt install php7.4-fpm -y
sudo apt install php7.4-xml php7.4-curl php7.4-gd php7.4-mbstring php7.4-readline -y 
sudo apt install php7.4-bz2 php7.4-zip php7.4-json php7.4-opcache -y 
sudo apt install php-mysql -y
sudo wget -O /tmp/latest.tar.gz https://wordpress.org/latest.tar.gz

sudo tar zxf /tmp/latest.tar.gz -C /var/www/html/

sudo chown -R www-data:www-data /var/www/html/wordpress/

sudo mv /home/ubuntu/default /etc/nginx/sites-available/


sudo systemctl restart nginx