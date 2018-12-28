DELETE FROM mysql.user;
CREATE USER 'root'@'%' IDENTIFIED BY 'toor';
GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
DROP DATABASE IF EXISTS test;

CREATE USER 'slurm'@'%' IDENTIFIED BY 'password';
CREATE DATABASE IF NOT EXISTS slurm_acct_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS slurm_jobcomp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

GRANT ALL ON slurm_acct_db.* TO 'slurm'@'%' ;
GRANT ALL ON slurm_jobcomp_db.* TO 'slurm'@'%' ;
FLUSH PRIVILEGES;

