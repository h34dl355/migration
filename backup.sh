#!/bin/bash
MIG_DATE=$(date +%F)
INSTANCE_ID=$1
INSTANCE_TYPE=$(grep -m1 pidfile /etc/init.d/*${INSTANCE_ID}*  | cut -d / -f4)
INSTANCE_NAME=$(grep -m1 pidfile /etc/init.d/*${INSTANCE_ID}*  | cut -d / -f5)
INSTALL_PATH=/opt/atlassian/${INSTANCE_TYPE}/
HOME_PATH=/var/atlassian/${INSTANCE_TYPE}/


if [ "${INSTANCE_TYPE}" == "jira" ]; then 

DB_NAME=$(grep -m1 "//localhost" /var/atlassian/jira/${INSTANCE_NAME}/dbconfig.xml | cut -d / -f 4 | sed 's/<//')
DB_USER=$(grep -m1 "username" /var/atlassian/jira/${INSTANCE_NAME}/dbconfig.xml | cut -d '<' -f 2 | cut -d '>' -f 2)
DB_PASSWD=$(grep -m1 "password" /var/atlassian/jira/${INSTANCE_NAME}/dbconfig.xml | cut -d '<' -f 2 | cut -d '>' -f 2)

clear
echo
echo "Checking variables!"
echo
echo "INSTANCE_ID = ${INSTANCE_ID}
INSTANCE_TYPE = ${INSTANCE_TYPE}
INSTANCE_NAME = ${INSTANCE_NAME}
INSTALL_PATH = ${INSTALL_PATH}
HOME_PATH = ${HOME_PATH}
DB_NAME = ${DB_NAME}
DB_USER = ${DB_USER}
DB_PASSWD = ${DB_PASSWD}

All correct? y/n"
read ANSWER    

case ${ANSWER} in
	y)
	echo "Lets start!"
	;;
	*) 
	echo "Exiting .."
	exit 1
	;;
esac

echo
echo "Create install archive"
echo
cd ${INSTALL_PATH} 
tar -czvf ${INSTANCE_ID}_install_${INSTANCE_NAME}_${MIG_DATE}.tar.gz  ${INSTANCE_NAME}
mv ${INSTANCE_ID}_install_${INSTANCE_NAME}_${MIG_DATE}.tar.gz /home/eldar

echo
echo "Create home archive"
echo
cd ${HOME_PATH} 
tar -czvf ${INSTANCE_ID}_home_${INSTANCE_NAME}_${MIG_DATE}.tar.gz  ${INSTANCE_NAME}
mv ${INSTANCE_ID}_home_${INSTANCE_NAME}_${MIG_DATE}.tar.gz /home/eldar

echo
echo "Create database dump"
echo
PGPASSWORD="${DB_PASSWD}" pg_dump --format=plain --no-owner --no-acl -U ${DB_USER} -d ${DB_NAME} > /home/eldar/${INSTANCE_ID}_database_${INSTANCE_NAME}_${MIG_DATE}.sql



elif [ "${INSTANCE_TYPE}" == "confluence" ]; then 

DB_NAME=$(grep -m1 "//localhost" /var/atlassian/confluence/${INSTANCE_NAME}/confluence.cfg.xml | cut -d / -f 4 | sed 's/<//')
DB_USER=$(grep -m1 "username" /var/atlassian/confluence/${INSTANCE_NAME}/confluence.cfg.xml | cut -d '<' -f 2 | cut -d '>' -f 2)
DB_PASSWD=$(grep -m1 "password" /var/atlassian/confluence/${INSTANCE_NAME}/confluence.cfg.xml | cut -d '<' -f 2 | cut -d '>' -f 2)

clear
echo
echo "Checking variables!"
echo
echo "INSTANCE_ID = ${INSTANCE_ID}
INSTANCE_TYPE = ${INSTANCE_TYPE}
INSTANCE_NAME = ${INSTANCE_NAME}
INSTALL_PATH = ${INSTALL_PATH}
HOME_PATH = ${HOME_PATH}
DB_NAME = ${DB_NAME}
DB_USER = ${DB_USER}
DB_PASSWD = ${DB_PASSWD}

All correct? y/n"
read ANSWER    

case ${ANSWER} in
	y)
	echo "Lets start!"
	;;
	*) 
	echo "Exiting .."
	exit 1
	;;
esac

echo
echo "Create install archive"
echo
cd ${INSTALL_PATH} 
tar -czvf ${INSTANCE_ID}_install_${INSTANCE_NAME}_${MIG_DATE}.tar.gz  ${INSTANCE_NAME}
mv ${INSTANCE_ID}_install_${INSTANCE_NAME}_${MIG_DATE}.tar.gz /home/eldar

echo
echo "Create home archive"
echo
cd ${HOME_PATH} 
tar -czvf ${INSTANCE_ID}_home_${INSTANCE_NAME}_${MIG_DATE}.tar.gz  ${INSTANCE_NAME}
mv ${INSTANCE_ID}_home_${INSTANCE_NAME}_${MIG_DATE}.tar.gz /home/eldar

echo
echo "Create database dump"
echo
PGPASSWORD="${DB_PASSWD}" pg_dump --format=plain --no-owner --no-acl -U ${DB_USER} -d ${DB_NAME} > /home/eldar/${INSTANCE_ID}_database_${INSTANCE_NAME}_${MIG_DATE}.sql

fi

cd /home/eldar
clear
echo 
echo "DONE!"
echo 
ls -lSah ${INSTANCE_ID}*

echo 
FILES=$(ls -d ${INSTANCE_ID}*)
TRANSFER=$(echo $FILES | tr ' ' ,|sed 's/^/{/' |sed 's/$/}/')
echo "YOU CAN TRANSFER THIS TO:"
echo
echo "LXC1 scp ${TRANSFER} lxc1.teamlead.ru:/home/eldar/"
echo "LXC2 scp -P65032 ${TRANSFER} lxc2.teamlead.ru:/home/eldar/"
echo "LXC3 scp -P65033 ${TRANSFER} lxc3.teamlead.ru:/home/eldar/"
echo "LXC4 scp -P65034 ${TRANSFER} lxc4.teamlead.ru:/home/eldar/"
echo "LXC5 scp -P65035 ${TRANSFER} lxc5.teamlead.ru:/home/eldar/"
