#!/usr/bin/env bash
set -e

defaultYes=""
if [ ! -f "conf/slurm.conf" ]; then
  cp conf-example/slurm-example.conf conf/slurm.conf
  cp conf-example/slurmdbd-example.conf conf/slurmdbd.conf
  defaultYes="Default=yes"
fi

echo "# COMPUTE NODES" >> conf/slurm.conf
hosts=($(docker node ls -q | xargs docker node inspect   -f '{{ .Description.Hostname }} {{ .Spec.Labels }}' | grep "role:$1" | awk '{print $1}'))
k=1
hostJoin=""
for host in ${hosts[@]}; do
  result=$(ssh $host << EOF
echo "NodeName=${2}$(printf '%02i' $k) CPUs=\$(lscpu | grep -E '^CPU\(' | grep -o '[0-9]\+$') Sockets=\$(lscpu | grep -E '^Socket' | grep -o '[0-9]\+$') ThreadsPerCore=\$(lscpu | grep -E '^Thread' | grep -o '[0-9]\+$') CoresPerSocket=\$(lscpu | grep -E '^Core' | grep -o '[0-9]\+$') RealMemory=\$(awk '/MemTotal/{printf("%.0f\n", \$2/1024*0.95)}' /proc/meminfo) State=UNKNOWN"
EOF
2>&1)
  echo $result >> conf/slurm.conf
  if [ "$hostJoin" = "" ]; then
    hostJoin="${2}$(printf '%02i' $k)"
  else
    hostJoin="$hostJoin,${2}$(printf '%02i' $k)"
  fi
  k=$(($k + 1))
done

echo "# PARTITIONS" >> conf/slurm.conf
echo "PartitionName=$3 ${defaultYes} Nodes=${hostJoin} State=UP" >> conf/slurm.conf

if [ ! -f "docker-compose.yml" ]; then
  cp docker-compose-example.yml docker-compose.yml
fi
k=1
for host in ${hosts[@]}; do
  echo "
  ${2}$(printf "%02i" $k):
    image: jamal0230/slurm-mpi-r:latest
    command: [\"slurmd\"]
    hostname: ${2}$(printf "%02i" $k)
    volumes:
      - etc_munge:/etc/munge
      - etc_slurm:/etc/slurm
      - slurm_jobdir:/data
      - var_log_slurm:/var/log/slurm
      - var_spool_slurm:/var/spool/slurm
    depends_on:
      - slurmctld
    networks:
      - slurm-net
    deploy:
      placement:
        constraints:
          - node.hostname == $host
      restart_policy:
        condition: on-failure
        max_attempts: 3"  >> docker-compose.yml
  k=$(($k + 1))
done

