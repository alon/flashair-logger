FROM docker.io/debian:latest
MAINTAINER alon
RUN apt update
RUN apt install -y lua5.1 lua-socket lua-posix
# TODO put a config file
ADD flashair-logger.deb /flashair-logger.deb
RUN dpkg -i /flashair-logger.deb
CMD sync_sd_to_remote
