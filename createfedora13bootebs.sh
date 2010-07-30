#!/bin/sh
# createfedora13bootebs-i386.sh
# Version 0.4
# version0.1 from:  http://www.ioncannon.net/system-administration/894/fedora-12-bootable-root-ebs-on-ec2/
# changelog:
#   Version 0.2:    massive changes.  More useful to consider this the "initial" version
#                   note: non-working.  Most likely not because of anything in this script
#   Version 0.3:    stepping back from partitioning the root device, changing to hd0 pv-grub aki.
#                   Removed selinux; bad Brian!  Using the "it's complicated" excuse.
#                   Other minor changes.
#   Version 0.4:    added some sed for a menu.lst that will function for kernels other than what is out today.
#                   gathered some of the sections together with like-stuff.
#                   Changed some things to make them easier to un-shell (perl?) later

# assumptions: you're on an amazon instance that has an extra EBS mounted at /dev/sdf, and internet access
# TODO: do i386/x86_64 install based on what the instance is

#clear table, create /boot, create swap, create /
#echo -e "o\nn\np\n1\n1\n+100M\nn\np\n2\n\n+2G\nt\n2\n82\nn\np\n3\n\n\na\n1\nw\n" | fdisk /dev/sdf

echo "y" | mkfs.ext4 /dev/sdf

##########FILESYSTEMS SECTION##############
mkdir /mnt/chroot
mount /dev/sdf /mnt/chroot
mkdir /mnt/chroot/dev /mnt/chroot/proc /mnt/chroot/etc /mnt/chroot/sys
# forgive me, I used gentoo years ago during a period - came back to fedora, though!
mount -o bind /dev /mnt/chroot/dev
mount -o bind /dev/pts /mnt/chroot/dev/pts
mount -o bind /dev/shm /mnt/chroot/dev/shm
mount -o bind /proc /mnt/chroot/proc
mount -o bind /sys /mnt/chroot/sys

cat <<EOL > /mnt/chroot/etc/mtab
/dev/sdf / ext4 rw 0 0
none /proc proc rw 0 0
none /sys sysfs rw 0 0
none /dev/pts devpts rw,gid=5,mode=620 0 0
none /dev/shm tmpfs rw 0 0
EOL

cat <<EOL > /mnt/chroot/etc/fstab
/dev/xvda1               /                       ext4    relatime 1 1
none                    /dev/pts                devpts  gid=5,mode=620 0 0
none                    /dev/shm                tmpfs   defaults 0 0
none                    /proc                   proc    defaults 0 0
none                    /sys                    sysfs   defaults 0 0
/dev/xvdc1               swap                    swap    pri=0,nofail 0 0
/dev/xvdc2               /tmp                    ext3    relatime,nosuid,nofail 0 0
EOL

for i in console null zero ; do /sbin/MAKEDEV -d /mnt/chroot/dev -x $i ; done

cat <<EOL > /tmp/yumec2.conf
[main]
cachedir=/var/cache/yum
debuglevel=2
logfile=/var/log/yum.log
exclude=*-debuginfo
gpgcheck=0
obsoletes=1
reposdir=/dev/null

[base]
name=Fedora 13 – i386 – Base
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-13&arch=i386
enabled=1

[updates-released]
name=Fedora 13 – i386 – Released Updates
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f13&arch=i386
enabled=1
EOL

yum -c /tmp/yumec2.conf --installroot=/mnt/chroot -y install grub grubby
yum -c /tmp/yumec2.conf --installroot=/mnt/chroot -y groupinstall Base
yum -c /tmp/yumec2.conf --installroot=/mnt/chroot -y install openssh-server kernel-headers kernel-PAE
yum -c /tmp/yumec2.conf --installroot=/mnt/chroot -y clean packages

echo "UseDNS no" >> /mnt/chroot/etc/ssh/sshd_config
echo "PermitRootLogin without-password" >> /mnt/chroot/etc/ssh/sshd_config

cp /etc/rc.local /mnt/chroot/etc/
cp /etc/sysconfig/network /mnt/chroot/etc/sysconfig/network
cp /etc/sysconfig/network-scripts/ifcfg-eth0 /mnt/chroot/etc/sysconfig/network-scripts/ifcfg-eth0
cp /usr/local/sbin/* /mnt/chroot/usr/local/sbin/

cat <<EOF >> /mnt/chroot/etc/rc.sysinit

# below lines added for setting up a couple devices on ebs
# later, will make this sexier
mknod -m 0644 /dev/random c 1 8
chown root:root /dev/random
mknod -m 0644 /dev/urandom c 1 9
chown root:root /dev/urandom

echo -e "o\nn\np\n1\n1\n+10G\nt\n1\n82\nn\np\n2\n\n\nw\n" | fdisk /dev/xvdc
echo "y" | mkfs.ext4 /dev/xvdc2
mkswap /dev/xvdc1
EOF

chroot /mnt/chroot chkconfig --level 2345 NetworkManager off
chroot /mnt/chroot chkconfig --level 2345 network on

# here's the trick...what should /boot look like?  answer: plain as hell
cat <<EOL > /mnt/chroot/boot/grub/grub.conf

default=0
timeout=0
title Fedora13-PAE
        root (hd0)
        kernel /boot/vmlinuz ro root=/dev/xvda1 rd_NO_PLYMOUTH
        initrd /boot/initramfs
EOL

chroot /mnt/chroot ln -s /boot/grub/grub.conf /boot/grub/menu.lst

kern=`ls /mnt/chroot/boot/vm*PAE|awk -F/ '{print $NF}'`
ird=`ls /mnt/chroot/boot/ini*PAE.img|awk -F/ '{print $NF}'`

sed -ie "s/vmlinuz/$kern/" /mnt/chroot/boot/grub/grub.conf
sed -ie "s/initramfs/$ird/" /mnt/chroot/boot/grub/grub.conf

sync

umount /mnt/chroot/dev/shm
umount /mnt/chroot/dev/pts
umount /mnt/chroot/sys
umount /mnt/chroot/proc
umount /mnt/chroot/dev
umount /mnt/chroot

echo "I...I think we've done it."
