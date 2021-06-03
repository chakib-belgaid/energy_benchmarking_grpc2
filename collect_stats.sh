#!/bin/sh

NAME=$1
REPORT_DIR=${2:-"results"}

rm -f "${REPORT_DIR}"/"${NAME}".stats

echo "timestamp;CPUPerc;MemUsage" >"${REPORT_DIR}"/"${NAME}".stats

sleep 1

while true; do
	stats=$(docker stats \
		--no-stream \
		--format "table {{.CPUPerc}};{{.MemUsage}}" \
		"${NAME}" | grep -v CPU) 2>/dev/null || break
	echo $(date +"%s")";"$stats >>"${REPORT_DIR}"/"${NAME}".stats
	sleep 5 || break
done
