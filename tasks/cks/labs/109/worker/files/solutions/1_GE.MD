[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 109 - ეტალონური ამოხსნა: encryption at rest Secret-ისთვის

> ვმუშაობთ როგორც გამოცდაზე: ბრძანებები `kubectl` სრულდება სამუშაო მანქანაზე, ხოლო ოპერაციები
> node-ზე (etcd, control-plane-ის ფაილები და manifest) - თავად control-plane-ზე: შედით მასზე
> `ssh control-plane`-ით, შეასრულეთ ბრძანებები და გამოდით (`exit`). ეს **მხოლოდ სასწავლო ერთკვანძიანი
> კლასტერია**; production-ში etcd-ზე პირდაპირ წვდომას მომხმარებლებს არ აძლევენ.

## სად ვიპოვოთ მაგალითები დოკუმენტაციაში

ქვემოთ ყველა ბრძანება აღებულია Kubernetes-ის ოფიციალური დოკუმენტაციიდან - გამოცდაზე მათი იქვე პოვნაა საჭირო,
და არა ზეპირად დამახსოვრება:

| რა არის საჭირო | გვერდი და განყოფილება |
| :--- | :--- |
| etcd-ის raw-ჩანაწერის წაკითხვა და პრეფიქსის `k8s:enc:aescbc:v1:` დანახვა (ბრძანება `ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/secrets/default/secret1 \| hexdump -C`) | [Encrypting Confidential Data at Rest - Verify that newly written data is encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted) |
| `EncryptionConfiguration`-ის მაგალითი `aescbc`-ით და `identity`-ით | [Encrypting Confidential Data at Rest - Write an encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#write-an-encryption-configuration-file) |
| ფლაგი `--encryption-provider-config` და ფაილის მიმაგრება kube-apiserver-ის static Pod-ში | [Encrypting Confidential Data at Rest - Use the new encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#use-the-new-encryption-configuration-file) |
| ყველა Secret-ის გადაწერა (`kubectl get secrets --all-namespaces -o json \| kubectl replace -f -`) | [Encrypting Confidential Data at Rest - Ensure all relevant data are encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#ensure-all-secrets-are-encrypted) |
| გასაღების როტაცია (ნაბიჯები 1-7) და ძველი გასაღების წაშლა | [Encrypting Confidential Data at Rest - Rotate a decryption key](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#rotating-a-decryption-key) |
| სად ვიპოვოთ etcd-ის სერტიფიკატების გზები, თუ არ გახსოვთ: „`trusted-ca-file`, `cert-file` და `key-file` შეიძლება მიღებულ იქნას etcd Pod-ის აღწერიდან“ (`kubectl -n kube-system describe pod etcd-<node>` ან `/etc/kubernetes/manifests/etcd.yaml`) | [Operating etcd clusters for Kubernetes - Snapshot using etcdctl options](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/) |
| Role/RoleBinding და ServiceAccount (`automountServiceAccountToken`) | [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/), [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) |

სერტიფიკატების გზები kubeadm-კლასტერში: `/etc/kubernetes/pki/etcd/ca.crt`,
`/etc/kubernetes/pki/etcd/server.crt`, `/etc/kubernetes/pki/etcd/server.key`; ნაგულისხმევი endpoint -
`https://127.0.0.1:2379`, ამიტომ control-plane-ზე ფლაგი `--endpoints` საჭირო არ არის.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
export NS=encryption-109
kubectl config use-context "$CTX"
```

## 1. plaintext-ის დადასტურების დაფიქსირება დაშიფვრის ჩართვამდე

`Secret.data` API-ში base64-ით კოდირდება, და არ იშიფრება. Bootstrap-მა შექმნა უსაფრთხო
canary EncryptionConfiguration-ის გამოჩენამდე. ჯერ ვუყურებთ etcd-ის raw-ჩანაწერს ბრძანებით
დოკუმენტაციიდან, შემდეგ ვინახავთ სტრიქონულ დადასტურებას ფაილში `/tmp/plaintext-proof.txt`
control-plane-ზე, შემდეგ ვაკოპირებთ მას სამუშაო მანქანაზე
`/var/work/109/plaintext-proof.txt`-ში (დირექტორია bootstrap-მა შექმნა): შემოწმება კითხულობს ფაილს სამუშაო მანქანაზე.

შედით control-plane-ზე და შეასრულეთ მასზე (ამ ბრძანებაში ყველაფერი დოკუმენტაციიდანაა, გარდა გასაღებისა
etcd-ში: `/registry/secrets/<namespace>/<name>`):

```bash
ssh control-plane
sudo -i
```

```bash
# control-plane-ზე: etcd-ის raw-ჩანაწერი, hexdump -C-ის გამოტანა აჩვენებს plaintext-ს
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C

# დადასტურების შენახვა (მხოლოდ მნიშვნელობა, strings-ით) - ასევე control-plane-ზე
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings > /tmp/plaintext-proof.txt
cat /tmp/plaintext-proof.txt
# cks-109-legacy-plaintext
exit   # root-იდან
exit   # control-plane-იდან
```

```bash
# სამუშაო მანქანაზე: დადასტურების კოპირება
scp control-plane:/tmp/plaintext-proof.txt /var/work/109/plaintext-proof.txt
cat /var/work/109/plaintext-proof.txt
```

ამ ნაბიჯზე ფაილში `k8s:enc:` არ არის. ეს მდგომარეობის დადასტურებაა **გამართვამდე**;
re-encryption-ის შემდეგ განმეორებითი გამოტანა აუცილებლად ciphertext გახდება და marker გაქრება.

## 2. EncryptionConfiguration-ის შექმნა

`aescbc` არჩეულია მხოლოდ CKS-ის სასწავლო მექანიკისთვის. Kubernetes AES-CBC-ს სუსტად მიიჩნევს
padding-oracle შეტევების რისკის გამო და production default-ად მას არ გირჩევთ. გარე key
manager-ისთვის გამოიყენეთ KMS v2; ლოკალური provider აირჩიეთ მხოლოდ აქტუალური threat model-ითა
და როტაციის პროცედურით.

დავაგენერიროთ 32-byte AES-256 გასაღები, დავაკოდიროთ base64-ით და შევქმნათ კონფიგურაცია control-plane-ზე.
`aescbc` პირველია: მისით ჩაიწერება ახალი Secret-ები. `identity` ბოლოს აძლევს API
server-ს ძველი plaintext ჩანაწერის წაკითხვის საშუალებას მხოლოდ მიგრაციამდე. ფაილის მაგალითი - დოკუმენტაციის
გვერდზე (ბმული ამოხსნის დასაწყისში).

```bash
ssh control-plane
sudo -i
```

```bash
# control-plane-ზე (root)
mkdir -m 700 /etc/kubernetes/enc
key=$(head -c 32 /dev/urandom | base64)
cat > /etc/kubernetes/enc/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: cks-109-aescbc
        secret: ${key}
  - identity: {}
EOF
chmod 600 /etc/kubernetes/enc/encryption-config.yaml
ls -ld /etc/kubernetes/enc; ls -l /etc/kubernetes/enc
exit   # root-იდან
exit   # control-plane-იდან
```

რეალური გასაღები Git-ში, ticket-ში, ტერმინალის log-ში ან Terraform state-ში არ უნდა მოხვდეს.
გასაღების დაკარგვისას snapshot-იდან encrypted Secret წაუკითხავი ხდება.

## 3. კონფიგურაციის მიერთება static kube-apiserver-თან

ჯერ manifest-ს ვინახავთ `/etc/kubernetes/manifests/` დირექტორიის **გარეთ**: kubelet static
Pod-ად კითხულობს ამ დირექტორიის ყველა არაფარულ ფაილს, `*.bak`-ის ჩათვლით. ორიგინალი manifest-ის ასლი
დირექტორიის შიგნით - ეს იმავე სახელის მქონე მეორე static Pod-ია; kubelet შეიძლება სწორედ მის გაშვებას აგრძელებდეს
(ძველი კონფიგურაცია `--encryption-provider-config`-ის გარეშე), ხოლო ძირითადი ფაილის შესწორება ჩუმად ძალაში
არ შევა, და დაშიფვრა გამორთული დარჩება, მაშინ როცა API server გარეგნულად ჯანსაღია.
control-plane-ზე გახსენით სწორედ არსებული static-Pod
manifest და **არსებულ** `command`-ს, `volumeMounts`-სა და `volumes`-ს დაამატეთ ეს ელემენტები;
მთელ ფაილს შაბლონით ნუ ჩაანაცვლებთ.

```bash
ssh control-plane
sudo -i
```

```bash
# control-plane-ზე (root)
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# container name: kube-apiserver
command:
- kube-apiserver
- --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
volumeMounts:
- name: encryption-config
  mountPath: /etc/kubernetes/enc
  readOnly: true

# spec.volumes
volumes:
- name: encryption-config
  hostPath:
    path: /etc/kubernetes/enc
    type: Directory
```

Kubelet ცვლილებას შეამჩნევს და static Pod-ს გადატვირთავს. გაგრძელებამდე დაელოდეთ API
server-ს, წინააღმდეგ შემთხვევაში YAML-ის/გზის შეცდომამ შეიძლება control-plane მიუწვდომელი დატოვოს.

```bash
# ისევ control-plane-ზე: შეამოწმეთ, რომ ფლაგი მუშა manifest-ში მოხვდა, შემდეგ გამოდით
grep -n -- '--encryption-provider-config\|encryption-config' /etc/kubernetes/manifests/kube-apiserver.yaml
exit   # root-იდან
exit   # control-plane-იდან
```

```bash
# სამუშაო მანქანაზე: API server დაახლოებით ერთი წუთი გადაიტვირთება; გაიმეორეთ, სანამ ბრძანება
# არ დააბრუნებს "readyz check passed"-ს (მანამდე იქნება "connection refused")
kubectl get --raw='/readyz?verbose'
```

## 4. ძველი Secret-ების გადაწერა და ciphertext-ის შემოწმება

კონფიგურაცია უკვე შენახულ ჩანაწერებს არ ცვლის. ჯერ შევქმნით Secret-ს provider-ის ჩართვის შემდეგ,
შემდეგ გადავწერთ ყველა არსებულ Secret-ს API-ს გავლით. production-ში ამის წინ
აკეთებენ დაცულ snapshot-ს და იყენებენ retry-ით კონტროლირებად პროცედურას.

```bash
kubectl -n "$NS" create secret generic encrypted-secret \
  --from-literal=token='cks-109-fresh-ciphertext'
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

kubectl -n "$NS" get secret legacy-secret -o jsonpath='{.data.token}' | base64 -d; echo
kubectl -n "$NS" get secret encrypted-secret -o jsonpath='{.data.token}' | base64 -d; echo
# cks-109-legacy-plaintext
# cks-109-fresh-ciphertext
```

Raw-ჩანაწერებს ვკითხულობთ control-plane-ზე, როგორც დავალება 1-ში:

```bash
ssh control-plane
sudo -i
```

```bash
# control-plane-ზე (root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/encrypted-secret | hexdump -C
# ორივე ჩანაწერი იწყება k8s:enc:aescbc:v1:...-ით
exit   # root-იდან
exit   # control-plane-იდან
```

API plaintext-ს უბრუნებს ავტორიზებულ კლიენტს - ეს ნორმალურია და at rest დაშიფვრას არ ამტკიცებს.
აქ დადასტურება - raw etcd შეიცავს `k8s:enc:aescbc:v1:`-ს
ძველი და ახალი ჩანაწერისთვის და legacy marker-ს აღარ შეიცავს.

ახლა migration fallback აღარ არის საჭირო. ვშლით `identity`-ს, ვაიძულებთ
static kube-apiserver-ის გადატვირთვას CRI-ს გავლით და კიდევ ერთხელ ვამოწმებთ ჯანმრთელობასა და წაკითხვას. ეს გააკეთეთ მხოლოდ
snapshot-ის შემდეგ და ყველა შესაბამისი ტიპის რესურსის ciphertext-ის დადასტურების შემდეგ.

```bash
ssh control-plane
sudo -i
```

```bash
# control-plane-ზე (root): identity-ის ამოღება და static kube-apiserver-ის გადატვირთვა
vim /etc/kubernetes/enc/encryption-config.yaml   # წაშალეთ სტრიქონი "- identity: {}"
crictl stop $(crictl ps --name kube-apiserver -q)
exit   # root-იდან
exit   # control-plane-იდან
```

```bash
# სამუშაო მანქანაზე
until kubectl get --raw=/readyz 2>/dev/null | grep -qx ok; do sleep 2; done
kubectl -n "$NS" get secret legacy-secret encrypted-secret
```

ამ ლაბის საბოლოო მდგომარეობა: მაშიფრებელი provider (`aescbc`) პირველი და ერთადერთია, `identity`
წაშლილია. დროებითი fallback მუდმივ „დაზღვევად“ არ უნდა დარჩეს.

## 5. API-წვდომის შეზღუდვა და token automount-ის გამორთვა

დაშიფვრა at rest RBAC-ს არ ანაცვლებს: subject, რომელსაც Secret-ზე `get` აქვს, plaintext-ს API-ით დაინახავს.
შევქმნათ ServiceAccount, რომელსაც ზუსტად ერთი Secret ექნება ხელმისაწვდომი, და დიაგნოსტიკური Pod
მიმაგრებული service-account token-ის გარეშე.

```yaml
# rbac-109.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-reader
  namespace: encryption-109
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader-109
  namespace: encryption-109
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["encrypted-secret"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader-109
  namespace: encryption-109
subjects:
- kind: ServiceAccount
  name: secret-reader
  namespace: encryption-109
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: secret-reader-109
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-reader-109
  namespace: encryption-109
spec:
  serviceAccountName: secret-reader
  automountServiceAccountToken: false
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.10
```

```bash
kubectl apply -f rbac-109.yaml
kubectl wait -n "$NS" --for=condition=Ready pod/secret-reader-109 --timeout=120s
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/encrypted-secret -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader list secrets -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/legacy-secret -n "$NS"
# yes
# no
# no

check_result
```

`automountServiceAccountToken: false` ამცირებს Pod-ისთვის ხელმისაწვდომ credential surface-ს, მაგრამ
თავად ServiceAccount-ის RBAC-ს არ ზღუდავს, თუ აპლიკაცია სხვა credentials-ს მიიღებს.

## დამატებით: როგორ გამოიყურება KMS v2 და გასაღების სრული როტაცია

### KMS v2: envelope encryption ლოკალური გასაღების გარეშე config-ში

`aescbc` ზემოთ მხოლოდ სასწავლო მექანიკისთვის არის საჭირო. production-ში KMS v2 აერთებს
მხარდაჭერილ KMS-plugin-ს ლოკალური Unix socket-ით `EncryptionConfiguration`-ში.
KMS v2-სთვის API server იყენებს დაშიფრულ seed/DEK-ს API server-ის დონეზე და
გამოიყვანს ცალკეული ჩანაწერების დაშიფვრის გასაღებებს. Plugin იცავს seed-ს გარე KEK-ით;
ამით KMS v2 განსხვავდება per-resource KMS v1-ისგან. Etcd ინახავს რესურსების ciphertext-სა და
გაშიფვრისთვის საჭირო მეტამონაცემებს. KEK რჩება გარე KMS-ში, და არა etcd-ში ან Git-ში. კონფიგურაციის
სქემა დამოკიდებულია Kubernetes-ისა და plugin-ის ვერსიაზე, მაგრამ პრინციპულად საჭიროა provider `kms`,
გასაღების სტაბილური სახელი და socket-ის endpoint. სხვის კლასტერიდან საილუსტრაციო endpoint-ს ნუ აკოპირებთ:
შეადარეთ KMS v2-ის ფორმატი და health/ACL მოთხოვნები თქვენი Kubernetes-ვერსიის დოკუმენტაციას.

### aescbc key-ის როტაციის სრული lifecycle

გადასვლა `identity -> aescbc` დავალება 4-ში - ეს migration-ია, და არა უკვე
დაშიფრული მონაცემებისთვის გასაღების როტაცია. როტაციამდე გააკეთეთ დაშიფრული etcd snapshot და შეინახეთ
ძველი გასაღები rollback-ისთვის. დაამატეთ ახალი გასაღები **პირველ ადგილზე**, ხოლო ძველი დროებით დატოვეთ
მეორე ადგილზე: providers იკითხება თანმიმდევრობით, ხოლო ახალი ჩანაწერები იწერება პირველი გასაღებით.

```yaml
- aescbc:
    keys:
    - name: cks-109-aescbc-2026-rotation
      secret: <base64-32-byte-new-key>
    - name: cks-109-aescbc
      secret: <base64-32-byte-old-key>
```

API server-ის გადატვირთვის შემდეგ გადაწერეთ რესურსები და შეამოწმეთ სწორედ ახალი key-ის სახელი raw
ciphertext-ში, და არა მხოლოდ საერთო `k8s:enc` prefix:

```bash
# სამუშაო მანქანაზე
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
ssh control-plane
sudo -i
```

```bash
# control-plane-ზე (root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings | grep -F 'k8s:enc:aescbc:v1:cks-109-aescbc-2026-rotation:'
exit   # root-იდან
exit   # control-plane-იდან
```

როცა ყველა Secret-ის migration დადასტურებულია, backup გაკეთებულია, API კითხულობს მონაცემებს და `/readyz`
აბრუნებს `ok`-ს, წაშალეთ ძველი key სიიდან, გადატვირთეთ API server და გაიმეორეთ
შემოწმებები. ძველ key-ს უფრო ადრე ნუ წაშლით: ჩანაწერები, რომლებიც ახალი provider-ით არ გადაწერილა,
წაუკითხავი გახდება. KMS v2-სთვის თანმიმდევრობა იგივეა: ჯერ ახალი primary KEK/plugin, შემდეგ
re-encryption, შემოწმება და მხოლოდ migration-ის შემდეგ ძველი KEK-ის ექსპლუატაციიდან გამოყვანა.
