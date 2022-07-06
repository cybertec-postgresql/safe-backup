#!/bin/bash

# pre-backup script for online backup

# load configuration
. ./config.sh

# start a coprocess that will perform the backup
coproc BACKUP {
	# start a psql coprocess
	coproc PSQL { psql -Atq; }

	# make sure we exit on error
	echo '\set ON_ERROR_STOP on' >&${PSQL[1]}
	if [ $? -ne 0 ]; then exit 1; fi

	# suppress unneeded output
	echo 'SET client_min_messages = error;' >&${PSQL[1]}
	if [ $? -ne 0 ]; then exit 1; fi

	# create the necessary objects if they don't exist yet
	echo "DO \$\$BEGIN
			CREATE TYPE backup_state
				AS ENUM ('running', 'done', 'complete', 'failed');
		EXCEPTION
			WHEN duplicate_object
			THEN NULL;
		END;\$\$;" >&${PSQL[1]}
	if [ $? -ne 0 ]; then exit 1; fi

	echo 'CREATE TABLE IF NOT EXISTS backup (
			id integer CONSTRAINT backup_pkey PRIMARY KEY DEFAULT 1,
			state backup_state NOT NULL,
			pid integer,
			backup_label text,
			tablespace_map text
		);' >&${PSQL[1]}
	if [ $? -ne 0 ]; then exit 1; fi

	echo 'CREATE UNIQUE INDEX IF NOT EXISTS backup_unique ON backup ((1));' >&${PSQL[1]}
	if [ $? -ne 0 ]; then exit 1; fi

	# kill any currently running backup
	echo "SELECT count(pg_terminate_backend(pid))
	FROM backup
	WHERE state = 'running'::backup_state;" >&${PSQL[1]}
	if [ $? -ne 0 ]; then exit 1; fi

	# read and ignore the query result
	read -u ${PSQL[0]} line
	if [ $? -ne 0 ]; then exit 1; fi

	# start the online backup
	echo "SELECT pg_backup_start('$(date +%F\ %T)', FALSE);" >&${PSQL[1]}
	if [ $? -ne 0 ]; then exit 1; fi

	# report the backup starting location
	read -u ${PSQL[0]} line
	echo "$line"

	# insert the information about the running backup into the "backup" table
	echo "INSERT INTO backup (state, pid, backup_label, tablespace_map)
		VALUES ('running'::backup_state, pg_backend_pid(), NULL, NULL)
		ON CONFLICT ON CONSTRAINT backup_pkey DO UPDATE
		SET state = 'running'::backup_state, pid = pg_backend_pid(),
			backup_label = NULL, tablespace_map = NULL;" >&${PSQL[1]}
	if [ $? -ne 0 ]; then exit 1; fi

	# wait for the backup to finish
	declare -i secs_waited=0
	while
		echo 'SELECT state FROM backup WHERE pid = pg_backend_pid();' >&${PSQL[1]}
		if [ $? -ne 0 ]; then exit 1; fi
		read -u ${PSQL[0]} line
		[ "$line" = 'running' ]
	do
		# exit with error if the timeout has expired
		if [ "$backup_timeout" -gt 0 -a "$secs_waited" -gt "$backup_timeout" ]; then
			echo "UPDATE backup SET
				state = 'failed'::backup_state;" >&${PSQL[1]}
			echo '\q' >&${PSQL[1]}
			echo "Backup timed out" 1>&2
			exit 1
		fi

		sleep 5

		secs_waited=secs_waited+5
	done

	if [ "$line" != 'done' ]; then
		echo "Backup failed" 1>&2
		echo '\q' >&${PSQL[1]}
		exit 1
	fi

	# complete backup and store "backup_label"
	echo "UPDATE backup SET
		(state, backup_label, tablespace_map) =
		(SELECT 'complete'::backup_state, labelfile, spcmapfile
			FROM pg_backup_stop());" >&${PSQL[1]}
	if [ $? -ne 0 ]; then exit 1; fi

	# quit the psql coprocess
	echo '\q' >&${PSQL[1]}
}

# report the backup starting location
read -u ${BACKUP[0]} line
rc=$?

if [ "$rc" -eq 0 ]; then
	echo "backup starting location: $line"
fi

exit $rc
