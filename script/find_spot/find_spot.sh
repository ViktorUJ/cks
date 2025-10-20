#!/usr/bin/env bash
set -euo pipefail

# -------- Config --------
REGION="${REGION:-eu-north-1}"           # EC2 region for offerings/describe
PRICING_REGION="${PRICING_REGION:-us-east-1}"  # Pricing API endpoint region
PRICING_LOCATION="${PRICING_LOCATION:-EU (Stockholm)}"  # Pricing "location" label
OS_BUCKET="${OS_BUCKET:-linux}"          # linux | windows for Spot Advisor buckets
MIN_MEM_MIB="${MIN_MEM_MIB:-4096}"       # >= 4 GiB
SIZE_RE='\.((medium)|(large)|(xlarge)|(2xlarge))$'  # up to 2xlarge
OUTPUT_LIMIT="${OUTPUT_LIMIT:-40}"       # number of types to output
PROFILE_OPT=${AWS_PROFILE:+--profile "$AWS_PROFILE"}

ADVISOR_URL="https://spot-bid-advisor.s3.amazonaws.com/spot-advisor-data.json"

# Families to exclude as "expensive" (GPU/FPGA/Inference/Trainium/Video etc.)
EXCLUDE_FAMILY_RE='^(g|p|inf|trn|f1|dl|vt)'

# -------- Dependencies --------
for bin in aws jq curl; do
  command -v "$bin" >/dev/null || { echo "❌ Missing dependency: $bin"; exit 1; }
done

# -------- Step 1: Region offerings (only types that actually exist in region) --------
readarray -t OFFERINGS < <(aws ec2 describe-instance-type-offerings \
  --region "$REGION" \
  --location-type region \
  --filters Name=location,Values="$REGION" \
  --query 'InstanceTypeOfferings[].InstanceType' \
  --output text $PROFILE_OPT | tr '\t' '\n' | sort -u)

(( ${#OFFERINGS[@]} > 0 )) || { echo "❌ No instance type offerings found for $REGION"; exit 1; }

# -------- Step 2: Describe types in chunks (≤100 per call) --------
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

# -------- Step 3: Filter by x86_64, mem ≥ 4GiB, size ≤ 2xlarge, exclude metal and expensive families --------
CANDIDATES=$(jq -r --arg re "$SIZE_RE" --argjson min "$MIN_MEM_MIB" '
  .InstanceTypes[]
  | select(.ProcessorInfo.SupportedArchitectures[] | contains("x86_64"))
  | select(.MemoryInfo.SizeInMiB >= $min)
  | .InstanceType as $t
  | select(($t | test($re)) and ($t | contains(".metal") | not))
  | $t
' <<<"$DESCRIBE_COMBINED" \
| awk -v RS='\n' -v ORS='\n' -v excl="$EXCLUDE_FAMILY_RE" '
    {
      fam=$0; sub(/\..*$/,"",fam);
      if ($0 !~ /\.metal$/ && fam !~ excl) print $0
    }
' | sort -u)

[[ -n "$CANDIDATES" ]] || { echo "❌ No matching x86 instance types after filters"; exit 1; }

# -------- Step 4: Fetch Spot Advisor (interruption/savings per family+size) --------
ADVISOR=$(curl -fsSL "$ADVISOR_URL")

# Map Spot interruption bucket to numeric (lower is better)
spot_bucket() {
  case "$1" in
    "<5%") echo 1;;
    "5-10%") echo 2;;
    "10-15%") echo 3;;
    "15-20%") echo 4;;
    ">20%") echo 5;;
    *) echo 9;;
  esac
}

# -------- Step 5: Pricing: fetch On-Demand Linux shared tenancy price per instance type --------
# Uses AWS Pricing API get-products. Returns hourly USD price as float.
get_price() {
  local itype="$1"

  # Query pricing for On-Demand, Linux, shared tenancy, no preinstalled SW, in EU (Stockholm)
  local prod_json price
  prod_json=$(aws pricing get-products \
    --region "$PRICING_REGION" \
    --service-code AmazonEC2 \
    --filters \
      Type=TERM_MATCH,Field=instanceType,Value="$itype" \
      Type=TERM_MATCH,Field=location,Value="$PRICING_LOCATION" \
      Type=TERM_MATCH,Field=operatingSystem,Value=Linux \
      Type=TERM_MATCH,Field=preInstalledSw,Value=NA \
      Type=TERM_MATCH,Field=capacitystatus,Value=Used \
      Type=TERM_MATCH,Field=tenancy,Value=Shared \
    --query 'PriceList[0]' \
    --output text 2>/dev/null || true)

  if [[ -z "$prod_json" || "$prod_json" == "None" ]]; then
    echo "nan"
    return
  fi

  # Extract first pricePerUnit USD from the OnDemand price dimensions
  price=$(jq -r '
    .terms.OnDemand | to_entries[0].value.priceDimensions
    | to_entries[0].value.pricePerUnit.USD // empty
  ' <<<"$prod_json")

  [[ -n "$price" ]] && printf "%s" "$price" || printf "nan"
}

# Cache prices locally to reduce API calls
declare -A PRICE_CACHE

price_of() {
  local it="$1"
  if [[ -n "${PRICE_CACHE[$it]:-}" ]]; then
    printf "%s" "${PRICE_CACHE[$it]}"
    return
  fi
  local p
  p=$(get_price "$it")
  PRICE_CACHE[$it]="$p"
  printf "%s" "$p"
}

# -------- Step 6: Rank: by lowest interruption bucket, then lowest on-demand price --------
rank_one() {
  local it="$1" fam size rate bucket price
  fam="${it%%.*}"
  size="${it##*.}"

  rate=$(jq -r --arg os "$OS_BUCKET" --arg reg "$REGION" --arg fam "$fam" --arg size "$size" \
         '.spot_advisor[$os][$reg][$fam][$size].r // empty' <<<"$ADVISOR")
  bucket=$(spot_bucket "$rate")
  price=$(price_of "$it")

  # Output sortable keys: bucket (asc), price (asc numeric, "nan" sorted last), instanceType
  # We map "nan" to a very large number for sorting.
  if [[ "$price" == "nan" ]]; then
    printf "%d\t%012.6f\t%s\n" "$bucket" "9999999.000000" "$it"
  else
    printf "%d\t%012.6f\t%s\n" "$bucket" "$price" "$it"
  fi
}

SORTED=$(
  while read -r it; do
    rank_one "$it"
  done <<<"$CANDIDATES" \
  | sort -n -k1,1 -k2,2 -k3,3 \
  | awk -F'\t' '{print $3}'
)

# -------- Step 7: Output top N in the requested array format --------
readarray -t FINAL < <(awk '!seen[$0]++' <<<"$SORTED" | head -n "$OUTPUT_LIMIT")

printf "[ "
for (( i=0; i<${#FINAL[@]}; i++ )); do
  (( i>0 )) && printf " , "
  printf "\"%s\"" "${FINAL[$i]}"
done
printf " ]\n"
