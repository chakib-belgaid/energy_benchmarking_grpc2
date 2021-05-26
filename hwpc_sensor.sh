#! /bin/sh

exp_name=`cat /etc/mailname` 
exp_name=${exp_name%%\.*} 

docker run --net=host --privileged --name powerapi-$exp_name --restart unless-stopped  -d            -v /sys:/sys -v /var/lib/docker/containers:/var/lib/docker/containers:ro            -v /tmp/powerapi-sensor-reporting/$exp_name:/reporting/   powerapi/hwpc-sensor:latest   -f 100         -n machine           -s rapl -e RAPL_ENERGY_PKG  -e RAPL_ENERGY_DRAM          -r csv -U /reporting/

