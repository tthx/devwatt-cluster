DROP DATABASE IF EXISTS tests;
CREATE DATABASE tests;
USE tests;
DROP TABLE IF EXISTS u_data PURGE;
CREATE TABLE u_data(
  userid INT,
  movieid INT,
  rating INT,
  unixtime STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

// wget http://files.grouplens.org/datasets/movielens/ml-100k.zip
LOAD DATA LOCAL INPATH '/tmp/ml-100k/u.data' OVERWRITE INTO TABLE u_data;

SELECT COUNT(*) FROM u_data;
ANALYZE TABLE u_data COMPUTE STATISTICS FOR COLUMNS;

DROP TABLE IF EXISTS u_data_orc PURGE;
CREATE TABLE u_data_orc STORED AS ORC AS SELECT * FROM u_data;
SELECT COUNT(*) FROM u_data_orc;
ANALYZE TABLE u_data_orc COMPUTE STATISTICS FOR COLUMNS;
SELECT
  userid,
  movieid,
  rating
FROM
  u_data_orc
GROUP BY
  userid,
  movieid,
  rating
ORDER BY
  userid,
  movieid,
  rating;

DROP TABLE IF EXISTS u_data_bucket PURGE;
CREATE TABLE u_data_bucket(
  userid INT,
  movieid INT,
  rating INT,
  unixtime STRING)
CLUSTERED BY(userid, movieid, unixtime) INTO 4 BUCKETS;
INSERT OVERWRITE TABLE u_data_bucket SELECT * FROM u_data_orc;
SELECT COUNT(*) FROM u_data_bucket;
ANALYZE TABLE u_data_bucket COMPUTE STATISTICS FOR COLUMNS;

DROP TABLE IF EXISTS u_data_opt PURGE;
CREATE TABLE u_data_opt(
  userid INT,
  movieid INT,
  rating INT,
  unixtime STRING)
CLUSTERED BY(userid, movieid, unixtime) INTO 4 BUCKETS
SKEWED BY (rating) ON (1,2,3,4,5);
INSERT OVERWRITE TABLE u_data_opt SELECT * FROM u_data_bucket;
SELECT COUNT(*) FROM u_data_opt;
ANALYZE TABLE u_data_opt COMPUTE STATISTICS FOR COLUMNS;
DESCRIBE FORMATTED u_data_opt;
SELECT userid, movieid, unixtime FROM u_data_opt WHERE unixtime>888639814 AND unixtime<888640275 AND rating>1 AND rating<=4 GROUP BY userid, movieid, unixtime;

DROP TABLE IF EXISTS u_data_join PURGE;
CREATE TABLE u_data_join(
  userid1 INT,
  userid2 INT,
  movieid INT,
  rating INT,
  unixtime1 STRING,
  unixtime2 STRING)
CLUSTERED BY(userid1, userid2, movieid, unixtime1, unixtime2) INTO 4 BUCKETS
SKEWED BY (rating) ON (1,2,3,4,5);
INSERT OVERWRITE TABLE u_data_join 
SELECT
  u1.userid,
  u2.userid,
  u1.movieid,
  u1.rating,
  u1.unixtime,
  u2.unixtime
FROM
  u_data_opt u1
JOIN u_data_opt u2
ON
  u1.userid<>u2.userid AND
  u1.movieid=u2.movieid AND
  u1.rating=u2.rating
GROUP BY
  u1.userid,
  u2.userid,
  u1.movieid,
  u1.rating,
  u1.unixtime,
  u2.unixtime;
SELECT COUNT(*) FROM u_data_join;
ANALYZE TABLE u_data_join COMPUTE STATISTICS FOR COLUMNS;
DESCRIBE FORMATTED u_data_join;

DROP TABLE IF EXISTS u_data_acid PURGE;
CREATE TABLE u_data_acid(
  userid INT,
  movieid INT,
  rating INT,
  unixtime STRING)
CLUSTERED BY(userid, movieid, unixtime) INTO 4 BUCKETS
SKEWED BY (rating) ON (1,2,3,4,5)
TBLPROPERTIES('transactional'='true');
INSERT OVERWRITE TABLE u_data_acid SELECT * FROM u_data_opt;
SELECT COUNT(*) FROM u_data_acid;
ANALYZE TABLE u_data_acid COMPUTE STATISTICS FOR COLUMNS;
DESCRIBE FORMATTED u_data_acid;

SELECT userid, movieid, unixtime FROM u_data_acid WHERE unixtime>888639814 AND unixtime<888640275 AND rating>1 AND rating<=4 GROUP BY userid, movieid, unixtime;

DROP TABLE IF EXISTS u_data_acid_join PURGE;
CREATE TABLE u_data_acid_join(
  userid1 INT,
  userid2 INT,
  movieid INT,
  rating INT,
  unixtime1 STRING,
  unixtime2 STRING)
CLUSTERED BY(userid1, userid2, movieid, unixtime1, unixtime2) INTO 4 BUCKETS
SKEWED BY (rating) ON (1,2,3,4,5)
TBLPROPERTIES('transactional'='true');
INSERT OVERWRITE TABLE u_data_acid_join 
SELECT
  u1.userid,
  u2.userid,
  u1.movieid,
  u1.rating,
  u1.unixtime,
  u2.unixtime
FROM
  u_data_acid u1
JOIN u_data_acid u2
ON
  u1.userid<>u2.userid AND
  u1.movieid=u2.movieid AND
  u1.rating=u2.rating
GROUP BY
  u1.userid,
  u2.userid,
  u1.movieid,
  u1.rating,
  u1.unixtime,
  u2.unixtime;
SELECT COUNT(*) FROM u_data_acid_join;
ANALYZE TABLE u_data_acid_join COMPUTE STATISTICS FOR COLUMNS;
DESCRIBE FORMATTED u_data_acid_join;
