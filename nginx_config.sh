#!/bin/sh
sudo apt install nginx -y

sudo systemctl start nginx
sudo systemctl enable nginx

sudo mv /etc/nginx/sites-available/default /etc/nginx/sites-available/backup_default