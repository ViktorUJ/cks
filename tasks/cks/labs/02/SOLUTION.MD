### login to worker node ad install falco 
```` 

curl -s https://falco.org/repo/falcosecurity-packages.asc | apt-key add -
echo "deb https://download.falco.org/packages/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
apt install -y dkms make linux-headers-$(uname -r) clang llvm dialog
echo "**** install falco"
apt  install falco

```` 

````
# use   'kmod'  and automatic mode update 
# check services
systemctl list-units | grep falco


````
###  https://falco.org/docs/rules/supported-fields

### https://github.com/draios/sysdig
### https://github.com/draios/sysdig/wiki/How-to-Install-Sysdig-for-Linux
### https://github.com/draios/sysdig/wiki/Sysdig-Examples#containers

#  sysdig  -p"%evt.time,%container.id,%container.name,%user.name,%k8s.ns.name,%k8s.pod.name"   container.image=docker.io/viktoruj/cks-lab:latest