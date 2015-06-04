#!/bin/bash

WEBMON_DIR="/tmp/webmon"
SHORT_URL=${1}
FULL_URL=${2}
DOWN_FILE="down.${SHORT_URL}"
EMAIL_TO=youremail@yourdomain.com
EMAIL_FROM=youremail@yourdomain.com
LOG_FILE="/path/to/your/logfile/webmon.${SHORT_URL}.txt"
OFFLINE_COUNT=0
SENDMAIL=/usr/sbin/sendmail

function check_vars {
  if [ -z ${SHORT_URL} ]
  then
    echo -e "You must provide a short URL name as the first parameter\nExample:  ${0} google.com http://www.google.com/"
    exit 1
  fi

  if [ -z ${FULL_URL} ]
  then
    echo -e "You must provide a full URL as the second parameter\nExample:  ${0} google.com http://www.google.com/"
    exit 1
  else
    temp_dir
  fi
}

function temp_dir {
  if [ ! -d "${WEBMON_DIR}" ]
  then
    mkdir ${WEBMON_DIR}
  fi

  if [ ! -f ${LOG_FILE} ]
  then
    echo -e "STATUS\tDATE/TIME\t\tSTATUS CODE" > ${LOG_FILE}
  fi

  TEMPDIR=/tmp/webmon_${SHORT_URL}_$(date +%N)
  mkdir ${TEMPDIR}
  if [ ! -d "${TEMPDIR}" ]
  then
    echo "unable to create temp directory"
    exit 1
  fi
  internet_check
}

function internet_check {
  FULL_INET_STATUS_CODE=$(curl -q -k -m 5 -s -I http://www.google.com/robots.txt | grep HTTP)
  SHORT_INET_STATUS_CODE=$(echo ${FULL_INET_STATUS_CODE} | awk '{ print $2 }')

  if [ -z ${SHORT_INET_STATUS_CODE} ]
  then
    echo ${FULL_INET_STATUS_CODE}
    echo "Unable to access Google; assuming offline"
    exit 1
  fi

  if [ ${SHORT_INET_STATUS_CODE} != "200" ]
  then
    echo ${FULL_INET_STATUS_CODE}
    echo "Unable to access Google; assuming offline"
    exit 1
  fi

  query_status
}

function query_status {
  FULL_STATUS_CODE=$(curl -q -k -m 15 -s -I ${FULL_URL} | grep HTTP)
  SHORT_STATUS_CODE=$(echo ${FULL_STATUS_CODE} | awk '{ print $2 }')

  if [ -z ${SHORT_STATUS_CODE} ]
  then
    FULL_STATUS_CODE="No HTTP code returned"
    verify_offline
  fi

  if [ ${SHORT_STATUS_CODE} != "200" ]
  then
    verify_offline
  else
    echo "${FULL_STATUS_CODE}"
    online_check
  fi
}

function verify_offline {
  OFFLINE_COUNT=$(expr ${OFFLINE_COUNT} + 1)

  if [ ${OFFLINE_COUNT} == 2 ]
  then
    echo "${FULL_STATUS_CODE}"
    email_offline
  else
    query_status
  fi
}

function online_check {
  if [ -f ${WEBMON_DIR}/${DOWN_FILE} ]
  then
    echo -e "UP\t$(date +%F" "%R" "%Z)\t${FULL_STATUS_CODE}" >> ${LOG_FILE}
    rm ${WEBMON_DIR}/${DOWN_FILE}
    MAIL=${TEMPDIR}/mail_$(date +%F)
    touch ${MAIL}
    chmod 600 ${MAIL}
    echo "To: ${EMAIL_TO}" >> ${MAIL}
    echo "From: $(hostname --fqdn) <${EMAIL_FROM}>" >> ${MAIL}
    echo "Subject: webmon: ${SHORT_URL} is back online" >> ${MAIL}
    echo "" >> ${MAIL}
    echo "webmon status:" >> ${MAIL}
    echo "     ${SHORT_URL} (${FULL_URL}) is back online" >> ${MAIL}
    echo "     ${FULL_STATUS_CODE}" >> ${MAIL}
    ${SENDMAIL} -t < ${MAIL}
  fi

  cleanup_tmp
}

function email_offline {
  if [ ! -f ${WEBMON_DIR}/${DOWN_FILE} ]
  then
    echo -e "DOWN\t$(date +%F" "%R" "%Z)\t${FULL_STATUS_CODE}" >> ${LOG_FILE}
    MAIL=${TEMPDIR}/mail_$(date +%F)
    touch ${MAIL}
    chmod 600 ${MAIL}
    echo "To: ${EMAIL_TO}" >> ${MAIL}
    echo "From: $(hostname --fqdn) <${EMAIL_FROM}>" >> ${MAIL}
    echo "Subject: webmon: ${SHORT_URL} is offline" >> ${MAIL}
    echo "" >> ${MAIL}
    echo "webmon status:" >> ${MAIL}
    echo "     ${SHORT_URL} (${FULL_URL}) is currently offline" >> ${MAIL}
    echo "     ${FULL_STATUS_CODE}" >> ${MAIL}
    ${SENDMAIL} -t < ${MAIL}
  fi

  touch ${WEBMON_DIR}/${DOWN_FILE}

  cleanup_tmp
}

function cleanup_tmp {
  rm -rf ${TEMPDIR}
  exit 0
}

check_vars
