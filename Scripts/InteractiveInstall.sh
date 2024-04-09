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

# Are we running as 'root'
[[ $EUID -ne 0 ]] && echo "This script must be run as root." && exit 1

# Get the administrator email of this soon to be Observium server
read -p "Enter the email address of the administrator: " ThisAdmin

# Get the Observium install script and proceed with installation
# (Note: provide a seed and hit enter to generate random database password ???)
wget http://www.observium.org/observium_installscript.sh
chmod +x observium_installscript.sh
sudo ./observium_installscript.sh
# Note: first user is "admin"
# Note: this also installs SNMPD and Unix agents

# Install postfix and mailutils
sudo apt install -y postfix
sudo apt install -y mailutils

# Install acme.sh and get initial certificate
sudo wget -O -  https://get.acme.sh | sh -s email=$ThisAdmin

sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt-get autoclean -y

echo "Q" | openssl s_client -connect www.google.com:443

