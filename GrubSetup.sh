#!/bin/sh
#
# Script to set up the chroot'ed /etc/fstab
#
#################################################################
CHROOT="${CHROOT:-/mnt/ec2-root}"
CHROOTDEV=${1:-UNDEF}
FSTAB="${CHROOT}/etc/fstab"
CHGRUBDEF="${CHROOT}/etc/default/grub"

# Check for arguments
if [[ $# -lt 1 ]]
then
   echo "Missing parameter(s). Aborting..." > /dev/stderr
   exit 1
fi

# Shouldn't need this, but the RPM seems to be broken (20160315)
if [[ ! -f ${CHGRUBDEF} ]]
then
   printf "The grub2-tools RPM (vers. "
   printf "$(rpm -q grub2-tools --qf '%{version}-%{release}\n')) "
   printf "was faulty. Installing ${CHGRUBDEF} from "
   printf "host system.\n"
   cp $(readlink -f $CHROOT/etc/sysconfig/grub) ${CHGRUBDEF}

   if [[ $? -ne 0 ]]
   then
      echo "Failed..." >> /dev/stderr
      exit 1
   fi
fi

# Add TERMINAL_OUTPUT line as necessary
if [[ $(grep -q GRUB_TERMINAL_OUTPUT ${CHGRUBDEF})$? -ne 0 ]]
then
   echo "Adding 'GRUB_TERMINAL_OUTPUT' to ${CHGRUBDEF}."
   sed -i '/GRUB_TERMINAL=/{N
      s/\n/\nGRUB_TERMINAL_OUTPUT="console"\n/
   }' ${CHGRUBDEF}
fi

## Only need if root not on LVM
## # Add appropriate root-dev
## if [[ $(grep -q "root=LABEL=" ${CHGRUBDEF})$? -ne 0 ]]
## then
##    echo "Adding root-label to ${CHGRUBDEF}."
##    RLABEL=$(e2label ${CHROOTDEV}2)
##    sed -i 's/GRUB_CMDLINE_LINUX="/&root=LABEL='${RLABEL}' /' ${CHGRUBDEF}
## fi

# Create a GRUB2 config file
chroot ${CHROOT} /sbin/grub2-install ${CHROOTDEV}
chroot ${CHROOT} /sbin/grub2-mkconfig  | sed 's#root='${CHROOTDEV}'. ##' > ${CHROOT}/boot/grub2/grub.cfg
CHROOTKRN=$(chroot $CHROOT rpm --qf '%{version}-%{release}.%{arch}\n' -q kernel)
chroot ${CHROOT} dracut -fv /boot/initramfs-${CHROOTKRN}.img ${CHROOTKRN}
