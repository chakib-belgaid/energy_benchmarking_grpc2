#! /bin/bash

dir="210106T181844"
bucketname=$dir

docker exec -it influxdb \
    influx bucket create \
    -o spirals \
    -t 'suI5rjdueTC4sPw33XKzngAnrqFwhMvJ2t4ikqMlT465PcHftUC_TmbpdERu3K3UqSWakeuJcLqz_jzkQl2LeA==' \
    --name $bucketname \
    --description "test" || echo it already exists

for i in $(ls /home/mbelgaid/grpc_bench/results/$dir/*.report); do
    name=${i##*/}
    name=${name%%.*}
    echo $name

    FILE="/results/$dir/$name.report"
    docker exec -it influxdb \
        influx write \
        -b $bucketname \
        -o spirals \
        -t 'suI5rjdueTC4sPw33XKzngAnrqFwhMvJ2t4ikqMlT465PcHftUC_TmbpdERu3K3UqSWakeuJcLqz_jzkQl2LeA==' \
        -p ns \
        --format=lp \
        -f $FILE

    FILE="/results/$dir/$name.rapl"
    docker exec -it influxdb \\
        influx write \
        -b $bucketname \
        -o spirals \
        -t 'suI5rjdueTC4sPw33XKzngAnrqFwhMvJ2t4ikqMlT465PcHftUC_TmbpdERu3K3UqSWakeuJcLqz_jzkQl2LeA==' \
        -p ms \
        --format=csv \
        --header "#constant measurement,power_$name" \
        --header "#datatype dateTime:number,ignore,ignore,tag,tag,long,long,long,long" \
        -f $FILE

done
