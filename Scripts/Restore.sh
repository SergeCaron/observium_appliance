#!/bin/bash

##******************************************************************
## Revision date: 2024.04.09
##
## Copyright (c) 2022-2024 PC-Évolution enr.
## This code is licensed under the GNU General Public License (GPL).
##
## THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
## ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
## IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
## PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
##
##******************************************************************

## Guidelines and code examples provided by Observium.org (https://docs.observium.org/server-migration/)

extractvalue () {
# $1 is the parameter
# $2 is the configuration file containing a (hopefully) single line parameter=value
#       existence of this file is NOT validated!

		# Allow a single instance of the parameter in this configuration file.
		count=$(grep -ow "$1" $2 | wc -l)
		if [[ "$count" -ne 1 ]] ; then
			while :
			do
				read -p "File $2 must contain a single instance of $1: abort this script with ^C and edit the file." anykey
				sleep 1
				read -p "Abort this script with ^C to exit." anykey
			done
		fi
 
		# Note: there is a special place in Hell for the creators of BASH parameter expansion ...
        Value=$(grep $1 $2 | sed -e "s/^.*=//" -e "s/;//" | tr -d ?[:blank:]\'\"?)

        # This script has no protection against passwords, usernames, etc., containing spaces
        if [ "$Value" == "${Value// /}" ]; then
                echo $Value
        else
                read -p "Internal error: '$Value' contains white space. Hit ^C to abort this script." anykey
                echo ${Value// /}
        fi
}

# Are we running as 'root'
[[ $EUID -ne 0 ]] && echo "This script must be run as root." && exit 1


DefaultLocalDirectory=/opt/observium
read -p "Local Observium installation directory [$DefaultLocalDirectory]: " LocalDirectory
LocalDirectory=${LocalDirectory:-$DefaultLocalDirectory}

# Make sure we have a 'valid' directory.
if [ ! -f $LocalDirectory/config.php ]; then
	echo "Observium configuration file not found in $LocalDirectory. Aborting ..."
	exit 911
fi

# Get the credentials to restore the remote database
local_db_user=$(extractvalue db_user $LocalDirectory/config.php)
local_db_pass=$(extractvalue db_pass $LocalDirectory/config.php)
local_db_name=$(extractvalue db_name $LocalDirectory/config.php)

# Presume a backup directory
PresumedDirectory=${SUDO_USER:+"/home/$SUDO_USER"}
read -p "Backup directory [$PresumedDirectory]: " BackupDirectory
BackupDirectory=${BackupDirectory:-$PresumedDirectory}

# Make sure we have a 'valid' configuration backup.
if [ ! -f $BackupDirectory/config.php ]; then
	echo "Observium configuration file not found in $BackupDirectory/. Aborting ..."
	exit 911
fi

# Get the credentials configured for the remote database
remote_db_user=$(extractvalue db_user $BackupDirectory/config.php)
remote_db_pass=$(extractvalue db_pass $BackupDirectory/config.php)
remote_db_name=$(extractvalue db_name $BackupDirectory/config.php)

echo
echo "Replacing the database credentials in the original configuration file:"
cp $BackupDirectory/config.php $BackupDirectory/configcandidate.php
pattern='s/'${remote_db_user}'/'${local_db_user}'/g'
sed -i "$pattern" $BackupDirectory/configcandidate.php
pattern='s/'${remote_db_pass}'/'${local_db_pass}'/g'
sed -i "$pattern" $BackupDirectory/configcandidate.php
pattern='s/'${remote_db_name}'/'${local_db_name}'/g'
sed -i "$pattern" $BackupDirectory/configcandidate.php
echo 
cat <(echo "Please review configuration variances:") \
    <(echo "--------------------------------------") \
	<(echo) \
    <(diff -c -b $LocalDirectory/config.php $BackupDirectory/configcandidate.php) | less

# Let the user decide what is kept...
read -r -p "Overwrite $LocalDirectory/config.php? [Y/n]: " killit
killit=${killit,,} # make it lower case
if [[ $killit =~ ^(y| ) ]] || [[ -z $killit ]]; then
    cp $BackupDirectory/configcandidate.php /opt/observium/config.php
fi

## See https://docs.observium.org/server-migration/ for documentation...

echo
echo "Caution: yoo will be asked for the mysql server password three times while restoring the Observium database."
echo "------------------------------------------------------------------------------------------------------------"

# Drop everything in current database. This uses the MySQL root password
echo
echo "Dropping existing Observium database contents ..."
echo "SET FOREIGN_KEY_CHECKS = 0;" > ./drop_all_tables.sql
(mysqldump --add-drop-table --no-data --no-tablespaces $local_db_name -u root -p | grep 'DROP TABLE') | tee -a ./drop_all_tables.sql
echo "SET FOREIGN_KEY_CHECKS = 1;" >> ./drop_all_tables.sql
mysql -u root -p $local_db_name < ./drop_all_tables.sql
rm ./drop_all_tables.sql
echo "... Done!"

# Restore RRDs while there is no active polling.
echo
echo "Restoring RRDs ..."
pushd $LocalDirectory
rm -rf rrd
tar zxvf $BackupDirectory/observium-rrd.tar.gz
chown -R $local_db_user.www-data rrd
popd
echo "... Done!"

echo
echo "Restoring the $local_db_name database ..."
mysql -u root -p $local_db_name < $BackupDirectory/observium-dump.sql
echo "... Done!"

read -p "Press any key to continue: " anykey

