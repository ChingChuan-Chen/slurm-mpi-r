FROM jamal0230/centos-rstudio-mkl-r:3.4.4

ENV SLURM_VER=18.08.4 MPICH_VER=3.2.1 GOSU_VER=1.11

WORKDIR /root
RUN rm -rf /var/cache/yum/ && yum makecache fast && yum update -y && \
  yum install -y golang mariadb-server mariadb-devel munge munge-libs munge-devel rng-tools \
    pam-devel numactl numactl-devel hwloc hwloc-devel lua lua-devel rrdtool-devel ncurses-devel \
    man2html libibmad libibumad cpanm* hdf5 hdf5-devel json-c-devel lz4-devel libibmad-devel \
    glibc-devel glib2-devel gtk2-devel rpmdevtools openssh-server mailx bind-utils net-tools && \
  # build/install SLURM
  wget -q https://download.schedmd.com/slurm/slurm-${SLURM_VER}.tar.bz2 && \
  rpmbuild -ta slurm-${SLURM_VER}.tar.bz2 && \
  yum install -y rpmbuild/RPMS/x86_64/slurm*.rpm && \
  rm -rf rpmbuild slurm* && \
  # build/install MPICH
  wget -q http://www.mpich.org/static/downloads/${MPICH_VER}/mpich-${MPICH_VER}.tar.gz && \
  tar zxf mpich-${MPICH_VER}.tar.gz && cd mpich-${MPICH_VER} && \
  ./configure --prefix=/usr --libdir=/usr/lib64 --with-slurm-include=/usr/include --with-slurm-lib=/usr/lib64 && \
  make -j$(nproc) && make install && cd .. && \
  rm -rf mpich* && \
  # build gosu
  wget -q https://github.com/tianon/gosu/archive/${GOSU_VER}.tar.gz && \
  mkdir -p /root/gosu/bin && tar zxf ${GOSU_VER}.tar.gz -C /root/gosu --strip-components=1 && \
  export GOPATH=/root/gosu && export GOBIN=/root/gosu/bin && \
  cd /root/gosu && go get && \
  cp bin/gosu /usr/bin/ && cd .. && \
  rm -rf ${GOSU_VER}.tar.gz gosu* && \
  unset GOPATH && unset GOBIN && \
  gosu nobody true && \
  # create munge key
  /sbin/create-munge-key && \
  # install Rmpi
  Rscript -e "install.packages('Rmpi', repos = '$CRAN_URL', configure.args = c('--with-Rmpi-include=/usr/include', '--with-Rmpi-libpath=/usr/lib64', '--with-Rmpi-type=MPICH2'))" && \
  Rscript -e "install.packages(c('snow', 'pipeR', 'data.table'), repos = '$CRAN_URL')" && \
  groupadd -r slurm --gid=991 && useradd -r -g slurm --uid=991 slurm && \
  mkdir -p /var/log/slurm /var/spool/slurm/slurmd /var/run/slurm && \
  chown slurm: /var/log/slurm && chown slurm: /var/run/slurm && \
  chown -R slurm: /var/spool/slurm && mkdir /data && chmod 777 /data

COPY docker-entrypoint.sh /slurm/docker-entrypoint.sh
ENTRYPOINT ["/slurm/docker-entrypoint.sh"]

CMD ["slurmdbd"]

