#! /bin/bash
function tmap-setup() {
   echo -e "\e[32mPlease enter a name for this VM. This is how the VM will be seen on the network."
   read -p '[ubuntuVMX]' MNAME
   if [ "$MNAME" == "" ]
   then
      MNAME='ubuntuVMX'
   fi
   echo -e "\e[32mPlease ensure that you have setup at least one shared folder for the VM. Press ENTER to continue."
   read TMP
   set +x
   sudo mkdir /mnt/shared
   sudo mount -t fuse.vmhgfs-fuse .host:/ /mnt/shared -o allow_other
   sudo sed -i.$(date "+%m%d%y").bak '$ a .host:/ /mnt/shared fuse.vmhgfs-fuse allow_other 0 0' /etc/fstab
   sudo sed -i.$(date "+%m%d%y").bak "s/ubuntu/$MNAME/g" /etc/hosts
   sudo sed -i.$(date "+%m%d%y").bak "s/ubuntu/$MNAME/g" /etc/hostname
   sudo sed -i.$(date "+%m%d%y").bak '/^deb cdrom:/s/^/# /' /etc/apt/sources.list
   sudo dpkg-reconfigure tzdata
   sudo apt update
   sudo apt install -y unattended-upgrades
   sudo apt full-upgrade -y
   sudo sed -i.$(date "+%m%d%y").bak "$ a ./tmap-install.sh after-reboot" ~/.profile
   set -x
   echo -e "\e[32mThe VM will now reboot and continue installation after the user logs back in. Press ENTER to continue."
   read TMP
}
function tmap-timemachine() {
      echo -e "\e[32mPlease enter the name you used for the time machine directory when setting up your VM Shared folders."
      read -p '[timemachine]:' TMSHARE
      if [ "$TMSHARE" == "" ]
      then
         TMSHARE='timemachine'
      fi
      echo -e "\e[32mPlease enter a user name to be used when accessing this time machine backup server"
      read -p '[timemachine]:' TMUNAME
      if [ "$TMUNAME" == "" ]
      then
         TMUNAME='timemachine'
      fi
      echo -e "\e[32mPlease enter a name to be used to identify this time machine backup server on Apple computers"
      read -p '[TimeMachineVMX]' TMNAME
      if [ "$TMNAME" == "" ]
      then
         TMNAME='TimeMachineVMX'
      fi
	  set +x
      sudo apt install -y build-essential devscripts debhelper cdbs autotools-dev dh-buildinfo libdb-dev libwrap0-dev libpam0g-dev libcups2-dev libkrb5-dev libltdl3-dev libgcrypt11-dev libcrack2-dev libavahi-client-dev libldap2-dev libacl1-dev libevent-dev d-shlibs dh-systemd avahi-daemon libc6-dev libnss-mdns git
      mkdir ~/netatalk-git
      cd ~/netatalk-git
      git clone https://github.com/adiknoth/netatalk-debian.git
      cd netatalk-debian
      debuild -b -uc -us
      cd ..
      LAT=`ls libatalk*.deb|grep -v dev`
      sudo dpkg -i $LAT
      NETAT=`ls netatalk*.deb`
      sudo dpkg -i $NETAT
      sudo addgroup timemachine
      sudo adduser --home /mnt/shared/$TMSHARE --no-create-home --ingroup timemachine $TMUNAME
      sudo chown -R $TMUNAME:timemachine /mnt/shared/$TMSHARE
      sudo sed -i.$(date "+%m%d%y").bak "$ a [$TMNAME]\ntime machine = yes\npath = /mnt/shared/$TMSHARE\nvol size limit = 980000\nvalid users = $TMUNAME\n" /etc/netatalk/afp.conf
      sudo systemctl enable netatalk.service
      sudo systemctl start netatalk.service
      sudo systemctl enable avahi-daemon.service
      sudo systemctl start avahi-daemon.service
	  set -x
}
function tmap-airprint() {
      echo -e "\e[32mPlease ensure that your printer is connected to the VM. Press ENTER to continue."
	  read TMP
	  set +x
      sudo apt install -y samba
      sudo sed -i.$(date "+%m%d%y").bak '/\[printers\]/,/^\[/ s/browseable = no/browseable = yes/' /etc/samba/smb.conf
      sudo sed -i '/\[printers\]/,/^\[/ s/guest ok = no/guest ok = yes/'  /etc/samba/smb.conf
      sudo systemctl restart smbd.service nmbd.service
      sudo apt install -y cups python-cups avahi-discover
      sudo cupsctl --remote-admin
      sudo systemctl restart cups
	  set -x
      echo -e "\e[32mOn your host machine open a browser and connect to your guest on port 631 \(i.e. http://guestname:631\)"
      echo -e "\e[32m\'guestname\' will be the name you provided during the initial setup after installing ubuntu."
      echo -e "\e[32mFollow the instructions to add your printer via the web interface."
}

if [ "$1" != "after-reboot" ]
then
   tmap-setup |& tee ~/tmap-setup.log
   sudo reboot
else
   echo -e "\e[32mResuming installation process. Press RETURN to continue."
   read TMP
   sudo sed -i "/after-reboot/d" ~/.profile
   echo -e "\e[32mDo you want to create a Time Machine Server?"
   read -p '[Y/n]' TMResponse
   if [ "$TMResponse" == "" ] || ["$TMResponse" == "Y" ] || ["$TMResponse" == "y" ]
   then
      tmap-timemachine |& tee ~/tmap-timemachine.log
   fi

   echo -e "\e[32mDo you want to create an Airprint Server?"
   read -p '[Y/n]' APResponse
   if [ "$APResponse" == "" ] || [ "$APResponse" == "Y" ] || [ "$APResponse" == "y"]
   then
      tmap-airprint |& tee ~/tmap-airprint.log
   fi
fi