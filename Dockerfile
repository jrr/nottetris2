# FROM ubuntu:22.04
# FROM ubuntu:20.04
# FROM ubuntu:18.04
FROM ubuntu:16.04

WORKDIR /root

RUN echo "source /etc/profile.d/bash_completion.sh" >>~/.bashrc

RUN apt-get update -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y wget

RUN wget https://github.com/love2d/love/archive/refs/tags/0.7.2.tar.gz
RUN tar xfz 0.7.2.tar.gz

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
	bash-completion \
	wget \
	make \
	automake \
	libtool \
	libsdl1.2-dev \
	libopenal-dev \
	liblua5.1-0-dev \
	libdevil-dev \
	libmng-dev \
	libfreetype6-dev \
	libphysfs-dev \
	libmodplug-dev \
	libmpg123-dev \
	libvorbis-dev \
	g++

# freetype:
# newer ubuntus (>18?) use libfreetype-dev
