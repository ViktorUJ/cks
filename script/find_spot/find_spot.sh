#!/usr/bin/env bash
set -euo pipefail

REGION="eu-north-1"      # Stockholm
OS_BUCKET="linux"        # linux | windows
MIN_MEM_MIB=4096         # ≥ 4 GiB
MAX_SIZE_REGEX='\.(medium|large|xlarge|2xlarge)$'
OUTPUT_LIMIT=40

# Получаем JSON Spot Advisor (тот же источник, что и веб)
ADVISOR_URL="https://spot-bid-advisor.s3.amazonaws.com/spot-advisor-data.json"

# Проверка зависимостей
for bin in aws jq curl; do
  command -v $bin >/dev/null || { echo "❌ Требуется $bin"; exit 1; }
done

# Получаем все доступные типы в регионе
OFFERINGS=$(aws ec2 describe-instance-type-offerings \
  --region "$REGION" \
  --location-type region \
  --filters Name=location,Values="$REGION" \
  --query 'InstanceTypeOfferings[].InstanceType' \
  --output text)

# Получаем детали по типам
DESCRIBE=$(aws ec2 describe-instance-types \
  --region "$REGION" \
  --instance-types $OFFERINGS \
  --output json)

# Фильтруем x86, ≥4 ГБ, не больше 2xlarge
CANDIDATES=$(echo "$DESCRIBE" | jq -r --arg re "$MAX_SIZE_REGEX" --argjson min "$MIN_MEM_MIB" '
  .InstanceTypes[]
  | select(.ProcessorInfo.SupportedArchitectures[] | contains("x86_64"))
  | select(.MemoryInfo.SizeInMiB >= $min)
  | .InstanceType as $t
  | select(($t | test($re)) and ($t | contains(".metal") | not))
  | $t
' | sort -u)

# Подгружаем данные Spot Advisor
ADVISOR=$(curl -s "$ADVISOR_URL")

# Функция: вычисляет рейтинг по прерываниям и экономии
rank() {
  local it="$1"
  local fam="${it%%.*}"
  local size="${it##*.}"

  local rate=$(echo "$ADVISOR" | jq -r --arg os "$OS_BUCKET" --arg reg "$REGION" --arg fam "$fam" --arg size "$size" '.spot_advisor[$os][$reg][$fam][$size].r // empty')
  local sav=$(echo "$ADVISOR" | jq -r --arg os "$OS_BUCKET" --arg reg "$REGION" --arg fam "$fam" --arg size "$size" '.spot_advisor[$os][$reg][$fam][$size].s // empty')

  # Чем меньше % прерываний, тем лучше
  local bucket=9
  case "$rate" in
    "<5%") bucket=1;; "5-10%") bucket=2;; "10-15%") bucket=3;; "15-20%") bucket=4;; ">20%") bucket=5;; *) bucket=9;;
  esac

  local sb=0
  case "$sav" in
    "70-90%") sb=5;; "60-70%") sb=4;; "50-60%") sb=3;; "40-50%") sb=2;; "30-40%") sb=1;;
  esac

  printf "%d\t%02d\t%s\n" "$bucket" $((100 - sb)) "$it"
}

# Сортируем по доступности
SORTED=$(while read -r it; do rank "$it"; done <<<"$CANDIDATES" | sort -n -k1,1 -k2,2 | awk -F'\t' '{print $3}' | head -n "$OUTPUT_LIMIT")

# Форматируем вывод в требуемом виде
echo "[ $(echo "$SORTED" | awk '{printf "\"%s\" , ", $1}' | sed 's/ , $//') ]"
