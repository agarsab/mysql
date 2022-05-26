#!/bin/bash
#================================================================
# AUTHOR        Angel Garcia-Galan (angelgs@gmail.com)
# COPYRIGHT     Cabildo de Tenerife (http://www.tenerife.es)
# LICENSE       European Union Public Licence (EUPL) (https://joinup.ec.europa.eu/collection/eupl/)
# SOURCE        https://github.com/agarsab/mysql
#
# FUNCTION      Makes a full backup (dump) of all MySQL databases
# NOTES         The script has to be run with mysql user/owner
#               Tested in MySQL 5.7 over CentOS 7.9
#
# ARGUMENTS     $1 = Path to store dump and log files
#               $2 = Number of days to preserve dumps
#
# IMPROVEMENTS  Avoid giving the password on the command line
#               Store password in an option file
#               https://dev.mysql.com/doc/refman/8.0/en/password-security-user.html
#

function print_log {
        NOW=`date '+%Y-%m-%d %H:%M:%S'`
        echo $NOW" "$1" "$2
}

EXIT_OK=0
EXIT_ERROR=1
TODAY=`date '+%Y-%m-%d'`

MYSQL_HOST=`hostname -s`
MYSQL_USR=root
MYSQL_PWD=123abcXYZ
MYSQL_CMD="/usr/bin/mysql"
BACKUP_CMD="/usr/bin/mysqldump"
BACKUP_ARG=" --add-drop-database --opt --routines --user="$MYSQL_USR" --password="$MYSQL_PWD

if [ ! -f $MYSQL_CMD ]; then
        print_log "ERROR: mysql command not found:" $MYSQL_CMD
        exit $EXIT_ERROR
fi

if [ ! -f $BACKUP_CMD ]; then
        print_log "ERROR: backup command not found:" $BACKUP_CMD
        exit $EXIT_ERROR
fi

if [ "$1" == "" ] || [ "$2" == "" ]; then
        print_log "ERROR: missing arguments."
        print_log "INFO: usage: "$0" </path/to/dumps> <days>"
        exit $EXIT_ERROR
fi

BACKUP_HOME=$1
if [ ! -w $BACKUP_HOME ]; then
        print_log "ERROR: backup path not writable:" $BACKUP_HOME
        exit $EXIT_ERROR
fi
BACKUP_LOG=$BACKUP_HOME"/"$TODAY"_"$MYSQL_HOST".log"

BACKUP_DAYS=$2
if [[ ! $BACKUP_DAYS =~ ^[0-9]+$ ]] || [[ ! $BACKUP_DAYS -gt 1 ]]; then
        print_log "ERROR: number of days:" $BACKUP_DAYS
        exit $EXIT_ERROR
fi

BACKUP_DBS=`$MYSQL_CMD --user=$MYSQL_USR -p$MYSQL_PWD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema)"`

for BACKUP_DB in $BACKUP_DBS; do
        BACKUP_SQL=$BACKUP_HOME"/"$TODAY"_"$MYSQL_HOST"_"$BACKUP_DB".sql"
        print_log "INFO: Starting backup database" $BACKUP_DB >> $BACKUP_LOG
        BACKUP_CMD=$BACKUP_CMD" "$BACKUP_ARG" --databases "$BACKUP_DB" --result-file="$BACKUP_SQL
        $BACKUP_CMD 2>> $BACKUP_LOG
        if [ "$?" -eq 0 ]; then
                print_log "INFO: mysqldump successful:" $BACKUP_SQL >> $BACKUP_LOG
        else
                print_log "ERROR: mysqldump error:" $BACKUP_CMD >> $BACKUP_LOG
        fi
        print_log "`ls -lh $BACKUP_SQL`" >> $BACKUP_LOG
        BACKUP_RESULT=`tail -5 "$BACKUP_SQL" | grep 'Dump completed'`
        if [ -z "BACKUP_RESULT" ]; then
                print_log "ERROR: Backup failed in database" $BACKUP_DB >> $BACKUP_LOG
        else
                print_log "INFO: Completed backup database" $BACKUP_DB >> $BACKUP_LOG
                print_log "INFO: Compressing file "$BACKUP_DB"..." >> $BACKUP_LOG
                nice gzip -f $BACKUP_SQL
                print_log "`ls -lh $BACKUP_SQL.gz`" >> $BACKUP_LOG
        fi
done

print_log "INFO: Removing old dumps and logs..." >> $BACKUP_LOG
OLD_FILES=`find $BACKUP_HOME -iname '20*.sql.gz' -mtime +$BACKUP_DAYS`
for FILE in $OLD_FILES; do
        print_log "INFO: Removing dump file" $FILE >> $BACKUP_LOG
        rm $FILE
done

OLD_FILES=`find $BACKUP_HOME -iname '20*.log' -mtime +$BACKUP_DAYS`
for FILE in $OLD_FILES; do
        print_log "INFO: Removing log file" $FILE >> $BACKUP_LOG
        rm $FILE
done

print_log "INFO: Finished." >> $BACKUP_LOG
exit $EXIT_OK
