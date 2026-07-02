#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

SHOP="http://shop.local:32080"
API="http://api.local:32080"

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 all backend pods have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n app --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n app -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -ge 5 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "app pods total=$total, injected=$injected (expected >=5 and equal)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 Gateway serves both shop.local and api.local" {
  echo '1' >> /var/work/tests/result/all

  hosts=$(kubectl get gateway -n app -o json | jq -r '[.items[].spec.servers[]?.hosts[]?] | join(",")')
  if echo "$hosts" | grep -q 'shop.local' && echo "$hosts" | grep -q 'api.local'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Gateway hosts are '$hosts' (expected shop.local and api.local)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 shop.local/catalog routes to the catalog service" {
  echo '1' >> /var/work/tests/result/all

  body=""
  for i in $(seq 12); do
    body=$(curl -s --max-time 8 "$SHOP/catalog" 2>/dev/null || true)
    echo "$body" | grep -q 'catalog' && break
    sleep 5
  done

  if echo "$body" | grep -q 'catalog'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "shop.local/catalog did not reach catalog (body='$body')"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 shop.local/cart routes to the cart service" {
  echo '1' >> /var/work/tests/result/all

  body=$(curl -s --max-time 8 "$SHOP/cart" 2>/dev/null || true)
  if echo "$body" | grep -q 'cart'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "shop.local/cart did not reach cart (body='$body')"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.3 shop.local/ routes to the frontend service" {
  echo '1' >> /var/work/tests/result/all

  body=$(curl -s --max-time 8 "$SHOP/" 2>/dev/null || true)
  if echo "$body" | grep -q 'frontend'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "shop.local/ did not reach frontend (body='$body')"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.4 api.local without header routes to api-v1" {
  echo '1' >> /var/work/tests/result/all

  body=$(curl -s --max-time 8 "$API/" 2>/dev/null || true)
  if echo "$body" | grep -q 'api-v1'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "api.local (no header) did not reach api-v1 (body='$body')"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.5 api.local with x-api-version:v2 routes to api-v2" {
  echo '1' >> /var/work/tests/result/all

  body=$(curl -s --max-time 8 -H "x-api-version: v2" "$API/" 2>/dev/null || true)
  if echo "$body" | grep -q 'api-v2'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "api.local (x-api-version:v2) did not reach api-v2 (body='$body')"
    result=1
  fi

  [ "$result" == "0" ]
}
