# cuckoo_host
Host installation script

Usage:

1) Run setup.sh on fresh Ubuntu/Debian install

2) Follow prompts to create a local Cuckoo user

3) If you have a locally available Windows ISO, you can create the VM at the end of the script. Or anytime afterwards with the vmcloak.sh script provided at the home directory of the user you created in step 2. You can use MySql as you database if you are running a larger deployment. If you chose to, you should change the keys in the setup.sh script BEFORE you run the inital setup.

4) When installation is complete you should switch accounts to the one created in step 2.

5) Launch virtualbox and import the VMs at ~/.vmcloak if created them in step 3 OR you can create your own. The required files for the host are stored at ~/windows_python_exe/

6) Before taking the running snapshot make sure that the python agent is running and your IPv4 settings are: 192.168.56.2 (address) 192.168.56.1 (gateway) 255.255.255.0 (broadcast) 8.8.8.8 (DNS server or whatever you prefer)

7) The included conf files, which are stored under /etc/cuckoo-modified/conf/ are good for one Windows 7 32-bit VM with a name of cuckoo1 and a running snapshot of vmcloak. If you need to modify them for your needs please read the offical Cuckoo Sandbox documentation.

8) Run the start_cuckoo.sh script and navigate to http://localhost:8000 or https://youripaddress if you ran the nginx script.

***Note***
You must install the provided agent on machine created with vmcloak. Start the VM, check (netstat -ano) and kill the included running agent on port 8000 (taskkill /F /pid #), download the modified one and start it. Take a running snapshot and proceed.
