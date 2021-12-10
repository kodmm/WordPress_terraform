CREATE DATABASE wordpress;

CREATE USER 'wordpress'@'%' IDENTIFIED BY 'wordpress';
GRANT ALL ON wordpress.* TO 'wordpress'@'%' WITH GRANT OPTION;
