# Usage:
# $ docker build -t pry .
# $ docker run -t pry
FROM ruby:2.6-stretch

RUN apt-get update -y
RUN apt-get install -y wget make git emacs-nox

ENV EDITOR emacs

ADD . /pry
WORKDIR /pry
RUN bundle install
