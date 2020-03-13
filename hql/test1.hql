CREATE TABLE u_data(
  userid INT,
  movieid INT,
  rating INT,
  unixtime STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

;; wget http://files.grouplens.org/datasets/movielens/ml-100k.zip

LOAD DATA LOCAL INPATH '/tmp/ml-100k/u.data' OVERWRITE INTO TABLE u_data;

SELECT COUNT(*) FROM u_data;

CREATE TABLE u_data_orc STORED AS ORC AS SELECT * FROM u_data;
DESCRIBE FORMATTED u_data_orc;

SELECT COUNT(*) FROM u_data_orc;

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
CLUSTERED BY(userid, movieid) INTO 4 BUCKETS;
INSERT OVERWRITE TABLE u_data_bucket SELECT * FROM u_data_orc;
DESCRIBE FORMATTED u_data_bucket;

DROP TABLE IF EXISTS u_data_opt PURGE;
CREATE TABLE u_data_opt(
  userid INT,
  movieid INT,
  rating INT,
  unixtime STRING)
CLUSTERED BY(userid, movieid) INTO 4 BUCKETS
SKEWED BY (rating) ON (1,2,3,45);
INSERT OVERWRITE TABLE u_data_opt SELECT * FROM u_data_orc;
DESCRIBE FORMATTED u_data_opt;
