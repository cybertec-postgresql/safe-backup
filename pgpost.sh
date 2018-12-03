#!/bin/bash

# post-backup script for online backup

# load configuration
. ./setup.sh

# start a psql coprocess
coproc PSQL { psql -Atq; }

# make sure we exit on error
echo '\set ON_ERROR_STOP on' >&${PSQL[1]}
if [ $? -ne 0 ]; then exit 1; fi

# suppress unneeded output
echo 'SET client_min_messages = error;' >&${PSQL[1]}
if [ $? -ne 0 ]; then exit 1; fi

# notify the pre-backup coprocess that we are done
echo "UPDATE backup SET state = 'done'::backup_state;" >&${PSQL[1]}
if [ $? -ne 0 ]; then exit 1; fi

#wait for pg_stop_backup() to finish
while
	echo 'SELECT state FROM backup;' >&${PSQL[1]}
	if [ $? -ne 0 ]; then exit 1; fi
	read -u ${PSQL[0]} line
	[ "$line" = 'done' ]
do
	sleep 5
done

if [ "$line" != 'complete' ]; then
	echo "Backup failed" 1>&2
	echo '\q' >&${PSQL[1]}
	exit 1
fi

# get "backup_label"
echo 'SELECT backup_label FROM backup;' >&${PSQL[1]}
if [ $? -ne 0 ]; then exit 1; fi
echo '\q' >&${PSQL[1]}
if [ $? -ne 0 ]; then exit 1; fi

# copy "backup_label" to standard output
cat <&${PSQL[0]}

exit 0
