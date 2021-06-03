#!/bin/bash

INFLUX_TOKEN='-Orik7Z89zOARUUcv14nfDgxQU4wpJeEOujVHEXRqr0OP9WlvaJMNUB1LtJ3OsFq4acPOqYc9x4GvlHmuxB0Hw=='

# curl mbelgaid-vm.lille.grid5000.fr:8086/metrics

curl -i -XPOST --header "Authorization: Token $INFLUX_TOKEN" 'mbelgaid-vm.lille.grid5000.fr:8086/api/v2/write?org=spirals&bucket=grcp&precision=ns' \
    --data-binary @results/210106T120715/java_aot_bench.report
