#!/usr/bin/env bash
set -Eeuo pipefail

# ---- traps (print where it failed) ----
on_err() {
  echo "❌ ERROR at line ${BASH_LINENO[0]}: command '${BASH_COMMAND}' failed." >&2
  echo "    Hint: run with --trace to see full execution." >&2
}
trap on_err ERR

# -------- Defaults --------
REGION="${REGION:-eu-north-1}"         # EC2 region
MIN_MEM_MIB="${MIN_MEM_MIB:-4096}"     # >= 4 GiB
SIZE_RE='\.((medium)|(large)|(xlarge)|(2xlarge))$'  # up to 2xlarge
OUTPUT_LIMIT_DEFAULT=50
INTERRUPT_THRESHOLD_DEFAULT=20
PROFILE_OPT=${AWS_PROFILE:+--profile "$AWS_PROFILE"}
ADVISOR_URL="https://spot-bid-advisor.s3.amazonaws.com/spot-advisor-data.json"
EXCLUDE_FAMILY_RE='^(g|p|inf|trn|f1|dl|vt)'  # exclude expensive families (GPU/Inferentia/Trainium/FPGA/Video)

# -------- CLI --------
OUTPUT_LIMIT="$OUTPUT_LIMIT_DEFAULT"
INTERRUPT_THRESHOLD="$INTERRUPT_THRESHOLD_DEFAULT"
INCLUDE_UNKNOWN=0      # include missing Advisor entries as rank=2 (~<=10%)
DEBUG=0
TRACE=0
OS_CLI="linux"        # --os linux|windows (default linux)
NO_EMOJI=0
ARCH="x86"            # --arch x86|arm (default x86)

usage() {
  cat <<'EOF'
Usage: find_spot.sh [options]

Filters:
  -i, --interrupt-threshold <PCT>   Max Spot interruption bucket (5,10,15,20). Includes lower. Default: 20
  -n, --limit <NUM>                 Max instance types in output. Default: 50
  -a, --arch <x86|arm>              Architecture filter (default: x86)
  --include-unknown                 Include types missing in Advisor as rank=2 (~<=10%)

System:
  --os <linux|windows>              OS for Spot Advisor (default: linux)
  --debug                           Verbose debug logs (JSON snippets for missing rates)
  --trace                           Bash trace (set -x)
  --no-emoji                        Disable emoji in logs

Env:
  REGION (default: eu-north-1)
  MIN_MEM_MIB (default: 4096)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--interrupt-threshold) INTERRUPT_THRESHOLD="${2:?}"; shift 2;;
    -n|--limit)               OUTPUT_LIMIT="${2:?}"; shift 2;;
    -a|--arch)                ARCH="${2,,}"; shift 2;;
    --include-unknown)        INCLUDE_UNKNOWN=1; shift;;
    --os)                     OS_CLI="${2:?}"; shift 2;;
    --debug)                  DEBUG=1; shift;;
    --trace)                  TRACE=1; shift;;
    --no-emoji)               NO_EMOJI=1; shift;;
    -h|--help)                usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

if (( TRACE )); then set -x; fi

# -------- Logging --------
log()   { printf "%s\n" "$*" >&2; }
debug() { if (( DEBUG )); then printf "[DEBUG] %s\n" "$*" >&2; fi; }

# Simple progress bar (no external seq)
pbar() {
  local progress=$1 total=$2 width=40
  if (( total <= 0 )); then total=1; fi
  if (( progress < 0 )); then progress=0; fi
  if (( progress > total )); then progress=$total; fi
  local percent=$(( progress * 100 / total ))
  local filled=$(( width * progress / total ))
  local empty=$(( width - filled ))
  local hashes spaces
  printf -v hashes '%*s' "$filled";  hashes=${hashes// /#}
  printf -v spaces '%*s' "$empty"
  printf "\r[%s%s] %3d%%" "$hashes" "$spaces" "$percent" >&2
}

EMOJI_BOX="📦"; EMOJI_MAG="🔍"; EMOJI_OK="✅"; EMOJI_CLOUD="☁️"
if (( NO_EMOJI )); then
  EMOJI_BOX="[ ]"; EMOJI_MAG="[*]"; EMOJI_OK="[OK]"; EMOJI_CLOUD="(cloud)"
fi

# -------- Dependencies --------
for bin in aws jq curl; do
  if ! command -v "$bin" >/dev/null; then
    echo "❌ Missing dependency: $bin" >&2
    exit 1
  fi
done

# -------- Normalize OS bucket to "Linux"/"Windows" --------
case "${OS_CLI,,}" in
  linux|"") OS_BUCKET="Linux" ;;
  windows)  OS_BUCKET="Windows" ;;
  *)        OS_BUCKET="Linux" ;;
esac
debug "OS bucket preferred: '$OS_BUCKET'"

# -------- Normalize architecture to jq filter value --------
case "$ARCH" in
  x86|x86_64|amd64) ARCH_FILTER="x86_64" ;;
  arm|arm64|aarch64) ARCH_FILTER="arm64" ;;
  *) echo "❌ Unknown arch: $ARCH (use x86 or arm)" >&2; exit 1 ;;
esac
debug "Architecture filter: $ARCH_FILTER"

# -------- 1) Offerings --------
log "$EMOJI_BOX Fetching available instance types for region $REGION ..."
readarray -t OFFERINGS < <(aws ec2 describe-instance-type-offerings \
  --region "$REGION" \
  --location-type region \
  --filters Name=location,Values="$REGION" \
  --query 'InstanceTypeOfferings[].InstanceType' \
  --output text $PROFILE_OPT | tr '\t' '\n' | sort -u || true)

if (( ${#OFFERINGS[@]} == 0 )); then
  echo "[]"
  echo "⚠️ No offerings in $REGION (are credentials/region correct?)." >&2
  exit 0
fi
debug "Found ${#OFFERINGS[@]} offerings"

# -------- 2) Describe types (≤100 per call) --------
log "$EMOJI_MAG Describing ${#OFFERINGS[@]} instance types..."
DESCRIBE_COMBINED='{"InstanceTypes":[]}'
CHUNK=100
chunks=$(( (${#OFFERINGS[@]} + CHUNK - 1) / CHUNK ))
if (( chunks == 0 )); then chunks=1; fi
for (( i=0; i<${#OFFERINGS[@]}; i+=CHUNK )); do
  PART=( "${OFFERINGS[@]:i:CHUNK}" )
  # shellcheck disable=SC2086
  DESCRIBE_JSON=$(aws ec2 describe-instance-types \
      --region "$REGION" \
      --instance-types ${PART[*]} \
      --output json $PROFILE_OPT)
  DESCRIBE_COMBINED=$(jq -s '{ "InstanceTypes": (.[0].InstanceTypes + .[1].InstanceTypes) }' \
    <(jq '.' <<<"$DESCRIBE_COMBINED") <(jq '.' <<<"$DESCRIBE_JSON"))
  pbar $((i/CHUNK+1)) $chunks
done
printf "\n" >&2
log "$EMOJI_OK Instance types described."

# -------- 3) Filter candidates (arch, mem >= 4GiB, size <= 2xlarge, exclude metal/expensive) --------
CANDIDATES=$(jq -r --arg re "$SIZE_RE" --argjson min "$MIN_MEM_MIB" --arg arch "$ARCH_FILTER" '
  .InstanceTypes[]
  | select(.ProcessorInfo.SupportedArchitectures[] | contains($arch))
  | select(.MemoryInfo.SizeInMiB >= $min)
  | .InstanceType as $t
  | select(($t | test($re)) and ($t | contains(".metal") | not))
  | $t
' <<<"$DESCRIBE_COMBINED" \
| awk -v RS='\n' -v ORS='\n' -v excl="$EXCLUDE_FAMILY_RE" '
    { fam=$0; sub(/\..*$/,"",fam); if (fam !~ excl) print $0 }
' | sort -u || true)
debug "Filtered candidates: $(echo "$CANDIDATES" | wc -l) types"

if [[ -z "$CANDIDATES" ]]; then
  echo "[]"
  echo "⚠️ No matching types after filters (arch/mem/size/family)." >&2
  exit 0
fi

# -------- 4) Load Spot Advisor --------
log "$EMOJI_CLOUD  Fetching Spot Advisor JSON..."
ADVISOR=$(curl -fSsL "$ADVISOR_URL")
log "$EMOJI_OK Spot Advisor loaded."
if (( DEBUG )); then
  debug "Top-level keys: $(jq -r '.spot_advisor | keys[]' <<<"$ADVISOR" | tr '\n' ' ')"
fi

# Optional JSON snippet for region
if (( DEBUG )); then
  if jq -e --arg reg "$REGION" '.spot_advisor[$reg] | type=="object"' <<<"$ADVISOR" >/dev/null; then
    debug "Region '$REGION' exists in Advisor."
    debug "Region-level keys (first 10): $(jq -r --arg reg "$REGION" '.spot_advisor[$reg] | keys[]' <<<"$ADVISOR" | head -n 10 | tr '\n' ' ')"
    echo "[DEBUG] --- JSON snippet for region '$REGION' ---" >&2
    jq --arg reg "$REGION" '.spot_advisor[$reg] | to_entries | .[0:3]' <<<"$ADVISOR" >&2
    echo "[DEBUG] ---------------------------------------" >&2
  else
    debug "Region '$REGION' not found at top-level of Advisor."
  fi
fi

# -------- 5) Access helper: try A/B/C/D/E and normalize "r" --------
# A: .spot_advisor[OS][REGION][family][size].r
# B: .spot_advisor[REGION][OS][family][size].r
# C: .spot_advisor[REGION][family][size].r
# D: .spot_advisor[REGION][OS][instanceType].r
# E: .spot_advisor[REGION][instanceType].r
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
        ($x + 1)  # 0..4 -> 1..5
      else empty end;
    ( .spot_advisor[$os][$reg][$fam][$size].r
    // .spot_advisor[$reg][$os][$fam][$size].r
    // .spot_advisor[$reg][$fam][$size].r
    // .spot_advisor[$reg][$os][$it].r
    // .spot_advisor[$reg][$it].r
    // empty ) as $r
    | norm($r)
  ' <<<"$ADVISOR"
}

# -------- 6) Threshold (convert percent to comparable rank) --------
threshold_to_rank() {
  local pct="$1"
  if   (( pct <= 5 ));  then echo 1
  elif (( pct <= 10 )); then echo 2
  elif (( pct <= 15 )); then echo 3
  elif (( pct <= 20 )); then echo 4
  else echo 4; fi
}
threshold_rank_max=$(threshold_to_rank "$INTERRUPT_THRESHOLD")

# Only print JSON dumps for the first few missing-rate cases
MISSING_DUMP_COUNT=0
MISSING_DUMP_LIMIT=3

# -------- 7) Rank by interruptions --------
rank_one() {
  local it="$1" fam size rank
  fam="${it%%.*}"
  size="${it##*.}"
  rank="$(jq_get_rank "$fam" "$size" "$it")"
  if [[ -z "$rank" ]]; then
    if (( DEBUG )) && (( MISSING_DUMP_COUNT < MISSING_DUMP_LIMIT )); then
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
    if (( INCLUDE_UNKNOWN )); then
      rank=2
    else
      return 0
    fi
  fi
  if (( rank > threshold_rank_max )); then return 0; fi
  printf "%d\t%s\n" "$rank" "$it"
}

PRE_SORTED=$(
  while read -r it; do rank_one "$it"; done <<<"$CANDIDATES" \
  | awk 'NF==2' \
  | LC_ALL=C sort -n -k1,1 -k2,2 \
  | awk '{print $2}'
)

# -------- 8) Output --------
if [[ -z "$PRE_SORTED" ]]; then
  echo "[]"
  echo "⚠️ No instances matched Spot threshold. Try --include-unknown or increase -i (e.g., 20)." >&2
  exit 0
fi

readarray -t FINAL < <(echo "$PRE_SORTED" | awk 'NF>0' | awk '!seen[$0]++' | head -n "$OUTPUT_LIMIT")

# Exact required format: [ "a" , "b" , "c" ]
printf "[ "
for (( i=0; i<${#FINAL[@]}; i++ )); do
  if (( i>0 )); then printf " , "; fi
  printf "\"%s\"" "${FINAL[$i]}"
done
printf " ]\n"
