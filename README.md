Now that exclusive backup with `pg_start_backup()` and `pg_stop_backup()`
has been deprecated, it is more difficult to perform a PostgreSQL online
file system backup using a pre-backup and a post-backup script.

This project provides two `bash` scripts that can be used for that purpose.

## Usage ##

Edit `config.sh` and adapt the variables to your needs.

Call `pgpre.sh`.  If successful, it will print the starting location of
the backup and exit with a return code of 0.

Then perform your file system backup any way you want.

When you are done (even in case of error!) call `pgpost.sh` to end the
backup.  It will return a return code of 0 if successful and print
the contents of the `backup_label` file to standard output.

You have to collect this output to a file `backup_label` and copy that
file into the backup to complete the online backup.
Alternatively, you can get the file contents by connecting to the database
and running `SELECT backup_label FROM backup`.

## Configuration ##

The scripts are configured by editing `config.sh`.

The environment variables `PGHOST`, `PGPORT`, `PGDATABASE` and `PGUSER`
determine which database cluster is backed up.  The table `backup`
containint the backup information will be created in `PGDATABASE`.

The parameter `backup_timeout` can be set to 0 to disable a timeout
or to the number of seconds the pre-backup script should wait for
the backup to complete before marking the backup as failed.

## Implementation ##

If it does not already exist, the pre-backup script creates a table
`backup` with the following columns:

- `state`: a column with an enum type that can take the values `running`,
  `done`, `complete` and `failed`, indicating the state of the bachup

- `pid`: the backend process ID if the pre-backup process that waits for
  the backup to complete

- `backup_label`: the contents of the `backup_label` file for the backup

Then it enters the database into backup mode and returns the WAL position
of the checkpoint starting the backup.

After that, it exits sucessfully, indicating that the actual backup can
begin, but the co-process controlling the PostgreSQL session keeps
running in the background and waits for the `state` column in the `backup`
table to signal that the backup is done.

If that does not happen before `backup_timeout` expires, the backup is
marked as failed.

Once the backup is done, the co-process ends backup mode and stored the
resulting `backup_label` contents in the `backup` table.

The post-backup script sets the `state` column in the `backup` table to
`done` and waits until the pre-backup co-process has set the `state`
to `completed`.

Then it reads `backup_label` from the `backup` table and emits it on
standard output before ending.
