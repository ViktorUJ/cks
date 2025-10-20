#!/usr/bin/env bash
set -euo pipefail

# -------- Defaults --------
REGION="${REGION:-eu-north-1}"         # EC2 region
OS_BUCKET_RAW="linux"                  # default OS (user input)
MIN_MEM_MIB="${MIN_MEM_MIB:-4096}"     # >= 4 GiB
SIZE_RE='\.((medium)|(large)|(xlarge)|(2xlarge))$'  # up to 2xlarge
OUTPUT_LIMIT_DEFAULT=50
INTERRUPT_THRESHOLD_DEFAULT=20
PROFILE_OPT=${AWS_PROFILE:+--profile "$AWS_PROFILE"}
ADVISOR_URL="https://spot-bid-advisor.s3.amazonaws.com/spot-advisor-data.json"
EXCLUDE_FAMILY_RE='^(g|p|inf|trn|f1|dl|vt)'  # exclude expensive families

# -------- CLI --------
OUTPUT_LIMIT="$OUTPUT_LIMIT_DEFAULT"
INTERRUPT_THRESHOLD="$INTERRUPT_THRESHOLD_DEFAULT"
INCLUDE_UNKNOWN=0  # include missing Advisor entries as rank=2
DEBUG=0
OS_CLI=""          # --os linux|windows

usage() {
  cat <<'EOF'
Usage: find_spot.sh [options]

Filters:
  -i, --interrupt-threshold <PCT>   Max Spot interruption bucket (5,10,15,20). Includes lower. Default: 20
  -n, --limit <NUM>                 Max instance types in output. Default: 50
  --include-unknown                 Include types missing in Advisor as rank=2 (~<=10%)

System:
  --os <linux|windows>              OS for Advisor if OS level exists (default: linux)
  --debug                           Verbose debug logs

Env:
  REGION (default: eu-north-1)
  MIN_MEM_MIB (default: 4096)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--interrupt-threshold) INTERRUPT_THRESHOLD="${2:?}"; shift 2;;
    -n|--limit)               OUTPUT_LIMIT="${2:?}"; shift 2;;
    --include-unknown)        INCLUDE_UNKNOWN=1; shift;;
    --os)                     OS_CLI="${2:?}"; shift 2;;
    --debug)                  DEBUG=1; shift;;
    -h|--help)                usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

# -------- Logging --------
log()    { printf "%s\n" "$*" >&2; }
debug()  { (( DEBUG )) && printf "[DEBUG] %s\n" "$*" >&2; }
pbar()   {
  local progress=$1 total=$2 width=40
  local percent=$(( total==0 ? 100 : progress * 100 / total ))
  local filled=$(( total==0 ? width : width * progress / total ))
  printf "\r[%-${width}s] %3d%%" "$(printf '#%.0s' $(seq 1 $filled))" "$percent" >&2
}

# -------- Dependencies --------
for bin in aws jq curl; do
  command -v "$bin" >/dev/null || { echo "❌ Missing dependency: $bin" >&2; exit 1; }
done

# -------- Normalize OS bucket name --------
case "${OS_CLI:-$OS_BUCKET_RAW,,}" in
  linux|"") OS_BUCKET="Linux" ;;
  windows)  OS_BUCKET="Windows" ;;
  *)        OS_BUCKET="Linux" ;;
esac
debug "OS bucket preferred: '$OS_BUCKET'"

# -------- 1) Offerings --------
log "📦 Fetching available instance types for region $REGION ..."
readarray -t OFFERINGS < <(aws ec2 describe-instance-type-offerings \
  --region "$REGION" \
  --location-type region \
  --filters Name=location,Values="$REGION" \
  --query 'InstanceTypeOfferings[].InstanceType' \
  --output text $PROFILE_OPT | tr '\t' '\n' | sort -u)
debug "Found ${#OFFERINGS[@]} offerings"
(( ${#OFFERINGS[@]} > 0 )) || { echo "❌ No offerings in $REGION" >&2; exit 1; }

# -------- 2) Describe types (≤100 per call) --------
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
  pbar $((i/CHUNK+1)) $chunks
done
printf "\n" >&2
log "✅ Instance types described."

# -------- 3) Filter candidates --------
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
debug "Filtered candidates: $(echo "$CANDIDATES" | wc -l) types"
[[ -n "$CANDIDATES" ]] || { echo "❌ No matching x86 types after filters" >&2; exit 1; }

# -------- 4) Load Spot Advisor --------
log "☁️  Fetching Spot Advisor JSON..."
ADVISOR=$(curl -fsSL "$ADVISOR_URL")
log "✅ Spot Advisor loaded."
debug "Spot Advisor top-level keys: $(jq -r '.spot_advisor | keys[]' <<<"$ADVISOR" | tr '\n' ' ')"

# -------- 5) Access helper: try all known layouts --------
# Layout A: .spot_advisor[OS][REGION][family][size].r
# Layout B: .spot_advisor[REGION][OS][family][size].r
# Layout C: .spot_advisor[REGION][family][size].r
jq_get_rate() {
  local fam="$1" size="$2"
  local r
  r=$(jq -r --arg os "$OS_BUCKET" --arg reg "$REGION" --arg fam "$fam" --arg size "$size" '
      .spot_advisor[$os][$reg][$fam][$size].r
      // .spot_advisor[$reg][$os][$fam][$size].r
      // .spot_advisor[$reg][$fam][$size].r
      // empty
    ' <<<"$ADVISOR")
  printf "%s" "$r"
}

# Helpful debug dump: show which keys exist under region
if (( DEBUG )); then
  if jq -e --arg reg "$REGION" '.spot_advisor[$reg] | type=="object"' <<<"$ADVISOR" >/dev/null; then
    debug "Region '$REGION' exists in Advisor."
    debug "Region-level keys: $(jq -r --arg reg "$REGION" '.spot_advisor[$reg] | keys[]' <<<"$ADVISOR" | head -n 10 | tr '\n' ' ') ..."
  else
    debug "Region '$REGION' not found at top-level of Advisor."
  fi
fi

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

# -------- 6) Rank by interruptions --------
rank_one() {
  local it="$1" fam size rate rank
  fam="${it%%.*}"
  size="${it##*.}"

  rate="$(jq_get_rate "$fam" "$size")"
  if (( DEBUG )) && [[ -z "$rate" ]]; then
    echo "[DEBUG] No rate for $fam.$size in region '$REGION' (trying A/B/C layouts failed)" >&2
  fi
  if [[ -z "$rate" || "$rate" == "null" ]]; then
    if (( INCLUDE_UNKNOWN == 1 )); then rank=2; else return; fi
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
debug "Pre-sorted count: $(echo "$PRE_SORTED" | wc -l)"

if [[ -z "$PRE_SORTED" ]]; then
  echo "[]"
  log "⚠️ No instances matched Spot threshold. Try --include-unknown or increase -i (e.g., 20)."
  exit 0
fi

# -------- 7) Output --------
readarray -t FINAL < <(echo "$PRE_SORTED" | awk '!seen[$0]++' | head -n "$OUTPUT_LIMIT")

printf "[ "
for (( i=0; i<${#FINAL[@]}; i++ )); do
  (( i>0 )) && printf " , "
  printf "\"%s\"" "${FINAL[$i]}"
done
printf " ]\n"
