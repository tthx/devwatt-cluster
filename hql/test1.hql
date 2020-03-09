CREATE TABLE u_data (
  userid INT,
  movieid INT,
  rating INT,
  unixtime STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

;; wget http://files.grouplens.org/datasets/movielens/ml-100k.zip

LOAD DATA LOCAL INPATH '/tmp/ml-100k/u.data'
OVERWRITE INTO TABLE u_data;

SELECT COUNT(*) FROM u_data;

CREATE TABLE u_data_orc 
STORED AS ORC
AS
SELECT * FROM u_data;

SELECT COUNT(*) FROM u_data_orc;