FROM ubuntu:noble

ARG NEXTCLOUD_VERSION=v31.0.7

# Variables d'environnement
ENV NEXTCLOUD_VERSION=${NEXTCLOUD_VERSION} \
    PHP_MEMORY_LIMIT=512M \
    PHP_UPLOAD_LIMIT=512M \
    OPCACHE_MEMORY_CONSUMPTION=128 \
    HOME=/var/www/html \
    DEBIAN_FRONTEND=noninteractive

# Installation des dépendances système
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    apache2 \
    php8.3 \
    php8.3-common \
    php8.3-gd \
    php8.3-zip \
    php8.3-curl \
    php8.3-xml \
    php8.3-mbstring \
    php8.3-sqlite \
    php8.3-pgsql \
    php8.3-intl \
    php8.3-imagick \
    php8.3-gmp \
    php8.3-bcmath \
    php8.3-redis \
    php8.3-soap \
    php8.3-imap \
    php8.3-opcache \
    php8.3-cli \
    php8.3-mysql \
    php8.3-ldap \
    php8.3-apcu \
    libapache2-mod-php8.3 \
    git \
    curl \
    unzip \
    ca-certificates \
    libmagickcore-6.q16-7-extra \
    postgresql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Installation de Composer
RUN curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php && \
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm /tmp/composer-setup.php

# Configuration PHP pour Nextcloud
RUN echo "memory_limit = ${PHP_MEMORY_LIMIT}" > /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "upload_max_filesize = ${PHP_UPLOAD_LIMIT}" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "post_max_size = ${PHP_UPLOAD_LIMIT}" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "max_execution_time = 360" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "max_input_time = 360" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "date.timezone = UTC" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.enable = 1" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.interned_strings_buffer = 16" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.max_accelerated_files = 20000" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.memory_consumption = ${OPCACHE_MEMORY_CONSUMPTION}" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.revalidate_freq = 1" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini

# Même configuration pour PHP CLI
RUN echo "memory_limit = ${PHP_MEMORY_LIMIT}" > /etc/php/8.3/cli/conf.d/99-nextcloud.ini && \
    echo "date.timezone = UTC" >> /etc/php/8.3/cli/conf.d/99-nextcloud.ini

# Clonage et installation de Nextcloud
RUN git clone https://github.com/nextcloud/server.git ${HOME}-temp && \
    cd ${HOME}-temp && git checkout ${NEXTCLOUD_VERSION} && cd .. && \
    cp -r ${HOME}-temp/. ${HOME}/ && \
    rm -rf ${HOME}-temp && \
    cd ${HOME} && git submodule update --init && \
    cd ${HOME} && composer install --no-dev --optimize-autoloader --no-interaction && \
    rm -rf /tmp/* /var/tmp/* ${HOME}/.cache ${HOME}/.git

# Configuration Apache pour OpenShift
RUN a2enmod rewrite headers env dir mime && \
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf && \
    sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' /etc/apache2/sites-available/000-default.conf && \
    echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    echo "ServerTokens Prod" >> /etc/apache2/apache2.conf && \
    echo "ServerSignature Off" >> /etc/apache2/apache2.conf && \
    # Configuration des logs
    ln -sf /dev/stdout /var/log/apache2/access.log && \
    ln -sf /dev/stderr /var/log/apache2/error.log && \
    # Configuration du PID file
    sed -i 's|^\(PIDFile\)|#\1|' /etc/apache2/apache2.conf && \
    echo "PidFile /tmp/apache2.pid" >> /etc/apache2/apache2.conf

# VirtualHost Nextcloud
COPY omni365-vhost.conf /etc/apache2/sites-available/nextcloud.conf
RUN a2ensite nextcloud.conf && a2dissite 000-default.conf

# Configuration CRITIQUE pour OpenShift - Permissions larges
RUN mkdir -p ${HOME}/data ${HOME}/config ${HOME}/apps2 /var/www/sessions /var/log/apache2 /var/run/apache2 && \
    # Donner des permissions complètes à tous les dossiers critiques
    chmod -R 777 ${HOME} /var/www/sessions /var/log/apache2 /var/run/apache2 && \
    # S'assurer que Apache peut écrire partout
    chown -R 1001:0 ${HOME} /var/www /var/log/apache2 /var/run/apache2 && \
    # Setgid pour conserver les permissions de groupe
    chmod g+s ${HOME} /var/www/sessions

# Nettoyage
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Script d'initialisation
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Exposition des ports
EXPOSE 8080

# Volume pour les données persistantes
VOLUME ["/var/www/html/data", "/var/www/html/config", "/var/www/html/apps2"]

WORKDIR ${HOME}

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2ctl", "-D", "FOREGROUND"]
