Now that exclusive backup with `pg_start_backup()` and `pg_stop_backup()`
has been deprecated, it is more difficult to perform a PostgreSQL online
file system backup using a pre-backup and a post-backup script.

This project provides two `bash` scripts that can be used for that purpose.

## Usage ##

Edit `pgpre.sh` and `pgpost.sh` and adapt the environment variables in
the beginning to your needs.

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
