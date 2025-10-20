#!/usr/bin/env bash
set -euo pipefail
# example usage:
# ./find_spot.sh
# ./find_spot.sh -i 5 -n 70

# -------- Default config --------
REGION="${REGION:-eu-north-1}"                 # EC2 region (Stockholm)
PRICING_REGION="${PRICING_REGION:-us-east-1}"  # Region for pricing API
PRICING_LOCATION="${PRICING_LOCATION:-EU (Stockholm)}"
OS_BUCKET="${OS_BUCKET:-linux}"                # linux | windows
MIN_MEM_MIB="${MIN_MEM_MIB:-4096}"             # ≥ 4 GiB
SIZE_RE='\.((medium)|(large)|(xlarge)|(2xlarge))$'  # instance sizes up to 2xlarge
OUTPUT_LIMIT_DEFAULT=50                        # default max count
INTERRUPT_THRESHOLD_DEFAULT=20                 # default threshold (%)
PROFILE_OPT=${AWS_PROFILE:+--profile "$AWS_PROFILE"}

ADVISOR_URL="https://spot-bid-advisor.s3.amazonaws.com/spot-advisor-data.json"
EXCLUDE_FAMILY_RE='^(g|p|inf|trn|f1|dl|vt)'    # skip expensive families (GPU, etc.)

# -------- CLI arguments --------
OUTPUT_LIMIT="$OUTPUT_LIMIT_DEFAULT"
INTERRUPT_THRESHOLD="$INTERRUPT_THRESHOLD_DEFAULT"

usage() {
  cat <<'EOF'
Usage: find_spot.sh [options]

Options:
  -i, --interrupt-threshold <PCT>   Max Spot interruption bucket (%). Allowed: 5,10,15,20.
                                    Includes all lower buckets. Default: 20
  -n, --limit <NUM>                 Max number of instance types to output (default: 50)
  -h, --help                        Show this help message

Example:
  ./find_spot.sh -i 10 -n 40
EOF
}

# Simple parser
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--interrupt-threshold)
      [[ $# -ge 2 ]] || { echo "Missing value for $1"; usage; exit 1; }
      [[ "$2" =~ ^[0-9]+$ ]] || { echo "Threshold must be integer"; exit 1; }
      INTERRUPT_THRESHOLD="$2"
      shift 2
      ;;
    -n|--limit)
      [[ $# -ge 2 ]] || { echo "Missing value for $1"; usage; exit 1; }
      [[ "$2" =~ ^[0-9]+$ ]] || { echo "Limit must be integer"; exit 1; }
      OUTPUT_LIMIT="$2"
      shift 2
      ;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1"; usage; exit 1;;
  esac
done

# -------- Dependencies check --------
for bin in aws jq curl; do
  command -v "$bin" >/dev/null || { echo "❌ Missing dependency: $bin"; exit 1; }
done

# -------- Step 1: Get region offerings --------
readarray -t OFFERINGS < <(aws ec2 describe-instance-type-offerings \
  --region "$REGION" \
  --location-type region \
  --filters Name=location,Values="$REGION" \
  --query 'InstanceTypeOfferings[].InstanceType' \
  --output text $PROFILE_OPT | tr '\t' '\n' | sort -u)

(( ${#OFFERINGS[@]} > 0 )) || { echo "❌ No instance type offerings in $REGION"; exit 1; }

# -------- Step 2: Describe in chunks (≤100) --------
DESCRIBE_COMBINED='{"InstanceTypes":[]}'
CHUNK=100
for (( i=0; i<${#OFFERINGS[@]}; i+=CHUNK )); do
  PART=( "${OFFERINGS[@]:i:CHUNK}" )
  DESCRIBE_JSON=$(aws ec2 describe-instance-types \
      --region "$REGION" \
      --instance-types ${PART[*]} \
      --output json $PROFILE_OPT)
  DESCRIBE_COMBINED=$(jq -s '{ "InstanceTypes": (.[0].InstanceTypes + .[1].InstanceTypes) }' \
    <(jq '.' <<<"$DESCRIBE_COMBINED") <(jq '.' <<<"$DESCRIBE_JSON"))
done

# -------- Step 3: Filter by criteria --------
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

[[ -n "$CANDIDATES" ]] || { echo "❌ No matching x86 instance types"; exit 1; }

# -------- Step 4: Fetch Spot Advisor --------
ADVISOR=$(curl -fsSL "$ADVISOR_URL")

spot_bucket_to_rank() {
  case "$1" in
    "<5%") echo 1;;
    "5-10%") echo 2;;
    "10-15%") echo 3;;
    "15-20%") echo 4;;
    ">20%") echo 5;;
    *) echo 9;;
  esac
}

# Allow all ranks <= user threshold
threshold_to_rank() {
  local pct="$1"
  if   (( pct <= 5  )); then echo 1
  elif (( pct <= 10 )); then echo 2
  elif (( pct <= 15 )); then echo 3
  elif (( pct <= 20 )); then echo 4
  else echo 4; fi
}
threshold_rank_max=$(threshold_to_rank "$INTERRUPT_THRESHOLD")

# -------- Step 5: Get On-Demand price for ranking --------
get_price() {
  local itype="$1"
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
    echo "nan"; return
  fi
  price=$(jq -r '
    .terms.OnDemand | to_entries[0].value.priceDimensions
    | to_entries[0].value.pricePerUnit.USD // empty
  ' <<<"$prod_json")
  [[ -n "$price" ]] && printf "%s" "$price" || printf "nan"
}

declare -A PRICE_CACHE
price_of() {
  local it="$1"
  if [[ -n "${PRICE_CACHE[$it]:-}" ]]; then
    printf "%s" "${PRICE_CACHE[$it]}"; return
  fi
  local p; p=$(get_price "$it"); PRICE_CACHE[$it]="$p"; printf "%s" "$p"
}

# -------- Step 6: Rank and filter --------
rank_one() {
  local it="$1" fam size rate rank price
  fam="${it%%.*}"
  size="${it##*.}"

  rate=$(jq -r --arg os "$OS_BUCKET" --arg reg "$REGION" --arg fam "$fam" --arg size "$size" \
         '.spot_advisor[$os][$reg][$fam][$size].r // empty' <<<"$ADVISOR")
  rank=$(spot_bucket_to_rank "$rate")
  (( rank > threshold_rank_max )) && return

  price=$(price_of "$it")
  if [[ "$price" == "nan" ]]; then
    printf "%d\t%012.6f\t%s\n" "$rank" "9999999.000000" "$it"
  else
    printf "%d\t%012.6f\t%s\n" "$rank" "$price" "$it"
  fi
}

SORTED=$(
  while read -r it; do rank_one "$it"; done <<<"$CANDIDATES" \
  | sort -n -k1,1 -k2,2 -k3,3 \
  | awk -F'\t' '{print $3}'
)

# -------- Step 7: Output --------
readarray -t FINAL < <(awk '!seen[$0]++' <<<"$SORTED" | head -n "$OUTPUT_LIMIT")

printf "[ "
for (( i=0; i<${#FINAL[@]}; i++ )); do
  (( i>0 )) && printf " , "
  printf "\"%s\"" "${FINAL[$i]}"
done
printf " ]\n"
