#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-117"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Artifact 1/natdiscovery.txt reports two NAT Gateways and the AZ without one" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  vpc=$(aws eks describe-cluster --name "$cluster" \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
  real_count=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc" \
    --query 'length(NatGateways[?State==`available`])' --output text 2>/dev/null || true)
  f=/var/work/tests/artifacts/1/natdiscovery.txt
  nat_count=$(grep '^nat_count=' "$f" 2>/dev/null | cut -d= -f2)
  no_nat_az=$(grep '^no_nat_az=' "$f" 2>/dev/null | cut -d= -f2)
  azs=$(grep -E '^nat_[0-9]+_az=' "$f" 2>/dev/null | cut -d= -f2 | sort -u)
  has_a=$(echo "$azs" | grep -c '^eu-central-1a$')
  has_b=$(echo "$azs" | grep -c '^eu-central-1b$')
  if [[ -s "$f" ]] && [[ "$nat_count" == "$real_count" ]] && [[ "$nat_count" == "2" ]] \
     && [[ "$no_nat_az" == "eu-central-1c" ]] && [[ "$has_a" -eq 1 ]] && [[ "$has_b" -eq 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "vpc=$vpc real_count=$real_count nat_count=$nat_count no_nat_az=$no_nat_az azs=$azs"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "2. Cross-AZ trap: subnet-3 routes to a neighbor NAT and crossaz pod egresses" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/2/crossaz.txt
  rtb=$(grep '^subnet_c_route_table_id=' "$f" 2>/dev/null | cut -d= -f2)
  nat_used=$(grep '^nat_gateway_id_used=' "$f" 2>/dev/null | cut -d= -f2)
  nat_az_used=$(grep '^nat_gateway_az_used=' "$f" 2>/dev/null | cut -d= -f2)
  http_code=$(grep '^egress_http_code=' "$f" 2>/dev/null | cut -d= -f2)
  route_ok=0
  if [[ -n "$rtb" ]] && [[ -n "$nat_used" ]]; then
    real_nat=$(aws ec2 describe-route-tables --route-table-ids "$rtb" \
      --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId" \
      --output text 2>/dev/null || true)
    [[ "$real_nat" == "$nat_used" ]] && route_ok=1
  fi
  ready=$(kubectl get deploy crossaz -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
  node=$(kubectl get po -n "$NS" -l app=crossaz -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || true)
  node_zone=$(kubectl get node "$node" \
    -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}' 2>/dev/null || true)
  if [[ "$route_ok" -eq 1 ]] && [[ "$nat_az_used" != "eu-central-1c" ]] \
     && [[ "$ready" == "1" ]] && [[ "$node_zone" == "eu-central-1c" ]] \
     && [[ "$http_code" == "200" ]] && [[ -s "$f" ]] && grep -qi 'cross-AZ' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "rtb=$rtb nat_used=$nat_used route_ok=$route_ok nat_az_used=$nat_az_used ready=$ready node_zone=$node_zone http_code=$http_code"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Gateway VPC endpoint for S3 is available on all three private route tables" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  vpc=$(aws eks describe-cluster --name "$cluster" \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
  state=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpc" \
    "Name=service-name,Values=com.amazonaws.eu-central-1.s3" \
    "Name=vpc-endpoint-type,Values=Gateway" \
    --query 'VpcEndpoints[0].State' --output text 2>/dev/null)
  rtb_count=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpc" \
    "Name=service-name,Values=com.amazonaws.eu-central-1.s3" \
    "Name=vpc-endpoint-type,Values=Gateway" \
    --query 'length(VpcEndpoints[0].RouteTableIds)' --output text 2>/dev/null || true)
  [[ "$rtb_count" =~ ^[0-9]+$ ]] || rtb_count=0
  f=/var/work/tests/artifacts/3/s3endpoint.txt
  if [[ "$state" == "available" ]] && [[ "$rtb_count" -ge 3 ]] && [[ -s "$f" ]] \
     && grep -qi 'available' "$f" && grep -qi 'бесплат' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "vpc=$vpc state=$state rtb_count=$rtb_count file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Interface VPC endpoint for ecr.api or sts is available with private DNS" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  vpc=$(aws eks describe-cluster --name "$cluster" \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
  ecr_state=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpc" \
    "Name=service-name,Values=com.amazonaws.eu-central-1.ecr.api" \
    --query 'VpcEndpoints[0].State' --output text 2>/dev/null)
  sts_state=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpc" \
    "Name=service-name,Values=com.amazonaws.eu-central-1.sts" \
    --query 'VpcEndpoints[0].State' --output text 2>/dev/null)
  ecr_dns=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpc" \
    "Name=service-name,Values=com.amazonaws.eu-central-1.ecr.api" \
    --query 'VpcEndpoints[0].PrivateDnsEnabled' --output text 2>/dev/null)
  sts_dns=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpc" \
    "Name=service-name,Values=com.amazonaws.eu-central-1.sts" \
    --query 'VpcEndpoints[0].PrivateDnsEnabled' --output text 2>/dev/null)
  f=/var/work/tests/artifacts/4/interfaceendpoint.txt
  ok=0
  if [[ "$ecr_state" == "available" ]] && [[ "$ecr_dns" == "True" ]]; then
    ok=1
  elif [[ "$sts_state" == "available" ]] && [[ "$sts_dns" == "True" ]]; then
    ok=1
  fi
  if [[ "$ok" -eq 1 ]] && [[ -s "$f" ]] && grep -qi 'available' "$f" \
     && grep -qE 'ecr\.api|sts' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "vpc=$vpc ecr_state=$ecr_state ecr_dns=$ecr_dns sts_state=$sts_state sts_dns=$sts_dns"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Artifact 5/natmetrics.txt sums BytesOutToDestination for both NAT Gateways" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/natmetrics.txt
  nat_a=$(grep '^nat_a_bytes_out_sum=' "$f" 2>/dev/null | cut -d= -f2)
  nat_b=$(grep '^nat_b_bytes_out_sum=' "$f" 2>/dev/null | cut -d= -f2)
  total=$(grep '^total_bytes_out_sum=' "$f" 2>/dev/null | cut -d= -f2)
  expected_total=$(python3 -c "print(int(${nat_a:-0}) + int(${nat_b:-0}))" 2>/dev/null)
  crossaz_f=/var/work/tests/artifacts/2/crossaz.txt
  nat_used=$(grep '^nat_gateway_id_used=' "$crossaz_f" 2>/dev/null | cut -d= -f2)
  if [[ -s "$f" ]] && [[ -n "$nat_a" ]] && [[ -n "$nat_b" ]] && [[ -n "$total" ]] \
     && [[ "$total" == "$expected_total" ]] && grep -q 'BytesOutToDestination' "$f" \
     && [[ -n "$nat_used" ]] && grep -q "$nat_used" "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "nat_a=$nat_a nat_b=$nat_b total=$total expected_total=$expected_total nat_used=$nat_used"
    result=1
  fi
  [ "$result" == "0" ]
}
