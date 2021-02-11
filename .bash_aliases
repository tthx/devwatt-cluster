export CC="gcc";
export CFLAGS="-O2";
export CXX="g++";
export CXXFLAGS="-O2 -std=c++17 -Wall -pedantic";

export PATH="${HOME}/k8s/bin:${PATH}";
export JAVA_HOME="/opt/jdk";
export PATH="${JAVA_HOME}/bin:${PATH}";
export JAVA_OPTS="-XX:+UseG1GC -XX:+ResizeTLAB -XX:+UseNUMA -XX:-ResizePLAB";
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
export NODEJS="/opt/node.js";
export PATH="${NODEJS}/bin:${PATH}";

alias h='history';
alias dir='ls -laF';
alias vi='vim';
alias md='mkdir -p';
alias cls='clear';
alias more='less';
alias chrome='google-chrome-stable 2>/dev/null';
alias firefox='/usr/bin/firefox 2>/dev/null';
alias sublime='/opt/sublime_text/sublime_text';
alias docker-purge='containers="$(docker container ls -aq)" && if [ -n "${containers}" ]; then docker container stop ${containers}; fi && docker system prune -a -f --volumes';
alias docker-clean='containers="$(docker container ls -aq)" && if [ -n "${containers}" ]; then docker container stop ${containers}; fi && docker container prune';
alias python='/usr/bin/python3'
alias clear-logs='journalctl --vacuum-time=1d';
alias eclipse='$HOME/eclipse/eclipse 2>/dev/null';
alias idea='$HOME/idea/bin/idea.sh 2>/dev/null';
alias yum-clean='sudo yum remove $(package-cleanup --leaves)'
alias yum-clean-kernel='sudo package-cleanup --oldkernels --count=1'

function parse_git_branch {
  [ -d .git ] && git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

if [[ -n "$(which git)" ]];
then
  export PS1='\u@\h:\[\e[32m\]\w \[\e[91m\]$(parse_git_branch)\[\e[00m\]'$'\n$ '
else
  export PS1='\u@\h:\[\e[32m\]\w \[\e[91m\]\[\e[00m\]'$'\n$ '
fi
