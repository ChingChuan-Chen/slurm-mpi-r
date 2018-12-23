#!/usr/bin/env bash
set -e
docker build -t jamal0230/slurm-mpi-r:17.11.12 .
docker push jamal0230/slurm-mpi-r:17.11.12
docker tag jamal0230/slurm-mpi-r:17.11.12 jamal0230/slurm-mpi-r:latest
docker push jamal0230/slurm-mpi-r:latest
