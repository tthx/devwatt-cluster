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
// put 
LOAD DATA INPATH '/tmp/u.data' OVERWRITE INTO TABLE u_data;

SELECT COUNT(*) FROM u_data;