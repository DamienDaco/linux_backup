#!/usr/bin/env bash
# Inspired by http://stackoverflow.com/questions/19664893/linux-shell-script-for-database-backup
# Modified to add .cnf file for safety 
# Added db name passed as a command line argument ($1)
# Added mail recipient as argument $2
# To use this script, add the db name as argument, e.g.: "dbbackup.sh dbname example@mail.com"

# A file named .dbname.cnf must exist in the root folder. 
# For ex., if your db is called 'foo', the file must be named .foo.cnf
# This file should contain your credentials with the following structure:
# [client]
# password=”your_password_here_did_you_notice_the_double_quotes?"
# [mysqldump]
# user=username
# host=localhost

if [ $# -eq 0 ]; then
	echo "No argument supplied. Correct usage: ./dbbackup.sh DB_NAME EMAIL@EXAMPLE.COM"
	echo "Exiting."
	exit 1
fi

dbname=$1

# Email Settings
message_success="Hi,
Your '$1' database backup was generated successfully.
"
message_failure="Warning:
Your '$1' database backup failed. Please investigate
"
subject="Database backup status"
recipient=$2
sender="damien@daco.tech"
boundary="gc0p4Jq0M2Yt08j34c0p"


now="$(date +'%d_%m_%Y_%H_%M_%S')"
filename="${dbname}_db_backup_${now}"
backupfolder="/backup/db"
dumpfile="$backupfolder/$filename"
#compressedfile="${backupfolder}/${filename}.gz"
logfile="${backupfolder}/${dbname}_backup_log_$(date +'%m_%Y').log"
echo "$dbname db mysqldump started at $(date +'%d-%m-%Y %H:%M:%S')" >> "$logfile"

# Attempt to create a dump:
# Measure the duration in milliseconds (date %s%N returns time in nanoseconds, then we divide it by 1000000)

dump_start=$(($(date +%s%N)/1000000))

# Call mysqldump, use the .dbname.cnf file for credentials, redirect errors to logfile
mysqldump --defaults-extra-file=/root/.${dbname}.cnf --default-character-set=utf8 $dbname > $dumpfile 2>> $logfile

dump_end=$(($(date +%s%N)/1000000))
dump_duration=$(($dump_end - $dump_start))

# Check if the dump was succesful, by checking the return status from previous command.
# It should return zero: 
if [ "$?" -eq 0 ]; then

echo "$dbname db mysqldump finished at $(date +'%d-%m-%Y %H:%M:%S')" >> "$logfile"

# Compress file, and measure duration in milliseconds:

compress_start=$(($(date +%s%N)/1000000))

gzip --best $dumpfile 2>> $logfile

compress_end=$(($(date +%s%N)/1000000))
compress_duration=$(($compress_end - $compress_start))

	if [ -f "${dumpfile}.gz" ]; then
		echo $message_success
		echo "Mysqldump duration: $dump_duration milliseconds."
		echo "Compression duration: $compress_duration milliseconds."
		# Delete the uncompressed file to save disk space
		# rm -f $uncompressedfile

		message="${message_success} 
Mysqldump duration: $dump_duration milliseconds.
Compression duration: $compress_duration milliseconds.
"
		echo $message >> $logfile
		success=1
	else
		success=0
	fi
fi

# Send a mail to user:

if [ "$success" -eq 1 ]; then

cat << EOF | /usr/sbin/sendmail -t
From: $sender
To: $recipient
Subject: $subject
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="${boundary}"

This is a multi-part message in MIME format.

--$boundary
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: quoted-printable

$message

--$boundary
Content-Type: application/x-gzip
Content-Disposition: attachment; filename="${filename}.gz"
Content-Transfer-Encoding: base64 

$(base64 "${dumpfile}.gz")

--$boundary--

EOF

# In case of failure, inform the user anyway, by sending an email with log file attached:

else
cat << EOF | /usr/sbin/sendmail -t
From: $sender
To: $recipient
Subject: $subject
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="${boundary}"

This is a multi-part message in MIME format.

--$boundary
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: quoted-printable

$message

--$boundary
Content-Type: text/plain
Content-Disposition: attachment; filename="${logfile}"
Content-Transfer-Encoding: base64 

$(base64 $logfile)

--$boundary--

EOF



fi

