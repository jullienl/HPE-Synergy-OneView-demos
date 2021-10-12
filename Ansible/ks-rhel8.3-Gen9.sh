#version=RHEL8.3

repo --name="AppStream" --baseurl=file:///run/install/sources/mount-0000-cdrom/AppStream


# For Gen9 not discovering the LUN
fcoe --nic=ens3f2 --autovlan

# Only use sda disk
ignoredisk --only-use=mpatha

# System bootloader configuration
bootloader --append="rhgb novga console=ttyS0,115200 console=tty0 panic=1" --location=mbr 
#--driveorder="sda" --boot-drive=sda

# Clear the Master Boot Record
zerombr

# Disk Partition clearing information
clearpart --all --initlabel --drives=mpatha

# Disk partitioning information
autopart --type=lvm

# Reboot after installation
reboot

# Use text mode install
text

# Use CDROM installation media
cdrom

# Keyboard layouts
keyboard --xlayouts='us'

# System language
lang en_US.UTF-8

# Installation logging level
logging --level=info

# Network information
# network --bootproto=static --ip={{ipaddr}} --netmask=255.255.252.0 --gateway=192.168.1.1 --nameserver=192.168.2.1 --hostname={{inventory_hostname}} --noipv6 --activate
network --bootproto=static --device=team0 --gateway=192.168.1.1 --ip={{ipaddr}} --nameserver=192.168.2.1 --netmask=255.255.252.0 --activate --teamslaves="ens3f0,ens3f1" --teamconfig='{"runner": {"name": "activebackup"}}'

# Root password
rootpw --iscrypted $6$In5T/HbkcnsjD.FS$L4yxkuNZHwtMJr3Zcl7mYWHmd3C1jW5VKDGe/Vqa8ICx/SM8uwM5VV9zrnVXl6NX27ra5j065tHAuK9l88hN3/

# System authorization information
authselect --enableshadow --passalgo=sha512

# SELinux configuration
selinux --disabled

# Run the Setup Agent on first boot
firstboot --disable

# Do not configure the X Window System
skipx

# System services
services --disabled="kdump,rpcbind,sendmail,postfix,chronyd"

# System timezone
timezone Europe/Paris --isUtc

# Create additional repo during installation - REMOVED FROM HERE AS DO NOT OFFER THE NO GPGCHECK OPTION - MOVED TO %POST
# repo --install --name="RHEL-8.3_baseos" --baseurl="https://liogw.lj.lab/deployment/rhel83-x64/BaseOS" --noverifyssl
# repo --install --name="RHEL-8.3_appstream" --baseurl="https://liogw.lj.lab/deployment/rhel83-x64/appstream" --noverifyssl

%pre --log=/tmp/kickstart_pre.log
modprobe fcoe
fipvlan -c -s –a
sleep 50
fipvlan -c -s –a

%end

%packages
@^server-product-environment
@system-tools
kexec-tools

echo "=============================="
echo "Kickstart pre install script completed at: `date`"

%end




%addon com_redhat_kdump --enable --reserve-mb='auto'

%end


%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end



%post --nochroot --log=/mnt/sysimage/var/log/kickstart_post_nochroot.log


echo "Copying %pre stage log files in /var/log folder"
/usr/bin/cp -rv /tmp/kickstart_pre.log /mnt/sysimage/var/log/

echo "=============================="
echo "Currently mounted partitions"
df -Th


# Set up the yum repositories for RHEL.
configure_yum_repos()
{
  # Enable internal RHEL repos (baseOS + appstream).
  cat >> /etc/yum.repos.d/rhel_liogw.repo << RHEL
[RHEL-8.3_baseos]
name=RHEL-8.3_baseos
baseurl=https://liogw.lj.lab/deployment/rhel83-x64/BaseOS
enabled=1
gpgcheck=0
sslverify=0

[RHEL-8.3_appstream]
name=RHEL-8.3_appstream
baseurl=https://liogw.lj.lab/deployment/rhel83-x64/appstream
enabled=1
gpgcheck=0
sslverify=0

RHEL
}

##########################################################################################################


configure_yum_repos

hostnamectl set-hostname {{inventory_hostname}}
hostnamectl --pretty set-hostname {{inventory_hostname}}
cp /etc/hostname /mnt/sysimage/etc/hostname
cp /etc/machine-info /mnt/sysimage/etc/machine-info


%end
