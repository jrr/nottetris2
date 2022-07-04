# FROM ubuntu:22.04
# FROM ubuntu:20.04
# FROM ubuntu:18.04
FROM ubuntu:16.04

WORKDIR /root

RUN echo "source /etc/profile.d/bash_completion.sh" >>~/.bashrc

RUN apt-get update -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y wget bash-completion make

COPY Makefile .

RUN make 0.7.2.tar.gz
RUN tar xfz 0.7.2.tar.gz

RUN make apt-install-deps

# freetype:
# newer ubuntus (>18?) use libfreetype-dev
