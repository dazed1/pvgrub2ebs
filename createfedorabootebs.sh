#!/bin/sh
# Version 0.7
# version0.1 from: http://www.ioncannon.net/system-administration/894/fedora-12-bootable-root-ebs-on-ec2/

# assumptions: you're on an amazon instance that has an extra EBS mounted at /dev/sdf

#from a base install, I need e2fsprogs; remove the next line if you're not on a yum system
yum -y install e2fsprogs

##########FILESYSTEMS SECTION##############
# forgive me, I used gentoo years ago during a period - came back to fedora, though!

#if you want to actually partition out your ebs...
#echo -e "o\nn\np\n1\n1\n+100M\nn\np\n2\n\n+2G\nt\n2\n82\nn\np\n3\n\n\na\n1\nw\n" | fdisk /dev/xvdf

echo -e "o\nw\n" | fdisk /dev/xvdf
mkfs.ext3 -F /dev/xvdf

mkdir /mnt/chroot
mount /dev/xvdf /mnt/chroot
mkdir /mnt/chroot/dev /mnt/chroot/proc /mnt/chroot/etc /mnt/chroot/sys
mount -o bind /dev /mnt/chroot/dev
mount -o bind /dev/pts /mnt/chroot/dev/pts
mount -o bind /dev/shm /mnt/chroot/dev/shm
mount -o bind /proc /mnt/chroot/proc
mount -o bind /sys /mnt/chroot/sys

cat <<EOL > /mnt/chroot/etc/fstab
/dev/xvda / ext4 relatime 1 1
none /dev/pts devpts gid=5,mode=620 0 0
none /dev/shm tmpfs defaults 0 0
none /proc proc defaults 0 0
none /sys sysfs defaults 0 0
EOL

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
name=Fedora 14 – x86_64 – Base
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-14&arch=x86_64
enabled=1

[updates-released]
name=Fedora 14 – x86_64 – Released Updates
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f14&arch=x86_64
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

cat <<EOF >> /mnt/chroot/etc/rc.sysinit

# below lines added for setting up a couple devices on ebs
# later, will make this sexier
mknod -m 0644 /dev/random c 1 8
chown root:root /dev/random
mknod -m 0644 /dev/urandom c 1 9
chown root:root /dev/urandom

#echo -e "o\nn\np\n1\n1\n+10G\nt\n1\n82\nn\np\n2\n\n\nw\n" | fdisk /dev/xvdc
#echo "y" | mkfs.ext4 /dev/xvdc2
#mkswap /dev/xvdc1
EOF

chroot /mnt/chroot chkconfig --level 2345 NetworkManager off
chroot /mnt/chroot chkconfig --level 2345 network on

# here's the trick...what should /boot look like? answer: plain as hell
cat <<EOL > /mnt/chroot/boot/grub/grub.conf

default=0
timeout=0
title Fedora14
        root (hd0)
        kernel /boot/vmlinuz ro root=/dev/xvda1 rd_NO_PLYMOUTH selinux=0
        initrd /boot/initramfs
EOL

chroot /mnt/chroot ln -s /boot/grub/grub.conf /boot/grub/menu.lst

kern=`ls /mnt/chroot/boot/vmlin*|awk -F/ '{print $NF}'`
ird=`ls /mnt/chroot/boot/initramfs*.img|awk -F/ '{print $NF}'`

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
