#!/bin/bash

SHORT_PN=$1
LONG_PN=$2
RUN_COUNT=0
EMAIL_TO=mbentley@arcus.io
EMAIL_FROM=noreply@roche.com
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
		check_process
	fi
}

function check_process {
	RUN_COUNT=$(expr $RUN_COUNT + 1)

	if [ ${RUN_COUNT} -gt "3" ]; then
		echo -e "check_process has ran more then 3 times.\naborting."
		exit 1
	fi

	if ps aux | grep "${LONG_PN}" | grep -v ${0} | grep -v grep  > /dev/null ; then
	        echo -e "${SHORT_PN} is running.\ndone."
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
		        echo -e "false alarm, ${SHORT_PN} is running.\ndone."
			i=5
		else
		        echo "check ${i}: ${SHORT_PN} is not running..."
			DOWN_COUNT=$(expr $DOWN_COUNT + 1)
		fi
	done

	if [ ${DOWN_COUNT} -eq "5" ]; then
		echo -e "check_process has verified that ${SHORT_PN} is down.\nsending notification now..."
		email_notify
	else
		echo "re-starting check_process..."
		check_process
	fi
}

function email_notify {
	tmp=/tmp/check_${SHORT_PN}-`date +%F`
	touch $tmp && chmod 600 $tmp

	echo "To: ${EMAIL_TO}" >> $tmp
	echo "From: `hostname --fqdn` <${EMAIL_FROM}>" >> $tmp
	echo "Subject: ${SHORT_PN} on `hostname` is down" >> $tmp
	echo "" >> $tmp
	echo "check_process has determined that ${SHORT_PN} is not running." >> $tmp

	${SENDMAIL} -t -f ${EMAIL_TO} < $tmp

	rm $tmp
}

check_vars
