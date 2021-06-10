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

DEFAULT_RESULTS_DIR="results/$(date '+%y%d%mT%H%M%S')"
RESULTS_DIR=${RESULTS_DIR:-$DEFAULT_RESULTS_DIR}
HWPC_NAME=${RESULTS_DIR#*/}
RECAP_FILE=$RESULTS_DIR/benchinfo.json

### stop creterion
GRPC_BENCHMARK_STOP_CRETERION=${GRPC_BENCHMARK_STOP_CRETERION:-"duration"}
GRPC_BENCHMARK_DURATION=${GRPC_BENCHMARK_DURATION:-"200s"}
GRPC_BENCHMARK_MAX_REQUESTS=${GRPC_BENCHMARK_MAX_REQUESTS:-"1000000000"}

### workload behaviour
GRPC_BENCHMARK_MODE=${GRPC_BENCHMARK_MODE:-"const"}
GRPC_BENCHMARK_START=${GRPC_BENCHMARK_START:-"1"}
GRPC_BENCHMARK_END=${GRPC_BENCHMARK_END:-"200000"}
GRPC_BENCHMARK_STEP=${GRPC_BENCHMARK_STEP:-"10000"}

GRPC_BENCHMARK_STEP_DURATION=${GRPC_BENCHMARK_STEP_DURATION:-"10s"}

### workload payload
GRPC_SERVER_CPUS=${GRPC_SERVER_CPUS:-"1"}
GRPC_SERVER_RAM=${GRPC_SERVER_RAM:-"512m"}
GRPC_CLIENT_CONNECTIONS=${GRPC_CLIENT_CONNECTIONS:-"5"}
GRPC_CLIENT_CONCURRENCY=${GRPC_CLIENT_CONCURRENCY:-"50"}
GRPC_CLIENT_CPUS=${GRPC_CLIENT_CPUS:-"1"}
GRPC_REQUEST_PAYLOAD=${GRPC_REQUEST_PAYLOAD:-"100B"}

### HWPC Sensor Parameters
HWPC_DURATION=${HWPC_DURATION-"1000"}

# Adding the energy functions
GRPC_EXTRA_OPTIONS=""

case $GRPC_BENCHMARK_STOP_CRETERION in
"duration")
    GRPC_EXTRA_OPTIONS=$GRPC_EXTRA_OPTIONS" --duration ${GRPC_BENCHMARK_DURATION}"
    ;;
"numberOfRequests")
    GRPC_EXTRA_OPTIONS=$GRPC_EXTRA_OPTIONS" --total=$GRPC_BENCHMARK_MAX_REQUESTS"
    ;;
esac

if [ -n "$GRPC_RPS" ]; then
    GRPC_EXTRA_OPTIONS=$GRPC_EXTRA_OPTIONS" --rps $GRPC_RPS"
else
    GRPC_RPS="None"
fi

############# print Recaps

print_recap() {
    ### print the recap in a json format
    echo '{'
    echo '"stop_creterion"' :\"$GRPC_BENCHMARK_STOP_CRETERION\" ,
    echo '"benchmark_duration"' :\"$GRPC_BENCHMARK_DURATION\",
    echo '"total_requests"' :$GRPC_BENCHMARK_MAX_REQUESTS ,
    if [ -n "$rps" ]; then
        echo '"rps"' :$GRPC_RPS ,
    fi
    echo '"mode"' :\"$GRPC_BENCHMARK_MODE\" ,
    echo '"startT"' :$GRPC_BENCHMARK_START ,
    echo '"end"' :$GRPC_BENCHMARK_END ,
    echo '"step"' :$GRPC_BENCHMARK_STEP ,
    echo '"step_duration"' : \"$GRPC_BENCHMARK_STEP_DURATION\" ,
    echo '"server_cpus"' : '[' $GRPC_SERVER_CPUS ']',
    echo '"server_ram"' :\"$GRPC_SERVER_RAM\" ,
    echo '"client_connections"' :$GRPC_CLIENT_CONNECTIONS ,
    echo '"client_concurrency"' :$GRPC_CLIENT_CONCURRENCY ,
    echo '"client_cpus"' :'['$GRPC_CLIENT_CPUS ']',
    echo '"payload"' :\"$GRPC_REQUEST_PAYLOAD\" ,
    freq=$(echo $HWPC_DURATION | awk -v freq=$HWPC_DURATION "{print 1000/freq}")
    echo '"hwpc_frequency"' : $freq ,
    benchnames=${benchnames%,*}
    echo '"benchmarks"' : '[' $benchnames ']'
    echo '}'
}

##############

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
########################################################
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

####### get the max energies for the  counters reset

MAX_ENRERGY_SERVER=$(read_maxenergy $SERVER_SOCKET)
MAX_ENRERGY_CLIENT=$(read_maxenergy $CLIENT_SOCKET)
DOMAINES=$(read_maxenergy)

# Let containers know how many CPUs they will be running on
export GRPC_SERVER_CPUS
export GRPC_CLIENT_CPUS

# docker pull infoblox/ghz:0.0.1

mkdir -p "${RESULTS_DIR}"

header=$(list_global_domains $DOMAINES)
ls "${RESULTS_DIR}/energy_server.csv" 1>/dev/null 2>/dev/null || echo "name;begin;end;$header" >"${RESULTS_DIR}/energy_server.csv"
# header=$(list_domains $MAX_ENRERGY_CLIENT)
ls "${RESULTS_DIR}/energy_client.csv" 1>/dev/null 2>/dev/null || echo "name;$header" >"${RESULTS_DIR}/energy_client.csv"

run_hwpc() {
    RESULTS_DIR=$1
    RAPL_PATH=$(pwd)"/"$RESULTS_DIR
    HWPC_NAME=$2
    docker run --net=host --privileged --name powerapi-$HWPC_NAME -d --rm -v /sys:/sys -v /var/lib/docker/containers:/var/lib/docker/containers:ro -v $RAPL_PATH:/reporting/ powerapi/hwpc-sensor:latest -n machine -s rapl -e RAPL_ENERGY_PKG -e RAPL_ENERGY_DRAM -r csv -U /reporting/ -f $HWPC_DURATION
    echo powerapi-$HWPC_NAME
}

stop_hwpc() {
    RESULTS_DIR=$1
    RAPL_PATH=$(pwd)"/"$RESULTS_DIR
    HWPC_NAME=$2
    docker stop powerapi-$HWPC_NAME >/dev/null
    mv "$RAPL_PATH/rapl" "$RAPL_PATH/$HWPC_NAME.rapl"
}
benchnames=()
for benchmark in ${BENCHMARKS_TO_RUN}; do
    NAME="${benchmark##*/}"
    benchnames+=\"$NAME\"','
    echo "==> Running benchmark for ${NAME}..."
    run_hwpc $RESULTS_DIR $NAME
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
    begin_time=$(date +"%s%6N")
    touch "${RESULTS_DIR}/${NAME}".Requests.csv
    ./collect_stats.sh "${NAME}" "${RESULTS_DIR}" &

    docker run --name ghz --rm -it --network=host -v "${PWD}/proto:/proto:ro" \
        -v "${PWD}/payload:/payload:ro" \
        -v "${PWD}/${RESULTS_DIR}:/${RESULTS_DIR}" \
        --cpuset-cpus $GRPC_CLIENT_CPUS \
        chakibmed/ghz:1.0 \
        --proto=/proto/helloworld/helloworld.proto \
        --call=helloworld.Greeter.SayHello \
        --insecure \
        --concurrency="${GRPC_CLIENT_CONCURRENCY}" \
        --connections="${GRPC_CLIENT_CONNECTIONS}" \
        --load-schedule=${GRPC_BENCHMARK_MODE} \
        --load-start="${GRPC_BENCHMARK_START}" \
        --load-end="${GRPC_BENCHMARK_END}" \
        --load-step="${GRPC_BENCHMARK_STEP}" \
        --load-step-duration="${GRPC_BENCHMARK_STEP_DURATION}" \
        --data-file /payload/"${GRPC_REQUEST_PAYLOAD}" \
        --name="${NAME}" \
        --format="seperate" \
        --output="/${RESULTS_DIR}/${NAME}".Requests.csv \
        $GRPC_EXTRA_OPTIONS \
        127.0.0.1:50051 >"${RESULTS_DIR}/${NAME}".report.json

    ends_client=$(read_energy $CLIENT_SOCKET)
    ends_server=$(read_energy $SERVER_SOCKET)
    end_time=$(date +"%s%6N")
    # cat "${RESULTS_DIR}/${NAME}".report. | grep "Requests/sec" | sed -E 's/^ +/    /'
    kill -INT %1 2>/dev/null
    docker container stop "${NAME}" >/dev/null
    stop_hwpc $RESULTS_DIR $NAME

    energies_server=$(calculate_energy $begins_server $ends_server $MAX_ENRERGY_SERVER)
    energies_client=$(calculate_energy $begins_client $ends_client $MAX_ENRERGY_CLIENT)
    energies_server=$(print_append_csv $energies_server)
    energies_client=$(print_append_csv $energies_client)

    echo $NAME";"$begin_time";"$end_time";"$energies_server >>"${RESULTS_DIR}/energy_server.csv"
    echo $NAME";"$begin_time";"$end_time";"$energies_client >>"${RESULTS_DIR}/energy_client.csv"

done

# sh analyze.sh $RESULTS_DIR
print_recap >$RECAP_FILE
echo "All done, results are saved in" $RESULTS_DIR
