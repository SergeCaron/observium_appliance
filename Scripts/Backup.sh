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

DefaultRemoteDirectory=/opt/observium
read -p "Remote Observium installation directory [$DefaultRemoteDirectory]: " RemoteDirectory
RemoteDirectory=${RemoteDirectory:-$DefaultRemoteDirectory}

read -p "Enter remote Observium user and server in the form user@<IP Address>: " sourceserver

echo
echo "Copying the remote Observium server data. The local user password may be required twice:"

# Create a public/private key pair if we don't have one
if [ ! -f .ssh/id_rsa.pub ]; then
	ssh-keygen
fi

# Copy our public key to the remote server: the .ssh may not exists in the administrator home directory
ssh $sourceserver -T 'mkdir .ssh 2>/dev/null'                                                     
cat .ssh/id_rsa.pub | ssh $sourceserver -T "cat >> .ssh/authorized_keys"

echo "Creating backup files on the source Observium server ..."
# Note: exit on scp failure: this is a cheap way of validating the remote directory.
scp $sourceserver:$RemoteDirectory/config.php ~/ || exit 911

# Get the credentials to dump the remote database
remote_db_user=$(extractvalue db_user ~/config.php)
remote_db_pass=$(extractvalue db_pass ~/config.php)
remote_db_name=$(extractvalue db_name ~/config.php)

echo $remote_db_pass | ssh $sourceserver -T "mysqldump -u $remote_db_user -p --databases $remote_db_name --no-tablespaces --add-drop-table --extended-insert > $RemoteDirectory/observium-dump.sql"
echo "... database dump completed."

ssh $sourceserver -T tar zcf $RemoteDirectory/observium-rrd.tar.gz -C $RemoteDirectory rrd
echo " ... rrd data compression completed."
echo ""

echo "Copying backup files from the remote Observium server ..."
scp $sourceserver:$RemoteDirectory/observium-rrd.tar.gz ~/
scp $sourceserver:$RemoteDirectory/observium-dump.sql ~/
echo " ... done!"
echo ""

read -n1 -r -p "Press any key to continue..." anykey

