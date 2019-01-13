# Usage:
# $ docker build -t pry .
# $ docker run -t pry
FROM ruby:2.6-stretch

RUN apt-get update -y
RUN apt-get install -y wget make git emacs-nox

RUN wget -O ruby-install-0.4.3.tar.gz https://github.com/postmodern/ruby-install/archive/v0.4.3.tar.gz
RUN tar -xzvf ruby-install-0.4.3.tar.gz
RUN cd ruby-install-0.4.3 && make install
RUN ruby-install ruby 1.9.3

ENV EDITOR emacs

ADD . /pry
WORKDIR /pry
RUN bundle install
