# Slurm Docker Cluster with R and MPI

This is mostly based on [giovtorres/slurm-docker-cluster](https://github.com/giovtorres/slurm-docker-cluster).

This is a multi-container SLURM cluster on docker swarm cluster with docker compose. The compose file creates network for SLURM cluster and named volumes for persistent storage of MySQL data files as well as SLURM state and log directories.

## Containers and Volumes

The compose file will run the following containers:

* mysql
* slurmdbd
* slurmctld
* c1 (slurmd)
* c2 (slurmd)

The compose file will create the following named volumes:

* etc_munge         ( -> /etc/munge     )
* etc_slurm         ( -> /etc/slurm     )
* slurm_jobdir      ( -> /data          )
* var_lib_mysql     ( -> /var/lib/mysql )
* var_log_slurm     ( -> /var/log/slurm )

## Starting the Cluster

1. Initialize a docker swarm cluster
```
docker swarm init --advertise-addr W.X.Y.Z
# show the token of worker
docker swarm join-token worker
# show the token of manager
docker swarm join-token manager
```

2. Join workers / manager
```
docker swarm join --token SWMTKN-1-U-V W.X.Y.Z:2377
```

3. label nodes
```
for host in host01 host02 host03; do
  docker node update --label-add role=slurmd $host
done
```

4. generate slurm configs (slurm.conf / slurmdbd.conf / docker-compose.yml)
```
ROLE_LABEL=slurmd
WORKER_HOSTNAME=worker
PARTITION_NAME=normal
./generate_slurm_config.sh ${ROLE_LABEL} ${WORKER_HOSTNAME} ${PARTITION_NAME}
```

5. modify `docker-compose.yml` to make etc_slurm to the directory, slurm-confs. Like this:
```
  etc_slurm:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /slurm-confs
```

6. copy `slurm-confs` to each node:
```
for host in host01 host02 host03; do
  scp -r slurm-confs $host:/
done
```

7. Run `docker stack` with `docker-compose.yml`
```
docker stack deploy --with-registry-auth slurm --compose-file=docker-compose.yml
```

## Check Services

```
docker stack services slurm
# ID                  NAME                MODE                REPLICAS            IMAGE                          PORTS
# 1izm55u6vikp        slurm_worker03      replicated          1/1                 jamal0230/slurm-mpi-r:latest
# i6md52xfk1wm        slurm_mysql         replicated          1/1                 mysql:5.7
# o1593exavzgm        slurm_worker01      replicated          1/1                 jamal0230/slurm-mpi-r:latest
# tm461b88qywm        slurm_slurmdbd      replicated          1/1                 jamal0230/slurm-mpi-r:latest
# w75hmehzgvp6        slurm_worker02      replicated          1/1                 jamal0230/slurm-mpi-r:latest
# wb8l2xs00xjx        slurm_slurmctld     replicated          1/1                 jamal0230/slurm-mpi-r:latest   *:8787->8787/tcp
```


## Register the Cluster with SlurmDBD

To register the cluster to the slurmdbd daemon, run the `register_cluster.sh`:

```
host=$(docker service ps -f 'name=slurm' slurm_slurmctld | awk '{print $4}' | tail -1)
scp register_cluster.sh $host:~/
CLUSTER_NAME=linux
ssh $host ~/register_cluster.sh ${CLUSTER_NAME}
```

> Note: You may have to wait a few seconds for the cluster daemons to become
> ready before registering the cluster.  Otherwise, you may get an error such
> as **sacctmgr: error: Problem talking to the database: Connection refused**.
>
> You can check the status of the cluster by viewing the logs: `docker service logs slurm_slurmdbd`

## Accessing the Cluster

Use `docker exec` to run a bash shell on the controller container:

```
# get host of slurmctld
host=$(docker service ps -f 'name=slurm' slurm_slurmctld | awk '{print $4}' | tail -1)
ssh $host
docker exec -it slurm_slurmctld.1.$(docker service ps -f 'name=slurm' slurm_slurmctld -q --no-trunc | head -n1) /bin/bash
```

From the shell, execute slurm commands, for example:

```console
[root@slurmctld /]# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up   infinite      3   idle slurm_worker[01-03]
```

## Submitting Jobs

The `slurm_jobdir` named volume is mounted on each Slurm container as `/data`.
Therefore, in order to see job output files while on the controller, change to
the `/data` directory when on the **slurmctld** container and then submit a job:

```console
[root@slurmctld /]# cd /data/
[root@slurmctld data]# sbatch --wrap="uptime"
Submitted batch job 2
[root@slurmctld data]# ls
slurm-2.out
```

## Deleting the Cluster

To remove all containers and volumes, run:

```console
docker stack rm slurm
docker volume rm slurm-docker-cluster_etc_munge slurm-docker-cluster_etc_slurm slurm-docker-cluster_slurm_jobdir slurm-docker-cluster_var_lib_mysql slurm-docker-cluster_var_log_slurm
```
