#!/bin/bash

WM_DIR="/tmp/webmon"
SHORT_URL=${1}
FULL_URL=${2}

DOWN_FILE="down.${SHORT_URL}"
EMAIL_TO=mbentley@arcus.io
EMAIL_FROM=noreply@roche.com
OFFLINE_COUNT=0
SENDMAIL=/usr/bin/mail

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
	if [ ! -d "${WM_DIR}" ]
	then
		mkdir ${WM_DIR}
	fi

	TEMPDIR=/tmp/webmon_${SHORT_URL}_`date +%N`
	mkdir ${TEMPDIR}
	if [ ! -d "${TEMPDIR}" ]
	then
		echo "unable to create temp directory"
		exit 1
	fi
	query_status
}

function query_status {
	FULL_STATUS_CODE=`curl -k -m 15 -s -I -q ${FULL_URL} | grep HTTP`
	SHORT_STATUS_CODE=`echo ${FULL_STATUS_CODE} | awk '{ print $2 }'`

	if [ ${SHORT_STATUS_CODE} != "200" ]
	then
		verify_offline
	else
		echo "${FULL_STATUS_CODE}"
		online_check
	fi
}

function verify_offline {
	OFFLINE_COUNT=`expr ${OFFLINE_COUNT} + 1`

	if [ ${OFFLINE_COUNT} == 3 ]
	then
		echo "${FULL_STATUS_CODE}"
		email_offline
	else
		sleep 1
		query_status
	fi
}

function online_check {
	if [ -f ${WM_DIR}/${DOWN_FILE} ]
	then
		rm ${WM_DIR}/${DOWN_FILE}
		MAIL=${TEMPDIR}/mail_`date +%F`
		touch ${MAIL}
		chmod 600 ${MAIL}
		echo "To: ${EMAIL_TO}" >> ${MAIL}
		echo "From: ${EMAIL_FROM}" >> ${MAIL}
		echo "Subject: webmon: ${SHORT_URL} is back online" >> ${MAIL}
		echo "" >> ${MAIL}
		echo "webmon status:" >> ${MAIL}
		echo "     ${FULL_URL} is back online" >> ${MAIL}
		echo "     ${FULL_STATUS_CODE}" >> ${MAIL}
		${SENDMAIL} -t -f ${EMAIL_TO} < ${MAIL}
	fi

	cleanup_tmp
}

function email_offline {
	if [ ! -f ${WM_DIR}/${DOWN_FILE} ]
	then
		MAIL=${TEMPDIR}/mail_`date +%F`
		touch ${MAIL}
		chmod 600 ${MAIL}
		echo "To: ${EMAIL_TO}" >> ${MAIL}
		echo "From: ${EMAIL_FROM}" >> ${MAIL}
		echo "Subject: webmon: ${SHORT_URL} is offline" >> ${MAIL}
		echo "" >> ${MAIL}
		echo "webmon status:" >> ${MAIL}
		echo "     ${FULL_URL} is currently offline" >> ${MAIL}
		echo "     ${FULL_STATUS_CODE}" >> ${MAIL}
		${SENDMAIL} -t -f ${EMAIL_TO} < ${MAIL}
	fi

	touch ${WM_DIR}/${DOWN_FILE}

	cleanup_tmp
}

function cleanup_tmp {
	rm -rf ${TEMPDIR}
	exit 0
}

check_vars
