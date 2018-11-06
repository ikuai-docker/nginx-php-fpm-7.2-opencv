FROM ikuai/ubuntu_cst_18.04

MAINTAINER Dylan <bbcheng@ikuai8.com>

#############################################################################################
# App Env
ENV php_conf /etc/php/7.2/fpm/php.ini
ENV fpm_conf /etc/php/7.2/fpm/pool.d/www.conf
ENV COMPOSER_VERSION 1.7.1

#############################################################################################
# Install Basic Requirements
RUN DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get --no-install-recommends --no-install-suggests -y install software-properties-common build-essential \
	&& add-apt-repository -y ppa:ondrej/php \
	&& add-apt-repository -y ppa:nginx/stable \
	&& apt-get update \
	&& apt-get --no-install-recommends --no-install-suggests -q -y install \
		wget cmake git checkinstall gcc make autoconf libc-dev pkg-config libmcrypt-dev php-pear php-cli php-dev \
		cron \
		iputils-ping \
		net-tools \
		curl \
		vim \
		zip \
		unzip \
		python-pip \
		python-setuptools \
		nginx \
		php7.2-bcmath \
		php7.2-bz2 \
		php7.2-fpm \
		php7.2-cli \
		php7.2-dev \
		php7.2-common \
		php7.2-json \
		php7.2-opcache \
		php7.2-readline \
		php7.2-mbstring \
		php7.2-curl \
		php7.2-memcached \
		php7.2-imagick \
		php7.2-mysql \
		php7.2-zip \
		php7.2-pgsql \
		php7.2-intl \
		php7.2-xml \
		php7.2-redis \
		php7.2-gd \
		php-mongodb \
	&& mkdir -p /run/php \
	&& pip install wheel \
	&& pip install supervisor supervisor-stdout \
	&& echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d \
	&& sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${php_conf} \
	&& sed -i -e "s/memory_limit\s*=\s*.*/memory_limit = 256M/g" ${php_conf} \
	&& sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" ${php_conf} \
	&& sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" ${php_conf} \
	&& sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${php_conf} \
	&& sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.2/fpm/php-fpm.conf \
	&& sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${fpm_conf} \
	&& sed -i -e "s/pm.max_children = 5/pm.max_children = 4/g" ${fpm_conf} \
	&& sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" ${fpm_conf} \
	&& sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${fpm_conf} \
	&& sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" ${fpm_conf} \
	&& sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${fpm_conf} \
	&& sed -i -e "s/^;clear_env = no$/clear_env = no/" ${fpm_conf}

RUN yes '' | pecl install -f mcrypt-1.0.1 \
	&& echo "extension=mcrypt.so" > /etc/php/7.2/cli/conf.d/mcrypt.ini \
	&& echo "extension=mcrypt.so" > /etc/php/7.2/fpm/conf.d/mcrypt.ini
	
RUN wget https://raw.githubusercontent.com/php-opencv/php-opencv-packages/master/opencv_3.4_amd64.deb && dpkg -i opencv_3.4_amd64.deb && rm opencv_3.4_amd64.deb \
	&& git clone https://github.com/php-opencv/php-opencv.git

RUN cd php-opencv && phpize && ./configure --with-php-config=/usr/bin/php-config && make && make install

RUN echo "extension=opencv.so" > /etc/php/7.2/cli/conf.d/opencv.ini \
	&& echo "extension=opencv.so" > /etc/php/7.2/fpm/conf.d/opencv.ini

RUN cd php-opencv \
	&& checkinstall --default --type debian --install=no --pkgname php-opencv --pkgversion "7.2-3.4" --pkglicense "Apache 2.0" --pakdir ~ --maintainer "php-opencv" --addso --autodoinst make install

# Clean
RUN apt-get purge -y --auto-remove software-properties-common build-essential \
	&& apt-get autoremove -y \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
	&& curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
	&& php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
	&& php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} \
	&& rm -rf /tmp/composer-setup.php

# Nginx Upstream config
COPY ./conf/upstream.conf /etc/nginx/upstream.conf

# Add upstream config to nginx.conf
COPY ./conf/nginx.conf /etc/nginx/nginx.conf

# Supervisor config
COPY ./conf/supervisord.conf /etc/supervisord.conf

# Override default nginx welcome page
COPY html /usr/share/nginx/html

# Add Scripts
COPY ./start.sh /start.sh

EXPOSE 80 443

CMD ["/start.sh"]
