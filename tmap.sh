#! /bin/bash
green=`tput setaf 2`
reset=`tput sgr 0`
function tmap-setup() {
   echo -e "${green}Please enter a name for this VM. This is how the VM will be seen on the network."
   read -p '[ubuntuVMX]{reset}' MNAME
   if [ "$MNAME" == "" ]
   then
      MNAME='ubuntuVMX'
   fi
   echo "${green}Please ensure that you have setup at least one shared folder for the VM. Press ENTER to continue.${reset}"
   read TMP
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
   sudo sed -i.$(date "+%m%d%y").bak "$ a ~/TMAP/tmap.sh after-reboot" ~/.profile
   echo "${green}The VM will now reboot and continue installation after the user logs back in. Press ENTER to continue.${reset}"
   read TMP
}
function tmap-timemachine() {
      echo "${green}Please enter the name you used for the time machine directory when setting up your VM Shared folders."
      read -p "[timemachine]:${reset}" TMSHARE
      if [ "$TMSHARE" == "" ]
      then
         TMSHARE='timemachine'
      fi
      echo -e "${green}Please enter a user name to be used when accessing this time machine backup server"
      read -p "[timemachine]:${reset}" TMUNAME
      if [ "$TMUNAME" == "" ]
      then
         TMUNAME='timemachine'
      fi
      echo "${green}Please enter a name to be used to identify this time machine backup server on Apple computers"
      read -p "[TimeMachineVMX]${reset}" TMNAME
      if [ "$TMNAME" == "" ]
      then
         TMNAME='TimeMachineVMX'
      fi
      sudo apt install -y build-essential devscripts debhelper cdbs autotools-dev dh-buildinfo libdb-dev libwrap0-dev libpam0g-dev libcups2-dev libkrb5-dev libltdl3-dev libgcrypt11-dev libcrack2-dev libavahi-client-dev libldap2-dev libacl1-dev libevent-dev d-shlibs dh-systemd avahi-daemon libc6-dev libnss-mdns
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
      TMPATH="/mnt/shared/$TMSHARE"
      sudo adduser --home $TMPATH --no-create-home --ingroup timemachine $TMUNAME
      sudo chown -R $TMUNAME:timemachine $TMPATH
      sudo chmod 755 $TMPATH
      sudo sed -i.$(date "+%m%d%y").bak "$ a [$TMNAME]\ntime machine = yes\npath = $TMPATH \nvol size limit = 980000\nvalid users = $TMUNAME\n" /etc/netatalk/afp.conf
      sudo systemctl enable netatalk.service
      sudo systemctl start netatalk.service
      sudo systemctl enable avahi-daemon.service
      sudo systemctl start avahi-daemon.service
}
function tmap-airprint() {
      echo "${green}Please ensure that your printer is connected to the VM. Press ENTER to continue.${reset}"
	   read TMP
      sudo apt install -y samba
      sudo sed -i.$(date "+%m%d%y").bak '/\[printers\]/,/^\[/ s/browseable = no/browseable = yes/' /etc/samba/smb.conf
      sudo sed -i '/\[printers\]/,/^\[/ s/guest ok = no/guest ok = yes/'  /etc/samba/smb.conf
      sudo systemctl restart smbd.service nmbd.service
      sudo apt install -y cups python-cups avahi-discover
      sudo cupsctl --remote-admin
      sudo systemctl restart cups
      echo "${green}On your host machine open a browser and connect to your guest on port 631 \(i.e. http://guestname:631\)"
      echo "${green}\'guestname\' will be the name you provided during the initial setup after installing ubuntu."
      echo "${green}Follow the instructions to add your printer via the web interface.${reset}"
}

if [ "$1" != "after-reboot" ]
then
   tmap-setup |& tee ~/tmap-setup.log
   sudo reboot
else
   echo "${green}Resuming installation process. Press RETURN to continue.${reset}"
   read TMP
   sudo sed -i "/after-reboot/d" ~/.profile
   echo "${green}Do you want to create a Time Machine Server?"
   read -p "[Y/n]${reset}" TMResponse
   if [ "$TMResponse" == "" ] || ["$TMResponse" == "Y" ] || ["$TMResponse" == "y" ]
   then
      tmap-timemachine |& tee ~/tmap-timemachine.log
   fi

   echo "${green}Do you want to create an Airprint Server?"
   read -p "[Y/n]${reset}" APResponse
   if [ "$APResponse" == "" ] || [ "$APResponse" == "Y" ] || [ "$APResponse" == "y" ]
   then
      tmap-airprint |& tee ~/tmap-airprint.log
   fi
fi