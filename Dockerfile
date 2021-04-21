FROM ghcr.io/linuxserver/baseimage-alpine-nginx:3.12

# set version label
ARG BUILD_DATE
ARG VERSION
ARG DISKOVER_VERSION
ARG ES_HOST=elasticsearch

#LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
#LABEL maintainer="AquaBearCo"

RUN echo "**** install build packages ****" && \
 apk add --no-cache --force-non-repository --virtual=build-dependencies \
	composer \
	curl \
	gcc \
	musl-dev \
	python3-dev && \
 echo "**** install runtime packages ****" && \
 apk add --no-cache \
	grep \
	ncurses \
	php7-curl \
	php7-phar \
	py3-pip \
  nano \
  php7 php7-common php7-fpm php7-opcache php7-pecl-mcrypt php7-cli php7-gd php7-mysqlnd php7-ldap php7-zip php7-xml php-xmlrpc php7-mbstring php7-json \
	python3 && \
 echo "**** install diskover ****" && \
 mkdir -p /app/diskover && \
 if [ -z ${DISKOVER_VERSION+x} ]; then \
	DISKOVER_VERSION=$(curl -sX GET "https://api.github.com/repos/AquaBearCo/diskover/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]'); \
 fi && \
 curl -o \
 /tmp/diskover.tar.gz -L \
	"https://github.com/AquaBearCo/diskover/archive/${DISKOVER_VERSION}.tar.gz" && \
 tar xf \
 /tmp/diskover.tar.gz -C \
	/app/diskover/ --strip-components=1 && \
 echo "**** install diskover-web ****" && \
 mkdir -p /app/diskover-web && \
 DISKOVER_WEB_VERSION=$(curl -sX GET "https://api.github.com/repos/AquaBearCo/diskover-web/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]'); \
 if [ "${DISKOVER_VERSION}" !=  "${DISKOVER_WEB_VERSION}" ] || [ -z ${DISKOVER_VERSION+x} ]; then \
	DISKOVER_VERSION=$(curl -sX GET "https://api.github.com/repos/AquaBearCo/diskover-web/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]'); \
 fi && \
 curl -o \
 /tmp/diskover-web.tar.gz -L \
	"https://github.com/AquaBearCo/diskover-web/archive/${DISKOVER_VERSION}.tar.gz" && \
 tar xf \
 /tmp/diskover-web.tar.gz -C \
	/app/diskover-web/ --strip-components=1 && \
 echo "**** install pip packages ****" && \
 cd /app/diskover && \
 pip3 install --no-cache-dir -r requirements.txt && \
 pip3 install rq-dashboard && \
 echo "**** install composer packages ****" && \
 cd /app/diskover-web && \
  mkdir -p /var/www/diskover-web && \
 cp composer.json /var/www/diskover-web/ && \
 cp -r /app/diskover-web/public/ /var/www/diskover-web/public/ && \
 cp -r /app/diskover-web/src /var/www/diskover-web/src && \
 cp /app/diskover-web/config/diskover-web.conf /etc/nginx/conf.d/diskover-web.conf && \
sed -i 's/abc/nginx/g' /etc/php7/php-fpm.d/www.conf && \
sed -i 's/;listen.owner = nobody/listen.owner = nginx/g' /etc/php7/php-fpm.d/www.conf && \
sed -i 's/;listen.group = nginx/listen.group = nginx/g' /etc/php7/php-fpm.d/www.conf && \
cp /var/www/diskover-web/src/diskover/Constants.php.sample /var/www/diskover-web/src/diskover/Constants.php && \
cp /var/www/diskover-web/public/smartsearches.txt.sample /var/www/diskover-web/public/smartsearches.txt && \
cp /var/www/diskover-web/public/customtags.txt.sample /var/www/diskover-web/public/customtags.txt && \
cp /var/www/diskover-web/public/extrafields.txt.sample /var/www/diskover-web/public/extrafields.txt && \
cd /var/www/diskover-web/public && \
chmod 660 *.txt && \
chown -R nginx:nginx /var/www/diskover-web/ && \
cd /var/www/diskover-web/ && \
composer install && \
sed -i "s!const ES_HOST = 'localhost';!const ES_HOST = '$ES_HOST';!g" /var/www/diskover-web/src/diskover/Constants.php && \
ln -s /var/www/diskover-web/public/dashboard.php /var/www/diskover-web/public/index.php && \
 echo "**** fix logrotate ****" && \
 sed -i "s#/var/log/messages {}.*# #g" /etc/logrotate.conf && \
 echo "**** symlink python3 ****" && \
 ln -s /usr/bin/python3 /usr/bin/python && \
 echo "**** cleanup ****" && \
 apk del --purge \
	build-dependencies && \
 rm -rf \
	/root/.cache \
	/tmp/*

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 8000
VOLUME /config
