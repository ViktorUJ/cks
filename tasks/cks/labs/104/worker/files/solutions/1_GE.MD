[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 104 - ეტალონური ამოხსნა: RBAC, ServiceAccount token და anonymous API

> შეასრულეთ ბრძანებები სამუშაო მანქანიდან, თუ ნაბიჯში სხვა რამ არ არის მითითებული. Namespace
> `security-104` უკვე არსებობს.
>
> გამოცდაზე `k` (`alias k=kubectl`) და bash-completion მისთვის უკვე გამართულია SSH-ჰოსტზე -
> დრო ნუ დაკარგავთ მათ გამართვაზე, უბრალოდ გამოიყენეთ `k` (იხ. თავი 33.6).

## 1. `auditor`-ის მინიმალური წვდომა მხოლოდ Pod-ებზე

გამოცდაზე ტიპური RBAC-ობიექტისთვის სრული YAML-ის ხელით წერა - დროის დაკარგვაა:
`kubectl create` ქმნის ServiceAccount/Role/RoleBinding-ს თითო ბრძანებით:

```bash
k create sa auditor -n security-104
k create role pod-observer -n security-104 --resource=pods --verb=get,list,watch
k create rolebinding auditor-pod-observer -n security-104 \
  --role=pod-observer --serviceaccount=security-104:auditor

k auth can-i list pods -n security-104 \
  --as=system:serviceaccount:security-104:auditor
k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:auditor # უნდა იყოს no
```

## 2. ServiceAccount-ის projected token

TokenRequest volume გასცემს ხანმოკლე token-ს; ჩვეულებრივი ავტომონტაჟი გამორთულია.
`audience: kubernetes.default.svc`-ს არ ვაფიქსირებთ: kubeadm-ისთვის ეს აუცილებლად
API server-ის მიერ მიღებული მნიშვნელობა არ არის. თუ `audience` გამოტოვებულია, kubelet იყენებს
API server-ის identifier-ს ნაგულისხმევად. ცალკე audience-ის მითითება დასაშვებია მხოლოდ control-plane-ზე
`--api-audiences`-ის (ან default-ის `--service-account-issuer`-იდან) შემოწმების შემდეგ.
`expirationSeconds` უნდა იყოს დიაპაზონში `600`-`3600` ჩათვლით - Kubernetes API
invalid-ად უარყოფს `600` წამზე ნაკლებ ნებისმიერ მნიშვნელობას `serviceAccountToken`
projected source-ისთვის, manifest-ში რაც არ უნდა ეწეროს.

`projected.sources[].serviceAccountToken`-ის ზუსტი სინტაქსის გამოცდაზე ზეპირად
გახსენება არ არის საჭირო - `kubernetes.io/docs`-ზე ის არის განყოფილებაში Concepts → Storage →
[Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/), სათაურით
**"serviceAccountToken projected volumes"** (იქ არის Pod-ის მზა მაგალითი ამ
volume-ით - სტრუქტურა იქიდან აიღეთ, და ნულიდან ნუ დაწერთ). `kubectl run` ფლაგებით ასეთი
volume-ის დამატებას ვერ ახერხებს - Pod-ის ჩონჩხს ვაგენერირებთ `--dry-run=client -o yaml`-ით და
`vim`-ში ვამატებთ მხოლოდ საჭირო ველებს, დოკუმენტაციის მაგალითიდან გადაწერილს:

```bash
k create sa api-client -n security-104
k run token-client -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > token-client.yaml
vim token-client.yaml
```

```yaml
# Pod-ის spec-ში დაამატეთ (containers/image/command უკვე დაგენერირებულია kubectl run-ით):
spec:
  serviceAccountName: api-client              # დაამატეთ
  automountServiceAccountToken: false         # დაამატეთ
  containers:
  - name: token-client
    volumeMounts:                             # დაამატეთ
    - name: api-token                         # დაამატეთ
      mountPath: /var/run/secrets/tokens       # დაამატეთ
      readOnly: true                          # დაამატეთ
    ...
  volumes:                                    # დაამატეთ
  - name: api-token                           # დაამატეთ
    projected:                                # დაამატეთ
      sources:                                # დაამატეთ
      - serviceAccountToken:                  # დაამატეთ
          path: api-token                     # დაამატეთ
          expirationSeconds: 3600             # დაამატეთ
```

```bash
k apply -f token-client.yaml
k wait -n security-104 --for=condition=Ready po/token-client --timeout=120s
k exec -n security-104 token-client -- \
  ls -l /var/run/secrets/tokens/api-token
# ფაილი არის - თუ manifest დოკუმენტაციის მაგალითს ემთხვევა, kubelet-მა ის გასცა

k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:api-client
# no
```

ვამოწმებთ არა მხოლოდ ფაილის არსებობას, არამედ იმასაც, რომ სწორედ მიმაგრებული projected token
რეალურად ავტენტიფიცირდება როგორც მოსალოდნელი ServiceAccount, მისი `TokenReview`-ში გაგზავნით:

```bash
TOKEN=$(k exec -n security-104 token-client -- cat /var/run/secrets/tokens/api-token)

k create -o jsonpath='{.status.authenticated}{" "}{.status.user.username}{"\n"}' -f - <<EOF
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: $TOKEN
EOF
# true system:serviceaccount:security-104:api-client
```

ლაბორატორიული სამუშაოსთვის ეს შემოწმება სავალდებულოა: ფაილის არსებობა თავისთავად არ ამტკიცებს,
რომ projected token ვალიდურია და ავტენტიფიცირდება როგორც მოსალოდნელი ServiceAccount. `TokenReview`
უნდა დააბრუნოს `authenticated: true` და username
`system:serviceaccount:security-104:api-client`.

გამოცდაზე `TokenReview`-ს ცალკე შესრულება საჭირო არ არის, თუ ამას ამოცანის პირობა არ მოითხოვს:
იქ საკმარისია სწრაფად შექმნათ სწორი projected token volume და შედეგი შეამოწმოთ იმ
გზით, რომელიც კონკრეტულ დავალებაში არის საჭირო. აქ `TokenReview` - სასწავლო verification-შემოწმებაა,
რომელიც ამავდროულად ლაბორატორიული სამუშაოს მიღების კრიტერიუმს შეესაბამება.

## 3. Pod API-token-ის გარეშე

ავტომონტაჟს ვთიშავთ როგორც ServiceAccount-ზე, ისე Pod-ზე: ეს იცავს შაბლონის ან ServiceAccount-ის
შემდგომი ცვლილებებისგან.

`kubectl create serviceaccount`-ს არ აქვს ფლაგი `automountServiceAccountToken`-ისთვის - ვქმნით
და მაშინვე ვპატჩავთ:

```bash
k create sa no-token-sa -n security-104
k patch sa no-token-sa -n security-104 -p '{"automountServiceAccountToken":false}'
k run no-token -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > no-token.yaml
vim no-token.yaml
```

```yaml
# Pod-ის spec-ში დაამატეთ:
spec:
  serviceAccountName: no-token-sa       # დაამატეთ
  automountServiceAccountToken: false   # დაამატეთ
  containers:
  - name: no-token
    ...
```

```bash
k apply -f no-token.yaml
k wait -n security-104 --for=condition=Ready po/no-token --timeout=60s
k get po no-token -n security-104 -o jsonpath='{.spec.automountServiceAccountToken}'

# ვადასტურებთ runtime-ის დონეზე, და არა მხოლოდ YAML-სპეციფიკაციის დონეზე:
# კონტეინერში token-ფაილი მართლაც არ არის.
k exec -n security-104 no-token -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - ფაილი არ არის, exec თავად წარმატებით შესრულდა
```

ცალკე legacy `Secret`-ს `type: kubernetes.io/service-account-token`-ით ნუ მიამაგრებთ -
გამორთული automount-ის დროსაც კი ასეთი Secret-ის ხელით მიმაგრება შეიძლება `volumes[].secret`-ის გავლით,
და მაშინ Pod automount-ველის მიხედვით ფორმალურად "token-ის გარეშეა", მაგრამ ფაქტობრივად
მაინც აქვს ვალიდური API-token კონტეინერის შიგნით.

## 4. wildcard-უფლებების წაშლა

ვშლით როგორც binding-ს (subject-ს წვდომა აღარ ექნება), ისე თავად ClusterRole-ს (სახიფათო
შაბლონი ხელახალი გამოყენებისთვის აღარ დარჩება):

```bash
k delete clusterrolebinding legacy-operator-admin
k delete clusterrole legacy-operator-admin
k auth can-i get secrets -n security-104 \
  --as=system:serviceaccount:security-104:legacy-operator # უნდა იყოს no
```

## 5. anonymous-auth-ის გამორთვა

მარტივი `--anonymous-auth=false` აქ არ გამოდგება: kubeadm `release-1.36` აგენერირებს
kube-apiserver static Pod-ს HTTPS liveness/readiness/startup probes-ით `/livez`-სა და
`/readyz`-ზე, ხოლო kubelet HTTP probes client credentials-ს არ გადასცემენ - anonymous access-ის სრული გამორთვისას
ეს მოთხოვნები მიიღებენ `401`-ს, და kubelet kube-apiserver-ს არაჯანსაღად მიიჩნევს
(რაც თავის მხრივ არღვევს დავალება 9-საც, რომელიც სტაბილურად მომუშავე API
server-ზეა დამოკიდებული). ამის ნაცვლად ვიყენებთ `AuthenticationConfiguration`-ს `anonymous.conditions`-ით,
რომელიც anonymous access-ს მხოლოდ სამი health-გზით ზღუდავს. გამოცდაზე ყოველ
ბრძანებას `sudo` პრეფიქსს ნუ დაუმატებთ - ერთხელ გახდით root (`sudo -i`), ეს უფრო სწრაფია:

```bash
ssh control-plane
sudo -i
cat > /etc/kubernetes/authentication-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
EOF
```

ვასწორებთ static manifest-ს: `--anonymous-auth=true`-ს მთლიანად ვშლით (`--authentication-config`-ის
გვერდით დატოვება არ შეიძლება - kube-apiserver გაშვებაზე უარს იტყვის, თუ ორივეა მითითებული),
ვამატებთ `--authentication-config`-ს, ასევე `hostPath` volume/volumeMount-ს ახალი
კონფიგურაციის ფაილისთვის - kube-apiserver კითხულობს `authentication-config.yaml`-ს node-ის ფაილურ
სისტემიდან, ამიტომ ფაილი უნდა ჩანდეს container-ის შიგნით volumeMount-ით, და არა
მხოლოდ ჰოსტზე იდოს:

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# command მასივში:
# - წაშალეთ სტრიქონი "- --anonymous-auth=true"
# - დაამატეთ სტრიქონი იმავე ჩაღრმავებით, რაც დანარჩენ არგუმენტებს აქვს:
#   - --authentication-config=/etc/kubernetes/authentication-config.yaml
# კონტეინერის volumeMounts-ში (იგივე ჩაღრმავება, რაც მეზობელ ელემენტებს):
#   - mountPath: /etc/kubernetes/authentication-config.yaml
#     name: authentication-config
#     readOnly: true
# Pod-ის volumes-ში (იგივე ჩაღრმავება, რაც მეზობელ ელემენტებს):
#   - hostPath:
#       path: /etc/kubernetes/authentication-config.yaml
#       type: File
#     name: authentication-config
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` აიძულებს static Pod-ის დაუყოვნებლივ ხელახლა აწყობას - გამოცდაზე
უფრო სწრაფია, ვიდრე ლოდინი, სანამ kubelet თავად შეამჩნევს ფაილის ცვლილებას (ჩვეულებრივ წამებში, მაგრამ
არა გარანტირებულად მყისიერად):

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS უნდა გახდეს Running - თუ ჯერ არა, დაელოდეთ რამდენიმე წამს და გაიმეორეთ
```

შეამოწმეთ სამივე ქცევა: `/version` უარყოფს ანონიმურ მოთხოვნებს, ხოლო `/livez`/`/readyz` -
იღებს:

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/version" # 401 - anonymous access დაკეტილია
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/livez"   # 200 - health probe მუშაობს
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/readyz"  # 200 - health probe მუშაობს
```

ავტენტიფიცირებული მოთხოვნა `/readyz`-ზე (უკვე გამართული kubectl context-ით)
აგრძელებს მუშაობას ზუსტად ისე, როგორც ადრე - `AuthenticationConfiguration.anonymous.conditions`
მხოლოდ აფართოებს წვდომას anonymous-მოთხოვნებისთვის კონკრეტულ გზებზე, მაგრამ არ ავიწროებს წვდომას
უკვე ავტენტიფიცირებული კლიენტებისთვის:

```bash
k get --raw=/readyz # ok
```

ავტენტიფიკაცია შემზღუდავი ავტორიზაციის გარეშე უაზროა - შეამოწმეთ, რომ
`--authorization-mode` static Pod-ზე ისევ `Node,RBAC`-ია და არ შეიცავს `AlwaysAllow`-ს
(kubeadm ამას ნაგულისხმევად ადგენს, მაგრამ ღირს დარწმუნება, რომ ფლაგი არაფერს შეუცვლია):

```bash
k get po -n kube-system -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep authorization-mode
# --authorization-mode=Node,RBAC
```

ცალკე ვაკეთებთ იმ ClusterRoleBinding-ების აუდიტს, რომელთა subjects ანონიმურ მომხმარებელზე
ან ჯგუფზე მიუთითებს - კლასტერში განზრახ დარჩენილია ერთი ასეთი lab-owned მიბმა:

```bash
k get clusterrolebinding -o json | jq -r \
  '.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name == "system:unauthenticated")] | length > 0) | .metadata.name'
# system:public-info-viewer
# lab104-unintended-anonymous-access
```

`system:public-info-viewer` - სტანდარტული kubeadm-მიბმაა: ისიც `system:unauthenticated`-ს
უმიზნებს, მაგრამ მისი ClusterRole უშვებს read-only `GET`-ს მხოლოდ
non-resource URL-ებზე `/livez`, `/readyz`, `/healthz`, `/version`, `/version/`, და არა ჩვეულებრივ
Kubernetes-რესურსებზე - ეს default Kubernetes RBAC-ია, bootstrap-ის აუცილებელი ნაწილი, ნუ შეეხებით
მას. ეს არ არის იგივე, რაც `anonymous.conditions` ამავე დავალებიდან: ის სია
ზღუდავს, რომელ გზებზე იღებს მოთხოვნა საერთოდ anonymous identity-ს authentication-ის ეტაპზე
(იქ მხოლოდ `/livez`/`/readyz`/`/healthz`) - `/version` ანონიმურად აბრუნებს
`401`-ს სწორედ იმიტომ, რომ anonymous identity იქ არ ენიჭება, და არა იმიტომ, რომ
`system:public-info-viewer`-ს იქ უფლებები არ ჰყოფნის. `lab104-unintended-anonymous-access` -
განზრახ lab-owned აღმოჩენაა: მისი ClusterRole `lab104-anonymous-debug-access` იძლევა
სრულფასოვან RBAC `get`/`list`-ს `pods`/`secrets`/`configmaps`-ზე კლასტერულად, ანუ ნებისმიერ
ანონიმურ მოთხოვნას მათი წაკითხვა შეუძლია. ვშლით ორივე ობიექტს, ისევე როგორც დავალებებში 4/7:

```bash
k delete clusterrolebinding lab104-unintended-anonymous-access
k delete clusterrole lab104-anonymous-debug-access
```

გაუქმებას ვადასტურებთ negative control-ით სწორედ არაავტენტიფიცირებული identity-ის სახელით
(`system:anonymous` + ჯგუფი `system:unauthenticated`, და მეტი არაფერი) `SubjectAccessReview`-ის
გავლით - მას admin-კონტექსტი ქმნის, ამიტომ ჯგუფების სიის
ხელოვნურად გაფართოება არ გვიწევს:

```bash
for R in pods secrets configmaps; do
  for NS in $(k get ns -o jsonpath='{.items[*].metadata.name}'); do
    ALLOWED=$(k create -o jsonpath='{.status.allowed}' -f - <<EOF
apiVersion: authorization.k8s.io/v1
kind: SubjectAccessReview
spec:
  user: system:anonymous
  groups: ["system:unauthenticated"]
  resourceAttributes:
    namespace: $NS
    resource: $R
    verb: get
EOF
    )
    printf '%-12s %-24s %s\n' "$R" "$NS" "$ALLOWED"
  done
done
# თითოეული სტრიქონისთვის მოსალოდნელია false
```

`can-i --as=system:anonymous`-ს `--as-group=system:authenticated` ნუ დაამატებთ: რეალური
არაავტენტიფიცირებული მოთხოვნა ამ ჯგუფში არ შედის, და შემოწმება აღარ ასახავს
ნამდვილ anonymous-identity-ს. თითოეულ namespace-ს ცალ-ცალკე ვამოწმებთ, რადგან
RoleBinding მოქმედებს მხოლოდ თავის namespace-ში: cluster-wide მიბმის არარსებობა
არ ამტკიცებს ლოკალურის არარსებობას, ხოლო მიღების კრიტერიუმი მოითხოვს, რომ წვდომა არც ერთ namespace-ში არ იყოს.

ბოლოს გაუშვით `check_result`.

## 6. Secret-ის გაჟონვა env-ით `/proc/1/environ`-ში: გადასვლა volume-ზე

`app-vulnerable` იღებს `db-creds`-ს `envFrom`-ით, ამიტომ მნიშვნელობა ხვდება
კონტეინერის PID 1 პროცესის environment-ში. ნებისმიერს, ვისაც ამ Pod-ში `kubectl exec`-ის უფლება აქვს,
შეუძლია secret პირდაპირ `/proc`-იდან წაიკითხოს, Kubernetes API-სთან მიმართვისა და
`get secrets`-ზე RBAC-უფლების გარეშე:

```bash
mkdir -p /var/work/tests/artifacts/6
k exec -n security-104 app-vulnerable -- cat /proc/1/environ \
  | tr '\0' '\n' | grep DB_PASSWORD | tee /var/work/tests/artifacts/6/env-leak-before.txt
```

ვინახავთ სწორედ სტრიქონს `DB_PASSWORD=<რეალური მნიშვნელობა>` პროცესის გარემოდან, და არა
უბრალოდ სიტყვას `DB_PASSWORD` მნიშვნელობის გარეშე - checker თავად შეადარებს მას Secret `db-creds`-ის ფაქტობრივ
მნიშვნელობას, მნიშვნელობის ცალკე გამოთვლა და შედარება თქვენ არ გჭირდებათ.

Pod-ს ხელახლა ვქმნით იმავე სახელით: ვშლით `envFrom`-ს, იმავე Secret-ს ვამაგრებთ როგორც volume
`db-creds-vol` `/etc/secrets`-ზე, read-only, `defaultMode: 0400`-ით (`256` decimal-ში, როგორც მას
აჩვენებს `kubectl get pod -o json`). `0400` - ეს read-only მხოლოდ ფაილის მფლობელისთვისაა
კონტეინერის შიგნით; აპლიკაციის პროცესი მაინც ამ UID-ით უნდა გაეშვას, წინააღმდეგ შემთხვევაში
ის ფაილს ვერ წაიკითხავს.

Pod-ის ველების უმეტესობა (მათ შორის `volumes`) შეუცვლელია (immutable), ამიტომ Pod უნდა წაიშალოს და ხელახლა შეიქმნას იმავე სახელით. ისევ უფრო იაფია
ჩონჩხის `--dry-run`-ით გენერირება და volume-ის `vim`-ში მიწერა, ვიდრე მთელი YAML-ის წერა:

```bash
k run app-vulnerable -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > app-vulnerable-fixed.yaml
vim app-vulnerable-fixed.yaml
```

```yaml
# Pod-ის spec-ში დაამატეთ:
spec:
  automountServiceAccountToken: false     # დაამატეთ
  containers:
  - name: app-vulnerable
    volumeMounts:                         # დაამატეთ
    - name: db-creds-vol                  # დაამატეთ
      mountPath: /etc/secrets             # დაამატეთ
      readOnly: true                      # დაამატეთ
    ...
  volumes:                                # დაამატეთ
  - name: db-creds-vol                    # დაამატეთ
    secret:                               # დაამატეთ
      secretName: db-creds                # დაამატეთ
      defaultMode: 0400                   # დაამატეთ
```

```bash
k delete pod app-vulnerable -n security-104
k apply -f app-vulnerable-fixed.yaml
k wait -n security-104 --for=condition=Ready po/app-vulnerable --timeout=120s
```

ვადასტურებთ სამ საბოლოო თვისებას, და არა მხოლოდ «secret environment-ში არ არის»: ფაილური
უფლებები ზუსტად `400`-ია (და არა უბრალოდ სადმე შეიცავს ქვესტრიქონს `400`), და, რაც უფრო მნიშვნელოვანია, აპლიკაციას
კვლავ რეალურად შეუძლია secret-ის მნიშვნელობის წაკითხვა - წინააღმდეგ შემთხვევაში hardening-ს შეეძლო შეუმჩნევლად
გაენადგურებინა თავად აპლიკაციის ფუნქციონალობა:

```bash
k exec -n security-104 app-vulnerable -- cat /proc/1/environ | tr '\0' '\n' | grep DB_PASSWORD
# არაფერი მოიძებნა - ეს მოსალოდნელია

k exec -n security-104 app-vulnerable -- stat -L -c '%a' /etc/secrets/DB_PASSWORD \
  | tee /var/work/tests/artifacts/6/secret-file-mode.txt
# 400 - სწორედ ეს მნიშვნელობა, და არა თვითნებური ტექსტი, რომელიც სადმე შეიცავს "400"-ს. ფლაგი -L
# სავალდებულოა: secret-ის volume მიმაგრდება სიმლინკების ჯაჭვით ("..data"), და -L-ის გარეშე
# stat აჩვენებს თავად სიმლინკის რეჟიმს (Linux-ში ყოველთვის 777), და არა რეალური ფაილისას.

# Positive control: აპლიკაციის პროცესს უნდა შეეძლოს secret-ის მნიშვნელობის რეალურად წაკითხვა.
k exec -n security-104 app-vulnerable -- cat /etc/secrets/DB_PASSWORD
# უნდა დაემთხვეს მნიშვნელობას, რომელიც ფიქსამდე იყო env-leak-before.txt-ში
```

`defaultMode: 0400` იცავს სხვა UID-ებით კითხვისგან ამავე Pod-ზე (მაგალითად, მეზობელი
sidecar-container-ით საჭირო UID-ის გარეშე), მაგრამ არ ანაცვლებს encryption at rest-ს etcd-ში და ხელს არ უშლის
მოსალოდნელი UID-ით გაშვებულ პროცესს, თავად ფაილი წაიკითხოს - mount სწორედ ამას უშვებს.
დარწმუნდით ასევე, რომ `db-creds` ერთდროულად რაიმე მეორე გზით არ არის მიმაგრებული
(მაგალითად, `projected` volume-ითაც) - უნდა დარჩეს ზუსტად ერთი volume,
რომელიც ამ Secret-ს ამაგრებს.

ბოლოს გაუშვით `check_result`.

## 7. ფარული RBAC privilege escalation-ის გზების აუდიტი და გაუქმება

`build-agent-hidden-privesc` არ შეიცავს wildcard `*`-ს, მაგრამ `impersonate`/`bind`/`escalate`/
CSR-approval - სახიფათო verbs-ის ცალკე კატეგორიაა: ისინი ხილული რესურსების სიას არ აფართოებენ,
არამედ იძლევიან **სხვისი სახელით მოქმედების** ან **საკუთარი თავისთვის
დამატებითი უფლებების გაცემის** საშუალებას. fixture-ის ამ ვერსიაში ClusterRole ასევე შეიცავს საბაზისო
`create`/`update` `clusterroles`/`clusterrolebindings`-ზე - მათ გარეშე `bind`/`escalate`
არასრული escalation primitives იქნებოდა (RBAC მოითხოვს, რომ ან უკვე გქონდეთ უფლებები როლიდან, ან
აშკარად გქონდეთ `escalate`/`bind` Role/Binding-ის რეალურად შექმნის/განახლების მცდელობის ფონზე).
ვპოულობთ ყველა ClusterRoleBinding-ს, რომელთა ClusterRole-ები უშვებს სახიფათო verbs-იდან ნებისმიერს. ვიწყებთ არა
ClusterRole-იდან (კლასტერში ისინი ათობითაა, სტანდარტული `system:*`-ის ჩათვლით), არამედ
ClusterRoleBinding-იდან - `kubectl get clusterrolebinding` ნაგულისხმევად უკვე აჩვენებს სვეტს
`ROLE` (ფორმატი `ClusterRole/<სახელი>`), ხოლო `-o wide` ამატებს ასევე `USERS`/`GROUPS`/
`SERVICEACCOUNTS`-ს - არც custom-columns, არც YAML არ არის საჭირო:

```bash
mkdir -p /var/work/tests/artifacts/7
k get clusterrolebinding -o wide | grep -v system:
# build-agent-hidden-privesc   ClusterRole/build-agent-hidden-privesc   ...   security-104/build-agent
```

თითოეული კანდიდატისთვის ვუყურებთ მის ClusterRole-ს ადამიანისთვის წასაკითხად, `jq`/`grep`-ის გარეშე YAML-ზე -
`kubectl describe` თავად ბეჭდავს verbs-ს ცხრილით, იქ მაშინვე ჩანს `impersonate`/`bind`/
`escalate` და ცალკე წესი `certificatesigningrequests/approval`-ზე:

```bash
k describe clusterrole build-agent-hidden-privesc
# PolicyRule-ცხრილში Verbs აჩვენებს impersonate / bind / escalate / update
# (certificatesigningrequests/approval-ზე) - თვალით ჩანს, რომ როლი სახიფათოა
```

ვინახავთ ClusterRoleBinding-ის სახელს (და არა ClusterRole-ისას - ისინი შეიძლება არ ემთხვეოდეს, ამ ლაბში
შემთხვევით დაემთხვა) artifact-ში:

```bash
echo build-agent-hidden-privesc > /var/work/tests/artifacts/7/dangerous-bindings-before.txt
cat /var/work/tests/artifacts/7/dangerous-bindings-before.txt
```

`build-agent-hidden-privesc` უნდა იყოს საბოლოო ფაილში (როგორც ClusterRoleBinding-ის სახელი,
და არა ClusterRole-ის). ვშლით სწორედ ამ ClusterRoleBinding-ს (და ClusterRole-ს, რათა შაბლონი
ხელახალი გამოყენებისთვის არ დარჩეს), `system:*` bindings-ს შეხების გარეშე, რომლებიც
Kubernetes-ის core-კომპონენტებს აძლევს აუცილებელ `impersonate`/CSR წვდომას:

```bash
k delete clusterrolebinding build-agent-hidden-privesc
k delete clusterrole build-agent-hidden-privesc
```

ვადასტურებთ ყველა დეკლარირებული სახიფათო უფლების გაუქმებას, და არა მხოლოდ მათი ნაწილისას. ორი ნიუანსი:
fixture იძლევა `impersonate`-ს ერთდროულად რესურსის სამ ტიპზე (`users`/`groups`/`serviceaccounts`) -
მხოლოდ `users`-ის შემოწმება დანარჩენი ორის გაუქმებას არ ამტკიცებს; ხოლო `TYPE/NAME` `kubectl auth
can-i`-ში - ეს resourceName-ია, და არა subresource (`kubectl auth can-i --help` პირდაპირ აჩვენებს
მაგალითს "jobs.batch/bar" - ობიექტის შემოწმება, რომელსაც სიტყვასიტყვით `bar` ჰქვია), ამიტომ
`certificatesigningrequests/approval`-ისთვის საჭიროა ცალკე ფლაგი `--subresource=approval`, და არა
დახრილი ხაზი (/):

```bash
k auth can-i impersonate users --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate groups --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate serviceaccounts -n security-104 --as=system:serviceaccount:security-104:build-agent
k auth can-i bind clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i escalate clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i update certificatesigningrequests --subresource=approval --as=system:serviceaccount:security-104:build-agent
k auth can-i approve signers/kubernetes.io/kube-apiserver-client --as=system:serviceaccount:security-104:build-agent
# no / no / no / no / no / no / no
```

ბოლოს გაუშვით `check_result`.

## 8. Namespace-level baseline: `default` SA automount-ის გარეშე

დავალება 3 automount-ს თიშავდა წერტილოვნად, კონკრეტულ Pod-სა და მის საკუთარ SA-ზე. აქ
საჭიროა სისტემური baseline: namespace-ის `default` SA-ს ვასწორებთ მასში რაიმე
Pod-ის **შექმნამდე**, რათა არც ერთმა ახალმა workload-მა ნაგულისხმევად token არ მიიღოს, თუნდაც დეველოპერმა
manifest-ში აშკარა ველი დაივიწყოს.

ServiceAccount `default` იქმნება ცალკე controller-ის მიერ ასინქრონულად Namespace-ის გამოჩენის შემდეგ -
`kubectl wait`-ს შეუძლია ობიექტის სწორედ გამოჩენის ლოდინი (`--for=create`), და არა
მხოლოდ მისი condition-ისა, ამიტომ არც ხელით retry არის საჭირო, არც თვითნაკეთი ციკლი:

```bash
k create namespace security-104-baseline
k wait -n security-104-baseline --for=create sa/default --timeout=30s

k -n security-104-baseline patch sa default \
  -p '{"automountServiceAccountToken":false}'
k -n security-104-baseline get sa default \
  -o jsonpath='{.automountServiceAccountToken}{"\n"}'
# false
```

ვქმნით Pod-ს, რომელიც **არ** ადგენს არც `serviceAccountName`-ს, არც `automountServiceAccountToken`-ს -
ეს რეალობაში ყველაზე ხშირი შემთხვევაა, როცა დეველოპერი უბრალოდ SA-ზე არ ფიქრობს. ველი
`automountServiceAccountToken` უნდა **არ** იყოს Pod-ის spec-ში - აშკარა `false`-ის მითითება
დაამტკიცებდა მხოლოდ თავად Pod-ის წერტილოვან პარამეტრს (როგორც დავალება 3-ში), და არა იმას, რომ
namespace-level baseline რეალურად მუშაობს.

აქ `--dry-run`-იც კი არ არის საჭირო - რადგან Pod-ში არ ემატება არც ერთი ველი SA/automount-ის შესახებ,
`kubectl run` ფლაგების გარეშე ქმნის ზუსტად იმას, რაც საჭიროა, პირდაპირ:

```bash
k run implicit-default-sa -n security-104-baseline --image=busybox:1.36 --command -- sh -c "sleep 3600"
k wait -n security-104-baseline --for=condition=Ready po/implicit-default-sa --timeout=60s
k get po implicit-default-sa -n security-104-baseline -o jsonpath='{.spec.serviceAccountName}{"\n"}'
# default

k get po implicit-default-sa -n security-104-baseline \
  -o jsonpath='{.spec.automountServiceAccountToken}{"\n"}'
# ცარიელი გამოტანა - ველი spec-ში არ არის, და არა false-ზე დაყენებული

k exec -n security-104-baseline implicit-default-sa -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - ფაილი არ არის, და თავად exec წარმატებით შესრულდა (ბანალური
# "cat"-ისგან არარსებულ ფაილზე განსხვავებით, რომლის exit code-იც cat-ის მხრიდან ასევე არანულოვანია, მაგრამ სხვა
# მიზეზით - test ! -e აკეთებს სწორედ იმ შემოწმებას, რომელიც საჭიროა, და მისი საკუთარი წარმატება
# ცალკე უნდა მოვითხოვოთ, და არა უბრალოდ "ნებისმიერი შეცდომა = ფაილი არ არის")
```

SA-ს მნიშვნელობა მოქმედებს მხოლოდ მაშინ, როცა Pod მას თავად არ გადაფარავს. თუ იმავე namespace-ს
დასჭირდება Pod API-წვდომით, დაამატეთ `automountServiceAccountToken: true` აშკარად
კონკრეტულ manifest-ში იმის შემოწმების შემდეგ, რომ წვდომა მართლაც საჭიროა - `default` SA-ს baseline-ს
ნუ დააბრუნებთ `true`-ზე მთელი namespace-ისთვის. ასევე ხელით ნუ მიამაგრებთ ძველ
(legacy) `Secret`-ს `type: kubernetes.io/service-account-token`-ით `volumes[].secret`-ის გავლით -
ეს Pod-ს ვალიდურ API-token-ს მისცემდა automount-ის პარამეტრების მიუხედავად.

ბოლოს გაუშვით `check_result`.

## 9. ინტეგრაციული დავალება: სახიფათო RBAC-ცვლილების აღმოჩენა → audit log → containment

დავალებები 1-8 ხურავდა privilege escalation-ის კონკრეტულ გზებს, თავად `build-agent`-ისთვის ხელმისაწვდომს
(wildcard, impersonate/bind/escalate, automount). აქ საჭიროა დაცვის სხვა ფენა -
**ადმინისტრატორის მიერ გაცემული სახიფათო RBAC grant-ის** აღმოჩენა (შეცდომით, კომპრომეტირებული
ავტომატიზაციის გამო, ან ბოროტი განზრახვით), და არა მხოლოდ RBAC-ის მიმდინარე snapshot.
ვუკავშირდებით control-plane-ს და ვამზადებთ მინიმალურ audit backend-ს:

```bash
ssh control-plane
sudo -i
mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["clusterroles", "clusterrolebindings"]
- level: Metadata
EOF
```

RBAC-წესი პირველია - უფრო სპეციფიკური წესი ზოგად catch-all-ს უნდა უსწრებდეს,
წინააღმდეგ შემთხვევაში `Metadata` მოვლენას ადრე ჩაიგდებს ხელში. `omitStages: [RequestReceived]`
მთელი policy-ის დონეზე აქრობს ზედმეტ ჩანაწერს მოთხოვნის დამუშავებამდე - მას არ აქვს
`requestObject`/`responseStatus`, და checker ასეთ ჩანაწერებს მაინც უგულებელყოფს (`stage ==
"ResponseComplete"`), ხოლო catch-all `Metadata`-წესით კლასტერის ყველა დანარჩენ მოთხოვნაზე
ეს სტადია audit.log-ის მოცულობას სარგებლის გარეშე გააორმაგებდა.

ვასწორებთ static manifest-ს: ვამატებთ `--audit-policy-file`/`--audit-log-path`-ს და hostPath
volume/volumeMount-ს policy-ისა და ლოგების დირექტორიებისთვის - იმავე ხერხით, რაც დავალება 5-ში
`authentication-config.yaml`-ისთვის:

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/9-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# command მასივში დაამატეთ სტრიქონები იმავე ჩაღრმავებით, რაც დანარჩენ არგუმენტებს აქვს:
#   - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
#   - --audit-log-path=/var/log/kubernetes/audit/audit.log
# კონტეინერის volumeMounts-ში (იგივე ჩაღრმავება, რაც მეზობელ ელემენტებს):
#   - mountPath: /etc/kubernetes/audit
#     name: audit-policy
#     readOnly: true
#   - mountPath: /var/log/kubernetes/audit
#     name: audit-log
# Pod-ის volumes-ში (იგივე ჩაღრმავება, რაც მეზობელ ელემენტებს):
#   - hostPath:
#       path: /etc/kubernetes/audit
#       type: Directory
#     name: audit-policy
#   - hostPath:
#       path: /var/log/kubernetes/audit
#       type: DirectoryOrCreate
#     name: audit-log
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` აიძულებს static Pod-ის დაუყოვნებლივ ხელახლა აწყობას - როგორც
დავალება 5-ში, ეს უფრო სწრაფია, ვიდრე ლოდინი, სანამ kubelet თავად შეამჩნევს ფაილის ცვლილებას:

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS უნდა გახდეს Running - თუ ჯერ არა, დაელოდეთ რამდენიმე წამს და გაიმეორეთ
```

ვბრუნდებით სამუშაო მანქანაზე (ადმინისტრატორ `cluster1-admin`-ის სახელით) და ვქმნით
სახიფათო მიბმას - ეს **არ** არის `build-agent`-ის მხრიდან ესკალაციის მცდელობა (მას ამისკენ უკვე აღარ აქვს
რეალური გზები დავალება 7-ის შემდეგ), არამედ მოდელირებული ადმინისტრატორული მოქმედება,
რომელიც audit log-მა უნდა დაიჭიროს როგორც რეპროდუცირებადი evidence იმის შესახებ, ვინ ზუსტად
გააკეთა ეს და ვის ზუსტად გადაეცა უფლებები:

```bash
k create clusterrolebinding incident-simulated-escalation \
  --clusterrole=cluster-admin \
  --serviceaccount=security-104:build-agent
```

ჯერ უბრალოდ თვალით ვრწმუნდებით, რომ audit-წესი რეალურად მუშაობს და მოვლენა
ლოგში მოხვდა - გამოცდაზე ჩვეულებრივ საჭიროა სწორედ ეს შემოწმება, და არა მზა artifact:

```bash
ssh control-plane
sudo cat /var/log/kubernetes/audit/audit.log | jq . | grep -A 30 incident-simulated-escalation
exit
```

`jq .` ბეჭდავს ლოგის თითოეულ ჩანაწერს ადამიანისთვის წასაკითხად (თითო ველი თითო სტრიქონზე), `grep -A 30`
აჩვენებს ნაპოვნ სტრიქონს სახელით და მის შემდეგ 30 სტრიქონს - ეს საკმარისია, რომ ვნახოთ
`stage`, `user.username` (რეალური ინიციატორი), `requestObject.roleRef`,
`requestObject.subjects` თვალით, სპეციალური jq-სინტაქსის გარეშე.

რეალური გამოცდისთვის ეს საკმარისია, მაგრამ ეს ლაბი დამატებით მოითხოვს artifact-ფაილს
მოვლენით - არა იმიტომ, რომ checker-ს არ ჰყოფნის იმის ცოდნა, რომ წესი მუშაობს (ის თავად, დამოუკიდებლად,
კითხულობს `audit.log`-ს control-plane-ზე SSH-ით), არამედ ცალკე უნარის შესამოწმებლად:
სწორედ რეალური ჩანაწერის ამოღება და შენახვა როგორც forensic evidence, და არა მისი
საკუთარი სიტყვებით გადმოცემა (checker ადარებს თქვენი ფაილის `auditID`-ს ლოგში რეალური ჩანაწერის `auditID`-თან).
`/var/work/tests/artifacts/9/` - გზაა სამუშაო მანქანაზე, და არა control-plane-ზე, ამიტომ
ვინახავთ სამუშაო მანქანიდან `ssh control-plane "..."`-ით, grep-ის იმავე კომბინაციით ჩვეულებრივ
ქვესტრიქონებზე (მოვლენის სახელი + `ResponseComplete`, რათა იმავე request-ის შუალედურ
`ResponseStarted` ჩანაწერზე არ მოვხვდეთ):

```bash
mkdir -p /var/work/tests/artifacts/9
ssh control-plane "sudo cat /var/log/kubernetes/audit/audit.log" \
  | grep incident-simulated-escalation | grep ResponseComplete \
  | tail -n1 > /var/work/tests/artifacts/9/audit-escalation-event.json
```

მოვლენას ვინახავთ **მთლიანად**, როგორც ის რეალურად დევს audit log-ში (`auditID`-ის ჩათვლით) - არ
ვაწერთ თავიდან და JSON-ს ხელით არ ვაწყობთ, წინააღმდეგ შემთხვევაში artifact ვერიფიკაციისას არ დაემთხვევა
ლოგში რეალურ ჩანაწერს.

Containment: ვშლით მიბმას და ვადასტურებთ, რომ წვდომა რეალურად გაუქმებულია, და არა უბრალოდ
ობიექტი გახდა წაკითხვისთვის მიუწვდომელი. `can-i` `-n`/`-A`-ის გარეშე ამოწმებს მხოლოდ მიმდინარე namespace-ს
kubeconfig-კონტექსტის მიხედვით, და არა მთელ კლასტერს - `security-104`-ში namespaced RoleBinding-ისთვის
(უკვე წაშლილი cluster-wide ClusterRoleBinding-ისგან განსხვავებით) ეს შედეგს ცვლის,
ამიტომ namespace-ს აშკარად ვუთითებთ:

```bash
k delete clusterrolebinding incident-simulated-escalation
k auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent \
  | tee /var/work/tests/artifacts/9/containment-result.txt
# no
```

განსხვავება დავალება 7-თან: იქ ჩვენ ვპოულობდით და ვაუქმებდით **უკვე არსებულ** ფარულ გზას RBAC-ობიექტების
სტატიკური ანალიზით - გზას, რომელიც თავად workload-ს (`build-agent`) ეკუთვნოდა. აქ
source of truth - **მოვლენაა დროში** (audit log), რომელიც ამტკიცებს, ვინ ზუსტად
(ველი `user.username` - მოთხოვნის რეალური ინიციატორი, ამ შემთხვევაში ადმინისტრატორი, და არა
`build-agent`) გასცა სახიფათო უფლებები და ვის ზუსტად - ეს არის ის, რაც რეალური
ინციდენტისთვის არის საჭირო, როცა თავად ობიექტი გამოყენების შემდეგ შეიძლება უკვე წაშლილიყო, ხოლო `build-agent`
მოვლენაში ფიგურირებს მხოლოდ უფლებების მიმღებად, და არა მოთხოვნის ავტორად.

ბოლოს გაუშვით `check_result`.

## 10. Secret-ის დეკოდირება, შექმნა და მიმაგრება

`legacy-config` უკვე არსებობს. ორივე მნიშვნელობას ვკითხულობთ API-ს გავლით, და არ ვარაუდობთ:

```bash
mkdir -p /var/work/tests/artifacts/10
SERVICE_USER=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_USER}' | base64 -d)
SERVICE_TOKEN=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_TOKEN}' | base64 -d)
printf 'SERVICE_USER=%s\nSERVICE_TOKEN=%s\n' "$SERVICE_USER" "$SERVICE_TOKEN" \
  | tee /var/work/tests/artifacts/10/decoded-values.txt
```

ვქმნით ახალ generic Secret-ს იმავე გასაღებების სახელებით და იმავე მნიშვნელობებით -
`--from-literal` თავად აკოდირებს მნიშვნელობას base64-ში, ხელით ამის გაკეთება საჭირო არ არის:

```bash
k create secret generic rehydrated-config -n security-104 \
  --from-literal=SERVICE_USER="$SERVICE_USER" \
  --from-literal=SERVICE_TOKEN="$SERVICE_TOKEN"
```

ვამაგრებთ მას Pod-ში როგორც read-only volume-ს - ისევ dry-run + წერტილოვანი შესწორება `vim`-ში:

```bash
k run secret-workflow -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > secret-workflow.yaml
vim secret-workflow.yaml
```

```yaml
# Pod-ის spec-ში დაამატეთ:
spec:
  automountServiceAccountToken: false      # დაამატეთ
  containers:
  - name: secret-workflow
    volumeMounts:                          # დაამატეთ
    - name: rehydrated-config-vol          # დაამატეთ
      mountPath: /etc/rehydrated           # დაამატეთ
      readOnly: true                       # დაამატეთ
    ...
  volumes:                                 # დაამატეთ
  - name: rehydrated-config-vol            # დაამატეთ
    secret:                                # დაამატეთ
      secretName: rehydrated-config        # დაამატეთ
```

```bash
k apply -f secret-workflow.yaml
k wait -n security-104 --for=condition=Ready po/secret-workflow --timeout=60s
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_USER
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_TOKEN
# უნდა დაემთხვეს ზემოთ მოცემულ $SERVICE_USER / $SERVICE_TOKEN-ს
```

ბოლოს გაუშვით `check_result`.

## 11. არსებული Role-ის გასწორება და მისი მიბმა სხვა namespace-ის SA-სთან

არსებული Role `pod-role` `rbac-a`-ში უშვებს `get`, `list`, `delete` - ზედმეტ `delete`-ს ვშლით,
საჭირო `watch`-ს ვამატებთ:

```bash
k patch role pod-role -n rbac-a --type=json -p \
  '[{"op":"replace","path":"/rules/0/verbs","value":["get","list","watch"]}]'
k auth can-i delete pods -n rbac-a --as=system:serviceaccount:rbac-a:dev # no
k auth can-i watch pods -n rbac-a --as=system:serviceaccount:rbac-a:dev  # yes
```

`shared-config` უკვე არსებობს `rbac-b`-ში. ვქმნით ახალ Role+RoleBinding-ს სწორედ
`rbac-b`-ში - RoleBinding მხარს უჭერს subject-ს სხვა namespace-იდან, მაგრამ თავად უფლებები
მოქმედებს მხოლოდ თავად RoleBinding-ის namespace-ში:

```bash
k create role configmap-reader -n rbac-b --resource=configmaps --verb=get,list
k create rolebinding configmap-reader-binding -n rbac-b \
  --role=configmap-reader --serviceaccount=rbac-a:dev

k auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev    # yes
k auth can-i delete configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev # no
k auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev       # no
```

ვქმნით Pod-ს `rbac-a`-ში, რომელიც რეალურად იყენებს `dev`-ს:

```bash
k run rbac-a-workload -n rbac-a --image=busybox:1.36 \
  --overrides='{"spec":{"serviceAccountName":"dev"}}' -- sh -c "sleep 3600"
```

ბოლოს გაუშვით `check_result`.

## 12. მომხმარებელი კლიენტის სერტიფიკატით CSR-ის გავლით + namespaced RBAC

ვაგენერირებთ private key-სა და CSR-ს `CN=john`-ით - RBAC სერტიფიკატზე დაფუძნებული მომხმარებლისთვის
უკავშირდება `kind: User`-ით, და არა `ServiceAccount`-ით, და `User`-ს საკუთარი API
ობიექტი არ აქვს: მისი identity მთლიანად განისაზღვრება იმით, რომ CN client-სერტიფიკატში
ემთხვევა `name`-ს binding-ში.

```bash
mkdir -p /var/work/tests/artifacts/12
openssl genrsa -out /var/work/tests/artifacts/12/john.key 2048
openssl req -new -key /var/work/tests/artifacts/12/john.key \
  -out /tmp/john.csr -subj "/CN=john"
```

ვაგზავნით როგორც Kubernetes `CertificateSigningRequest`-ს იმავე signer-ით, რომელიც უკვე
გამოიყენება დავალება 7-ში CSR-ის დასამტკიცებლად (`kubernetes.io/kube-apiserver-client` -
სწორი signer სწორედ client-auth სერტიფიკატისთვის, რომელიც API server-ზე მოთხოვნებს
ავტენტიფიცირებას გაუკეთებს):

```bash
cat > john-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-csr
spec:
  request: $(base64 -w0 /tmp/john.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
EOF
k apply -f john-csr.yaml
k certificate approve john-csr
k get csr john-csr -o jsonpath='{.status.certificate}' \
  | base64 -d > /var/work/tests/artifacts/12/john.crt
```

ვამოწმებთ, რომ სერტიფიკატი რეალურად ამ კლასტერის მიერ არის ხელმოწერილი, და არა მხოლოდ ის, რომ ველი
`status.certificate` არ არის ცარიელი:

```bash
openssl verify -CAfile <(ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt) \
  /var/work/tests/artifacts/12/john.crt
# /var/work/tests/artifacts/12/john.crt: OK
openssl x509 -in /var/work/tests/artifacts/12/john.crt -noout -subject
# subject=CN = john
```

RBAC: Role `development`-ში, RoleBinding `kind: User, name: john`-ზე - `--user=john`
`kubectl create rolebinding`-ში თავად აყენებს `kind: User`-ს, YAML-ის წერა საჭირო არ არის:

```bash
k create role john-pod-access -n development --resource=pods --verb=create,list,get
k create rolebinding john-pod-access-binding -n development \
  --role=john-pod-access --user=john

k auth can-i create pods -n development --as=john  # yes
k auth can-i list pods -n development --as=john    # yes
k auth can-i get pods -n development --as=john     # yes
k auth can-i delete pods -n development --as=john  # no
k auth can-i create pods -n security-104 --as=john # no
```

`--as=john` ამტკიცებს მხოლოდ RBAC-ლოგიკას (impersonation, ხელმისაწვდომი ნებისმიერი admin-ისთვის
იმის მიუხედავად, გაცემულია თუ არა რეალური სერტიფიკატი). ცალკე ვამტკიცებთ, რომ სწორედ
გაცემული სერტიფიკატი რეალურად მიიღება API server-ის მიერ ნამდვილი TLS client-auth
მოთხოვნით:

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt > /tmp/cluster-ca.crt
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/development/pods"     # 200
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/security-104/pods"     # 403
```

იგივე დამტკიცება, მაგრამ ჩვეული `kubectl`-ით, და არა `curl`-ით - John-ისთვის ცალკე
kubeconfig-ს ვაწყობთ უკვე გაცემული სერტიფიკატიდან (`set-credentials` `--client-certificate`/
`--client-key`-ით, და არა `--token`-ით, რადგან აქ identity სწორედ client-cert-ია, და არა
ServiceAccount token):

```bash
k config set-cluster cluster1 --server="$SERVER" \
  --certificate-authority=/tmp/cluster-ca.crt --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-credentials john \
  --client-certificate=/var/work/tests/artifacts/12/john.crt \
  --client-key=/var/work/tests/artifacts/12/john.key --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-context john@cluster1 --cluster=cluster1 --user=john \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config use-context john@cluster1 \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development
# მუშაობს - RBAC უშვებს

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n security-104
# Error from server (Forbidden) - იგივე 403, რაც curl-შემოწმებაში ზემოთ

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig auth whoami
# Username: john - ადასტურებს, რომ kubeconfig რეალურად სწორედ როგორც
# john ავტენტიფიცირდება, და არა უბრალოდ შემთხვევით იძლევა საჭირო პასუხის კოდებს
```

ბოლოს გაუშვით `check_result`.
