#!/bin/bash
set -e

echo "---> Starting the MUNGE Authentication service (munged) ..."
gosu munge /usr/sbin/munged

if [ ! -d /var/run/sshd ]; then
  mkdir /var/run/sshd
  ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
fi
gosu root /usr/sbin/sshd

if [ "$1" = "slurmdbd" ]; then
  echo "---> Starting the Slurm Database Daemon (slurmdbd) ..."
  {
    . /etc/slurm/slurmdbd.conf
    until echo "SELECT 1" | mysql -h $StorageHost -u$StorageUser -p$StoragePass 2>&1 > /dev/null
    do
      echo "-- Waiting for database to become active ..."
      sleep 2
    done
  }

   echo "-- Database is now active ..."
  exec gosu slurm /usr/sbin/slurmdbd -Dvvv
fi

if [ "$1" = "slurmctld" ]; then
  echo "---> Verify Run User"
  if [ ! -z "$PASSWORD" ]; then
    if [ ! -z "$USER" ]; then
      echo "---> Creating User ..."
      userdel -r rstudio
      useradd $USER
      usermod -a -G ruser $USER
      echo "$USER:$PASSWORD" | chpasswd
      mkdir -p /home/$USER/.R/rstudio/keybindings
      cp /rstudio-server/keybindings/*.json /home/$USER/.R/rstudio/keybindings/
      mkdir -p /home/$USER/.rstudio/monitored/user-settings
      cp /rstudio-server/user-settings/* /home/$USER/.rstudio/monitored/user-settings/
      cp /rstudio-server/benchmark.R /home/$USER
      chown -R $USER: /home/$USER/
    else
      USER=rstudio
      echo "---> Changing Password of rstudio ..."
      echo "rstudio:$PASSWORD" | chpasswd
    fi
  fi

  echo "---> Starting the RStudio Server ..."
  gosu root /usr/lib/rstudio-server/bin/rserver --rsession-which-r /usr/lib64/R/bin/R --auth-required-user-group ruser
 
  echo "---> Waiting for mariadb to become active before starting slurmctld ..."

  until 2>/dev/null >/dev/tcp/slurmdbd/6819
  do
    echo "-- mariadb is not available.  Sleeping ..."
    sleep 2
  done
  echo "-- mariadb is now active ..."

  echo "---> Starting the Slurm Controller Daemon (slurmctld) ..."
  exec gosu slurm /usr/sbin/slurmctld -Dvvv
fi

if [ "$1" = "slurmd" ]; then
  echo "---> Waiting for slurmctld to become active before starting slurmd..."

  until 2>/dev/null >/dev/tcp/slurmctld/6817
  do
    echo "-- slurmctld is not available.  Sleeping ..."
    sleep 2
  done
  echo "-- slurmctld is now active ..."

  echo "---> Starting the Slurm Node Daemon (slurmd) ..."
  exec /usr/sbin/slurmd -Dvvv
fi

exec "$@"

