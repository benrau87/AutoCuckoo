#!/bin/bash

###Change these as needed and save them securely somewhere! Only needed if you plan on using MySQL##################
root_mysql_pass='w4ndZrsM2H_K4FjqSaog4_jWg'
cuckoo_mysql_pass='DuZXb7K7cldzU5DS5Q5lVzaay'

####################################################################################################################
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
gitdir=$PWD

##Logging setup
logfile=/var/log/cuckoo_install.log
mkfifo ${logfile}.pipe
tee < ${logfile}.pipe $logfile &
exec &> ${logfile}.pipe
rm ${logfile}.pipe

##Functions
function print_status ()
{
    echo -e "\x1B[01;34m[*]\x1B[0m $1"
}

function print_good ()
{
    echo -e "\x1B[01;32m[*]\x1B[0m $1"
}

function print_error ()
{
    echo -e "\x1B[01;31m[*]\x1B[0m $1"
}

function print_notification ()
{
	echo -e "\x1B[01;33m[*]\x1B[0m $1"
}

function error_check
{

if [ $? -eq 0 ]; then
	print_good "$1 successfully."
else
	print_error "$1 failed. Please check $logfile for more details."
exit 1
fi

}

function install_packages()
{

apt-get update &>> $logfile && apt-get install -y --allow-unauthenticated ${@} &>> $logfile
error_check 'Package installation completed'

}

function dir_check()
{

if [ ! -d $1 ]; then
	print_notification "$1 does not exist. Creating.."
	mkdir -p $1
else
	print_notification "$1 already exists. (No problem, We'll use it anyhow)"
fi

}

########################################
##BEGIN MAIN SCRIPT##
#Pre checks: These are a couple of basic sanity checks the script does before proceeding.

print_status "OS Version Check.."
release=`lsb_release -r|awk '{print $2}'`
if [[ $release == "16."* ]]; then
	print_good "OS is Ubuntu. Good to go."
else
    print_notification "This is not Ubuntu 16.x, this autosnort script has NOT been tested on other platforms."
	print_notification "You continue at your own risk!(Please report your successes or failures!)"
fi

##Cuckoo user account
echo -e "${YELLOW}We need to create a local account to run your Cuckoo sandbox from; What would you like your Cuckoo account username to be?${NC}"
read name
adduser $name --gecos ""

##Add startup script to cuckoo users home folder
chmod +x start_cuckoo.sh
chown $name:$name start_cuckoo.sh
cd $gitdir
mv start_cuckoo.sh /home/$name/

##Start mongodb 
chmod 755 mongodb.service
cp mongodb.service /etc/systemd/system/

##Create directories for later
cd /home/$name/
dir=$PWD
dir_check /home/$name/tools
rm -rf /home/$name/tools/*
cd tools/

##Depos add
#this is a nice little hack I found in stack exchange to suppress messages during package installation.
export DEBIAN_FRONTEND=noninteractive

echo
print_status "${YELLOW}Adding Repositories...Please Wait${NC}"

##Mongodb
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6 &>> $logfile
echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list &>> $logfile
error_check 'Mongodb added'

##Elasticsearch
add-apt-repository ppa:webupd8team/java -y &>> $logfile
error_check 'Java Repo added'
wget -qO - https://packages.elasticsearch.org/GPG-KEY-elasticsearch | sudo apt-key add -
add-apt-repository "deb http://packages.elasticsearch.org/elasticsearch/1.4/debian stable main" &>> $logfile
error_check 'Elasticsearch Repo added'

##Suricata
add-apt-repository ppa:oisf/suricata-beta -y &>> $logfile
error_check 'Suricata Repo added'

##Holding pattern for dpkg...
print_status "${YELLOW}Waiting for dpkg process to free up...${NC}"
print_status "${YELLOW}If this takes too long try running ${RED}sudo rm -f /var/lib/dpkg/lock${YELLOW} in another terminal window.${NC}"
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
   sleep 1
done

# System updates
print_status "${YELLOW}Performing apt-get update and upgrade (May take a while if this is a fresh install)..${NC}"
apt-get update &>> $logfile && apt-get -y upgrade &>> $logfile
error_check 'Updated system'

####Not working
#mongodb-org=3.2.11
#declare -a packages=(autoconf automake bison checkinstall clamav clamav-daemon clamav-daemon clamav-freshclam curl exiftool flex geoip-database libarchive-dev libboost-all-dev libcap2-bin libconfig-dev libfuzzy-dev libgeoip-dev libhtp1 libjpeg-dev libjansson-dev libmagic1 libmagic-dev libre2-dev libssl-dev libtool libvirt-dev mongodb-org mono-utils openjdk-8-jre-headless p7zip-full python python-bottle python-bson python-chardet python-dev python-dpkt python-geoip python-jinja2 python-libvirt python-m2crypto python-magic python-pefile python-pip python-pymongo python-yara suricata ssdeep swig tcpdump unzip upx-ucl uthash-dev virtualbox wget wkhtmltopdf xfonts-100dpi xvfb yara);
#install_packages ${packages[@]}
 
#print_status "${YELLOW}Upgrading PIP${NC}"
#pip install --upgrade pip &>> $logfile
#error_check 'PIP upgraded'

#print_status "${YELLOW}Installing PIP requirements${NC}"
#sudo -H pip install -r $gitdir/requirements.txt &>> $logfile
#error_check 'PIP requirements installation'
#####Test version repos

##Java install for elasticsearch
print_status "${YELLOW}Installing Java${NC}"
echo debconf shared/accepted-oracle-license-v1-1 select true | \
  sudo debconf-set-selections &>> $logfile
apt-get install oracle-java8-installer -y &>> $logfile
error_check 'Java Installed'

##Apt packages
print_status "${YELLOW}Installing:${NC} autoconf automake bison checkinstall clamav clamav-daemon clamav-daemon clamav-freshclam curl exiftool flex geoip-database libarchive-dev libboost-all-dev libcap2-bin libconfig-dev libfuzzy-dev libgeoip-dev libhtp1 libjpeg-dev libjansson-dev libmagic1 libmagic-dev libre2-dev libssl-dev libtool libvirt-dev mongodb-org mono-utils openjdk-8-jre-headless p7zip-full python python-bottle python-bson python-chardet python-dev python-dpkt python-geoip python-jinja2 python-libvirt python-m2crypto python-magic python-pefile python-pip python-pymongo python-yara suricata ssdeep swig tcpdump unzip upx-ucl uthash-dev virtualbox wget wkhtmltopdf xfonts-100dpi xvfb yara .."

declare -a packages=(autoconf autogen automake bison flex yara libfuzzy-dev libmagic-dev libconfig-dev libjansson-dev shtool python-pip oracle-java8-installer elasticsearch mongodb-org python python-sqlalchemy python-bson python-dpkt python-jinja2 python-magic python-pymongo python-libvirt python-bottle python-pefile python-chardet swig libssl-dev clamav-daemon python-geoip geoip-database mono-utils wkhtmltopdf xvfb xfonts-100dpi tcpdump libtool libcap2-bin virtualbox suricata p7zip-full unzip);
install_packages ${packages[@]}

##Upgrade PIP
print_status "${YELLOW}Upgrading PIP${NC}"
pip install --upgrade pip &>> $logfile
error_check 'PIP upgraded'

##PIP Packages
print_status "${YELLOW}Installing PIP requirements${NC}"
#sudo -H pip install jinja2 pymongo pymysql bottle pefile django chardet pygal m2crypto clamd django-ratelimit pycrypto weasyprint rarfile jsbeautifier python-whois bs4 &>> $logfile
#pip install cybox==2.1.0.9 &>> $logfile
#pip install maec==4.1.0.11 &>> $logfile
sudo -H pip install -r $gitdir/requirements.txt &>> $logfile
error_check 'PIP requirements installation'

##Setup Elasticsearch
print_status "${YELLOW}Setting up Elasticsearch${NC}"
update-rc.d elasticsearch defaults 95 10 &>> $logfile
/etc/init.d/elasticsearch start &>> $logfile
service elasticsearch start &>> $logfile

##Add user to vbox and enable mongodb
print_status "${YELLOW}Setting up Mongodb${NC}"
usermod -a -G vboxusers $name
systemctl start mongodb &>> $logfile
sleep 5
systemctl enable mongodb &>> $logfile
systemctl daemon-reload &>> $logfile
error_check 'Mongodb setup'

##tcpdump permissions
setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump

##Yara
cd /home/$name/tools/
print_status "${YELLOW}Downloading Yara${NC}"
#wget https://github.com/VirusTotal/yara/archive/v3.5.0.tar.gz &>> $logfile
git clone https://github.com/VirusTotal/yara.git &>> $logfile
error_check 'Yara downloaded'
#tar -zxf v3.5.0.tar.gz &>> $logfile
print_status "${YELLOW}Building and compiling Yara${NC}"
#cd yara-3.5.0
cd yara/
./bootstrap.sh &>> $logfile
./configure --with-crypto --enable-cuckoo --enable-magic &>> $logfile
error_check 'Yara compiled and built'
print_status "${YELLOW}Installing Yara${NC}"
make &>> $logfile
make install &>> $logfile
make check &>> $logfile
error_check 'Yara installed'

##Pydeep
cd /home/$name/tools/
print_status "${YELLOW}Setting up Pydeep${NC}"
sudo -H pip install git+https://github.com/kbandla/pydeep.git &>> $logfile
error_check 'Pydeep installed'

##Malheur
cd /home/$name/tools/
print_status "${YELLOW}Setting up Malheur${NC}"
git clone https://github.com/rieck/malheur.git &>> $logfile
error_check 'Malheur downloaded'
cd malheur
./bootstrap &>> $logfile
./configure --prefix=/usr &>> $logfile
make install &>> $logfile
error_check 'Malheur installed'

##Volatility
cd /home/$name/tools/
print_status "${YELLOW}Setting up Volatility${NC}"
git clone https://github.com/volatilityfoundation/volatility.git &>> $logfile
error_check 'Volatility downloaded'
cd volatility
python setup.py build &>> $logfile
python setup.py install &>> $logfile
error_check 'Volatility installed'

##Suricata
cd /home/$name/tools/
print_status "${YELLOW}Setting up Suricata${NC}"
#dir_check /etc/suricata/rules/cuckoo.rules
touch /etc/suricata/rules/cuckoo.rules &>> $logfile
echo "alert http any any -> any any (msg:\"FILE store all\"; filestore; noalert; sid:15; rev:1;)"  | sudo tee /etc/suricata/rules/cuckoo.rules &>> $logfile
cp $gitdir/suricata-cuckoo.yaml /etc/suricata/
git clone https://github.com/seanthegeek/etupdate &>> $logfile
cd etupdate
mv etupdate /usr/sbin/
/usr/sbin/etupdate -V &>> $logfile
error_check 'Suricata updateded'
chown $name:$name /usr/sbin/etupdate &>> $logfile
chown -R $name:$name /etc/suricata/rules &>> $logfile
crontab -u $name $gitdir/cron 
error_check 'Suricata configured for auto-update'

##Other tools
cd /home/$name/tools/
print_status "${YELLOW}Grabbing other tools${NC}"
apt-get install libboost-all-dev -y &>> $logfile
sudo -H pip install git+https://github.com/buffer/pyv8 &>> $logfile
error_check 'PyV8 installed'
#git clone https://github.com/jpsenior/threataggregator.git &>> $logfile
#error_check 'Threat Aggregator downloaded'
#wget https://github.com/kevthehermit/VolUtility/archive/v1.0.tar.gz &>> $logfile
#error_check 'Volutility downloaded'
#tar -zxf v1.0*

##Cuckoo
cd /etc/
rm -rf cuckoo-modified
print_status "${YELLOW}Downloading Cuckoo${NC}"
git clone https://github.com/spender-sandbox/cuckoo-modified.git  &>> $logfile
error_check 'Cuckoo downloaded'
cd cuckoo-modified/
print_status "${YELLOW}Downloading Java tools${NC}"
wget https://bitbucket.org/mstrobel/procyon/downloads/procyon-decompiler-0.5.30.jar  &>> $logfile
error_check 'Java tools downloaded'
##Can probably remove one of the requirements.txt docs at some point
print_status "${YELLOW}Installing any dependencies that may have been missed...Please wait${NC}"
sudo -H pip install -r requirements.txt &>> $logfile
sudo -H pip install django-ratelimit &>> $logfile
error_check 'Cuckoo dependencies'
cd utils/
python comm* --all --force &>> $logfile
error_check 'Community signature updated'
cd ..
cd data/yara/
print_status "${YELLOW}Downloading Yara Rules...Please wait${NC}"
git clone https://github.com/yara-rules/rules.git &>> $logfile
cp rules/**/*.yar /etc/cuckoo-modified/data/yara/binaries/ &>> $logfile
##Remove Android and none working rules for now
mv /etc/cuckoo-modified/data/yara/binaries/Android* /etc/cuckoo-modified/data/yara/rules/  &>> $logfile
rm /etc/cuckoo-modified/data/yara/binaries/vmdetect.yar  &>> $logfile
rm /etc/cuckoo-modified/data/yara/binaries/antidebug_antivm.yar  &>> $logfile
rm /etc/cuckoo-modified/data/yara/binaries/MALW_AdGholas.yar  &>> $logfile
error_check 'Adding Yara rules'
##Office Decrypt
cd /etc/cuckoo-modified/
dir_check work
cd work/
print_status "${YELLOW}Downloading Office Decrypt${NC}"
git clone https://github.com/herumi/cybozulib &>> $logfile
git clone https://github.com/herumi/msoffice &>> $logfile
cd msoffice
make -j RELEASE=1 &>> $logfile
error_check 'Office decrypt installed'

##Copy over conf files
cd $gitdir/
cp *.conf /etc/cuckoo-modified/conf/

##Add vmcloak scripts 
chmod +x vmcloak.sh
cp vmcloak.sh $dir/

##Add windows python and PIL installers for VMs
cd /home/$name/tools/
dir_check windows_python_exe/
cp /etc/cuckoo-modified/agent/agent.py $dir/tools/windows_python_exe/
cd windows_python_exe/
print_status "${YELLOW}Downloading Windows Python Depos${NC}"
wget http://effbot.org/downloads/PIL-1.1.7.win32-py2.7.exe &>> $logfile
wget https://www.python.org/ftp/python/2.7.11/python-2.7.11.msi &>> $logfile
error_check 'Windows depos downloaded'

##Change ownership for folder that have been created
chown -R $name:$name /home/$name/*
chown -R $name:$name /etc/cuckoo-modified/*
chmod -R 777 /etc/cuckoo-modified/

###Setup of VirtualBox forwarding rules and host only adapter
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1
iptables -A FORWARD -o eth0 -i vboxnet0 -s 192.168.56.0/24 -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A POSTROUTING -t nat -j MASQUERADE
sudo sysctl -w net.ipv4.ip_forward=1

##Below can be enabled if using a external DB connection
#iptables -A INPUT -s 0.0.0.0 -p tcp --destination-port 27017 -m state --state NEW,ESTABLISHED -j ACCEPT
#iptables -A OUTPUT -d 0.0.0.0 -p tcp --source-port 27017 -m state --state ESTABLISHED -j ACCEPT

print_status "${YELLOW}Waiting for dpkg process to free up...${NC}"
print_status "${YELLOW}If this takes too long try running ${RED}sudo rm -f /var/lib/dpkg/lock${YELLOW} in another terminal window.${NC}"
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
   sleep 1
done
##DAMN THING NEVER INSTALLS!!!!!!
sudo -H pip install distorm3 re2 &>> $logfile
##RANT OVER
wait 1 &>> $logfile

# ClamAV check
print_status "${YELLOW}Uninstalling Clamd if needed${NC}"
sudo -H pip uninstall clamd -y &>> $logfile
error_check 'Clamd uninistalled'

###Extras Extras!
read -p "Do you want to iptable changes persistent so that forwarding rules from the created subnet are applied at boot? This is highly recommended. Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
echo
apt-get -qq install iptables-persistent -y &>> $logfile
error_check 'Persistent Iptable entries'
fi
echo

read -p "Would you like to create VMs at this time? You will need a local Windows ISO to proceed. Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
echo
bash $dir/vmcloak.sh
fi
echo

read -p "Would you like to harden this host from malware Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
echo
apt-get install -qq unattended-upgrades apt-listchanges fail2ban -y  &>> $logfile
error_check 'Security upgrades'
fi
echo

read -p "Would you like secure the Cuckoo webserver with SSL? Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
echo
bash $gitdir/nginx.sh
fi
echo

read -p "Would you like to use a SQL database to support multi-threaded analysis? Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
print_status "Setting ENV variables"
debconf-set-selections <<< "mysql-server mysql-server/$root_mysql_pass password root"
debconf-set-selections <<< "mysql-server mysql-server/$root_mysql_pass password root"
error_check 'MySQL passwords set'
print_status "Downloading and installing MySQL"
apt-get -y install mysql-server python-mysqldb &>> $logfile
error_check 'MySQL installed'
#mysqladmin -uroot password $root_mysql_pass &>> $logfile
#error_check 'MySQL root password change'	
mysql -uroot -p$root_mysql_pass -e "DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'); DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; DROP DATABASE IF EXISTS cuckoo; CREATE DATABASE cuckoo; GRANT ALL PRIVILEGES ON cuckoo.* TO 'cuckoo'@'localhost' IDENTIFIED BY '$cuckoo_mysql_pass'; FLUSH PRIVILEGES;" &>> $logfile
error_check 'MySQL secure installation and cuckoo database/user creation'
replace "connection =" "connection = mysql://cuckoo:$cuckoo_mysql_pass@localhost/cuckoo" -- /etc/cuckoo-modified/conf/cuckoo.conf &>> $logfile
error_check 'Configuration files modified'
fi

echo -e "${YELLOW}Installation complete, login as $name and open the terminal. In $name home folder you will find the start_cuckoo script. To get started as fast as possible you will need to create a virtualbox vm and name it ${RED}cuckoo1${NC}.${YELLOW} On the Windows VM install the windows_exes that can be found under the tools folder. Name the snapshot ${RED}vmcloak${YELLOW}. Alternatively you can create the VM with the vmcloak.sh script provided in your home directory. This will require you have a local copy of the Windows ISO you wish to use. You can then launch cuckoo_start.sh and navigate to $HOSTNAME:8000 or https://$HOSTNAME if Nginx was installed.${NC}"

exit 0
