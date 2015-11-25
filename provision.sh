#!/usr/bin/env bash
# provision.sh
# Provisioning script for SuricataPod Vagrant DevelopmentBox

# Update and install common tools
dnf -y update
dnf -y install git vim make libtool gcc

# Install dependencies for suricata
dnf -y install hiredis-devel luajit-devel libpcap-devel pcre-devel libyaml-devel file-devel zlib-devel jansson-devel nss-devel libcap-ng-devel libnet-devel

# Create working area for Suricata installation
mkdir /home/vagrant/dev
cd /home/vagrant/dev

# Clone Suricata GIT Repo
git clone https://github.com/inliniac/suricata.git
cd suricata
git clone https://github.com/ironbee/libhtp
./autogen.sh
./configure --prefix=/usr/ --sysconfdir=/etc/ --localstatedir=/var/
make && make install-full

# Set the correct user permisions
chown -R vagrant:vagrant /home/vagrant/dev
chown -R vagrant:vagrant /etc/suricata
