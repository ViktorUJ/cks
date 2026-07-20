#!/usr/bin/env bats
# Проверка кластера выполняется на первой control plane ноде (cp1, node-1). Здесь — заглушка.

@test "0 Init" {
  mkdir -p /var/work/tests/result
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  [ "$?" -eq 0 ]
}

@test "1. Проверка HA-кластера выполняется на ноде cp1 (node-1)" {
  echo '1' >> /var/work/tests/result/all
  echo '1' >> /var/work/tests/result/ok
  [ "$?" -eq 0 ]
}
