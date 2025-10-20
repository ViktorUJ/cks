#!/usr/bin/env bash
set -euo pipefail

# -------- Defaults --------
REGION="${REGION:-eu-north-1}"         # EC2 region to target
OS_BUCKET="${OS_BUCKET:-linux}"        # preferred OS bucket name
MIN_MEM_MIB="${MIN_MEM_MIB:-4096}"     # >= 4 GiB
SIZE_RE='\.((medium)|(large)|(xlarge)|(2xlarge))$'  # up to 2xlarge
OUTPUT_LIMIT_DEFAULT=50
INTERRUPT_THRESHOLD_DEFAULT=20
PROFILE_OPT=${AWS_PROFILE:+--profile "$AWS_PROFILE"}

ADVISOR_URL="https://spot-bid-advisor.s3.amazonaws.com/spot-advisor-data.json"
EXCLUDE_FAMILY_RE='^(g|p|inf|trn|f1|dl|vt)'  # exclude expensive families (GPU/FPGA/Infer/Trainium/Video)

# -------- CLI --------
OUTPUT_LIMIT="$OUTPUT_LIMIT_DEFAULT"
INTERRUPT_THRESHOLD="$INTERRUPT_THRESHOLD_DEFAULT"
INCLUDE_UNKNOWN=0  # include family/size missing in Advisor as rank=2 (<=10%)

usage() {
  cat <<'EOF'
Usage: find_spot.sh [options]

Filters:
  -i, --interrupt-threshold <PCT>   Max Spot interruption bucket (%). Includes all lower buckets.
                                    Examples: 5, 10, 15, 20. Default: 20
  -n, --limit <NUM>                 Max number of instance types in output. Default: 50
  --include-unknown                 Include family/size missing in Advisor (treated as rank=2)

Misc:
  -h, --help                        Show help

Env overrides:
  REGION (default: eu-north-1)
  OS_BUCKET (default: linux)
  MIN_MEM_MIB (default: 4096)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--interrupt-threshold) INTERRUPT_THRESHOLD="${2:?}"; shift 2;;
    -n|--limit)               OUTPUT_LIMIT="${2:?}"; shift 2;;
    --include-unknown)        INCLUDE_UNKNOWN=1; shift;;
    -h|--help)                usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

# -------- Logging (stderr) --------
log() { printf "%s\n" "$*" >&2; }
progress_bar() {
  local progress=$1 total=$2 width=40
  local percent=$(( total==0 ? 100 : progress * 100 / total ))
  local filled=$(( total==0 ? width : width * progress / total ))
  printf "\r[%-${width}s] %3d%%" "$(printf '#%.0s' $(seq 1 $filled))" "$percent" >&2
}

# -------- Dependencies --------
for bin in aws jq curl; do
  command -v "$bin" >/dev/null || { echo "❌ Missing dependency: $bin" >&2; exit 1; }
done

# -------- 1) Get offerings in region --------
log "📦 Fetching available instance types for region $REGION ..."
readarray -t OFFERINGS < <(aws ec2 describe-instance-type-offerings \
  --region "$REGION" \
  --location-type region \
  --filters Name=location,Values="$REGION" \
  --query 'InstanceTypeOfferings[].InstanceType' \
  --output text $PROFILE_OPT | tr '\t' '\n' | sort -u)
(( ${#OFFERINGS[@]} > 0 )) || { echo "❌ No offerings in $REGION" >&2; exit 1; }

# -------- 2) Describe in chunks (≤100) --------
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

# -------- 3) Filter candidates (x86_64, >=4GiB, <=2xlarge, not metal, not expensive) --------
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

# -------- 4) Load Spot Advisor --------
log "☁️  Fetching Spot Instance Advisor..."
ADVISOR=$(curl -fsSL "$ADVISOR_URL")
log "✅ Spot Advisor JSON loaded."

# -------- 4a) Robust accessors for both JSON layouts --------
# Layout A: .spot_advisor[os][region][family][size].r
# Layout B: .spot_advisor[region][os][family][size].r
jq_has_path() {
  local os="$1" reg="$2"
  jq -e --arg os "$os" --arg reg "$reg" '
    (.spot_advisor[$os][$reg] // empty) | type == "object"
    or
    (.spot_advisor[$reg][$os] // empty) | type == "object"
  ' <<<"$ADVISOR" >/dev/null
}

jq_get_rate() {
  local os="$1" reg="$2" fam="$3" size="$4"
  jq -r --arg os "$os" --arg reg "$reg" --arg fam "$fam" --arg size "$size" '
    .spot_advisor[$os][$reg][$fam][$size].r
    // .spot_advisor[$reg][$os][$fam][$size].r
    // empty
  ' <<<"$ADVISOR"
}

# Validate that some path exists; if not, try to auto-pick alternatives
OS_EFF="$OS_BUCKET"
REG_EFF="$REGION"
if ! jq_has_path "$OS_EFF" "$REG_EFF"; then
  # Try swapping order (maybe region-first)
  # If still not found, try to find any linux/Windows bucket paired with our region
  # 1) Try same OS with any region
  alt_reg=$(jq -r --arg os "$OS_EFF" '
    [
      (.spot_advisor[$os] // {}) | keys[]?,
      (.spot_advisor | keys[]? | select(test("^[a-z]{2}-")))  # maybe region-first
    ] | unique[]
  ' <<<"$ADVISOR" | head -n1 || true)
  if [[ -n "$alt_reg" ]] && jq_has_path "$OS_EFF" "$alt_reg"; then
    REG_EFF="$alt_reg"
  else
    # 2) Try to find any OS that pairs with our region
    alt_os=$(jq -r --arg reg "$REG_EFF" '
      [
        (.spot_advisor | keys[]?)                          # could be OS or region
        | select(. != null)
      ] | unique[]
    ' <<<"$ADVISOR" | head -n1 || true)
    if [[ -n "$alt_os" ]] && jq_has_path "$alt_os" "$REG_EFF"; then
      OS_EFF="$alt_os"
    fi
  fi
fi

# -------- 4b) Bucket mapping and threshold --------
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
threshold_to_rank() {
  local pct="$1"
  if   (( pct <= 5 )); then echo 1
  elif (( pct <= 10 )); then echo 2
  elif (( pct <= 15 )); then echo 3
  elif (( pct <= 20 )); then echo 4
  else echo 4; fi
}
threshold_rank_max=$(threshold_to_rank "$INTERRUPT_THRESHOLD")

# -------- 5) Rank by interruptions only (stable & fast) --------
rank_one() {
  local it="$1" fam size rate rank
  fam="${it%%.*}"
  size="${it##*.}"

  # Try both layouts transparently
  rate="$(jq_get_rate "$OS_EFF" "$REG_EFF" "$fam" "$size")"

  if [[ -z "$rate" || "$rate" == "null" ]]; then
    # Missing in Advisor
    if (( INCLUDE_UNKNOWN == 1 )); then
      rank=2   # treat unknown as reasonably stable (<=10%)
    else
      return   # skip unknown
    fi
  else
    rank=$(spot_bucket_to_rank "$rate")
  fi

  (( rank > threshold_rank_max )) && return
  printf "%d\t%s\n" "$rank" "$it"
}

PRE_SORTED=$(
  while read -r it; do rank_one "$it"; done <<<"$CANDIDATES" \
  | awk 'NF==2' \
  | LC_ALL=C sort -n -k1,1 -k2,2 \
  | awk '{print $2}'
)

if [[ -z "$PRE_SORTED" ]]; then
  echo "[]"   # still produce a valid array
  log "⚠️ No instances passed the Spot threshold. Try --include-unknown or increase -i (e.g., 20)."
  exit 0
fi

# -------- 6) Output in the requested array format --------
readarray -t FINAL < <(echo "$PRE_SORTED" | awk '!seen[$0]++' | head -n "$OUTPUT_LIMIT")

printf "[ "
for (( i=0; i<${#FINAL[@]}; i++ )); do
  (( i>0 )) && printf " , "
  printf "\"%s\"" "${FINAL[$i]}"
done
printf " ]\n"
