#!/bin/bash
docker pull ubuntu:18.04
# SYS_TIME is required for kudu to work. The container will be able to change the time of the host.
# -p options expose the container's ports to the host. You can add more in need.
# If you need to share files between the container and the host, add another -v option, e.g. "-v ~/Downloads/:/HostShared"
docker run --cap-add SYS_TIME --interactive --tty --name impala-dev -p 25000:25000 -p 25010:25010 -v ~/tmp/docker:/exchange -p 25020:25020 ubuntu:18.04 bash

docker ps

docker commit <CONTAINER ID> impala/boot:0.0.1

docker container stop $(docker container ls -aq)
docker container prune

docker run --cap-add SYS_TIME --interactive --tty --name impala-dev -p 25000:25000 -p 25010:25010 -v ~/tmp/docker:/exchange -p 25020:25020 impala/boot:0.0.1 bash
docker start --interactive impala-dev

docker exec -it <CONTAINER ID> bash
