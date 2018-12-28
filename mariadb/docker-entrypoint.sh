#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
  set -- mysqld_safe "$@"
fi

if [ "$1" = 'mysqld_safe' ]; then 
  echo 'Running mysql_install_db ...'
  mysql_install_db --datadir="/var/lib/mysql"
  echo 'Finished mysql_install_db'

  set -- "$@" --init-file="/slurm-mariadb/init.sql"
fi
exec "$@"

