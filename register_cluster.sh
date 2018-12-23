#!/bin/bash
set -e

docker exec -it slurm_slurmctld.1.$(docker service ps -f 'name=slurm' slurm_slurmctld -q --no-trunc | head -n1) /bin/bash -c "/usr/bin/sacctmgr --immediate add cluster name=$1" && \
docker service update slurm_slurmdbd --force && \
docker service update slurm_slurmctld --force
