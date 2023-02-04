# Configure mTLS .Linkerd
````` 
cd /root/
wget https://run.linkerd.io/install-edge
chmod  +x install-edge
./install-edge
export PATH=$PATH:/root/.linkerd2/bin

linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
`````