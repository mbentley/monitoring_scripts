#!/bin/bash

CHECKPROC_DIR="/tmp/checkproc"
SHORT_PN=${1}
LONG_PN=${2}
DOWN_FILE="down.${SHORT_PN}"
EMAIL_TO=mbentley@arcus.io
EMAIL_FROM=noreply@roche.com
RUN_COUNT=0
SENDMAIL=/usr/bin/mail

function check_vars {
	if [ -z ${SHORT_PN} ]
	then
		echo -e "You must provide a short process name as the first parameter\nExample:  ${0} sshd /usr/sbin/sshd"
		exit 1
	fi

	if [ -z ${LONG_PN} ]
	then
		echo -e "You must provide a long process name as the second parameter\nExample:  ${0} sshd /usr/sbin/sshd"
		exit 1
	else
		temp_dir
	fi
}

function temp_dir {
	if [ ! -d "${CHECKPROC_DIR}" ]
	then
		mkdir ${CHECKPROC_DIR}
	fi

	TEMPDIR=/tmp/checkproc_${SHORT_PN}_`date +%N`
	mkdir ${TEMPDIR}
	if [ ! -d "${TEMPDIR}" ]
	then
		echo "unable to create temp directory"
		exit 1
	fi
	check_process
}

function check_process {
	RUN_COUNT=$(expr $RUN_COUNT + 1)

	if [ ${RUN_COUNT} -gt "3" ]; then
		echo -e "check_process has ran more then 3 times.\naborting."
		exit 1
	fi

	if ps aux | grep "${LONG_PN}" | grep -v ${0} | grep -v grep  > /dev/null ; then
	        echo "${SHORT_PN} is running."
		online_check
	else
		echo -e "${SHORT_PN} may be down.\nperforming further tests..."
		sleep 2
		process_down_verify
	fi
}

function process_down_verify {
	DOWN_COUNT=0

	for (( i=1; i<=5; i++ ))
	do
		sleep 2

		if ps aux | grep "${LONG_PN}" | grep -v ${0} | grep -v grep  > /dev/null ; then
		        echo "false alarm, ${SHORT_PN} is running."
			i=5
		else
		        echo "check ${i}: ${SHORT_PN} is not running..."
			DOWN_COUNT=$(expr $DOWN_COUNT + 1)
		fi
	done

	if [ ${DOWN_COUNT} -eq "5" ]; then
		echo "check_process has verified that ${SHORT_PN} is down."
		email_offline
	else
		echo "re-starting check_process..."
		check_process
	fi
}

function online_check {
	if [ -f ${CHECKPROC_DIR}/${DOWN_FILE} ]
	then
		rm ${CHECKPROC_DIR}/${DOWN_FILE}
		MAIL=${TEMPDIR}/mail_`date +%F`
		touch ${MAIL}
		chmod 600 ${MAIL}
		echo "To: ${EMAIL_TO}" >> ${MAIL}
		echo "From: `hostname --fqdn` <${EMAIL_FROM}>" >> ${MAIL}
		echo "Subject: ${SHORT_PN} on `hostname` is back up" >> ${MAIL}
		echo "" >> ${MAIL}
		echo "check_process has determined that ${SHORT_PN} is back up." >> ${MAIL}
		${SENDMAIL} -t -f ${EMAIL_TO} < ${MAIL}
	fi

	cleanup_tmp
}

function email_offline {
	if [ ! -f ${CHECKPROC_DIR}/${DOWN_FILE} ]
	then
		MAIL=${TEMPDIR}/mail_`date +%F`
		touch ${MAIL}
		chmod 600 ${MAIL}
		echo "To: ${EMAIL_TO}" >> ${MAIL}
		echo "From: `hostname --fqdn` <${EMAIL_FROM}>" >> ${MAIL}
		echo "Subject: ${SHORT_PN} on `hostname` is down" >> ${MAIL}
		echo "" >> ${MAIL}
		echo "check_process has determined that ${SHORT_PN} is not running." >> ${MAIL}
		${SENDMAIL} -t -f ${EMAIL_TO} < ${MAIL}
	fi

	touch ${CHECKPROC_DIR}/${DOWN_FILE}

	cleanup_tmp
}

function cleanup_tmp {
	rm -rf ${TEMPDIR}
	exit 0
}

check_vars
