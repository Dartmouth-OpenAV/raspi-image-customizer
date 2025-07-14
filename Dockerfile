FROM ubuntu:latest

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install file unzip bc openssl fdisk -y

COPY start.sh /sbin/start.sh
RUN chmod 500 /sbin/start.sh

ENTRYPOINT ["/sbin/start.sh"]