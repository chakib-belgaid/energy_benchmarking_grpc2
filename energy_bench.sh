#!/bin/bash

## The list of benchmarks to run
BENCHMARKS_TO_RUN="${@}"
##  ...or use all the *_bench dirs by default
BENCHMARKS_TO_RUN="${BENCHMARKS_TO_RUN:-$(find . -maxdepth 1 -name '*_bench' -type d | sort)}"

SERVER_SOCKET="${SERVER_SOCKET:-0}"
CLIENT_SOCKET="${CLIENT_SOCKET:-1}"

# pin the client and trhe server into different sockets - using dual sockets machine
GRPC_SERVER_CPUS=$(lscpu | egrep -e "NUMA node$SERVER_SOCKET" | awk -F ' ' '{printf $4}')
GRPC_CLIENT_CPUS=$(lscpu | egrep -e "NUMA node$CLIENT_SOCKET" | awk -F ' ' '{printf $4}')

RESULTS_DIR="results/$(date '+%y%d%mT%H%M%S')"
GRPC_BENCHMARK_ITERATIONS=${GRPC_BENCHMARK_DURATION:-"1"}
GRPC_BENCHMARK_DURATION=${GRPC_BENCHMARK_DURATION:-"200s"}
GRPC_SERVER_CPUS=${GRPC_SERVER_CPUS:-"1"}
GRPC_SERVER_RAM=${GRPC_SERVER_RAM:-"512m"}
GRPC_CLIENT_CONNECTIONS=${GRPC_CLIENT_CONNECTIONS:-"5"}
GRPC_CLIENT_CONCURRENCY=${GRPC_CLIENT_CONCURRENCY:-"50"}
GRPC_CLIENT_QPS=${GRPC_CLIENT_QPS:-"0"}
GRPC_CLIENT_QPS=$((GRPC_CLIENT_QPS / GRPC_CLIENT_CONCURRENCY))
GRPC_CLIENT_CPUS=${GRPC_CLIENT_CPUS:-"1"}
GRPC_REQUEST_PAYLOAD=${GRPC_REQUEST_PAYLOAD:-"100B"}

# Adding the energy functions

read_energy() {

	socket=$1
	components=$(find /sys/devices/virtual/powercap/intel-rapl/intel-rapl:$socket* -name "energy_uj")

	data=""
	for component in ${components[@]}; do

		name=$(cat ${component%energy_uj}/name)
		energy=$(cat $component)
		data=$data$component,$name,$energy\;
	done
	timestamp=$(date +"%s%6N")
	data="global:/,duration,$timestamp;${data%;}"
	echo $data
}

read_maxenergy() {
	socket=$1
	components=$(find /sys/devices/virtual/powercap/intel-rapl/intel-rapl:$socket* -name "energy_uj")

	data=""
	for component in ${components[@]}; do

		name=$(cat ${component%energy_uj}/name)
		energy=$(cat ${component%energy_uj}/max_energy_range_uj)
		data=$data$component,$name,$energy\;
	done
	data="global:/,duration,0;${data%;}"
	echo $data
}

calculate_energy() {
	begins=$1
	ends=$2
	maxenergies=$3
	energies=$(echo | awk -v begins=$begins -v ends=$ends -v maxenergies=$maxenergies 'BEGIN \
    {
    split(ends,ends1,";");
    split(begins,begins1,";");
    split(maxenergies,maxenergies1,";");


    for (i in ends1 ){
        split(ends1[i],dataends,",")
        names[dataends[1]]  = dataends[2]
        energiesends[dataends[1]] =dataends[3]
    }    

     for (i in begins1 ){
        split(begins1[i],databegins,",")
        energiesbegins[databegins[1]] =databegins[3]
    }      

    for (i in maxenergies1 ){
        split(maxenergies1[i],datamax,",")
        energiesmax[datamax[1]] =datamax[3]
    }      


    for (i in names ){

        x = energiesends[i] - energiesbegins[i]
        if (x < 0 )
            {
                x=x+energiesmax[i]
            }
        printf i","names[i]","x";" 
        }

    }')
	energies="${energies%;}"
	energies=$(echo $energies | sed -r 's/package-([0-9]+)/cpu/g')
	echo $energies

}

print_csv() {

	echo | awk -v data=$1 'BEGIN \
    {
        split(data,data1,";");
        asort(data1)
        for (line in data1 )  {
            split(data1[line],line1,",");
            path=line1[1];
            name=line1[2];
            value=line1[3];
            split(path,path1,":")
            cpu=path1[2]
            split(cpu,cpu1,"/")
            cpu=cpu1[1]
            energies[name,cpu]=value
           
        }
        asorti(energies,indices )
         for (i in indices ) {
        
           printf ";"toupper(indices[i])";"energies[indices[i]]
        }
        
    }'
}

list_domains() {
	dt=$1
	dt=$(echo $dt | sed -r 's/package-([0-9]+)/cpu/g')
	domains=$(echo | awk -v data=$dt 'BEGIN \
    {
        split(data,data1,";");
        asort(data1)
        for (line in data1 )  {
            split(data1[line],line1,",");
            path=line1[1];
            name=line1[2];
            value=line1[3];
            split(path,path1,":")
            cpu=path1[2]
            split(cpu,cpu1,"/")
            cpu=cpu1[1]
            energies[name,cpu]=value
           
        }
        asorti(energies,indices )
         for (i in indices ) {
           printf toupper(indices[i])";"
        }

    }')
	domains="${domains%;}"
	echo $domains
}

list_global_domains() {
	dt=$1
	dt=$(echo $dt | sed -r 's/package-([0-9]+)/cpu/g')
	domains=$(echo | awk -v data=$dt 'BEGIN \
    {
        
        split(data,data1,";");
        for (line in data1 )  {
            split(data1[line],line1,",");
            path=line1[1];
            name=line1[2];
            value=line1[3];
            split(path,path1,":")
            cpu=path1[2]
            split(cpu,cpu1,'//')
            cpu=cpu1[1]
            energies[name]=energies[name]+value
        }
        
        asorti(energies,indices )
         for (i in indices ) {
           printf toupper(indices[i])";"
        }
    }')
	domains="${domains%;}"
	echo $domains
}

print_append_csv() {

	energies=$(echo | awk -v data=$1 'BEGIN \
    {
        split(data,data1,";");
        asort(data1)
        for (line in data1 )  {
            split(data1[line],line1,",");
            path=line1[1];
            name=line1[2];
            value=line1[3];
            split(path,path1,":")
            cpu=path1[2]
            split(cpu,cpu1,"/")
            cpu=cpu1[1]
            energies[name,cpu]=value
           
        }
        asorti(energies,indices )
         for (i in indices ) {
        
           printf energies[indices[i]]";"
        }
        
    }')
	energies="${energies%;}"
	echo $energies
}

####### get the max energies for the  counters reset

MAX_ENRERGY_SERVER=$(read_maxenergy $SERVER_SOCKET)
MAX_ENRERGY_CLIENT=$(read_maxenergy $CLIENT_SOCKET)
DOMAINES=$(read_maxenergy)

# Let containers know how many CPUs they will be running on
export GRPC_SERVER_CPUS
export GRPC_CLIENT_CPUS

docker pull infoblox/ghz:0.0.1

mkdir -p "${RESULTS_DIR}"

header=$(list_global_domains $DOMAINES)
echo "benchmark;$header" >"${RESULTS_DIR}/energy_server.csv"
# header=$(list_domains $MAX_ENRERGY_CLIENT)
echo "benchmark;$header" >"${RESULTS_DIR}/energy_client.csv"

for benchmark in ${BENCHMARKS_TO_RUN}; do
	NAME="${benchmark##*/}"
	echo "==> Running benchmark for ${NAME}..."
	# begins_server=$(read_energy $SERVER_SOCKET)
	docker run --name "${NAME}" --rm \
		--cpuset-cpus "${GRPC_SERVER_CPUS}" \
		--memory "${GRPC_SERVER_RAM}" \
		-e GRPC_SERVER_CPUS \
		--network=host --detach --tty "${NAME}" >/dev/null

	sleep 5
	## wait for the warmup
	begins_client=$(read_energy $CLIENT_SOCKET)
	begins_server=$(read_energy $SERVER_SOCKET)

	./collect_stats.sh "${NAME}" "${RESULTS_DIR}" &
	docker run --name ghz --rm --network=host -v "${PWD}/proto:/proto:ro" \
		-v "${PWD}/payload:/payload:ro" \
		--cpuset-cpus $GRPC_CLIENT_CPUS \
		--entrypoint=ghz infoblox/ghz:0.0.1 \
		--proto=/proto/helloworld/helloworld.proto \
		--call=helloworld.Greeter.SayHello \
		--insecure \
		--concurrency="${GRPC_CLIENT_CONCURRENCY}" \
		--connections="${GRPC_CLIENT_CONNECTIONS}" \
		--qps="${GRPC_CLIENT_QPS}" \
		--duration "${GRPC_BENCHMARK_DURATION}" \
		--data-file /payload/"${GRPC_REQUEST_PAYLOAD}" \
		127.0.0.1:50051 >"${RESULTS_DIR}/${NAME}".report

	ends_client=$(read_energy $CLIENT_SOCKET)
	ends_server=$(read_energy $SERVER_SOCKET)
	cat "${RESULTS_DIR}/${NAME}".report | grep "Requests/sec" | sed -E 's/^ +/    /'
	kill -INT %1 2>/dev/null
	docker container stop "${NAME}" >/dev/null
	energies_server=$(calculate_energy $begins_server $ends_server $MAX_ENRERGY_SERVER)
	energies_client=$(calculate_energy $begins_client $ends_client $MAX_ENRERGY_CLIENT)
	energies_server=$(print_append_csv $energies_server)
	energies_client=$(print_append_csv $energies_client)

	echo $NAME";"$energies_server >>"${RESULTS_DIR}/energy_server.csv"
	echo $NAME";"$energies_client >>"${RESULTS_DIR}/energy_client.csv"

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

sh analyze.sh $RESULTS_DIR

echo "All done."
