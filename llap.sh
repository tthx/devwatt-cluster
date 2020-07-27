hive \
--output "/var/hive/llap-devwatt" \
--service llap \
--instances 3 \
--executors 2 \
--args "-XX:+UseG1GC -XX:+ResizeTLAB -XX:+UseNUMA -XX:-ResizePLAB" \
--loglevel DEBUG \
--name "llap-devwatt" \
--queue "root.hive" \
--xmx 8192m \
--size 10240m

--service-am-container-mb 2048 \
--cache 1024m \