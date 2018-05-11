#!/usr/bin/env bash
set -ex

sudo apt-get update -y
sudo apt-get install git -y
git clone https://github.com/openstack-dev/devstack || true
cd devstack; git checkout stable/ocata
#patch -p1 < /vagrant/patches/pip_version_check_fix.patch 
sudo apt-get install openvswitch-switch -y
sudo ovs-vsctl add-br br-ex
netif=$(ip a | grep '192.168.0' | awk '{print $NF}')
echo $netif
inet=$(ip a | grep "inet.*$netif" | cut -f6 -d' ')
sudo ip addr flush $netif
sudo ovs-vsctl add-port br-ex $netif
sudo ifconfig br-ex $inet up
sudo ip route del default
sudo ip route add default via 192.168.0.254
echo "source /vagrant/openrc" >> $HOME/.bash_profile
