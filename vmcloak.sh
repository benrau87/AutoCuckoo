#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}What is your cuckoo user account name?${NC}"
read user


apt-get install mkisofs genisoimage -y
sudo mkdir -p /mnt/windows_ISOs
##VMCloak
echo
read -n 1 -s -p "Please place your Windows 7 32-bit ISO in the folder under /mnt/windows_ISOs and press any key to continue"
echo

pip install vmcloak --upgrade
mount -o loop,ro  --source /mnt/windows_ISOs/*.iso --target /mnt/windows_ISOs/
vmcloak-vboxnet0
echo -e "${YELLOW}###################################${NC}"
echo -e "${YELLOW}This process will take some time, you should get a sandwich, or watch the install if you'd like...${NC}"
echo
sleep 5
vmcloak init --vm-visible --win7x86 --iso-mount /mnt/windows_ISOs/ seven0
vmcloak install seven0 adobe9 wic pillow dotnet40 java7


echo
read -p "Would you like to install Office 2007? This WILL require an ISO and key. Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo
  echo -e "${YELLOW}What is the path to the iso?${NC}"
  read path
  echo
  echo -e "${YELLOW}What is the license key?${NC}"
  read key
  vmcloak install seven0 office2007 \
    office2007.isopath=$path \
    office2007.serialkey=$key
fi
echo
echo -e "${YELLOW}Starting VM and creating a running snapshot...Please wait.${NC}"  
vmcloak snapshot seven0 cuckoo1 192.168.56.2



chown -R $user:$user ~/.vmcloak

echo
echo -e "${YELLOW}The VM is located under your current OR sudo user's home folder under .vmcloak, you will need to register this with Virtualbox on your cuckoo account.${NC}"  


