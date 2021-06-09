#! /bin/bash

export GRPC_MODE="fix"
export GRPC_BENCHMARK_STOP_CRETERION="duration"
export GRPC_BENCHMARK_DURATION="5s"
./benchmarkit.sh $@
