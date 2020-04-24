FROM ubuntu:20.04
RUN apt-get update \
&& apt-get -y install vim sudo \
&& adduser --disabled-password --gecos '' impala \
&& echo 'impala ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
