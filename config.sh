# superuser connection to the administrative database

export PGHOST=/tmp
export PGPORT=5432
export PGDATABASE=postgres
export PGUSER=postgres

# maximum seconds we want to wait for the backup to complete
# set to 0 to disable timeout

backup_timeout=0
