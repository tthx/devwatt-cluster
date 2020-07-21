hive \
--service llap \
--instances 4 \
--executors 1 \
--iothreads 1 \
--args "-XX:+UseG1GC -XX:+ResizeTLAB -XX:+UseNUMA -XX:-ResizePLAB" \
--loglevel DEBUG \
--name llap-devwatt \
--queue hive \
--service-am-container-mb 2048 \
--cache 4096m \
--xmx 4096m \
--size 10240m
