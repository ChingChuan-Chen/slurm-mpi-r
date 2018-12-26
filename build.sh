#!/usr/bin/env bash
set -e
docker build -t jamal0230/slurm-mpi-r:18.08.4 .
docker push jamal0230/slurm-mpi-r:18.08.4
docker tag jamal0230/slurm-mpi-r:18.08.4 jamal0230/slurm-mpi-r:latest
docker push jamal0230/slurm-mpi-r:latest
