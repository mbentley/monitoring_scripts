#!/bin/bash

SHORT_PN=$1
LONG_PN=$2
RUN_COUNT=0

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
	down_count=0

	for (( i=1; i<=5; i++ ))
	do
		sleep 2

		if ps aux | grep "${LONG_PN}" | grep -v ${0} | grep -v grep  > /dev/null ; then
		        echo -e "false alarm, ${SHORT_PN} is running.\ndone."
			i=5
		else
		        echo "check ${i}: ${SHORT_PN} is not running..."
			down_count=$(expr $down_count + 1)
		fi
	done

	if [ ${down_count} -eq "5" ]; then
		echo -e "check_process has verified that ${SHORT_PN} is down.\nstarting ${SHORT_PN} now..."
		fix_process
	else
		echo "re-starting check_process..."
		check_process
	fi
}

function fix_process {
	/etc/init.d/${SHORT_PN} start

	tmp=/tmp/check_${SHORT_PN}-`date +%F`
	touch $tmp && chmod 600 $tmp

	echo "To: mbentley@mbentley.net" >> $tmp
	echo "From: `hostname --fqdn` <mbentley@mbentley.net>" >> $tmp
	echo "Subject: ${SHORT_PN} on `hostname` was down" >> $tmp
	echo "" >> $tmp
	echo "check_process has determined that ${SHORT_PN} was stopped and has restarted the process." >> $tmp

	/usr/sbin/sendmail -t -f mbentley@mbentley.net < $tmp

	rm $tmp
}

check_process
