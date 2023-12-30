
````
mkdir -p /var/work/tests/artifacts/1/
kubectl config get-contexts -o name > /var/work/tests/artifacts/1/contexts



````

````
k config view --raw
# or cat ~./kube/config

# find cert  and decode
echo "{sert}" | base64 -d > /var/work/tests/artifacts/1/cert

````
