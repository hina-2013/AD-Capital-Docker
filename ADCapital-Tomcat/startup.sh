#!/bin/sh
source /env.sh

echo "export APP_NAME="${APP_NAME} > /etc/sysconfig/appdynamics-universal-agent
echo "export NODE_NAME="${NODE_NAME} >> /etc/sysconfig/appdynamics-universal-agent
echo "export TIER_NAME="${TIER_NAME} >> /etc/sysconfig/appdynamics-universal-agent

# Handle version string in UA install path
UA_VER=$(cd ${UA_INSTALL}; ls -d ua*)

# Install Universal Agent
# Commandline flag format changed between 4.3 and 4.4
#if [[ ${UA_VER} =~ ua4\.4.* ]]; then
#  ${UA_INSTALL}/${UA_VER}/bin/install.sh \
#    --controller_host ${CONTROLLER} --controller_port ${APPD_PORT} \
#    --account_name ${ACCOUNT_NAME%%_*} --account_access_key ${ACCESS_KEY}
#elif [[ ${UA_VER} =~ ua4\.3.* ]]; then
#  ${UA_INSTALL}/${UA_VER}/bin/install.sh \
#    -controller_host ${CONTROLLER} -controller_port ${APPD_PORT} \
#    -account_name ${ACCOUNT_NAME%%_*} -account_access_key ${ACCESS_KEY}
#fi

# Set LD_PRELOAD and add jre/lib/ext/tools.jar before starting agent JVMs
#/opt/appdynamics/universal-agent/ua --enable-ldpreload
#. /opt/appdynamics/universal-agent/ua_preload.sh
cp ${JAVA_HOME}/lib/tools.jar ${JAVA_HOME}/jre/lib/ext/tools.jar

# Service dependencies
if [ -n "${rest}" ]; then
  dockerize -wait tcp://adcapitaldb:3306 \
            -wait-retry-interval ${RETRY} -timeout ${TIMEOUT} || exit $?
  cd /${PROJECT}/AD-Capital; gradle createDB

  cp  /${PROJECT}/AD-Capital/Rest/build/libs/Rest.war /tomcat/webapps;
  cd ${CATALINA_HOME}/bin;
  java ${JMX_OPTS} -cp ${CATALINA_HOME}/bin/bootstrap.jar:${CATALINA_HOME}/bin/tomcat-juli.jar org.apache.catalina.startup.Bootstrap &

elif [ -n "${portal}" ]; then
  dockerize -wait tcp://rabbitmq:5672 \
            -wait tcp://rabbitmq:15672 \
            -wait tcp://rest:8080 \
            -wait-retry-interval ${RETRY} -timeout ${TIMEOUT} || exit $?
  
  cp /${PROJECT}/AD-Capital/Portal/build/libs/portal.war /tomcat/webapps;
  cd ${CATALINA_HOME}/bin;
  java ${JMX_OPTS} -cp ${CATALINA_HOME}/bin/bootstrap.jar:${CATALINA_HOME}/bin/tomcat-juli.jar org.apache.catalina.startup.Bootstrap &

elif [ -n "${processor}" ]; then
  dockerize -wait tcp://adcapitaldb:3306 \
            -wait tcp://rabbitmq:5672 \
            -wait tcp://rabbitmq:15672 \
            -wait tcp://rest:8080 \
            -wait-retry-interval ${RETRY} -timeout ${TIMEOUT} || exit $?

  cp /${PROJECT}/AD-Capital/Processor/build/libs/processor.war /tomcat/webapps;
  cd ${CATALINA_HOME}/bin;
  java ${JMX_OPTS} -cp ${CATALINA_HOME}/bin/bootstrap.jar:${CATALINA_HOME}/bin/tomcat-juli.jar org.apache.catalina.startup.Bootstrap &

elif [ -n "${queuereader}" ]; then
  dockerize -wait tcp://rabbitmq:5672 \
            -wait tcp://rabbitmq:15672 \
            -wait tcp://rest:8080 \
            -wait-retry-interval ${RETRY} -timeout ${TIMEOUT} || exit $?

  cd ${CATALINA_HOME}/bin;
  java ${JMX_OPTS} -jar ${PROJECT}/AD-Capital/QueueReader/build/libs/QueueReader.jar &

elif [ -n "verification" ]; then
  dockerize -wait tcp://adcapitaldb:3306 \
            -wait tcp://rabbitmq:5672 \
            -wait tcp://rabbitmq:15672 \
            -wait tcp://rest:8080 \
            -wait-retry-interval ${RETRY} -timeout ${TIMEOUT} || exit $?

  cd ${CATALINA_HOME}/bin;
  java ${JMX_OPTS} -jar ${PROJECT}/AD-Capital/Verification/build/libs/Verification.jar &

fi

# Start rsyslog and tail
service rsyslog start 
tail -f /var/log/messages 2>&1 > /dev/null
