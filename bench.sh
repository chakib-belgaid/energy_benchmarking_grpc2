#!/bin/sh

## The list of benchmarks to run
BENCHMARKS_TO_RUN="${@}"
##  ...or use all the *_bench dirs by default
BENCHMARKS_TO_RUN="${BENCHMARKS_TO_RUN:-$(find . -maxdepth 1 -name '*_bench' -type d | sort)}"

RESULTS_DIR="results/$(date '+%y%d%mT%H%M%S')"
GRPC_BENCHMARK_DURATION=${GRPC_BENCHMARK_DURATION:-"5s"}
GRPC_SERVER_CPUS=${GRPC_SERVER_CPUS:-"1"}
GRPC_SERVER_RAM=${GRPC_SERVER_RAM:-"512m"}
GRPC_CLIENT_CONNECTIONS=${GRPC_CLIENT_CONNECTIONS:-"5"}
GRPC_CLIENT_CONCURRENCY=${GRPC_CLIENT_CONCURRENCY:-"50"}
GRPC_CLIENT_QPS=${GRPC_CLIENT_QPS:-"0"}
GRPC_CLIENT_QPS=$(( GRPC_CLIENT_QPS / GRPC_CLIENT_CONCURRENCY ))
GRPC_CLIENT_CPUS=${GRPC_CLIENT_CPUS:-"1"}
GRPC_REQUEST_PAYLOAD=${GRPC_REQUEST_PAYLOAD:-"100B"}

# Let containers know how many CPUs they will be running on
export GRPC_SERVER_CPUS
export GRPC_CLIENT_CPUS

# docker pull infoblox/ghz:0.0.1

for benchmark in ${BENCHMARKS_TO_RUN}; do
	NAME="${benchmark##*/}"
	echo "==> Running benchmark for ${NAME}..."

	mkdir -p "${RESULTS_DIR}"
	docker run --name "${NAME}" --rm \
		--cpus "${GRPC_SERVER_CPUS}" \
		--memory "${GRPC_SERVER_RAM}" \
		-e GRPC_SERVER_CPUS \
		--network=host --detach --tty "${NAME}" >/dev/null
	sleep 5
	./collect_stats.sh "${NAME}" "${RESULTS_DIR}" &
	docker run --name ghz --rm --network=host -v "${PWD}/proto:/proto:ro"\
	    -v "${PWD}/payload:/payload:ro"\
		--cpus $GRPC_CLIENT_CPUS \
		chakibmed/ghz:1.0 \
		--proto=/proto/helloworld/helloworld.proto \
		--call=helloworld.Greeter.SayHello \
        --insecure \
        --concurrency="${GRPC_CLIENT_CONCURRENCY}" \
        --connections="${GRPC_CLIENT_CONNECTIONS}" \
        --duration "${GRPC_BENCHMARK_DURATION}" \
        --data-file /payload/"${GRPC_REQUEST_PAYLOAD}" \
		-O "csv" \
		127.0.0.1:50051 >"${RESULTS_DIR}/${NAME}".report
	cat "${RESULTS_DIR}/${NAME}".report | grep "Requests/sec" | sed -E 's/^ +/    /'

	kill -INT %1 2>/dev/null
	docker container stop "${NAME}" >/dev/null
done

tee $RESULTS_DIR/bench.info <<EOF
Benchmark info:
$(git log -1 --pretty="%h %cD %cn %s")
Benchmarks run: $BENCHMARKS_TO_RUN
GRPC_BENCHMARK_DURATION=$GRPC_BENCHMARK_DURATION
GRPC_SERVER_CPUS=$GRPC_SERVER_CPUS
GRPC_SERVER_RAM=$GRPC_SERVER_RAM
GRPC_CLIENT_CONNECTIONS=$GRPC_CLIENT_CONNECTIONS
GRPC_CLIENT_CONCURRENCY=$GRPC_CLIENT_CONCURRENCY
GRPC_CLIENT_QPS=$GRPC_CLIENT_QPS
GRPC_CLIENT_CPUS=$GRPC_CLIENT_CPUS
GRPC_REQUEST_PAYLOAD=$GRPC_REQUEST_PAYLOAD
EOF

# sh analyze.sh $RESULTS_DIR

echo "All done."
