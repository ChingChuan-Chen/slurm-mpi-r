FROM centos:7

RUN rm -rf /var/cache/yum/ && yum makecache fast && yum update -y && \
  yum install -y epel-release && \
  yum install -y mariadb-server bind-utils && \
  rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mariadb /var/log/mariadb && \
  chown -R mysql:mysql /var/lib/mysql /var/run/mariadb /var/log/mariadb

COPY init.sql /slurm-mariadb/init.sql
COPY docker-entrypoint.sh /slurm-mariadb/docker-entrypoint.sh
VOLUME /var/lib/mysql

USER 27
EXPOSE 3306
ENTRYPOINT ["/slurm-mariadb/docker-entrypoint.sh"]
CMD ["mysqld_safe"]

