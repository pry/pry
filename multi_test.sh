#!/bin/bash -e

docker build -t pry/pry .
docker run -i -t -v /tmp/prytmp:/tmp/prytmp pry/pry ./multi_test_inside_docker.sh
