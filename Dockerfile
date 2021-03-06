# QGIS Server 2.18 and MapCache 1.6.1 with Apache FCGI

FROM phusion/baseimage:0.10.1

# Based off work by Sourcepole 
MAINTAINER Stefan Ziegler

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# TODO: CHANGE BACK to upgrade!!!!!!!!
#RUN apt-get update && apt-get upgrade -y
RUN apt-get update 

# Install fonts
RUN apt-get update && apt-get install -y ttf-dejavu ttf-bitstream-vera fonts-liberation ttf-ubuntu-font-family

# Install additional user fonts
RUN apt-get update && apt-get install -y fontconfig unzip
ADD fonts/* /usr/share/fonts/truetype/

RUN fc-cache -f && fc-list | sort

# Install Headless X Server
RUN apt-get update && apt-get install -y xvfb

RUN mkdir /etc/service/xvfb
ADD xvfb-run.sh /etc/service/xvfb/run
RUN chmod +x /etc/service/xvfb/run

# Install Apache FCGI
RUN apt-get update && apt-get install -y apache2 libapache2-mod-fcgid

# Install QGIS Server and MapCache
#RUN echo "deb http://qgis.org/debian-ltr xenial main" > /etc/apt/sources.list.d/qgis.org-debian.list
#RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-key CAEB3DC3BDF7FB45
RUN apt-get install -qqy software-properties-common --no-install-recommends  && \
    apt-add-repository -y ppa:ubuntugis/ubuntugis-unstable && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 314DF160    
RUN apt-get update && apt-get install -y qgis-server libapache2-mod-mapcache libmapcache1 libmapcache1-dev mapcache-cgi mapcache-tools

# Enable apache modules
RUN a2enmod rewrite
RUN a2enmod cgid
RUN a2enmod headers
RUN a2enmod mapcache

# QGIS server and MapCache configuration
# Writeable dir for qgis_mapserv.log and qgis-auth.db
RUN mkdir /var/log/qgis && chown www-data:www-data /var/log/qgis
RUN mkdir /var/lib/qgis && chown www-data:www-data /var/lib/qgis
ARG URL_PREFIX=/qgis
ARG QGIS_SERVER_LOG_LEVEL=2

#COPY mapcache.conf /etc/apache2/sites-available/mapcache.conf
RUN mkdir /mapcache
COPY mapcache.xml /mapcache/mapcache.xml

ADD qgis-server.conf /etc/apache2/sites-available/qgis-server.conf
RUN sed -i "s!@URL_PREFIX@!$URL_PREFIX!g; s!@QGIS_SERVER_LOG_LEVEL@!$QGIS_SERVER_LOG_LEVEL!g" /etc/apache2/sites-available/qgis-server.conf
RUN a2ensite qgis-server
RUN a2dissite 000-default 


# Install apache2 run script
RUN mkdir /etc/service/apache2
ADD apache2-run.sh /etc/service/apache2/run
RUN chmod +x /etc/service/apache2/run

# Docker log file
RUN mkdir /etc/service/dockerlog
ADD dockerlog-run.sh /etc/service/dockerlog/run
RUN chmod +x /etc/service/dockerlog/run

# Copy postgres service file w/ connection credentials
ADD pg_service.conf /etc/postgresql-common/

# Copy QGIS project files. See qgis-server.conf.
RUN mkdir /data
COPY qgs/*.qgs /data/

# Copy background map masking layer and seeding perimeters. 
# Masking layer MUST BE STORED IN THE DATABASE! TODO!
COPY data/*.gpkg /data/
RUN chmod 777 /data/*.gpkg

# Copy additional svg symbols
COPY symbols/grundbuchplan.zip /tmp/grundbuchplan.zip
RUN unzip -d /usr/share/qgis/svg/ /tmp/grundbuchplan.zip && \
    rm /tmp/grundbuchplan.zip && \
    chmod +rx /usr/share/qgis/svg/*.svg

# Directory for external (raster) data
RUN mkdir /geodata

# Directory for tiles
RUN mkdir /tiles

EXPOSE 80

#VOLUME ["/data"]
VOLUME ["/geodata/geodata"]
VOLUME ["/tiles"]

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Clean up downloaded packages
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*