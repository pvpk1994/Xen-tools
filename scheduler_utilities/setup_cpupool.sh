#!/bin/bash

# This script sets up cpupool by taking following inputs:
# NUM_CPUS:	Number of CPUs to be assigned to this pool
# CPU_RANGE:	list of CPUs to be added to the pool
# POOL_NAME:	Name of the pool
# SCHED:	Name of the scheduler to operate on this pool

# only root user privilieges to use xl toolstack
if [[ $EUID -ne 0 ]]; then
	echo "[*] Script can only be run as a root!"
	exit 1
fi

NUM_CPUS="$1"
CPU_RANGE="$2"
POOL_NAME="$3"
SCHED="$4"

xl_cpupool_create() {
	for cpu in "${CPU_LIST[@]}"; do
		echo "[*] Removing CPU ${cpu} from Pool-0"
		xl cpupool-cpu-remove Pool-0 ${cpu}
	done

	echo "[*] Creating $POOL_NAME for scheduler $SCHED"
	xl cpupool-create name=\"${POOL_NAME}\" sched=\"${SCHED}\"

	for cpu in "${CPU_LIST[@]}"; do
		echo "[*] Adding CPU ${cpu} to ${POOL_NAME}"
		xl cpupool-cpu-add ${POOL_NAME} ${cpu}
	done
}

cpu_parser() {
	# CPU Range: Either 1-3 (for multi-cpu) (or) 4 (for single-cpu)
	if [[ "$NUM_CPUS" == "1" && "$CPU_RANGE" =~ ^[0-9]+$ ]]; then
		CPU_LIST="$CPU_RANGE"

	elif [[ "$NUM_CPUS" > 1 && "$CPU_RANGE" =~ ^([0-9]+)-([0-9]+)$ ]]; then
		IFS='-' read -r START END <<< "$CPU_RANGE"
		readarray -t CPU_LIST < <(seq "$START" "$END")
		#declare -p CPU_LIST

		if (( START > END || END > NUM_CPUS )); then
			echo "[-] Invalid CPU range provided"
			exit 1
		fi

	else
		echo "[-] Error: CPU_RANGE must be either a single-CPU/multi-CPU"
		usage
		exit 1
	fi
}

usage() {
	echo "$0 [NUM_CPUS][CPU_RANGE][POOL_NAME][SCHED]"
	echo "NUM_CPUS		Number of CPUs to be added to ARINC-run cpupool"
	echo "CPU_RANGE		Range of CPUs to be added (Ex: 1-3 or 4)"
	echo "POOL_NAME		Name of the CPU pool"
	echo "SCHED		Scheduler to run for this cpupool"
	exit 1
}

# Check for correct number of args
if [ "$#" -ne 4 ]; then
	usage
fi

# Validate number of CPUs
if ! [[ "$1" =~ [0-9]+$ ]]; then
	echo "[-] Error: Number of CPUs must be a number"
	usage
	exit 1
fi

# CPU range parser
cpu_parser
xl_cpupool_create
xl cpupool-list
