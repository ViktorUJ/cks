[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 103 - эталонное решение (адресный план: ENI, prefix delegation, secondary CIDR)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl уже настроен на
кластер (kubeconfig собран через `aws eks update-kubeconfig` при загрузке машины).

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
kubectl create namespace eks-103
```

## Задание 1. Расчёт max-pods по формуле и сверка с фактом

Создаём базовую нагрузку и ждём, пока Karpenter поднимет для неё EC2-ноду в обычном
(адресном) режиме VPC CNI - аддон пока не переключён на prefix delegation:

```bash
kubectl create deployment baseline --image=viktoruj/ping_pong:latest --replicas=2 -n eks-103
kubectl rollout status deployment/baseline -n eks-103

NODE=$(kubectl get po -n eks-103 -l app=baseline -o jsonpath='{.items[0].spec.nodeName}')
TYPE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
echo "node=$NODE type=$TYPE"
```

Получаем ENI, IP на ENI и vCPU для этого типа инстанса:

```bash
ENI=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.MaximumNetworkInterfaces' --output text)
IPS=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.Ipv4AddressesPerInterface' --output text)
VCPU=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].VCpuInfo.DefaultVCpus' --output text)
echo "eni=$ENI ips_per_eni=$IPS vcpu=$VCPU"
```

Считаем по формуле `max-pods = ENI * (IP на ENI - 1) + 2` и применяем кэп managed node
group (`110` при `vCPU < 30`, иначе `250`):

```bash
FORMULA=$((ENI * (IPS - 1) + 2))
if [ "$VCPU" -lt 30 ]; then CAP=110; else CAP=250; fi
if [ "$FORMULA" -lt "$CAP" ]; then EXPECTED=$FORMULA; else EXPECTED=$CAP; fi
echo "formula=$FORMULA cap=$CAP expected_max_pods=$EXPECTED"

ACTUAL=$(kubectl get node "$NODE" -o jsonpath='{.status.allocatable.pods}')
echo "actual_allocatable_pods=$ACTUAL"
```

Пример для `m5.large`: `ENI=3`, `IP на ENI=10` дают `formula = 3*(10-1)+2 = 29`, кэп `110`
не влияет (`29 < 110`), значит `expected_max_pods = 29` - и именно это должен показать
`kubectl get node`.

Сохраняем расчёт и факт в артефакт:

```bash
mkdir -p /var/work/tests/artifacts/1
cat > /var/work/tests/artifacts/1/maxpods.txt <<EOF
node=$NODE
instance_type=$TYPE
eni=$ENI
ips_per_eni=$IPS
vcpu=$VCPU
formula=$FORMULA
cap=$CAP
expected_max_pods=$EXPECTED
actual_allocatable_pods=$ACTUAL
EOF
cat /var/work/tests/artifacts/1/maxpods.txt
```

Если `expected_max_pods` и `actual_allocatable_pods` не совпали - kubelet узнаёт max-pods
только при старте ноды, сверка должна выполняться на ноде, которая уже полностью Ready.

## Задание 2. Prefix delegation: новая нода против старой

Фиксируем состояние старой ноды (адресный режим) до включения prefix delegation:

```bash
OLD_NODE="$NODE"
OLD_PODS=$(kubectl get node "$OLD_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "old_node=$OLD_NODE old_node_allocatable_pods=$OLD_PODS"
```

Включаем prefix delegation на managed addon `vpc-cni` (работает только на инстансах на
базе Nitro, поэтому важно, чтобы NodePool использовал такие типы):

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --configuration-values '{"env":{"ENABLE_PREFIX_DELEGATION":"true","WARM_PREFIX_TARGET":"1"}}' \
  --resolve-conflicts PRESERVE

aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --query 'addon.configurationValues'
```

Prefix delegation касается только новых нод: старая нода `baseline` уже получила свой
лимит `allocatable.pods` от kubelet при старте и не пересчитает его, пока не будет
пересоздана. Провоцируем создание новой ноды нагрузкой, которая не влезает в старую:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scale
  namespace: eks-103
spec:
  replicas: 6
  selector:
    matchLabels:
      app: scale
  template:
    metadata:
      labels:
        app: scale
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "1"
            memory: "128Mi"
EOF

kubectl rollout status deployment/scale -n eks-103
```

Определяем новую ноду и сравниваем лимиты:

```bash
NEW_NODE=$(kubectl get po -n eks-103 -l app=scale -o jsonpath='{.items[*].spec.nodeName}' \
  | tr ' ' '\n' | grep -v "^${OLD_NODE}$" | head -n1)
NEW_TYPE=$(kubectl get node "$NEW_NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
NEW_PODS=$(kubectl get node "$NEW_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "new_node=$NEW_NODE new_node_instance_type=$NEW_TYPE new_node_allocatable_pods=$NEW_PODS"
```

Пример для `m5.large` в режиме префиксов лимит подскакивает с `29` до `434` (до кэпа
managed node group `110`, поэтому фактический потолок - `110`, но это всё равно намного
больше `29` адресного режима).

Сохраняем сравнение и объяснение в артефакт:

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/prefixdelegation.txt <<EOF
old_node=$OLD_NODE
old_node_allocatable_pods=$OLD_PODS
new_node=$NEW_NODE
new_node_instance_type=$NEW_TYPE
new_node_allocatable_pods=$NEW_PODS

old_node_allocatable_pods не изменился, потому что kubelet считает max-pods один раз,
при старте ноды, и prefix delegation влияет только на новые ноды, а не на уже
запущенные. new_node уже создана после включения prefix delegation, поэтому её ENI
занимают префиксы /28 (по 16 адресов), а не одиночные IP, и лимит подов заметно выше.
EOF
cat /var/work/tests/artifacts/2/prefixdelegation.txt
```

## Задание 3. Планирование размера подсети под рост

Считаем итоговую потребность: `850` подов, запас `20%` на warm pool, затем ещё `15%` на
rolling update (запасы умножаются последовательно):

```bash
python3 - <<'EOF'
base = 850
after_warm = base * 1.20
after_roll = after_warm * 1.15
print(f"base={base} after_warm_pool={after_warm:.0f} after_rolling_update={after_roll:.0f}")
EOF
```

Итог: `850 * 1.20 = 1020`, `1020 * 1.15 = 1173` - итоговая потребность примерно `1173`
адреса. Сверяем с таблицей доступных адресов по префиксу подсети (AWS резервирует `5`
адресов на подсеть):

- `/24` - всего `256`, доступно `251` - меньше `1173`, не подходит;
- `/22` - всего `1024`, доступно `1019` - тоже меньше `1173`, не подходит;
- `/20` - всего `4096`, доступно `4091` - хватает с большим запасом.

`4091 / 1173 ≈ 3.5` раза запаса, что покрывает и текущий расчёт, и будущий рост, поэтому
выбираем `/20`.

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/cidrplan.txt <<'EOF'
Потребность: 850 подов * 1.20 (запас на warm pool) * 1.15 (запас на rolling update)
= 1173 адреса (итоговая потребность в адресах).

/24 (всего 256, доступно 251) - не подходит, доступно меньше потребности.
/22 (всего 1024, доступно 1019) - не подходит, доступно меньше потребности (1173).
/20 (всего 4096, доступно 4091) - подходит: 4091 / 1173 ~= 3.5 раза запаса.

Выбор: /20. Warm pool Karpenter и одновременный rolling update кратковременно держат
лишние адреса занятыми, поэтому подсеть должна быть заметно больше точечного пика,
а не впритык к 1173 адресам.
EOF
cat /var/work/tests/artifacts/3/cidrplan.txt
```

## Задание 4. Secondary CIDR: расширяем адресный план VPC

Узнаём `vpc-id` кластера и подключаем secondary CIDR из RFC 6598 shared address space
(`100.64.0.0/16` не пересекается с primary CIDR `10.10.0.0/16` этой VPC):

```bash
VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

aws ec2 associate-vpc-cidr-block --vpc-id "$VPC" --cidr-block 100.64.0.0/16
```

Ждём состояния `associated` (сразу после вызова блок может быть в `associating`):

```bash
until aws ec2 describe-vpcs --vpc-ids "$VPC" \
    --query "Vpcs[].CidrBlockAssociationSet[?CidrBlock=='100.64.0.0/16'].CidrBlockState.State" \
    --output text | grep -q associated; do
  echo "waiting for secondary CIDR to become associated..."
  sleep 5
done

aws ec2 describe-vpcs --vpc-ids "$VPC" \
  --query 'Vpcs[].CidrBlockAssociationSet[].{CIDR:CidrBlock,State:CidrBlockState.State}'
```

Создаём подсеть в новом блоке:

```bash
SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 100.64.1.0/24 \
  --availability-zone eu-central-1a --query 'Subnet.SubnetId' --output text)
echo "subnet=$SUBNET"
```

Сохраняем результат в артефакт:

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "secondary_cidr=100.64.0.0/16"
  aws ec2 describe-vpcs --vpc-ids "$VPC" \
    --query 'Vpcs[].CidrBlockAssociationSet[].{CIDR:CidrBlock,State:CidrBlockState.State}' \
    --output table
  echo "subnet_id=$SUBNET"
} > /var/work/tests/artifacts/4/secondary_cidr.txt
cat /var/work/tests/artifacts/4/secondary_cidr.txt
```

Если бы вместо `100.64.0.0/16` мы попробовали `172.16.0.0/12` или `192.168.0.0/16` -
AWS не даст добавить их к VPC, у которой primary CIDR уже в диапазоне `10.0.0.0/8`
(пересечение приватных диапазонов RFC 1918), поэтому обычно берут именно RFC 6598.

## Задание 5. Диагностика нехватки адресов (без реального отказа)

Инфраструктуру лабы не трогаем: подсети не урезаем и адреса искусственно не исчерпываем.
Смотрим текущее состояние подсетей кластера - это те же команды, которыми диагностируют
нехватку адресов на живом кластере:

```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' \
  --output table
```

Сохраняем объяснение диагностики нехватки адресов в артефакт:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnostics.txt <<'EOF'
Как диагностировать нехватку IP-адресов на живом кластере:

1. Симптом на поде: kubectl describe pod покажет в Events событие
   FailedCreatePodSandBox от aws-cni - это первый сигнал, что VPC CNI не смог
   выделить адрес.

2. Общая нехватка адресов в подсети: aws ec2 describe-subnets --query
   'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' -
   если AvailableIpAddressCount своей AZ равен 0, это прямой диагноз исчерпания
   адресов в этой подсети и AZ.

3. Фрагментация вместо реальной нехватки: если включён prefix delegation, а
   непрерывного блока /28 в подсети нет (адреса раздроблены отдельными занятыми
   IP), в логах ipamd/aws-node будет ошибка InsufficientCidrBlocks, даже когда
   AvailableIpAddressCount подсети выглядит большим. Это разные причины одного
   и того же внешнего симптома (под не может получить адрес), и лечатся они
   по-разному: нехватка адресов - расширением CIDR или secondary CIDR (задание 4),
   фрагментация - освобождением места под непрерывный блок или новой подсетью.
EOF
cat /var/work/tests/artifacts/5/diagnostics.txt
```

## Быстрая проверка

```bash
check_result
```
