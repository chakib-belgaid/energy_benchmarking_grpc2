#! /bin/bash

export GRPC_MODE="fix"
export GRPC_BENCHMARK_STOP_CRETERION="duration"
export GRPC_BENCHMARK_DURATION="5s"
export GRPC_REQUEST_PAYLOAD="100KB"
export HWPC_DURATION=100
./benchmarkit.sh $@
