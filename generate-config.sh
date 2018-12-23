#!/usr/bin/env bash
set -e

for f in `ls slurm-confs-example/`; do
  cp slurm-confs-example/$f slurm-confs/$(echo $f | cut -d '.' -f 1).conf
done

echo "# COMPUTE NODES" >> slurm-confs/slurm.conf
hosts=($(docker node ls -q | xargs docker node inspect   -f '{{ .Description.Hostname }} {{ .Spec.Labels }}' | grep "role:$1" | awk '{print $1}'))
k=1
for host in ${hosts[@]}; do
  result=$(ssh $host << EOF
echo "NodeName=${2}$(printf '%02i' $k) CPUs=\$(lscpu | grep -E '^CPU\(' | grep -o '[0-9]\+$') ThreadsPerCore=$(lscpu | grep -E '^Thread' | grep -o '[0-9]\+$') CoresPerSocket=\$(lscpu | grep -E '^Core' | grep -o '[0-9]\+$') RealMemory=\$(awk '/MemTotal/{printf("%.0f\n", \$2/1024)}' /proc/meminfo) State=UNKNOWN"
EOF
2>&1)
  echo $result >> slurm-confs/slurm.conf
  k=$(($k + 1))
done

hostJoin=$(printf '%s,' ${hosts[@]})
echo "# PARTITIONS" >> slurm-confs/slurm.conf
echo "PartitionName=$3 Default=yes Nodes=${hostJoin:1} State=UP" >> slurm-confs/slurm.conf

cp docker-compose.yml.example docker-compose.yml
k=1
for host in ${hosts[@]}; do
  echo "
  worker$(printf "%02i" $k):
    image: jamal0230/slurm-mpi-r:latest
    command: [\"slurmd\"]
    hostname: worker$(printf "%02i" $k)
    volumes:
      - etc_munge:/etc/munge
      - etc_slurm:/etc/slurm
      - slurm_jobdir:/data
      - var_log_slurm:/var/log/slurm
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
