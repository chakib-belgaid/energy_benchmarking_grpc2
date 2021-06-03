#!/bin/bash
mkdir /tmp/influxdb 2>/dev/null
docker run --name influxdb -d --privileged --name influxdb --restart on-failure -p 8086:8086 \
    --volume /tmp/influxdb:/var/lib/influxdb2 \
    --volume /home/mbelgaid/grpc_bench/results:/results \
    -e DOCKER_INFLUXDB_INIT_USERNAME=spirals \
    -e DOCKER_INFLUXDB_INIT_PASSWORD=spirals1234 \
    -e DOCKER_INFLUXDB_INIT_ORG=my-spirals \
    influxdb:2.0.6
