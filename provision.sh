#!/usr/bin/env bash
# provision.sh
# Provisioning script for SuricataPod Vagrant DevelopmentBox

# Variables for this provisioning script
GOLANGFILE="go1.5.1.linux-amd64.tar.gz"

# Function to add something to a file if it is not present
function add_if_not_there {
    if ! grep -q "$1" "$2"; then
        echo "$1" >> "$2"
    fi
}

function log {
    echo "[$(date)]: $1"
}

function quiet_install {
    dnf --quiet --debuglevel=0 -y install $* &> /dev/null

    # Check if something whent wrong with install
    if [ ! $? -eq 0 ]; then
        log "Something went wrong while installing: $*"
        exit 1
    else
        log "Done installing: $*"
    fi
}

# Update and install common tools
log "Updating system and installing common tools"
dnf --quiet --debuglevel=0 -y update &> /dev/null
quiet_install wget git vim make libtool gcc docker

# Start docker process
log "Starting Docker process"
sudo systemctl start docker

# Install dependencies for suricata
log "Installing dependencies for Suricata"
quiet_install hiredis-devel luajit-devel libpcap-devel pcre-devel libyaml-devel file-devel zlib-devel jansson-devel nss-devel libcap-ng-devel libnet-devel

# Download Go
log "Downloading Go-Lang Archive"
wget --quiet https://storage.googleapis.com/golang/$GOLANGFILE -O /tmp/$GOLANGFILE

# If the file was downloaded and all is good, extract the archive and set needed environment variables
if [ $? -eq 0 ] && [ -f /tmp/$GOLANGFILE ]; then
    
    # Extract the golang tar to /usr/local
    tar -C /usr/local -xzf /tmp/$GOLANGFILE

    # Check if something went wrong with un-archiving
    if [ ! $? -eq 0 ]; then
        log "Something went wrong while extracting $GOLANGFILE"
        exit 1
    fi

    # Add ENV variables and create workspace
    add_if_not_there "export PATH=$PATH:/usr/local/go/bin" "/home/vagrant/.bash_profile"
    [ -d /home/vagrant/go ] || mkdir /home/vagrant/go
    [ -d /home/vagrant/go/src ] || mkdir /home/vagrant/go/src
    [ -d /home/vagrant/go/pkg ] || mkdir /home/vagrant/go/pkg
    [ -d /home/vagrant/go/bin ] || mkdir /home/vagrant/go/bin
    add_if_not_there "export GOPATH=/home/vagrant/go" "/home/vagrant/.bash_profile"
else
    log "Cannot find GOLANGFILE, was download not successful?"
    exit 1
fi


# Create working area for Suricata installation
log "Creating dev folder in Vagrant HOME"
[ -d /home/vagrant/dev ] || mkdir /home/vagrant/dev

# Clone Suricata GIT Repo
log "Cloning Suricata GITHUB Repository"
cd /home/vagrant/dev
git clone https://github.com/inliniac/suricata.git

log "Cloning OISF LibHTP GITHUB Repository"
cd suricata
git clone https://github.com/ironbee/libhtp

# Configure and make suricata
log "Configuring suricata and performing make + install"
./autogen.sh
./configure --prefix=/usr/ --sysconfdir=/etc/ --localstatedir=/var/ --enable-luajit --enable-hiredis --enable-lua --enable-luajit --enable-geoip
make
make install-full

# Set the correct user permisions
log "Setting ownership permisions"
chown -R vagrant:vagrant /home/vagrant
chown -R vagrant:vagrant /etc/suricata
