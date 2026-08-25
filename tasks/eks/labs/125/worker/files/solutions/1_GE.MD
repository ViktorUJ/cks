[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 125 - ეტალონური გამოსავალი (EKS Auto Mode საკუთარი სტეკის წინააღმდეგ)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის მეშვეობით. kubectl უკვე
კონფიგურირებულია კლასტერზე. კლასტერი შექმნილია ჩართული Auto Mode-ით და ერთი ჩაშენებული
NodePool `general-purpose`-ით - ამ ლაბში არც Fargate profile, არც managed addon-ები, არც
Karpenter არსებობს.

კლასტერის სახელს იღებთ kubeconfig-იდან: `list-clusters[0]` დააბრუნებდა ანგარიშის პირველ
კლასტერს, ეს კი აუცილებლად ჩვენი არ არის.

```bash
export CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
echo "$CLUSTER"
```

## დავალება 1. რეჟიმის დადასტურება: Auto Mode ჩართულია

```bash
mkdir -p /var/work/tests/artifacts/1
{
  echo "=== aws eks describe-cluster computeConfig ==="
  aws eks describe-cluster --name "$CLUSTER" --query 'cluster.computeConfig'
  echo
  echo "=== kubectl get nodepools ==="
  kubectl get nodepools
} > /var/work/tests/artifacts/1/automode.txt
cat /var/work/tests/artifacts/1/automode.txt
```

`computeConfig.enabled` უნდა იყოს `true`, ხოლო `nodePools` უნდა შეიცავდეს
`general-purpose`-ს. `kubectl get nodepools` აჩვენებს იმავე NodePool-ს, როგორც ჩვეულებრივ
Kubernetes რესურსს - Auto Mode ჩართულ ჩაშენებულ pool-ებს Kubernetes API-ის მეშვეობით
მატერიალიზებს (თავი 9).

## დავალება 2. მეორე ჩაშენებული NodePool გამორთულია

```bash
kubectl get nodepools
```

სიაში `system` არ არის - ჩაშენებული NodePool კლასტერის რესურსად ხდება მხოლოდ მაშინ, როცა
მისი სახელი `computeConfig.nodePools`-ში ფიგურირებს; ამ ლაბში იქ მხოლოდ `general-purpose`
წერია.

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/twopools.txt <<'EOF'
EKS Auto Mode-ს ორი ჩაშენებული NodePool აქვს: general-purpose და system. NodePool system
ატარებს taint CriticalAddonsOnly-ს, რომელს ტოლერირებენ კლასტერისთვის კრიტიკული
კომპონენტები (მაგალითად CoreDNS) - ეს არის საშუალება მათი ჩვეულებრივი დატვირთვისგან
გამოსაცალკევებლად, რომ არ იკონკურირონ აპლიკაციებთან რესურსებზე და არ გამოდევნონ
general-purpose ნოუდების კონსოლიდაციისას.

ამ ლაბში node_pools მხოლოდ general-purpose-ს შეიცავს, ამიტომ system კლასტერის რესურსად
არ იქმნება: kubectl get nodepools მას არ აჩვენებს. მისი ჩართვა ნიშნავს
computeConfig.nodePools-ის რედაქტირებას control plane-ზე, არა kubectl ობიექტის შექმნას.
EOF
cat /var/work/tests/artifacts/2/twopools.txt
```

## დავალება 3. დატვირთვა general-purpose-ზე და ჩაშენებული NodePool-ის შეცვლის მცდელობა

```bash
kubectl create namespace eks-125
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-125
kubectl rollout status deployment/web -n eks-125

kubectl get pods -n eks-125 -o wide
```

ორივე რეპლიკა `Running` მდგომარეობაში გადავა ნოუდზე, რომელიც Auto Mode-მა თავად აწია
`general-purpose`-ის ქვეშ - Fargate profile-ისა და გარეშე Karpenter-ის გარეშე, რომლებიც
საჭიროა ლაბ 101-ის ბაზაში.

ვცდილობთ ჩაშენებული NodePool-ის რედაქტირებას. AWS ჩაშენებულ NodePool-ებს დოკუმენტირებულად
აღწერს, როგორც „enabled or disabled but not modified", მაგრამ ეს ხელით უნდა
შემოწმდეს - admission დონეზე აკრძალვა არ არსებობს:

```bash
mkdir -p /var/work/tests/artifacts/3
{
  echo "=== ჩაშენებული pool-ის kubectl patch ==="
  kubectl patch nodepool general-purpose --type merge -p '{"spec":{"limits":{"cpu":"100"}}}'
  echo "limits ცვლილების შემდეგ: $(kubectl get nodepool general-purpose -o jsonpath='{.spec.limits}')"
  echo
  echo "=== ვისია ობიექტის მფლობელი ==="
  kubectl get nodepool general-purpose -o jsonpath='labels={.metadata.labels}{"\n"}'
  kubectl get nodepool general-purpose \
    -o jsonpath='managedFields managers={range .metadata.managedFields[*]}{.manager}{","}{end}{"\n"}'
  echo
  echo "=== დასკვნა ==="
  echo "ცვლილება მიღებულია: ბრძანებამ დააბრუნა patched, მნიშვნელობა ობიექტში დარჩა."
  echo "მაგრამ ობიექტი სერვისს ეკუთვნის: ლეიბლი app.kubernetes.io/managed-by=eks,"
  echo "ველების მფლობელია eks-auto-mode. მართვის მხოლოდ ერთი მხარდაჭერილი გზა არსებობს -"
  echo "pool-ის სახელის ჩართვა და გამორთვა computeConfig.nodePools-ში. ამ სიის შეცვლისას"
  echo "რესურსი ნოუდებთან ერთად წაშლილია და თავიდან იქმნება, ჩვენი ცვლილებების გარეშე."
} > /var/work/tests/artifacts/3/builtin.txt
cat /var/work/tests/artifacts/3/builtin.txt
```

დავაბრუნოთ pool საწყის მდგომარეობაში - ჩვენი არ არსებული ობიექტზე ზედმეტი `limits`
საჩვენი არ გვსჭირდება:

```bash
kubectl patch nodepool general-purpose --type merge -p '{"spec":{"limits":null}}'
kubectl get nodepool general-purpose -o jsonpath='{.spec.limits}{"\n"}'
```

ყურადღება: `kubectl delete nodepool general-purpose` ჩაივლის, მაგრამ EKS ობიექტს
ხელახლა არ ქმნის, pool-ის ნოუდები დრეინირდება - კლასტერი გამოთვლის გარეშე რჩება.
აღდგენა მხოლოდ `computeConfig`-ის მეშვეობით ხდება (რეცეპტი README-ის „წაშლის" ნაწილში).

## დავალება 4. ნოუდზე წვდომა არ არსებობს: SSH და SSM by design დახურულია

Auto Mode-ში ნოუდის სახელი თავადვე instance ID-ია, `providerID`-ის ცალკე დამუშავება
საჭირო არ არის:

```bash
NODE=$(kubectl get pods -n eks-125 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node=$NODE"
```

ვაგროვებთ სამ მტკიცებულებას. პირველი - instance-ს key pair არ აქვს (`KeyName`), ესე იგი
SSH გასაღებით შეუძლებელია, პორტ 22-ზე ვინმეს მოსმენა ხდება თუ არა.

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "=== key pair და ნოუდის image ==="
  aws ec2 describe-instances --instance-ids "$NODE" \
    --query 'Reservations[0].Instances[0].[KeyName,ImageId,PlatformDetails]' --output text
  echo "KeyName ცარიელია (None) - ნოუდს key pair არ აქვს"
  echo
  echo "=== SSM: კავშირი არ არსებობს ==="
  aws ssm get-connection-status --target "$NODE" --output json
  echo "SSM ინვენტარი (ნოუდი მასში არ უნდა იყოს):"
  aws ssm describe-instance-information \
    --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output text
} > /var/work/tests/artifacts/4/nossh.txt
```

აქ არ გამოიყენოთ `aws ssm start-session`: სამუშაო მანქანას `ssm:StartSession` უფლება არ
აქვს, ამიტომ ბრძანება აბრუნებს `AccessDeniedException`-ს - ეს worker-ის პოლიტიკის ფაქტია,
არა ნოუდისა. დავალების კითხვას პასუხობს `get-connection-status` სტატუსით `notconnected`.

მესამე მტკიცებულება საპირისპირო მიმართულებით მოქმედებს: ჰოსტი კლასტერისგან
იზოლირებული არ არის. პრივილეგირებული pod `hostPath`-ით `/`-ზე ნოუდის ფაილურ სისტემას
კითხულობს:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hostprobe
  namespace: eks-125
spec:
  nodeName: $NODE
  restartPolicy: Never
  containers:
  - name: p
    image: busybox
    command: ["sh","-c","cat /host/etc/os-release; echo ---; ls /host/bin | head -5"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: h
      mountPath: /host
  volumes:
  - name: h
    hostPath:
      path: /
EOF

kubectl wait --for=condition=Ready pod/hostprobe -n eks-125 --timeout=90s 2>/dev/null
sleep 5
{
  echo
  echo "=== ჰოსტი პრივილეგირებული pod-იდან ==="
  kubectl logs hostprobe -n eks-125
  echo
  echo "=== დასკვნა ==="
  echo "SSH შეუძლებელია (key pair KeyName არ არსებობს), SSM დაკავშირებული არ არის"
  echo "(notconnected) - ოპერატორს ნოუდზე წვდომა არ აქვს. მაგრამ Bottlerocket image"
  echo "პრივილეგირებული pod-იდან იკითხება: Auto Mode ხურავს ოპერატორის კარს, არა"
  echo "cluster-admin-ის კარს. ამაზე პასუხისმგებელია Pod Security Admission და"
  echo "admission პოლიტიკები (თავები 19 და 22)."
} >> /var/work/tests/artifacts/4/nossh.txt

kubectl delete pod hostprobe -n eks-125
cat /var/work/tests/artifacts/4/nossh.txt
```

Auto Mode ნოუდები არის Bottlerocket read-only root-ით და SELinux enforcing რეჟიმში,
shell-ისა და პაკეტების მენეჯერის გარეშე, ნოუდის მაქსიმალური სიცოცხლის ვადა 21 დღეა
ავტომატური ჩანაცვლებით (თავი 9). მისი debug-ი ჩვეული SSH და SSM საშუალებებით პრინციპში
შეუძლებელია - ეს მინიმალური ექსპლუატაციის ღირებულებაა.

## დავალება 5. საკუთარი NodePool ცხადი limits-ით

ჩაშენებულ pool-ებს `limits` არ აქვთ - მოთხოვნის უსაზღვრო ზრდისას ისინი ჭერის გარეშე
გაიზრდებოდნენ (თავი 9, ნაწილი 9.7). თქვენი საკუთარი NodePool ჩაშენებულ `NodeClass`
`default`-ს მიმართავს და ლიმიტებს თავად ადგენს:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: custom-limited
spec:
  template:
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default
      requirements:
        - key: "eks.amazonaws.com/instance-category"
          operator: In
          values: ["c", "m", "r"]
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
  limits:
    cpu: "10"
    memory: 10Gi
EOF

kubectl get nodepool custom-limited
```

საკუთარი NodePool-ები ჩაშენებული pool-ების შეზღუდვებს არ იმემკვიდრებენ (მხოლოდ C/M/R,
მხოლოდ on-demand, generation 5+) - მათ ხელით ადგენთ, `limits`-ის ჩათვლით, სხვაგვარად
pool ჭერის გარეშე გაიზრდება (თავი 9, ნაწილი 9.7).

## სწრაფი შემოწმება

```bash
check_result
```
