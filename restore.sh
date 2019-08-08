#!/bin/bash
clear
echo "untar archive, wait .."
find . -name "*_install_*" -exec tar -zxf {} \;

INSTANCE_NAME=$(find . -name "*_install_*" |cut -d _ -f3)
ID=$(find . -name "*_install_*" |cut -d _ -f1 |sed 's/.\///')
HOST_ID="host_$(find . -name "*_install_*" |cut -d _ -f1 |sed 's/.\///')"
INSTANCE_TYPE=$(find . -maxdepth 3 -name stats.properties -exec grep dirName=atlassian {} \; |cut -d - -f 2)
DISTR=$(find . -maxdepth 3 -name stats.properties -exec grep dirName=atlassian {} \; |cut -d - -f 3)
VERSION=$(find . -maxdepth 3 -name stats.properties -exec grep dirName=atlassian {} \; |cut -d - -f 4)
DB_ROOT_PWD=""
DB_PASS_NEW=$(< /dev/urandom tr -dc A-Z0-9a-z0-9A-Z0-9a-z0-9 | head -c${420:-12};echo;)
LXC_NODE=$(grep "search tl" /etc/resolv.conf |cut -c 10)
DB_HOST="postgres${LXC_NODE}.tl${LXC_NODE}.local"
DB_DUMP_FILE=$(find . -name "*.sql" )

clear

echo
echo "Check info"
echo 
echo "Node - LXC${LXC_NODE}"
echo "HOST_ID - ${HOST_ID}"
echo "INSTANCE_NAME - ${INSTANCE_NAME}"
echo "TYPE - ${INSTANCE_TYPE}"
echo "VERSION - ${VERSION}"
echo "DISTR - ${DISTR}"
echo "DB_HOST - ${DB_HOST}"
echo "DB_DUMP_FILE - ${DB_DUMP_FILE}"
echo
echo "Try donload ${INSTANCE_TYPE}-${VERSION}  -${DISTR} ?"
echo y/n
read ANSWER
case ${ANSWER} in
  y )
    if [[ "${INSTANCE_TYPE}" == "jira" && "${DISTR}" == "software" ]]; then 
      wget https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-${VERSION}-x64.bin
      chmod +x atlassian-jira-software-${VERSION}-x64.bin
    elif [[ "${INSTANCE_TYPE}" == "jira" && "${DISTR}" == "core" ]]; then
      wget https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-core-${VERSION}-x64.bin
      chmod +x atlassian-jira-core-${VERSION}-x64.bin
    elif [[ "${INSTANCE_TYPE}" == "confluence" ]]; then
      wget https://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${VERSION}-x64.bin
      chmod +x atlassian-confluence-${VERSION}-x64.bin
    else
      wget https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-${VERSION}-x64.bin
      chmod +x atlassian-jira-${VERSION}-x64.bin
    fi
    echo "Skip install? - [ s ] Try install? - [ i ] Exit? - [ e ]"
    read ANSWER2
    case ${ANSWER2} in
    e ) echo "exiting .."; exit 1       
      ;;
    i ) echo "Trying install"; ./atlassian-*x64.bin
      ;;
    * ) echo "Next step .."
      ;;
    esac
  ;;
  * ) echo "Download ${INSTANCE_TYPE} skiped .."
  ;;   
esac

/etc/init.d/${INSTANCE_TYPE} stop

if [ "${INSTANCE_TYPE}" == "jira" ]; then
  echo "Config for HAproxy"
  echo
  echo "
###host-${ID}###
frontend host-${ID}
    bind *:6${ID}
    mode http
    maxconn 5120
    option forwardfor
    default_backend host-${ID}

backend host-${ID}
    description Jira http:8080
    mode http
    timeout server 1h
    server host-${ID} host-${ID}.tl${LXC_NODE}.local:8080
###host-${ID}###
"
  echo "Config for Apache"
  echo "http://lxc${LXC_NODE}.teamlead.ru:6${ID}/"

  echo "Delete old files.."
  rm -rf /var/atlassian/jira/* && rm -rf /opt/atlassian/jira/*  
  rm -rf /opt/atlassian/jira/.install4j
  rm -rf /var/atlassian/jira/.jira-home.lock
  echo "Move app dir.."
  mv  ${INSTANCE_NAME} /opt/atlassian/jira/
  find . -name "*_home_*" -exec tar -zxf {} \;
  echo "Move home dir.."
  mv  ${INSTANCE_NAME} /var/atlassian/jira/
  echo "Change permission.."
  chown -R jira:jira /var/atlassian/jira/  && chown -R jira:jira /opt/atlassian/jira/
  echo "edit init.d user.sh"
  sed -i "s/.*atlassian.*/cd \/opt\/atlassian\/jira\/${INSTANCE_NAME}\/bin\//" /etc/init.d/jira
  sed -i "s/_${INSTANCE_NAME}//" /opt/atlassian/jira/${INSTANCE_NAME}/bin/user.sh

  echo PGPASSWORD="${DB_ROOT_PWD}" psql -q -Upostgres -h"${DB_HOST}" -c "CREATE USER ${HOST_ID} WITH CREATEDB PASSWORD '${DB_PASS_NEW}'" 
  echo PGPASSWORD="${DB_ROOT_PWD}" psql -q -U"${HOST_ID}" -h"${DB_HOST}" -dtemplate1 -c "CREATE DATABASE ${HOST_ID} WITH ENCODING 'UNICODE' LC_COLLATE 'C' LC_CTYPE 'ru_RU.UTF-8' TEMPLATE template0" 
  echo PGPASSWORD="${DB_ROOT_PWD}"  psql -q -U"${HOST_ID}" -h"${DB_HOST}" -c "ALTER DATABASE ${HOST_ID} OWNER TO ${HOST_ID}"
  echo PGPASSWORD="${DB_ROOT_PWD}"  psql -q -U"${HOST_ID}" -h"${DB_HOST}" -c "GRANT ALL PRIVILEGES ON DATABASE ${HOST_ID} TO ${HOST_ID}"
  echo PGPASSWORD="${DB_ROOT_PWD}"  psql -q -U"${HOST_ID}" -h"${DB_HOST}" -d "${HOST_ID}" < ${DB_DUMP_FILE}

  DB_CONNECT="<url>jdbc:postgresql://postgres${LXC_NODE}.tl${LXC_NODE}.local:5432/${HOST_ID}</url>"
  DB_CONNECT_USER="<username>${HOST_ID}</username>"
  DB_CONNECT_PASS="<password>${DB_PASS_NEW}</password>"
  echo "edit DB_CONNECT"
  sed -i "s/.*jdbc:postgresql.*/"${DB_CONNECT}"/" /var/atlassian/jira/${INSTANCE_NAME}/dbconfig.xml
  sed -i "s/.*username.*/"${DB_CONNECT_USER}"/" /var/atlassian/jira/${INSTANCE_NAME}/dbconfig.xml
  sed -i "s/.*password.*/"${DB_CONNECT_PASS}"/" /var/atlassian/jira/${INSTANCE_NAME}/dbconfig.xml
fi

if [ "${INSTANCE_TYPE}" == "confluence" ]; then
  echo "Config for HAproxy"
  echo
  echo "
###host-${ID}###
frontend host-${ID}
    bind *:6${ID}
    mode http
    maxconn 5120
    option forwardfor
    default_backend host-${ID}

backend host-${ID}
    description http:8090
    mode http
    timeout server 1h
    server host-${ID} host-${ID}.tl${LXC_NODE}.local:8090

frontend host-${ID}-synchrony
    bind *:5${ID}
    mode tcp
    maxconn 5120
    option forwardfor
    default_backend host-${ID}-synchrony

backend host-${ID}-synchrony
    description tcp:8091
    mode tcp
    timeout server 1h
    server host-${ID} host-${ID}.tl${LXC_NODE}.local:8091
###host-${ID}###
"
  echo "Config for Apache"
  echo "http://lxc${LXC_NODE}.teamlead.ru:6${ID}/"

  echo "Delete old files.."
  rm -rf /var/atlassian/confluence/* && rm -rf /opt/atlassian/confluence/*  
  rm -rf /opt/atlassian/confluence/.install4j
  echo "Move app dir.."
  mv  ${INSTANCE_NAME} /opt/atlassian/confluence/
  find . -name "*_home_*" -exec tar -zxf {} \;
  echo "Move home dir.."
  mv  ${INSTANCE_NAME} /var/atlassian/confluence/
  echo "Change permission.."
  chown -R confluence:confluence /var/atlassian/confluence/  && chown -R confluence:confluence /opt/atlassian/confluence/
  echo "edit init.d user.sh"
  sed -i "s/.*atlassian.*/cd \/opt\/atlassian\/confluence\/"${INSTANCE_NAME}"\/bin\//" /etc/init.d/confluence
  sed -i "s/_${INSTANCE_NAME}//" /opt/atlassian/confluence/"${INSTANCE_NAME}"/bin/user.sh

  echo PGPASSWORD="${DB_ROOT_PWD}"  psql -q -Upostgres -h"${DB_HOST}" -c "CREATE USER ${HOST_ID} WITH CREATEDB PASSWORD '${DB_PASS_NEW}'" 
  echo PGPASSWORD="${DB_ROOT_PWD}"  psql -q -U"${HOST_ID}" -h"${DB_HOST}" -dtemplate1 -c "CREATE DATABASE ${HOST_ID} WITH ENCODING 'UNICODE' LC_COLLATE 'ru_RU.UTF-8' LC_CTYPE 'ru_RU.UTF-8' TEMPLATE template0" 
  echo PGPASSWORD="${DB_ROOT_PWD}"  psql -q -U"${HOST_ID}" -h"${DB_HOST}" -c "ALTER DATABASE ${HOST_ID} OWNER TO ${HOST_ID}"
  echo PGPASSWORD="${DB_ROOT_PWD}"  psql -q -U"${HOST_ID}" -h"${DB_HOST}" -c "GRANT ALL PRIVILEGES ON DATABASE ${HOST_ID} TO ${HOST_ID}"
  echo PGPASSWORD="${DB_ROOT_PWD}"  psql -q -U"${HOST_ID}" -h"${DB_HOST}" -d "${HOST_ID}" < ${DB_DUMP_FILE}

DB_CONNECT="<url>jdbc:postgresql://postgres${LXC_NODE}.tl${LXC_NODE}.local:5432/${HOST_ID}</url>"
DB_CONNECT_USER="<property name="hibernate.connection.username">${HOST_ID}</property>"
DB_CONNECT_PASS="<property name="hibernate.connection.password">${DB_PASS_NEW}</property>"
echo "edit DB_CONNECT"
sed -i s/.*jdbc:postgresql.*/"${DB_CONNECT}"/ /var/atlassian/confluence/${INSTANCE_NAME}/confluence.cfg.xml
sed -i s/.*username.*/"${DB_CONNECT_USER}"/ /var/atlassian/confluence/${INSTANCE_NAME}/confluence.cfg.xml
sed -i s/.*password.*/"${DB_CONNECT_PASS}"/ /var/atlassian/confluence/${INSTANCE_NAME}/confluence.cfg.xml
fi