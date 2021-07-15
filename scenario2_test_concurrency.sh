#! /bin/bash

### unlimeted RPS
### Fixed  duration 200 s 
### one conection per client 
### fixed payload 

export GRPC_WORKLOAD_MODE="const"
export GRPC_BENCHMARK_STOP_CRETERION="duration"
export GRPC_BENCHMARK_DURATION="200s"
export GRPC_REQUEST_PAYLOAD="1KB"
export HWPC_DURATION="10"
 
# export PAYLOADS=(100B 10KB)

DEFAULT_RESULTS_DIR="results/concurrency_$(date '+%y%d%mT%H%M%S')"

BENCHMARKS_TO_RUN="${@}"
BENCHMARKS_TO_RUN="${BENCHMARKS_TO_RUN:-$(find . -maxdepth 1 -name '*_bench' -type d | sort)}"

NUMBER_CLIENTS=(1 `seq 5  5  200 `)
for benchmark in ${BENCHMARKS_TO_RUN}; do

    for numberclients in ${NUMBER_CLIENTS[@]}; do
        echo $numberclients

        export RESULTS_DIR=$DEFAULT_RESULTS_DIR"/$numberclients"
        export GRPC_CLIENT_CONCURRENCY="$numberclients"
        ./benchmarkit.sh $benchmark
        sleep 2 
    done
done
