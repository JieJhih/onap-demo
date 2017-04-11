#!/bin/bash

# Read configuration files
NEXUS_REPO=$(cat /opt/config/nexus_repo.txt)
ARTIFACTS_VERSION=$(cat /opt/config/artifacts_version.txt)
DOCKER_KEY=$(cat /opt/config/docker_key.txt)
DNS_IP_ADDR=$(cat /opt/config/dns_ip_addr.txt)
CLOUD_ENV=$(cat /opt/config/cloud_env.txt)
GERRIT_BRANCH=$(cat /opt/config/gerrit_branch.txt)

# Add host name to /etc/host to avoid warnings in openstack images
if [[ $CLOUD_ENV == "openstack" ]]
then
	echo 127.0.0.1 $(hostname) >> /etc/hosts
fi

# Download dependencies
add-apt-repository -y ppa:openjdk-r/ppa
apt-get update
apt-get install -y apt-transport-https ca-certificates wget openjdk-8-jdk git ntp ntpdate

# Download scripts from Nexus
curl -k $NEXUS_REPO/org.openecomp.demo/boot/$ARTIFACTS_VERSION/docker_key.txt -o /opt/config/docker_key.txt
curl -k $NEXUS_REPO/org.openecomp.demo/boot/$ARTIFACTS_VERSION/asdc_vm_init.sh -o /opt/asdc_vm_init.sh
curl -k $NEXUS_REPO/org.openecomp.demo/boot/$ARTIFACTS_VERSION/asdc_serv.sh -o /opt/asdc_serv.sh
chmod +x /opt/asdc_vm_init.sh
chmod +x /opt/asdc_serv.sh
mv /opt/asdc_serv.sh /etc/init.d
update-rc.d asdc_serv.sh defaults

# Download and install docker-engine and docker-compose
apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys $DOCKER_KEY
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" | sudo tee /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual
apt-get install -y docker-engine

mkdir /opt/docker
curl -L https://github.com/docker/compose/releases/download/1.9.0/docker-compose-`uname -s`-`uname -m` > /opt/docker/docker-compose
chmod +x /opt/docker/docker-compose

# Create partition and mount the external volume
curl -k $NEXUS_REPO/org.openecomp.demo/boot/$ARTIFACT_VERSION/asdc_ext_volume_partitions.txt -o /opt/asdc_ext_volume_partitions.txt

if [[ $CLOUD_ENV == "rackspace" ]]
then
	DISK="xvdb"
else
	DISK="vdb"
fi

sfdisk /dev/$DISK < /opt/asdc_ext_volume_partitions.txt
mkfs -t ext4 /dev/$DISK"1"
mkdir -p /data
mount /dev/$DISK"1" /data
echo "/dev/"$DISK"1  /data           ext4    errors=remount-ro,noatime,barrier=0 0       1" >> /etc/fstab

# DNS IP address configuration
echo "nameserver "$DNS_IP_ADDR >> /etc/resolvconf/resolv.conf.d/head
resolvconf -u

# Clone Gerrit repository
cd /opt
mkdir -p /data/environments
mkdir -p /data/scripts
mkdir -p /data/logs/BE
mkdir -p /data/logs/FE
chmod 777 /data
chmod 777 /data/logs/BE
chmod 777 /data/logs/FE

git clone -b $GERRIT_BRANCH --single-branch http://gerrit.onap.org/r/sdc.git

cat > /root/.bash_aliases << EOF
alias dcls='/data/scripts/docker_clean.sh \$1'
alias dlog='/data/scripts/docker_login.sh \$1'
alias rund='/data/scripts/docker_run.sh'
alias health='/data/scripts/docker_health.sh'
EOF

# Rename network interface in openstack Ubuntu 16.04 images. Then, reboot the VM to pick up changes
if [[ $CLOUD_ENV == "openstack" ]]
then
	sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/g" /etc/default/grub
	grub-mkconfig -o /boot/grub/grub.cfg
	sed -i "s/ens[0-9]*/eth0/g" /etc/network/interfaces.d/*.cfg
	echo "APT::Periodic::Unattended-Upgrade \"0\";" >> /etc/apt/apt.conf.d/10periodic
	reboot
fi

# Run docker containers. For openstack Ubuntu 16.04 images this will run as a service after the VM has restarted
./asdc_vm_init.sh