#!/usr/bin/env bash
# provision.sh
# Provisioning script for SuricataPod Vagrant DevelopmentBox

# Variables for this provisioning script
GOLANGFILE="go1.5.1.linux-amd64.tar.gz"
KIBANAFILE="kibana-4.3.0-linux-x64.tar.gz"

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

function check_result {
    if [ ! $1 -eq 0 ]; then
        log "$2"
        exit 1
    fi
}

function safe_append {
    if ! grep -q "$1" "$2"; then
        echo "$1" >> "$2"
        check_result $? "Something whent wrong while adding content to $2"
    fi
}

function safe_create {
    [ -d $1 ] || mkdir $1
    check_result $? "Something went wrong while creating: $1"
}

# Add Elastic key to the system
rpm --import https://packages.elastic.co/GPG-KEY-elasticsearch

# Add the Elasticsearch Repository to DNF
echo "[elasticsearch-2.x]
name=Elasticsearch repository for 2.x packages
baseurl=http://packages.elastic.co/elasticsearch/2.x/centos
gpgcheck=1
gpgkey=http://packages.elastic.co/GPG-KEY-elasticsearch
enabled=1" > /etc/yum.repos.d/elasticsearch.repo

# Add the Logstash Repository to DNF
echo "[logstash-2.1]
name=Logstash repository for 2.1.x packages
baseurl=http://packages.elastic.co/logstash/2.1/centos
gpgcheck=1
gpgkey=http://packages.elastic.co/GPG-KEY-elasticsearch
enabled=1" > /etc/yum.repos.d/logstash.repo

# Update and install common tools
log "Updating system and installing common tools"
dnf --quiet --debuglevel=0 -y update &> /dev/null
quiet_install htop nload wget git vim make libtool gcc docker elasticsearch logstash redis

# Enable Elasticsearch
log "Enabeling Elasticsearch in systemctl"
/bin/systemctl daemon-reload
/bin/systemctl enable /usr/lib/systemd/system/elasticsearch.servicie

# Make it so that the vagrant user can use docker without use of SUDO
log "Adding docker group and vagrant user to docker group"
groupadd docker
gpasswd -a vagrant docker

# Start docker process
log "Starting Docker process"
sudo systemctl start docker

# Install dependencies for suricata
log "Installing dependencies for Suricata"
quiet_install GeoIP-devel hiredis-devel luajit-devel libpcap-devel pcre-devel libyaml-devel file-devel zlib-devel jansson-devel nss-devel libcap-ng-devel libnet-devel

# Download Kibana
log "Downloading Kibana Archive"
wget --quiet https://download.elastic.co/kibana/kibana/$KIBANAFILE -O /tmp/$KIBANAFILE

# If the file was downloaded and all is good, then extract the archive
if [ $? -eq 0 ] && [ -f /tmp/$KIBANAFILE ]; then

    # Extract the kibana archive
    tar -C /usr/local -xzf /tmp/$KIBANAFILE
    check_result $? "Something went wrong while extracting /tmp/$KIBANAFILE"
else
    log "Cannot find $KIBANAFILE, was download not successful?"
    exit 1
fi

# Download Go
log "Downloading Go-Lang Archive"
wget --quiet https://storage.googleapis.com/golang/$GOLANGFILE -O /tmp/$GOLANGFILE

# If the file was downloaded and all is good, extract the archive and set needed environment variables
if [ $? -eq 0 ] && [ -f /tmp/$GOLANGFILE ]; then
    
    # Extract the golang tar to /usr/local
    tar -C /usr/local -xzf /tmp/$GOLANGFILE
    check_result $? "Something went wrong while extracting /tmp/$GOLANGFILE"

    # Create golang workspace
    safe_create /home/vagrant/go
    safe_create /home/vagrant/go/src
    safe_create /home/vagrant/go/pkg
    safe_create /home/vagrant/go/bin
    
    # Add ENV variables (PATH and GOPATH)
    safe_append "export PATH=$PATH:/usr/local/go/bin" "/home/vagrant/.bash_profile"
    safe_append "export GOPATH=/home/vagrant/go" "/home/vagrant/.bash_profile"
else
    log "Cannot find $GOLANGFILE, was download not successful?"
    exit 1
fi


# Create working area for Suricata installation
log "Creating dev folder in Vagrant HOME"
safe_create /home/vagrant/dev

# Clone Suricata GIT Repo
log "Cloning Suricata GITHUB Repository"
cd /home/vagrant/dev
if [ -d suricata ]; then rm -rf suricata; fi
git clone https://github.com/inliniac/suricata.git

log "Cloning OISF LibHTP GITHUB Repository"
cd suricata
if [ -d libhtp ]; then rm -rf libhtp; fi
git clone https://github.com/ironbee/libhtp

log "Running Suricata autogen"
./autogen.sh > /tmp/suricata_autogen.log 2>&1
check_result $? "Something when wrong when running autogen.sh: `cat /tmp/suricata_autogen.log`"

log "Configuring Suricata"
./configure --prefix=/usr/ --sysconfdir=/etc/ --localstatedir=/var/ --enable-luajit --enable-hiredis --enable-geoip > /tmp/suricata_configure.log 2>&1
check_result $? "Something went wrong when trying to configure suricata: `cat /tmp/suricata_configure.log`"

log "Making Suricata"
make > /tmp/suricata_make.log 2>&1
check_result $? "Something went wrong when trying to make suricata: `cat /tmp/suricata_make.log`"

log "Installing Suricata"
make install-full > /tmp/suricata_make_install.log 2>&1
check_result $? "Something went wrong when trying to install suricata: `cat /tmp/suricata_make_install.log`"

# Set the correct user permisions
log "Setting ownership permisions"
chown -R vagrant:vagrant /home/vagrant
chown -R vagrant:vagrant /etc/suricata
