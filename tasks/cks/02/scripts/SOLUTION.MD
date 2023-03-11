### login to worker node ad install falco 
```` 
curl -s https://falco.org/repo/falcosecurity-packages.asc | apt-key add -
echo "deb https://download.falco.org/packages/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
apt-get  install linux-headers-$(uname -r) clang llvm   dkms make dialog  -y
apt-get  install falco -y 
````

