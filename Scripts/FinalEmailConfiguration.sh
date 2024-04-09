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

# Extract the emal address used by Let's Encrypt
ThisAdmin=$(sudo grep -i email /root/.acme.sh/account.conf)
# Presume we are getting a string similar to parameter=value, quoted or not, with whitespace or not
ThisAdmin=$(echo $ThisAdmin | sed -e "s/^.*=//" -e "s/;//" | tr -d ?[:blank:]\'\"?)

read -p "External email address where postmaster's and root's mail is redirected [$ThisAdmin]: " email
email=${email:-$ThisAdmin}

echo "Creating aliases..."
sudo sed -i  -e '$aroot: external' /etc/aliases
sudo sed -i -e "\$aexternal: $email" /etc/aliases
sudo newaliases
sudo systemctl reload postfix

echo "Sending a test message..."
echo "This message 1/2" | mail -s "Test message to the administrator" $email
echo "This message 2/2" | mail -s "Test message redirected from root" root

echo "-----------------------------------------------------------"
echo "After editing, these parameters differ from the default configuration:"
echo ""
postconf -n
echo ""
echo "Done!"
