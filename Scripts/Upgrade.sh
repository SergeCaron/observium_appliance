#!/bin/bash

##******************************************************************
## Revision date: 2024.04.18
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

## Guidelines and code examples provided by Observium.org (https://docs.observium.org/updating/)

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

# Remove previous backup, if any
SetAside=$(echo $LocalDirectory | sed 's/.*/&_old/')
if [ -d $SetAside ]; then
	echo "There is a previous backup of the Observium installation in $SetAside."
	read -n1 -r -p "If you continue, this backup will be removed. Hit ^C to abort ..." anykey
	rm -rf $SetAside
fi

# Get the latest Community Edition
wget -Oobservium-community-latest.tar.gz https://www.observium.org/observium-community-latest.tar.gz
if [ $? -ne 0 ]; then
    echo "Observium Community Edition cannot be safely downloaded at this time."
	exit 911
fi

# Find the name of the cron service on thi system
CRONServiceName=$(systemctl -all list-units --type=service | grep cron | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]].*$//')

# Stop the scheduler
echo ""
echo "Stopping CRON..."
systemctl stop $CRONServiceName
echo "... CRON must be manually restarted if this upgrade is aborted."

echo ""
echo "Creating backup files on the source Observium server ..."
cp $LocalDirectory/config.php ~/

# Get the credentials to dump the remote database
local_db_user=$(extractvalue db_user ~/config.php)
local_db_pass=$(extractvalue db_pass ~/config.php)
local_db_name=$(extractvalue db_name ~/config.php)

# Actual dump
echo "NOTE: the database password is available in plain text in Observium's configuration file."
echo "      You can safely disregard the mysqldump [Warning]."
mysqldump -u "$local_db_user" --password="$local_db_pass" --databases "$local_db_name" --no-tablespaces --add-drop-table --extended-insert > ~/observium-dump.sql
echo " ... database dump completed."

tar zcf ~/observium-rrd.tar.gz -C "$LocalDirectory" rrd
echo " ... rrd data compression completed."
echo ""

echo " ... done!"
echo ""

read -n1 -r -p "Abort if the backup is not successful ..." anykey

# Switch to the directory containing the Observium Community Edition
pushd $(dirname $LocalDirectory)
if [ ! -d "observium" ]; then
	echo "This installation does not conform to the Observium Community Edition default install directory '(observium')."
	exit 911
fi

# Protect current installation
mv $LocalDirectory $SetAside

# Recreate Community Edition
tar zxvf observium-community-latest.tar.gz

# Override the data
mv $SetAside/rrd observium/
mv $SetAside/logs observium/
mv $SetAside/config.php observium/

# Get back to our root ;-)
popd

# Update DB schema:
$LocalDirectory/discovery.php -u

# Force an immediate rediscovery of all devices to make sure things are up to date
echo ""
echo "Forcing a rediscovery of all devices is a long process recommended"
echo "if it has been a very long time since you've updated."
read -n 1 -r -p "Force an immediate rediscovery of all devices to make sure things are up to date? [N/y]"  anykey
echo ""
if [[ $anykey =~ ^[Yy]$ ]]
then
    $LocalDirectory/discovery.php -h all
fi

# Start the scheduler
echo "Starting CRON..."
systemctl start $CRONServiceName

echo "Done!"


