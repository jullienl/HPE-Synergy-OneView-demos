#version=RHEL8.3

repo --name="AppStream" --baseurl=file:///run/install/sources/mount-0000-cdrom/AppStream

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
# network --bootproto=static --ip={{ipaddr}} --netmask=255.255.252.0 --gateway=192.168.1.1 --nameserver=192.168.2.1 --hostname={{hostname}} --noipv6 --activate
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


# Include the partitioning logic from the %pre section. 
# Required to replace the $BOOTDRIVE variable with its value for the drive selection and partitionning
%include /tmp/part-include


# pre section
%pre --log=/tmp/kickstart_pre.log

echo "Currently mounted partitions"
df -Th

echo "=============================="
echo "Available memory"
free -m

# Directive for Gen9 using Broadcom CNA not discovering FCoE LUNs
if [[ "{{generation}}" == "Gen9" ]]; then
echo "Gen9 server detected, applying directives for successful FCoE discovery"
# End of software FCoE support with DCB enabled Ethernet CNAs since RHEL 8
# modprobe fcoe
fipvlan -c -s –a
sleep 50
fipvlan -c -s –a

# End of software FCoE support with DCB enabled Ethernet CNAs since RHEL 8
cat << EOF >> /tmp/part-include
#     # Capture adapter name of primary boot connection using MAC address coming from the Server Profile
#     adapter=`ip address | grep {{mac}} -B 1 -i | sed -n '1 p' | cut -c 4-9`
#     echo "Primary boot adapter is $adapter"
#     # Adding FCoE disk(s) 
#     fcoe --nic=$adapter --autovlan
      ignoredisk --only-use=mpatha
EOF

fi

# Select the first drive that is the closest to SIZE, the size of the boot disk defined in the Server Profile

echo "Detecting boot drive for OS installation..."
SIZE={{size}}
BOOTDRIVE=""
MINDELTA=100


for DEV in /sys/block/s*; do
    if [[ -d $DEV && `cat $DEV/size` -ne 0  ]]; then
        #echo $DEV
        DISKSIZE=`cat $DEV/size`
        GB=$(($DISKSIZE/2**21))
        #echo "size $GB"
        DELTA=$(( $GB - $SIZE ))
        if [ "$DELTA" -lt 0 ]; then 
            DELTA=$((-DELTA))
        fi
                
        if [ $DELTA -lt $MINDELTA ]; then
            MINDELTA=$DELTA
            DRIVE=`echo $DEV | awk '{ print substr ($0, 12 ) }'`
        fi 
    echo "Diff is $DELTA with `echo $DEV | awk '{ print substr ($0, 12 ) }'`: $GB GB"
    fi

done

# Collecting multipath device name tied to the drive found
BOOTDRIVE=`lsblk -nl -o NAME /dev/$DRIVE  | sed -n '2 p'`

echo "BOOTDRIVE detected is $BOOTDRIVE"

cat << EOF >> /tmp/part-include
    # Clear the Master Boot Record
    zerombr
    # Disk Partition clearing information
    clearpart --all --initlabel --drives=$BOOTDRIVE

    # System bootloader configuration
    bootloader --append="rhgb novga console=ttyS0,115200 console=tty0 panic=1" --location=mbr --boot-drive=$BOOTDRIVE
    #--driveorder="sda" --boot-drive=sda
    # --driveorder=$BOOTDRIVE

    # Disk partitioning information
    autopart --type=lvm
EOF

echo "=============================="
echo "Kickstart pre install script completed at: `date`"

%end



%packages
@^server-product-environment
@system-tools
kexec-tools

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

hostnamectl set-hostname {{hostname}}
hostnamectl --pretty set-hostname {{hostname}}
cp /etc/hostname /mnt/sysimage/etc/hostname
cp /etc/machine-info /mnt/sysimage/etc/machine-info

%end
