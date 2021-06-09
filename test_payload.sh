#! /bin/bash

### Fixed number of requests
### unlimeted RPS
### unlimited duration
### Constant connections
### Variant payload
export GRPC_BENCHMARK_MODE="const"
export GRPC_BENCHMARK_STOP_CRETERION="numberOfRequests"
export GRPC_BENCHMARK_MAX_REQUESTS=1000

DEFAULT_RESULTS_DIR="results/payloads_$(date '+%y%d%mT%H%M%S')"

for payload in $(ls payload/); do
    echo $payload
    export RESULTS_DIR=$DEFAULT_RESULTS_DIR"/$payload"
    export GRPC_REQUEST_PAYLOAD="$payload"
    ./benchmarkit.sh $@
done
