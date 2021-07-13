#! /bin/bash

export GRPC_WORKLOAD_MODE="const"
export GRPC_BENCHMARK_STOP_CRETERION="numberOfRequests"
export GRPC_BENCHMARK_DURATION="5s"
export GRPC_BENCHMARK_MAX_REQUESTS=100
export GRPC_RPS=""
export GRPC_REQUEST_PAYLOAD="100KB"
export HWPC_DURATION=10
./benchmarkit.sh $@
