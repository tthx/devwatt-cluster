CREATE TABLE u_data(
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

CREATE TABLE u_data_bucket(
  userid INT,
  movieid INT,
  rating INT,
  unixtime STRING)
CLUSTERED BY(userid, movieid) INTO 256 BUCKETS;

CREATE TABLE u_data_opt(
  userid INT,
  movieid INT,
  rating INT,
  unixtime STRING)
CLUSTERED BY(userid, movieid) INTO 256 BUCKETS
SKEWED BY (rating) ON (1,2,3,45);

INSERT OVERWRITE TABLE u_data_bucket SELECT * FROM u_data_orc;

DESCRIBE FORMATTED u_data_bucket;

INSERT OVERWRITE TABLE u_data_opt SELECT * FROM u_data_orc;

2020-03-12T09:11:31,536 ERROR [Thread-88] stats.StatsFactory: jdbc:postgres Publisher/Aggregator classes cannot be loaded.
java.lang.IllegalArgumentException: No enum constant org.apache.hadoop.hive.common.StatsSetupConst.StatDB.jdbc:postgres
  at java.lang.Enum.valueOf(Enum.java:238) ~[?:1.8.0_241]
  at org.apache.hadoop.hive.common.StatsSetupConst$StatDB.valueOf(StatsSetupConst.java:55) ~[hive-exec-3.1.2.jar:3.1.2]
  at org.apache.hadoop.hive.ql.stats.StatsFactory.initialize(StatsFactory.java:70) ~[hive-exec-3.1.2.jar:3.1.2]
  at org.apache.hadoop.hive.ql.stats.StatsFactory.newFactory(StatsFactory.java:57) ~[hive-exec-3.1.2.jar:3.1.2]
  at org.apache.hadoop.hive.ql.stats.StatsFactory.newFactory(StatsFactory.java:46) ~[hive-exec-3.1.2.jar:3.1.2]
  at org.apache.hadoop.hive.ql.exec.tez.DagUtils.createVertex(DagUtils.java:1347) ~[hive-exec-3.1.2.jar:3.1.2]
  at org.apache.hadoop.hive.ql.exec.tez.TezTask.build(TezTask.java:463) ~[hive-exec-3.1.2.jar:3.1.2]
  at org.apache.hadoop.hive.ql.exec.tez.TezTask.execute(TezTask.java:205) ~[hive-exec-3.1.2.jar:3.1.2]
  at org.apache.hadoop.hive.ql.exec.Task.executeTask(Task.java:205) ~[hive-exec-3.1.2.jar:3.1.2]
  at org.apache.hadoop.hive.ql.exec.TaskRunner.runSequential(TaskRunner.java:97) ~[hive-exec-3.1.2.jar:3.1.2]
  at org.apache.hadoop.hive.ql.exec.TaskRunner.run(TaskRunner.java:76) ~[hive-exec-3.1.2.jar:3.1.2]
