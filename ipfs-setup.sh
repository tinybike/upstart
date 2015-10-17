#!/bin/bash
# go-ipfs setup helper
# @author Jack Peterson (jack@tinybike.net)

set -e
trap "exit" INT

IPFS_BIN="/usr/local/bin/ipfs"
IPFS_LOG="/var/log/ipfs.log"
IPFS_UPSTART="/etc/init/ipfs.conf"

BLUE='\033[0;34m'
NC='\033[0m'

# set up go directory and GOPATH
if [ ! -d "$HOME/go" ]; then
    echo "Setting up ~/go directory and GOPATH env variable..."
    mkdir -p ~/go
    echo "export GOPATH=$HOME/go" >> ~/.bashrc
    echo "export PATH=$PATH:$HOME/go/bin:/usr/local/go/bin" >> ~/.bashrc
    source ~/.bashrc
fi
export GOPATH=$HOME/go
export PATH=$PATH:$HOME/go/bin:/usr/local/go/bin

# install and symlink to ipfs
echo -e "Get go-ipfs: ${BLUE}git@github.com:ipfs/go-ipfs${NC}"
if [ -f "${IPFS_BIN}" ]; then
    sudo rm $IPFS_BIN
fi
go get -u github.com/ipfs/go-ipfs/cmd/ipfs
echo -e "Installed:" $BLUE`which ipfs`$NC
if [ ! -f "${IPFS_BIN}" ]; then
    sudo ln -s `which ipfs` $IPFS_BIN
fi
echo -e "Created symlink:" $BLUE`which ipfs`$NC

# set up ipfs log file
echo -e "Log file: ${BLUE}${IPFS_LOG}${NC}"
if [ -f "${IPFS_LOG}" ]; then
    sudo rm $IPFS_LOG
fi
sudo touch $IPFS_LOG
sudo chown $USER:$USER $IPFS_LOG

# create upstart configuration file
echo -e "Upstart script: ${BLUE}${IPFS_UPSTART}${NC}"
if [ -f "${IPFS_UPSTART}" ]; then
    sudo rm $IPFS_UPSTART
fi
sudo touch $IPFS_UPSTART
sudo chmod 666 $IPFS_UPSTART
cat >$IPFS_UPSTART <<EOL
#!upstart
description "ipfs"
env USER=${USER}
start on runlevel [2345]
stop on runlevel [016]
respawn
exec start-stop-daemon --start --chuid $USER --exec ${IPFS_BIN} -- daemon >> ${IPFS_LOG} 2>&1
EOL
sudo chmod 644 $IPFS_UPSTART

# update firewall: open port 5001
echo -e "Opening port ${BLUE}5001${NC}..."
UDP="INPUT -p udp --dport 5001 -j ACCEPT"
TCP="INPUT -p tcp --dport 5001 -j ACCEPT"
set +e
sudo iptables -D $UDP >> /dev/null 2>&1
sudo iptables -D $TCP >> /dev/null 2>&1
set -e
sudo iptables -A $UDP
sudo iptables -A $TCP

# start ipfs
sudo service ipfs status | grep start >> /dev/null && sudo service ipfs stop
sudo service ipfs start
