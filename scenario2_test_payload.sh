#! /bin/bash

### Fixed number of requests
### unlimeted RPS
### unlimited duration
### Constant connections
### Variant payload
export GRPC_WORKLOAD_MODE="const"
export GRPC_BENCHMARK_STOP_CRETERION="numberOfRequests"
export GRPC_BENCHMARK_MAX_REQUESTS=10000
export HWPC_DURATION="10"
# export PAYLOADS=(100B 10KB)

DEFAULT_RESULTS_DIR="results/payloads_$(date '+%y%d%mT%H%M%S')"

BENCHMARKS_TO_RUN="${@}"
BENCHMARKS_TO_RUN="${BENCHMARKS_TO_RUN:-$(find . -maxdepth 1 -name '*_bench' -type d | sort)}"

PAYLOADS=${PAYLOADS:-$(ls payload/)}

for benchmark in ${BENCHMARKS_TO_RUN}; do

    for payload in ${PAYLOADS[@]}; do
        echo $payload
        export RESULTS_DIR=$DEFAULT_RESULTS_DIR"/$payload"
        export GRPC_REQUEST_PAYLOAD="$payload"
        ./benchmarkit.sh $benchmark
        sleep 2 
    done

done
