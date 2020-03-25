CREATE DATABASE metastore;
USE metastore;
SOURCE /opt/hive/scripts/metastore/upgrade/mysql/hive-schema-3.1.0.mysql.sql;
CREATE USER 'hive'@'%' IDENTIFIED BY 'D@$#H0le99*';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'hive'@'%';
GRANT ALL PRIVILEGES ON metastore.* TO 'hive'@'%';
FLUSH PRIVILEGES;

;; CREATE DATABASE statistics DEFAULT CHARACTER SET utf8;
;; GRANT ALL PRIVILEGES ON statistics.* TO 'hive'@'%';
;; FLUSH PRIVILEGES;

quit;