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

read -p "Enter the email address of the administrator of this domain: " ThisAdmin
ThisDomain=$(echo $ThisAdmin | sed -e "s/^.*@//" | tr -d "[:blank:]")
ThisHost=$(hostname)
FQDN=$ThisHost.$ThisDomain
echo "A certificate will be requested for" $FQDN

# Get the certificate (example based on Google Cloud DNS API
# See details at https://github.com/acmesh-official/acme.sh/wiki/dnsapi#dns_gcloud)
export CLOUDSDK_ACTIVE_CONFIG_NAME=default  # see the note above
.acme.sh/acme.sh --issue --dns dns_gcloud -d $FQDN

# Wait for user's confirmation
read -n1 -r -p "Hit ^C to abort or press anykey to confirm that a certificate is available..." anykey

# Overwrite the default virtual host configurations
sudo cp $(dirname "$0")/000-default.conf /etc/apache2/sites-available/000-default.conf

# Enable related modules
sudo a2enmod ssl
sudo a2enmod rewrite
sudo a2enmod headers

# Update Apache2 configuration
sudo mkdir /etc/apache2/certificate
.acme.sh/acme.sh --install-cert -d $FQDN \
--cert-file      /etc/apache2/certificate/apache-certificate.crt  \
--key-file       /etc/apache2/certificate/apache.key  \
--fullchain-file /etc/apache2/certificate/server-ca.crt \
--reloadcmd     "service apache2 force-reload"

# Install CRON job
.acme.sh/acme.sh --install-cronjob

# To activate the new configuration, you need to run:
sudo systemctl restart apache2


