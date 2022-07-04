
################################################
# Dockerized build environment (linux)
################################################

docker-build:
	docker build -f Dockerfile -t linux-env . --platform=linux/amd64

linux-env:
	docker-compose run -w /app dockerized-build
