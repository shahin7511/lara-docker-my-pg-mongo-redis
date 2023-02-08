This directory pertains to Docker. If you are on-prem or vagrant, disregard this directory.

nginx - nginx related configs

php.ini - originally taken from docker/php:7.4-fpm; it exists in case you need to deploy a custom php.ini

supervisord.conf - settings to monitor dual process nginx/php and recover if either fails