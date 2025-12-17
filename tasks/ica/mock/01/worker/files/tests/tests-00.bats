#!/usr/bin/env bats

@test "0 Init" {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]
}
