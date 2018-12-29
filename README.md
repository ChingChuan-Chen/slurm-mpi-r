### After testing, it stil fail to start SLURM cluster due to network problem. Its root cause is that slurmdbd will store the ip of slurmctld and not correctly get ip address of slurmctld. Maybe you can fix it by disabling slurmdbd, but we are stop here.

### Also, it works by giving static ip to slurmctld when docker swarm provides static ip setting.

# Slurm Docker Cluster with R and MPI

This is mostly based on [giovtorres/slurm-docker-cluster](https://github.com/giovtorres/slurm-docker-cluster).

This is a multi-container SLURM cluster on docker swarm cluster with docker compose. The compose file creates network for SLURM cluster and named volumes for persistent storage of MySQL data files as well as SLURM state and log directories.

## Containers and Volumes

The compose file will run the following containers:

* mariadb
* slurmdbd
* slurmctld
* worker\* (generated by `generate_slurm_config.sh`)

The compose file will create the following named volumes:

* etc_munge              ( -> /etc/munge       )
* etc_slurm       (nfs)  ( -> /etc/slurm       )
* slurm_jobdir    (nfs)  ( -> /data            )
* var_lib_mysql   (nfs)  ( -> /var/lib/mysql   )
* var_log_slurm          ( -> /var/log/slurm   )
* var_spool_slurm (nfs)  ( -> /var/spool/slurm )

## Starting the Cluster

1. Initialize a docker swarm cluster
``` shell
docker swarm init --advertise-addr W.X.Y.Z
# show the token of worker
docker swarm join-token worker
# show the token of manager
docker swarm join-token manager
```

2. Join workers / manager
``` shell
docker swarm join --token SWMTKN-1-U-V W.X.Y.Z:2377
```

3. label nodes
``` shell
for host in jamalslurm01 jamalslurm02 jamalslurm03; do
  docker node update --label-add role=slurmd $host
done
```

4. generate slurm configs (slurm.conf / slurmdbd.conf / docker-compose.yml)
``` shell
./generate_conf.sh slurmd worker normal
```

5. create nfs for volumes
``` shell
# install nfs
for host in jamalslurm01 jamalslurm02 jamalslurm03; do
  ssh $host << EOF
yum -y install nfs-utils
systemctl start rpcbind
systemctl enable rpcbind
EOF
done

## at jamalslurm01
mkdir -p /data/nfs_vol
touch /data/nfs_vol/test.txt
tee /etc/exports << EOF
# swarm nfs share volume
# /data/nfs_vol: shared directory
# 192.168.1.0/24: subnet having privilege to access
# rw: permission to read and write. ro: read only
# sync: synchronized, slow, secure.
# async: asynchronized, fast, less secure
# no_root_squash: open to root to use
/data/nfs_vol 192.168.1.0/24(rw,sync,no_root_squash)
EOF
# start nfs
systemctl enable nfs
systemctl start nfs

# install and config autofs on nodes
for host in jamalslurm02 jamalslurm03; do
  ssh $host << EOF
yum -y install autofs
tee -a /etc/auto.master << EOF2
/mnt /etc/auto.mnt
EOF2
tee /etc/auto.mnt << EOF2
nfs_vol -rw,bg,soft,intr,rsize=8192,wsize=8192 jamalslurm01:/data/nfs_vol
EOF2
systemctl enable autofs
systemctl start autofs
EOF
done
```

6. create folders
``` shell
mkdir -p /data/nfs_vol/slurm/spool/slurmd
mkdir -p /data/nfs_vol/slurm/conf
mkdir -p /data/nfs_vol/slurm/data
mkdir -p /data/nfs_vol/slurm/mysql
```

7. copy `conf/*.conf` to nfs:
``` shell
rm -f /data/nfs_vol/slurm_conf/*.conf
cp conf/*.conf /data/nfs_vol/slurm_conf
```

8. Run `docker stack` with `docker-compose.yml`
``` shell
docker stack deploy --with-registry-auth slurm --compose-file=docker-compose.yml
```

## Check Services

``` shell
docker stack services slurm
ID                  NAME                MODE                REPLICAS            IMAGE                            PORTS
18p4gitx4m8e        slurm_worker02      replicated          1/1                 jamal0230/slurm-mpi-r:latest
f98afkeyzciw        slurm_slurmctld     replicated          1/1                 jamal0230/slurm-mpi-r:latest     *:8787->8787/tcp
fzennkproo20        slurm_worker01      replicated          1/1                 jamal0230/slurm-mpi-r:latest
jpv445trpuot        slurm_mariadb       replicated          1/1                 jamal0230/slurm-mariadb:latest
whf8zcacg39a        slurm_slurmdbd      replicated          1/1                 jamal0230/slurm-mpi-r:latest
xuu3qvazd6c8        slurm_worker03      replicated          1/1                 jamal0230/slurm-mpi-r:latest

docker service ps slurm_mariadb
# ID                  NAME                IMAGE                            NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
# msyveciyyif9        slurm_mariadb.1     jamal0230/slurm-mariadb:latest   jamalslurm01        Running             Running 30 seconds ago

docker service ps slurm_slurmdbd
# ID                  NAME                IMAGE                          NODE                DESIRED STATE       CURRENT STATE           ERROR               PORTS
# pg6gxemhb9pe        slurm_slurmdbd.1    jamal0230/slurm-mpi-r:latest   jamalslurm03        Running             Running 9 seconds ago

docker service ps slurm_slurmctld
# ID                  NAME                IMAGE                          NODE                DESIRED STATE       CURRENT STATE           ERROR               PORTS
# mgvppcfk3q6t        slurm_slurmctld.1   jamal0230/slurm-mpi-r:latest   jamalslurm02        Running             Running 5 seconds ago

docker service ps slurm_worker01
# ID                  NAME                IMAGE                          NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
# pjiiq1hx5dcp        slurm_worker01.1    jamal0230/slurm-mpi-r:latest   jamalslurm01        Running             Running 32 seconds ago

docker service ps slurm_worker02
# ID                  NAME                IMAGE                          NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
# tzab7ngihgi1        slurm_worker02.1    jamal0230/slurm-mpi-r:latest   jamalslurm02        Running             Running 33 seconds ago

docker service ps slurm_worker03
# ID                  NAME                IMAGE                          NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
# si3kg2yctu9y        slurm_worker03.1    jamal0230/slurm-mpi-r:latest   jamalslurm03        Running             Running about a minute ago

```

## Register the Cluster with SlurmDBD

To register the cluster to the slurmdbd daemon, run the `register_cluster.sh`:

```shell
host=$(docker service ps -f 'name=slurm' slurm_slurmctld | awk '{print $4}' | head -2 | tail -1)
scp register_cluster.sh $host:~/
ssh $host ~/register_cluster.sh 
```

> Note: You may have to wait a few seconds for the cluster daemons to become
> ready before registering the cluster.  Otherwise, you may get an error such
> as **sacctmgr: error: Problem talking to the database: Connection refused**.
>
> You can check the status of the cluster by viewing the logs: `docker service logs slurm_slurmdbd`

## Accessing the Cluster

Use `docker exec` to run a bash shell on the controller container:

```shell
# get host of slurmctld
host=$(docker service ps -f 'name=slurm' slurm_slurmctld | awk '{print $4}' | head -2 | tail -1)
ssh $host
docker exec -it slurm_slurmctld.1.$(docker service ps -f 'name=slurm' slurm_slurmctld -q --no-trunc | head -n1) /bin/bash

# get host of worker01
host=$(docker service ps -f 'name=slurm' slurm_worker01 | awk '{print $4}' | head -2 | tail -1)
ssh $host
docker exec -it slurm_worker01.1.$(docker service ps -f 'name=slurm' slurm_worker01 -q --no-trunc | head -n1) /bin/bash
```

From the shell, execute slurm commands, for example:

```console
[root@slurmctld /]# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal       up   infinite      3   idle worker[01-03]
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
[root@slurmctld data]# srun -N3 hostname
0:
1:
2:
```

## Deleting the Cluster

To remove all containers and volumes, run:

``` shell
docker stack rm slurm
for host in jamalslurm01 jamalslurm02 jamalslurm03; do
  ssh $host << EOF
docker stop \$(docker ps -a -f name=slurm_ -q) 2>&1 >/dev/null
docker rm \$(docker ps -a -f name=slurm_ -q) 2>&1 >/dev/null
EOF
ssh $host docker volume rm slurm_etc_munge slurm_etc_slurm slurm_slurm_jobdir slurm_var_lib_mysql slurm_var_log_slurm slurm_var_spool_slurm
done

# clean up node/job status
rm -rf /data/nfs_vol/slurm/mysql/*
rm -rf /data/nfs_vol/slurm/spool/*
```

## Installing Other R Packages

You can enter the container of slurmctld and then implement following script:

``` shell
yum install sshpass -y
su - rstudio
# gen ssh key
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -q -N ""

# get hosts
hosts=($(cat /etc/slurm/slurm.conf  | grep "^NodeName" | cut -d " " -f 1 | cut -d "=" -f 2))

# copy ssh key (PASS may be changed in docker-compose.yml)
yum install -y sshpass
PASS=rstudio
for host in ${hosts[@]}; do
  ssh-keyscan $host >> ~/.ssh/known_hosts
  sshpass -p $PASS ssh-copy-id rstudio@$host
done

# install
for host in ${hosts[@]}; do 
  ssh rstudio@$host Rscript -e "install.packages(c('snow', 'data.table', 'pipeR', 'stringr', 'lubridate'), repos = '$CRAN_URL')"
done
```

