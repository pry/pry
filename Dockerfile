FROM ubuntu:latest

RUN apt-get update -y
RUN apt-get install -y wget make git

RUN wget --no-check-certificate -O ruby-install-0.4.3.tar.gz https://github.com/postmodern/ruby-install/archive/v0.4.3.tar.gz
RUN tar -xzvf ruby-install-0.4.3.tar.gz
RUN cd ruby-install-0.4.3 && make install

RUN ruby-install ruby 1.9.3
RUN ruby-install ruby 2.1.1
RUN ruby-install ruby 2.1.2

ADD . /pry
WORKDIR /pry
