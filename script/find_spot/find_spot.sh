#!/usr/bin/env bash
set -euo pipefail

# -------- Defaults --------
REGION="${REGION:-eu-north-1}"         # EC2 region
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
INCLUDE_UNKNOWN=0      # include missing Advisor entries as rank=2 (~<=10%)
DEBUG=0
OS_CLI="linux"        # --os linux|windows (default linux)

usage() {
  cat <<'EOF'
Usage: find_spot.sh [options]

Filters:
  -i, --interrupt-threshold <PCT>   Max Spot interruption bucket (5,10,15,20). Includes lower. Default: 20
  -n, --limit <NUM>                 Max instance types in output. Default: 50
  --include-unknown                 Include types missing in Advisor as rank=2 (~<=10%)

System:
  --os <linux|windows>              OS for Spot Advisor (default: linux)
  --debug                           Verbose debug logs (JSON snippets for missing rates)

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

# -------- Normalize OS bucket to "Linux"/"Windows" --------
case "${OS_CLI,,}" in
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

# Debug JSON snippet for the chosen region (does not break stdout)
if (( DEBUG )); then
  if jq -e --arg reg "$REGION" '.spot_advisor[$reg] | type=="object"' <<<"$ADVISOR" >/dev/null; then
    debug "Region '$REGION' exists in Advisor."
    debug "Region-level keys (first 10): $(jq -r --arg reg "$REGION" '.spot_advisor[$reg] | keys[]' <<<"$ADVISOR" | head -n 10 | tr '\n' ' ')"
    echo "[DEBUG] --- JSON snippet for region '$REGION' ---" >&2
    jq --arg reg "$REGION" '.spot_advisor[$reg] | to_entries | .[0:3]' <<<"$ADVISOR" >&2
    echo "[DEBUG] ---------------------------------------" >&2
  else
    debug "Region '$REGION' not found at top-level of Advisor."
    echo "[DEBUG] --- JSON root preview ---" >&2
    jq '.spot_advisor | to_entries | .[0:3]' <<<"$ADVISOR" >&2
    echo "[DEBUG] --------------------------------------" >&2
  fi
fi

# -------- 5) Access helper: try all known layouts and normalize "r" --------
# Supported layouts:
# A: .spot_advisor[OS][REGION][family][size].r
# B: .spot_advisor[REGION][OS][family][size].r
# C: .spot_advisor[REGION][family][size].r
# D: .spot_advisor[REGION][OS][instanceType].r
# E: .spot_advisor[REGION][instanceType].r
#
# We normalize:
# - if r is a string ("<5%","5-10%",...) -> map to rank 1..5
# - if r is a number (0..4)              -> rank = r + 1
jq_get_rank() {
  local fam="$1" size="$2" it="$3"
  jq -r --arg os "$OS_BUCKET" --arg reg "$REGION" --arg fam "$fam" --arg size "$size" --arg it "$it" '
    def norm($x):
      if ($x|type)=="string" then
        if   $x=="<5%"     then 1
        elif $x=="5-10%"   then 2
        elif $x=="10-15%"  then 3
        elif $x=="15-20%"  then 4
        elif $x==">20%"    then 5
        else empty end
      elif ($x|type)=="number" then
        # numeric 0..4 -> 1..5
        ($x + 1)
      else empty end;
    # try all layouts, pick first non-empty
    ( .spot_advisor[$os][$reg][$fam][$size].r
    // .spot_advisor[$reg][$os][$fam][$size].r
    // .spot_advisor[$reg][$fam][$size].r
    // .spot_advisor[$reg][$os][$it].r
    // .spot_advisor[$reg][$it].r
    // empty ) as $r
    | norm($r)
  ' <<<"$ADVISOR"
}

# -------- 6) Buckets & threshold --------
threshold_to_rank() {
  local pct="$1"
  if   (( pct <= 5 ));  then echo 1
  elif (( pct <= 10 )); then echo 2
  elif (( pct <= 15 )); then echo 3
  elif (( pct <= 20 )); then echo 4
  else echo 4; fi
}
threshold_rank_max=$(threshold_to_rank "$INTERRUPT_THRESHOLD")

# Counter to print JSON dump for first 3 missing-rate cases only
MISSING_DUMP_COUNT=0
MISSING_DUMP_LIMIT=3

# -------- 7) Rank by interruptions --------
rank_one() {
  local it="$1" fam size rank
  fam="${it%%.*}"
  size="${it##*.}"

  rank="$(jq_get_rank "$fam" "$size" "$it")"
  if [[ -z "$rank" ]]; then
    if (( DEBUG && MISSING_DUMP_COUNT < MISSING_DUMP_LIMIT )); then
      ((MISSING_DUMP_COUNT++))
      echo "[DEBUG] No rate for ${it} in region '${REGION}' (tried A/B/C/D/E). Dump #${MISSING_DUMP_COUNT}:" >&2

      echo "[DEBUG]   Path D: .spot_advisor[\"$REGION\"][\"$OS_BUCKET\"][\"$it\"]" >&2
      jq -r --arg reg "$REGION" --arg os "$OS_BUCKET" --arg it "$it" '
        { value: (.spot_advisor[$reg][$os][$it] // null),
          keys_under_os: ((.spot_advisor[$reg][$os] // {}) | (keys[0:15]))
        }' <<<"$ADVISOR" >&2

      echo "[DEBUG]   Path E: .spot_advisor[\"$REGION\"][\"$it\"]" >&2
      jq -r --arg reg "$REGION" --arg it "$it" '
        { value: (.spot_advisor[$reg][$it] // null),
          region_keys: ((.spot_advisor[$reg] // {}) | keys[0:15])
        }' <<<"$ADVISOR" >&2

      echo "[DEBUG]   Path B: .spot_advisor[\"$REGION\"][\"$OS_BUCKET\"][\"$fam\"][\"$size\"]" >&2
      jq -r --arg reg "$REGION" --arg os "$OS_BUCKET" --arg fam "$fam" --arg size "$size" '
        { value: (.spot_advisor[$reg][$os][$fam][$size] // null),
          fam_exists_under_os: (.spot_advisor[$reg][$os][$fam] | (type=="object"))
        }' <<<"$ADVISOR" >&2

      echo "[DEBUG]   Path C: .spot_advisor[\"$REGION\"][\"$fam\"][\"$size\"]" >&2
      jq -r --arg reg "$REGION" --arg fam "$fam" --arg size "$size" '
        { value: (.spot_advisor[$reg][$fam][$size] // null),
          fam_exists_under_region: (.spot_advisor[$reg][$fam] | (type=="object"))
        }' <<<"$ADVISOR" >&2

      echo "[DEBUG]   Path A: .spot_advisor[\"$OS_BUCKET\"][\"$REGION\"][\"$fam\"][\"$size\"]" >&2
      jq -r --arg os "$OS_BUCKET" --arg reg "$REGION" --arg fam "$fam" --arg size "$size" '
        { value: (.spot_advisor[$os][$reg][$fam][$size] // null),
          os_exists_top: (.spot_advisor[$os] | (type=="object"))
        }' <<<"$ADVISOR" >&2
      echo "[DEBUG] --------------------------------------------------------------" >&2
    fi
    if (( INCLUDE_UNKNOWN == 1 )); then
      rank=2
    else
      return
    fi
  fi

  # Threshold filter
  (( rank > threshold_rank_max )) && return
  # Emit: rank \t instanceType
  printf "%d\t%s\n" "$rank" "$it"
}

PRE_SORTED=$(
  while read -r it; do rank_one "$it"; done <<<"$CANDIDATES" \
  | awk 'NF==2' \
  | LC_ALL=C sort -n -k1,1 -k2,2 \
  | awk '{print $2}'
)
# Note: wc -l on empty string returns 0, on blank line returns 1; use non-empty check below.
debug "Pre-sorted empty? $([[ -z "${PRE_SORTED}" ]] && echo yes || echo no)"

# -------- 8) Output --------
if [[ -z "$PRE_SORTED" ]]; then
  echo "[]"
  log "⚠️ No instances matched Spot threshold. Try --include-unknown or increase -i (e.g., 20)."
  exit 0
fi

readarray -t FINAL < <(echo "$PRE_SORTED" | awk 'NF>0' | awk '!seen[$0]++' | head -n "$OUTPUT_LIMIT")

# Exact required format: [ "a" , "b" , "c" ]
printf "[ "
for (( i=0; i<${#FINAL[@]}; i++ )); do
  (( i>0 )) && printf " , "
  printf "\"%s\"" "${FINAL[$i]}"
done
printf " ]\n"
