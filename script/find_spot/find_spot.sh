#!/usr/bin/env bash
set -euo pipefail

# -------- Config --------
REGION="${REGION:-eu-north-1}"      # Stockholm
OS_BUCKET="${OS_BUCKET:-linux}"     # linux | windows (Spot Advisor bucket)
MIN_MEM_MIB="${MIN_MEM_MIB:-4096}"  # Minimum memory in MiB (>= 4 GiB)
SIZE_RE='\.((medium)|(large)|(xlarge)|(2xlarge))$'
OUTPUT_LIMIT="${OUTPUT_LIMIT:-40}"  # Max number of instance types to output
PROFILE_OPT=${AWS_PROFILE:+--profile "$AWS_PROFILE"}

ADVISOR_URL="https://spot-bid-advisor.s3.amazonaws.com/spot-advisor-data.json"

# -------- Check dependencies --------
for bin in aws jq curl; do
  command -v "$bin" >/dev/null || { echo "❌ Missing dependency: $bin"; exit 1; }
done

# -------- Step 1: Get instance type offerings for the region --------
readarray -t OFFERINGS < <(aws ec2 describe-instance-type-offerings \
  --region "$REGION" \
  --location-type region \
  --filters Name=location,Values="$REGION" \
  --query 'InstanceTypeOfferings[].InstanceType' \
  --output text $PROFILE_OPT | tr '\t' '\n' | sort -u)

(( ${#OFFERINGS[@]} > 0 )) || { echo "❌ No instance type offerings found for $REGION"; exit 1; }

# -------- Step 2: Describe instance types in chunks (max 100 per request) --------
DESCRIBE_COMBINED='{"InstanceTypes":[]}'
CHUNK=100
for (( i=0; i<${#OFFERINGS[@]}; i+=CHUNK )); do
  PART=( "${OFFERINGS[@]:i:CHUNK}" )
  # shellcheck disable=SC2086
  DESCRIBE_JSON=$(aws ec2 describe-instance-types \
      --region "$REGION" \
      --instance-types ${PART[*]} \
      --output json $PROFILE_OPT)

  DESCRIBE_COMBINED=$(jq -s '{ "InstanceTypes": (.[0].InstanceTypes + .[1].InstanceTypes) }' \
    <(jq '.' <<<"$DESCRIBE_COMBINED") <(jq '.' <<<"$DESCRIBE_JSON"))
done

# -------- Step 3: Filter by criteria (x86_64, >= 4GiB RAM, <= 2xlarge, exclude metal) --------
CANDIDATES=$(jq -r --arg re "$SIZE_RE" --argjson min "$MIN_MEM_MIB" '
  .InstanceTypes[]
  | select(.ProcessorInfo.SupportedArchitectures[] | contains("x86_64"))
  | select(.MemoryInfo.SizeInMiB >= $min)
  | .InstanceType as $t
  | select(($t | test($re)) and ($t | contains(".metal") | not))
  | $t
' <<<"$DESCRIBE_COMBINED" | sort -u)

[[ -n "$CANDIDATES" ]] || { echo "❌ No matching x86_64 instance types (RAM≥4GiB, <=2xlarge) in $REGION"; exit 1; }

# -------- Step 4: Fetch Spot Advisor data and rank instances --------
ADVISOR=$(curl -fsSL "$ADVISOR_URL")

# Function to calculate ranking based on interruption rate and savings
rank_one() {
  local it="$1" fam size rate sav bucket sb
  fam="${it%%.*}"; size="${it##*.}"

  rate=$(jq -r --arg os "$OS_BUCKET" --arg reg "$REGION" --arg fam "$fam" --arg size "$size" \
         '.spot_advisor[$os][$reg][$fam][$size].r // empty' <<<"$ADVISOR")
  sav=$(jq -r  --arg os "$OS_BUCKET" --arg reg "$REGION" --arg fam "$fam" --arg size "$size" \
         '.spot_advisor[$os][$reg][$fam][$size].s // empty' <<<"$ADVISOR")

  # Lower interruption bucket = better
  case "$rate" in
    "<5%") bucket=1;;
    "5-10%") bucket=2;;
    "10-15%") bucket=3;;
    "15-20%") bucket=4;;
    ">20%") bucket=5;;
    *) bucket=9;;
  esac

  # Higher savings = better (we invert it later for sorting)
  case "$sav" in
    "70-90%") sb=5;;
    "60-70%") sb=4;;
    "50-60%") sb=3;;
    "40-50%") sb=2;;
    "30-40%") sb=1;;
    *) sb=0;;
  esac

  # Output format: bucket, (100 - sb), instanceType
  printf "%d\t%02d\t%s\n" "$bucket" $((100 - sb)) "$it"
}

# Rank and sort candidates by availability
SORTED=$(while read -r it; do rank_one "$it"; done <<<"$CANDIDATES" \
         | sort -n -k1,1 -k2,2 -k3,3 | awk -F'\t' '{print $3}')

# -------- Step 5: Limit output and print in JSON-like format --------
readarray -t FINAL < <(awk '!seen[$0]++' <<<"$SORTED" | head -n "$OUTPUT_LIMIT")

# Print exactly like: [ "a" , "b" , "c" ]
printf "[ "
for (( i=0; i<${#FINAL[@]}; i++ )); do
  (( i>0 )) && printf " , "
  printf "\"%s\"" "${FINAL[$i]}"
done
printf " ]\n"
