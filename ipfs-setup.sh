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

# install and symlink to ipfs
echo -e "Installing go-ipfs from ${BLUE}git@github.com:ipfs/go-ipfs${NC}..."
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
exec start-stop-daemon --start --chdir /home/$USER --chuid $USER --exec ${IPFS_BIN} -- daemon >> /var/log/ipfs.log 2>&1
EOL
sudo chmod 644 $IPFS_UPSTART

# update iptables to open port 5001
echo -e "Opening port 5001 in firewall..."
sudo iptables-restore <<EOL
*filter
-A INPUT -i lo -j ACCEPT
-A INPUT -d 127.0.0.0/8 -j REJECT
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -j ACCEPT
-A INPUT -p tcp --dport 80 -j ACCEPT
-A INPUT -p tcp --dport 443 -j ACCEPT
-A INPUT -p tcp --dport 8545 -j ACCEPT
-A INPUT -p tcp --dport 4567 -j ACCEPT
-A INPUT -p tcp --dport 30303 -j ACCEPT
-A INPUT -p tcp --dport 4547 -j ACCEPT
-A INPUT -p tcp --dport 30304 -j ACCEPT
-A INPUT -p udp --dport 30303 -j ACCEPT
-A INPUT -p udp --dport 30304 -j ACCEPT
-A INPUT -p udp --dport 5001 -j ACCEPT
-A INPUT -p tcp --dport 5001 -j ACCEPT
-A INPUT -p tcp -m state --state NEW --dport 22 -j ACCEPT
-A INPUT -p icmp --icmp-type echo-request -j ACCEPT
-A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7
-A INPUT -j DROP
-A FORWARD -j DROP
COMMIT
EOL

# start ipfs
if [ `pidof ipfs` <> 0 ]; then
    sudo service ipfs stop
fi
sudo service ipfs start
