export CXX="g++";
export CXXFLAGS="-O2 -std=c++17 -Wall -pedantic";

export M2_HOME="/opt/maven";
export MAVEN_OPTS="${JAVA_OPTS} -Xms256m -Xmx512m";
export PATH="${M2_HOME}/bin:${PATH}";
export ANT_HOME="/opt/ant";
export PATH="${ANT_HOME}/bin:${PATH}";
export GRADLE_HOME="/opt/gradle";
export PATH="${GRADLE_HOME}/bin:${PATH}";
export JMETER_HOME="/opt/jmeter";
export PATH="${JMETER_HOME}/bin:${PATH}";
export SCALA_HOME="/opt/scala";
export PATH="${SCALA_HOME}/bin:${PATH}";
export SBT_HOME="/opt/sbt";
export SBT_OPTS="-Dhttp.proxyHost=devwatt-proxy.si.fr.intraorange -Dhttp.proxyPort=8080";
export PATH="${SBT_HOME}/bin:${PATH}";
export GOROOT="/opt/go";
export PATH="${GOROOT}/bin:${PATH}";
export NODEJS="/opt/nodejs";
export PATH="${NODEJS}/bin:${PATH}";

alias h='history';
alias dir='ls -laF';
alias vi='vim';
alias md='mkdir -p';
alias cls='clear';
alias more='less';
alias python='python3';
alias chrome='google-chrome-stable 2>/dev/null';
alias firefox='/usr/bin/firefox 2>/dev/null';
alias sublime='/opt/sublime_text/sublime_text';
alias docker-clean='docker stop $(docker container ls -a -q) && docker system prune -a -f --volumes';
alias python='/usr/bin/python3'
alias clear-logs='journalctl --vacuum-time=1d';
