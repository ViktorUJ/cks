#!/usr/bin/env bats

# https://github.com/sobolevn/git-secret/tree/master/tests
@test "1 gvisor" {
  echo '10'>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  result="$(echo 2+2 | bc)"
  if [[ "$result" == "4" ]]; then
   echo '10'>>/var/work/tests/result/ok
  fi
  [ "$result" -eq 4 ]


}


@test "2  api logs " {
  echo '17'>>/var/work/tests/result/all
  result="$(echo 2+2 | bc)"
  if [[ "$result" == "5" ]]; then
   echo '17'>>/var/work/tests/result/ok
  fi
  [ "$result" -eq 5 ];
   echo "ok"

}
