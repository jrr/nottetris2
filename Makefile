apt-install-deps:
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
		automake \
		make \
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

0.7.2.tar.gz:
	wget https://github.com/love2d/love/archive/refs/tags/0.7.2.tar.gz


################################################
# Dockerized build environment (linux)
################################################

docker-build:
	docker build -f Dockerfile -t linux-env . --platform=linux/amd64

linux-env:
	docker-compose run -w /app dockerized-build
