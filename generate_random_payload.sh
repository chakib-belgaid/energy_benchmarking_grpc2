#! /bin/bash
size=$1

header='{"name":"'
filename="payload/${size}B"

echo -n $header >$filename
dd if=/dev/urandom bs=$1 count=1 | base64 | tr -d "\n\r+=" >>$filename
echo -n '"}' >>$filename
