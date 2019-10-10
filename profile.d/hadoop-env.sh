export HADOOP_CLASSPATH="$(find $HADOOP_HOME/. -name '*.jar' | xargs echo | tr ' ' ':')";
alias start-hs='mapred --daemon start historyserver';
alias stop-hs='mapred --daemon stop historyserver';
