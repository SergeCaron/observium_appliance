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

# New in Ubuntu 22.04: autoaccept service restarts instead of using interactive mode
echo "\$nrconf{restart} = 'a';" > /etc/needrestart/conf.d/no-prompt.conf

# Install on a bare installation
sudo apt update && sudo apt install -y wget
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt-get autoclean -y

