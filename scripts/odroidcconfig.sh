#!/bin/bash

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.

echo "Creating \"fstab\""
echo "# OdroidC fstab" > /etc/fstab
echo "" >> /etc/fstab
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0 
tmpfs   /var/cache/apt/archives tmpfs   defaults,noexec,nosuid,nodev,mode=0755 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults        0 0
" > /etc/fstab

  
if [ -e "/c2.flag" ]; then
  echo "Adding sound modules"
  #TODO: only works for C2 at the moment
  echo "
snd_soc_pcm5102
snd_soc_odroid_dac
" >> /etc/modules
fi

echo "Prevent services starting during install, running under chroot" 
echo "(avoids unnecessary errors)"
cat > /usr/sbin/policy-rc.d << EOF
exit 101
EOF
chmod +x /usr/sbin/policy-rc.d

echo "Installing additonal packages"
apt-get update
apt-get -y install u-boot-tools liblircclient0 lirc 

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d

echo "Adding custom modules overlayfs, squashfs and nls_cp437"
echo "overlayfs" >> /etc/initramfs-tools/modules
echo "squashfs" >> /etc/initramfs-tools/modules
echo "nls_cp437" >> /etc/initramfs-tools/modules

echo "Copying volumio initramfs updater"
cd /root/
mv volumio-init-updater /usr/local/sbin

#On The Fly Patch
if [ "$PATCH" = "volumio" ]; then
echo "No Patch To Apply"
else
echo "Applying Patch ${PATCH}"
PATCHPATH=/${PATCH}
cd $PATCHPATH
#Check the existence of patch script
if [ -f "patch.sh" ]; then
sh patch.sh
else
echo "Cannot Find Patch File, aborting"
fi
cd /
rm -rf ${PATCH}
fi
rm /patch

echo "Changing to 'modules=dep'"
echo "(otherwise Odroid won't boot due to uInitrd 4MB limit)"
sed -i "s/MODULES=most/MODULES=dep/g" /etc/initramfs-tools/initramfs.conf

#First Boot operations
echo "Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart

echo "Creating initramfs 'volumio.initrd'"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp

echo "Creating uInitrd from 'volumio.initrd'"
if [ -e "/c1.flag" ]; then
   echo "  for kernel armhf"
   mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
   rm /c1.flag
else
   echo "  for kernel AArch64"
   mkimage -A arm64 -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
   rm /c2.flag
fi

echo "Removing unnecessary /boot files"
rm /boot/volumio.initrd




