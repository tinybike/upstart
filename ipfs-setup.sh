#!/bin/bash
# go-ipfs setup helper
# @author Jack Peterson (jack@tinybike.net)

set -e
trap "exit" INT

# set up go directory and GOPATH
if [ ! -d "$HOME/go" ]; then
    mkdir -p ~/go
    echo "export GOPATH=$HOME/go" >> ~/.bashrc
    echo "export PATH=$PATH:$HOME/go/bin:/usr/local/go/bin" >> ~/.bashrc
    source ~/.bashrc
fi

# install and symlink to ipfs
go get -u github.com/ipfs/go-ipfs/cmd/ipfs
sudo ln -s `which ipfs` /usr/local/bin/ipfs

# set up ipfs log file
sudo touch /var/log/ipfs.log
sudo chown $USER:$USER /var/log/ipfs.log

# create upstart configuration file
sudo cat >/etc/init/ipfs.conf <<EOL
#!upstart
description "ipfs"

env USER=${USER}

start on runlevel [2345]
stop on runlevel [016]

respawn

exec start-stop-daemon --start --chdir /home/$USER --chuid $USER --exec /usr/local/bin/ipfs -- daemon >> /var/log/ipfs.log 2>&1
EOL

# update iptables to open port 5001
sudo iptables-restore < <<EOL
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
sudo service ipfs start
echo "IPFS daemon running:" `pidof ipfs`
