#
# This file is being used by RIO. Changing it will impact the deployment.
#


FROM php:8.0.2-fpm

RUN apt-get update && apt-get install -y \
    git \
    curl \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    mariadb-client \
    libldap2-dev \
    libcurl4-openssl-dev \
    libcurl4 \               
    nginx \
    supervisor \
    sendmail \
    netcat \
    net-tools \
    vim \
    libpq-dev 

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg

RUN docker-php-ext-install -j$(nproc) \
    pdo pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
	ldap

RUN pecl install mongodb && docker-php-ext-enable mongodb

# Install Postgre
RUN docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-install pdo_pgsql pgsql

# PHP.INI
#
# See configuration section @ https://hub.docker.com/_/php/
#
# Do we need a custom php.ini(?)
# COPY configs/php.ini /usr/local/etc/php/php.ini
#
# otherwise, use the default production configuration thats inside the image
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"



# This is not php.ini settings
# SETUP PHP-FPM CONFIG SETTINGS (max_children / max_requests)
# zz-docker.conf already exits, we use it instead of creating a new file and copying to the container
# if you create a new file, keep in mind there is an order of operations which could rule out your params
# see: https://serverfault.com/questions/805647/override-php-fpm-pool-config-values-with-another-file
RUN echo 'pm.max_children = 50' >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo 'pm.start_servers = 5' >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo 'pm.min_spare_servers = 5' >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo 'pm.max_spare_servers = 35' >> /usr/local/etc/php-fpm.d/zz-docker.conf
    #echo 'pm.max_requests = 500' >> /usr/local/etc/php-fpm.d/zz-docker.conf


# We can not run composer as root; so we create a user that can run composer.
ARG uid=5555
ARG user=composer

RUN useradd -G www-data,root -u $uid -d /home/$user $user

RUN mkdir -p /home/$user/.composer && \
    chown -R $user:$user /home/$user

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create self signed certs for testing ssl
RUN mkdir /etc/nginx/ssl/


COPY ./configs/nginx/cert/self-signed.crt  /etc/nginx/ssl/tls.crt

COPY ./configs/nginx/cert/self-signed.key /etc/nginx/ssl/tls.key


#k8s ingress controller lacks the proper fastcgi; so we we have to handle nginx ourselves
COPY configs/nginx/default.conf /etc/nginx/sites-enabled/default
#supervisor will guarantee that both processess run together
COPY configs/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY laravel /var/www/html/laravel
COPY public /var/www/html/public

WORKDIR /var/www/html/laravel

ENV COMPOSER_ALLOW_SUPERUSER=1

### Build larvel
RUN composer install

# This fake .env is needed so RIO can run artisan key:generate
COPY ./laravel/.env.example /var/www/html/laravel/.env

# Error fix:
# The stream or file "/var/www/html/laravel/storage/logs/laravel.log" 
# could not be opened in append mode: failed to open stream: Permission denied
RUN chown -R www-data:www-data /var/www 
RUN chmod -R 755 /var/www


# This is needed so RIO does not error out with:
# No application encryption key has been specified
RUN php artisan key:generate

# Default to this during logins
WORKDIR /var/www/html/

EXPOSE 80 443
CMD ["/usr/bin/supervisord"]