#!/usr/bin/env bash
set -euo pipefail

# -------- Default config --------
REGION="${REGION:-eu-north-1}"
PRICING_REGION="${PRICING_REGION:-us-east-1}"
PRICING_LOCATION="${PRICING_LOCATION:-EU (Stockholm)}"
OS_BUCKET="${OS_BUCKET:-linux}"
MIN_MEM_MIB="${MIN_MEM_MIB:-4096}"
SIZE_RE='\.((medium)|(large)|(xlarge)|(2xlarge))$'
OUTPUT_LIMIT_DEFAULT=50
INTERRUPT_THRESHOLD_DEFAULT=20
PROFILE_OPT=${AWS_PROFILE:+--profile "$AWS_PROFILE"}
ADVISOR_URL="https://spot-bid-advisor.s3.amazonaws.com/spot-advisor-data.json"
EXCLUDE_FAMILY_RE='^(g|p|inf|trn|f1|dl|vt)'

# Pricing controls
PRICE_PARALLEL_DEFAULT=6     # concurrent pricing calls
PRICE_TIMEOUT_DEFAULT=20     # seconds per call
PRICE_RETRIES_DEFAULT=3
PRICE_MAX_DEFAULT=120        # limit how many types we query price for
USE_PRICE_DEFAULT=1          # 1=use price, 0=rank by interruptions only

# -------- CLI args --------
OUTPUT_LIMIT="$OUTPUT_LIMIT_DEFAULT"
INTERRUPT_THRESHOLD="$INTERRUPT_THRESHOLD_DEFAULT"
PRICE_PARALLEL="$PRICE_PARALLEL_DEFAULT"
PRICE_TIMEOUT="$PRICE_TIMEOUT_DEFAULT"
PRICE_RETRIES="$PRICE_RETRIES_DEFAULT"
PRICE_MAX="$PRICE_MAX_DEFAULT"
USE_PRICE="$USE_PRICE_DEFAULT"

usage() {
  cat <<'EOF'
Usage: find_spot.sh [options]

Filters:
  -i, --interrupt-threshold <PCT>   Max Spot interruption bucket (%). Includes all lower buckets.
                                    Example: -i 10 -> allow "<5%" and "5-10%". Default: 20
  -n, --limit <NUM>                 Max number of instance types in output. Default: 50

Pricing:
  --no-price                        Do not query On-Demand prices (rank by interruptions only)
  --price-parallel <N>              Parallel Pricing API calls. Default: 6
  --price-timeout  <SEC>            Timeout per Pricing API call. Default: 20
  --price-retries  <N>              Retries per Pricing API call. Default: 3
  --price-max      <N>              Query price only for top-N by interruptions. Default: 120

General:
  -h, --help                        Show this help

Environment overrides:
  REGION (default: eu-north-1), PRICING_REGION (default: us-east-1),
  PRICING_LOCATION (default: "EU (Stockholm)"), OS_BUCKET (default: linux),
  MIN_MEM_MIB (default: 4096)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--interrupt-threshold) INTERRUPT_THRESHOLD="${2:?}"; shift 2;;
    -n|--limit)               OUTPUT_LIMIT="${2:?}"; shift 2;;
    --no-price)               USE_PRICE=0; shift;;
    --price-parallel)         PRICE_PARALLEL="${2:?}"; shift 2;;
    --price-timeout)          PRICE_TIMEOUT="${2:?}"; shift 2;;
    --price-retries)          PRICE_RETRIES="${2:?}"; shift 2;;
    --price-max)              PRICE_MAX="${2:?}"; shift 2;;
    -h|--help)                usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

# -------- Logging & progress (stderr) --------
log() { printf "%s\n" "$*" >&2; }
progress_bar() {
  local progress=$1 total=$2 width=40
  local percent=$(( total==0 ? 100 : progress * 100 / total ))
  local filled=$(( total==0 ? width : width * progress / total ))
  printf "\r[%-${width}s] %3d%%" "$(printf '#%.0s' $(seq 1 $filled))" "$percent" >&2
}

# -------- Dependency checks --------
for bin in aws jq curl; do
  command -v "$bin" >/dev/null || { echo "❌ Missing dependency: $bin" >&2; exit 1; }
done

# -------- Step 1: Offerings in region --------
log "📦 Fetching available instance types for region $REGION ..."
readarray -t OFFERINGS < <(aws ec2 describe-instance-type-offerings \
  --region "$REGION" \
  --location-type region \
  --filters Name=location,Values="$REGION" \
  --query 'InstanceTypeOfferings[].InstanceType' \
  --output text $PROFILE_OPT | tr '\t' '\n' | sort -u)
(( ${#OFFERINGS[@]} > 0 )) || { echo "❌ No offerings found in $REGION" >&2; exit 1; }

# -------- Step 2: Describe in chunks (≤100) --------
log "🔍 Describing ${#OFFERINGS[@]} instance types..."
DESCRIBE_COMBINED='{"InstanceTypes":[]}'
CHUNK=100
chunks=$(( (${#OFFERINGS[@]} + CHUNK - 1) / CHUNK ))
for (( i=0; i<${#OFFERINGS[@]}; i+=CHUNK )); do
  PART=( "${OFFERINGS[@]:i:CHUNK}" )
  DESCRIBE_JSON=$(aws ec2 describe-instance-types \
      --region "$REGION" \
      --instance-types ${PART[*]} \
      --output json $PROFILE_OPT)
  DESCRIBE_COMBINED=$(jq -s '{ "InstanceTypes": (.[0].InstanceTypes + .[1].InstanceTypes) }' \
    <(jq '.' <<<"$DESCRIBE_COMBINED") <(jq '.' <<<"$DESCRIBE_JSON"))
  progress_bar $((i/CHUNK+1)) $chunks
done
printf "\n" >&2
log "✅ Instance types described."

# -------- Step 3: Filter (x86_64, ≥4GiB, up to 2xlarge, exclude metal & expensive families) --------
CANDIDATES=$(jq -r --arg re "$SIZE_RE" --argjson min "$MIN_MEM_MIB" '
  .InstanceTypes[]
  | select(.ProcessorInfo.SupportedArchitectures[] | contains("x86_64"))
  | select(.MemoryInfo.SizeInMiB >= $min)
  | .InstanceType as $t
  | select(($t | test($re)) and ($t | contains(".metal") | not))
  | $t
' <<<"$DESCRIBE_COMBINED" \
| awk -v RS='\n' -v ORS='\n' -v excl="$EXCLUDE_FAMILY_RE" '
    { fam=$0; sub(/\..*$/,"",fam); if (fam !~ excl) print $0 }
' | sort -u)
[[ -n "$CANDIDATES" ]] || { echo "❌ No matching x86 types after filters" >&2; exit 1; }

# -------- Step 4: Spot Advisor --------
log "☁️  Fetching Spot Advisor data..."
ADVISOR=$(curl -fsSL "$ADVISOR_URL")
log "✅ Spot Advisor data loaded."

spot_bucket_to_rank() {
  case "$1" in
    "<5%") echo 1;; "5-10%") echo 2;; "10-15%") echo 3;; "15-20%") echo 4;; ">20%") echo 5;; *) echo 9;;
  esac
}
threshold_to_rank() {
  local pct="$1"
  if   (( pct <= 5 )); then echo 1
  elif (( pct <= 10 )); then echo 2
  elif (( pct <= 15 )); then echo 3
  elif (( pct <= 20 )); then echo 4
  else echo 4; fi
}
threshold_rank_max=$(threshold_to_rank "$INTERRUPT_THRESHOLD")

# Pre-rank by interruptions only (no pricing yet)
pre_rank_one() {
  local it="$1" fam size rate rank
  fam="${it%%.*}"; size="${it##*.}"
  rate=$(jq -r --arg os "$OS_BUCKET" --arg reg "$REGION" --arg fam "$fam" --arg size "$size" \
         '.spot_advisor[$os][$reg][$fam][$size].r // empty' <<<"$ADVISOR")
  rank=$(spot_bucket_to_rank "$rate")
  (( rank > threshold_rank_max )) && return
  printf "%d\t%s\n" "$rank" "$it"
}

PRE_SORTED=$(
  while read -r it; do pre_rank_one "$it"; done <<<"$CANDIDATES" \
  | awk 'NF==2' \
  | LC_ALL=C sort -n -k1,1 -k2,2 \
  | awk '{print $2}'
)

# If pricing disabled, output by interruptions only
if (( USE_PRICE == 0 )); then
  readarray -t FINAL < <(echo "$PRE_SORTED" | awk '!seen[$0]++' | head -n "$OUTPUT_LIMIT")
  printf "[ "
  for (( i=0; i<${#FINAL[@]}; i++ )); do
    (( i>0 )) && printf " , "
    printf "\"%s\"" "${FINAL[$i]}"
  done
  printf " ]\n"
  exit 0
fi

# Limit how many types we price (top by interruptions)
readarray -t TO_PRICE < <(echo "$PRE_SORTED" | head -n "$PRICE_MAX")
(( ${#TO_PRICE[@]} > 0 )) || { echo "[]"; echo "⚠️ Nothing to price after filtering" >&2; exit 0; }

# -------- Step 5: Pricing with parallelism, timeout, retry --------
log "💰 Fetching On-Demand pricing for ${#TO_PRICE[@]} types (parallel=$PRICE_PARALLEL, timeout=${PRICE_TIMEOUT}s, retries=$PRICE_RETRIES)..."

# Prepare a temp file for results
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export PRICING_REGION PRICING_LOCATION PRICE_TIMEOUT PRICE_RETRIES PROFILE_OPT
price_worker() {
  # $1 = instance type, $2 = output file path
  local it="$1" out="$2"
  local attempt=0 delay=1
  while (( attempt < PRICE_RETRIES )); do
    if prod_json=$(timeout "$PRICE_TIMEOUT" aws pricing get-products \
      --region "$PRICING_REGION" \
      --service-code AmazonEC2 \
      --filters \
        Type=TERM_MATCH,Field=instanceType,Value="$it" \
        Type=TERM_MATCH,Field=location,Value="$PRICING_LOCATION" \
        Type=TERM_MATCH,Field=operatingSystem,Value=Linux \
        Type=TERM_MATCH,Field=preInstalledSw,Value=NA \
        Type=TERM_MATCH,Field=capacitystatus,Value=Used \
        Type=TERM_MATCH,Field=tenancy,Value=Shared \
      --query 'PriceList[0]' \
      --output text $PROFILE_OPT 2>/dev/null ) && [[ -n "$prod_json" && "$prod_json" != "None" ]]; then
        price=$(jq -r '.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD // empty' <<<"$prod_json")
        [[ -z "$price" ]] && price="nan"
        printf "%s\t%s\n" "$it" "$price" > "$out"
        return 0
    fi
    ((attempt++))
    sleep "$delay"; delay=$((delay*2))
  done
  printf "%s\tnan\n" "$it" > "$out"
  return 0
}

# Run workers in parallel batches
total=${#TO_PRICE[@]}
running=0
idx=0
pbar_last=0
for it in "${TO_PRICE[@]}"; do
  price_worker "$it" "$TMPDIR/$idx.price" &
  ((running++))
  ((idx++))
  if (( running >= PRICE_PARALLEL )); then
    wait -n
    running=$((running-1))
    # update progress
    done_count=$(ls -1 "$TMPDIR" | wc -l | tr -d ' ')
    if (( done_count > pbar_last )); then
      progress_bar "$done_count" "$total"
      pbar_last="$done_count"
    fi
  fi
done
# wait for remaining
wait
progress_bar "$total" "$total"; printf "\n" >&2
log "✅ Pricing data fetched."

# Load prices into an assoc array
declare -A PRICE
while read -r line; do
  itype=$(awk -F'\t' '{print $1}' <<<"$line")
  val=$(awk -F'\t' '{print $2}' <<<"$line")
  PRICE["$itype"]="$val"
done < <(cat "$TMPDIR"/*.price)

# -------- Step 6: Merge (interrupt rank + price), sort, output --------
merge_and_sort() {
  while read -r it; do
    fam="${it%%.*}"; size="${it##*.}"
    rate=$(jq -r --arg os "$OS_BUCKET" --arg reg "$REGION" --arg fam "$fam" --arg size "$size" \
           '.spot_advisor[$os][$reg][$fam][$size].r // empty' <<<"$ADVISOR")
    rank=$(spot_bucket_to_rank "$rate")
    (( rank > threshold_rank_max )) && continue
    p="${PRICE[$it]:-nan}"
    if [[ "$p" == "nan" ]]; then
      printf "%d\t%012.6f\t%s\n" "$rank" "9999999.000000" "$it"
    else
      printf "%d\t%012.6f\t%s\n" "$rank" "$p" "$it"
    fi
  done <<<"$PRE_SORTED" \
  | awk 'NF==3' \
  | LC_ALL=C sort -n -k1,1 -k2,2 -k3,3 \
  | awk -F'\t' '{print $3}'
}

SORTED=$(merge_and_sort)
readarray -t FINAL < <(awk '!seen[$0]++' <<<"$SORTED" | head -n "$OUTPUT_LIMIT")

# Print exact format: [ "a" , "b" , "c" ]
printf "[ "
for (( i=0; i<${#FINAL[@]}; i++ )); do
  (( i>0 )) && printf " , "
  printf "\"%s\"" "${FINAL[$i]}"
done
printf " ]\n"
