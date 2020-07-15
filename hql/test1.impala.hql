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
// put /tmp/ml-100k/u.data in HDFS /tmp/u.data
LOAD DATA INPATH '/tmp/u.data' OVERWRITE INTO TABLE u_data;

SELECT COUNT(*) FROM u_data;

DROP TABLE IF EXISTS u_data_parquet PURGE;
CREATE TABLE u_data_parquet STORED AS PARQUET AS SELECT * FROM u_data;
SELECT COUNT(*) FROM u_data_parquet;
SELECT
  userid,
  movieid,
  rating
FROM
  u_data_parquet
GROUP BY
  userid,
  movieid,
  rating
ORDER BY
  userid,
  movieid,
  rating;
