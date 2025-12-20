#!/usr/bin/env bats
# ICA Mock Exam - Task 18: Configure Header-Based Routing
# Validates VirtualService with header matching for commander: shepard

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="magenta"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  [ "$?" -eq 0 ]
}

# Task 18: Configure Header-Based Routing (3 points)

@test "18.1 Gateway exists for ship.milkyway.gal" {
  echo '0.5' >> /var/work/tests/result/all
  gw_hosts=$(kubectl get gateway -n istio-system --context $CONTEXT -o jsonpath='{.items[*].spec.servers[*].hosts[*]}')
  if echo "$gw_hosts" | grep -q "ship.milkyway.gal"; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  echo "$gw_hosts" | grep -q "ship.milkyway.gal"
}

@test "18.2 VirtualService exists in magenta namespace" {
  echo '0.25' >> /var/work/tests/result/all
  kubectl get virtualservice -n $NAMESPACE --context $CONTEXT | grep -q "magenta"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "18.3 VirtualService has header match for commander: shepard" {
  echo '0.75' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  header_match=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o json | jq -r '.spec.http[0].match[0].headers.commander.exact')
  if [[ "$header_match" == "shepard" ]]; then
    echo '0.75' >> /var/work/tests/result/ok
  fi
  [ "$header_match" == "shepard" ]
}

@test "18.4 DestinationRule has v1 and v2 subsets" {
  echo '0.25' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  subsets=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.subsets[*].name}')
  if echo "$subsets" | grep -q "v1" && echo "$subsets" | grep -q "v2"; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  echo "$subsets" | grep -q "v1" && echo "$subsets" | grep -q "v2"
}

@test "18.5 Header match routes to v1 subset" {
  echo '0.5' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  v1_subset=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o json | jq -r '.spec.http[0].route[0].destination.subset')
  if [[ "$v1_subset" == "v1" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$v1_subset" == "v1" ]
}

@test "18.6 Default route (no match) routes to v2 subset" {
  echo '0.25' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  v2_subset=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o json | jq -r '.spec.http[1].route[0].destination.subset')
  if [[ "$v2_subset" == "v2" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$v2_subset" == "v2" ]
}

@test "18.7 Request with commander: shepard header goes to v1" {
  echo '0.25' >> /var/work/tests/result/all

  # Get NodePort
  NODE_PORT=$(kubectl get svc istio-demo-ingress -n istio-system --context $CONTEXT -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
  NODE_IP=$(kubectl get nodes --context $CONTEXT -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

  # Test with header (should get v1 response: "welcome aboard capitan")
  response=$(curl -s -H "Host: ship.milkyway.gal" -H "commander: shepard" --max-time 10 http://$NODE_IP:$NODE_PORT/normandy)

  if echo "$response" | grep -q "welcome aboard capitan"; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  echo "$response" | grep -q "welcome aboard capitan"
}

@test "18.8 Request without header goes to v2" {
  echo '0.25' >> /var/work/tests/result/all

  # Get NodePort
  NODE_PORT=$(kubectl get svc istio-demo-ingress -n istio-system --context $CONTEXT -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
  NODE_IP=$(kubectl get nodes --context $CONTEXT -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

  # Test without header (should get v2 response: "Normandy SR2")
  response=$(curl -s -H "Host: ship.milkyway.gal" --max-time 10 http://$NODE_IP:$NODE_PORT/normandy)

  if echo "$response" | grep -q "Normandy SR2"; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  echo "$response" | grep -q "Normandy SR2"
}

# Total: 3 points for Task 18
