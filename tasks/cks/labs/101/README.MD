# Configure mTLS .Linkerd
`````
cd /root/
wget https://run.linkerd.io/install-edge
chmod  +x install-edge
./install-edge
export PATH=$PATH:/root/.linkerd2/bin

linkerd install --crds | kubectl apply -f -
linkerd install  --set proxyInit.runAsRoot=true | kubectl apply -f -

# check linkerd pods
kubectl  get  po -n linkerd

`````
