### login to worker node ad install falco 
```` 

curl -s https://falco.org/repo/falcosecurity-packages.asc | apt-key add -
echo "deb https://download.falco.org/packages/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
apt install -y dkms make linux-headers-$(uname -r)
# If you use the falco-driver-loader to build the BPF probe locally you need also clang toolchain
apt install -y clang llvm dialog
# You can install also the dialog package if you want it
apt install  dialog -y 
sleep 5 
apt  install falco

```` 

````
# use   'kmod'  and automatic mode update 
# check services
systemctl list-units | grep falco


````
###  https://falco.org/docs/rules/supported-fields
