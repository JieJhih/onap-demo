#!/usr/bin/env bash
set -ex


sudo apt update 
sudo apt-get install -y build-essential linux-headers-`uname -r`
sudo apt-get install -y virtualbox
ver=$(apt-cache policy vagrant | grep Installed | cut -d ':' -f 3)
if [[ "$ver" != "2.0.3" ]]; then
    wget --no-check-certificate https://releases.hashicorp.com/vagrant/2.0.3/vagrant_2.0.3_x86_64.deb
    sudo dpkg -i vagrant_2.0.3_x86_64.deb
fi

vagrant destroy -f
vagrant up
