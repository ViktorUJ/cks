inspect definitions of deployments

````
kubectl  exec deployment1-6d65bf9fc9-clj5x   -n restricted -- cat  /var/secret/secret ; echo
kubectl  exec deployment2-64487c7d-nhnds  -n restricted -- sh -c  "echo \$SECRET_USERNAME"

````

login to pod of deployment3
````
kubectl  exec -ti deployment3-798fff6fd5-pprkv -n restricted  -- bash
````

into pod
````
token=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
curl https://kubernetes.default/api/v1/namespaces/restricted/secrets -H "Authorization: Bearer $token" -k

````

it will be like this
````
deployment3-798fff6fd5-pprkv:/# curl https://kubernetes.default/api/v1/namespaces/restricted/secrets/secret3 -H "Authorization: Bearer $token" -k
{
  "kind": "Secret",
  "apiVersion": "v1",
  "metadata": {
    "name": "secret3",
    "namespace": "restricted",
    "uid": "dc2c08bb-4dc9-4831-a1bb-4afadebcdbac",
    "resourceVersion": "3153",
    "creationTimestamp": "2023-03-05T11:21:33Z",
    "annotations": {
      "kubectl.kubernetes.io/last-applied-configuration": "{\"apiVersion\":\"v1\",\"data\":{\"secret\":\"MzMzMw==\"},\"kind\":\"Secret\",\"metadata\":{\"annotations\":{},\"creationTimestamp\":null,\"name\":\"secret3\",\"namespace\":\"restricted\"}}\n"
    },
    "managedFields": [
      {
        "manager": "kubectl-client-side-apply",
        "operation": "Update",
        "apiVersion": "v1",
        "time": "2023-03-05T11:21:33Z",
        "fieldsType": "FieldsV1",
        "fieldsV1": {
          "f:data": {
            ".": {},
            "f:secret": {}
          },
          "f:metadata": {
            "f:annotations": {
              ".": {},
              "f:kubectl.kubernetes.io/last-applied-configuration": {}
            }
          },
          "f:type": {}
        }
      }
    ]
  },
  "data": {
    "secret": "MzMzMw=="
  },
  "type": "Opaque"
}
````
````
echo "MzMzMw==" | base64 -d
````
