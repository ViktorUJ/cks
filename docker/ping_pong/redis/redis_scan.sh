#!/bin/bash

while [[ $# > 0 ]]; do
    key="$1"
    case "$key" in
      --REDIS_HOST)
         REDIS_HOST="$2"
         shift
      ;;
      --REDIS_PORT)
         REDIS_PORT="$2"
         shift
      ;;
      --SLEEP_TIME)
         SLEEP_TIME="$2"
         shift
     ;;
      --NO_TTL_FILE)
         NO_TTL_FILE="$2"
         shift
      ;;
      --WITH_TTL_FILE)
         WITH_TTL_FILE="$2"
         shift
      ;;
      --help|-h)
         echo "Usage: $0 --REDIS_HOST <host> [--REDIS_PORT <port>] [--SLEEP_TIME <seconds>] [--NO_TTL_FILE <file>] [--WITH_TTL_FILE <file>]"
         echo "  --REDIS_HOST: Redis server hostname or IP (required)"
         echo "  --REDIS_PORT: Redis server port (default: 6379)"
         echo "  --SLEEP_TIME: Time to sleep between key checks (default: 0.0001 seconds)"
         echo "  --NO_TTL_FILE: Output file for keys without TTL (default: keys_without_ttl.txt)"
         echo "  --WITH_TTL_FILE: Output file for keys with TTL (default: keys_with_ttl.txt)"
         exit 0
      ;;
      *)
      ;;
    esac
    shift
done

if [ -z "$REDIS_HOST" ]; then
     echo "Error: --REDIS_HOST is required"
     exit 1
fi

if [ -z "$REDIS_PORT" ]; then
     REDIS_PORT="6379"
fi

if [ -z "$SLEEP_TIME" ]; then
     SLEEP_TIME="0.0001"
fi

if [ -z "$NO_TTL_FILE" ]; then
     NO_TTL_FILE="keys_without_ttl.txt"
fi

if [ -z "$WITH_TTL_FILE" ]; then
     WITH_TTL_FILE="keys_with_ttl.txt"
fi

# ── Timer start ─────────────────────────────
START_TIME=$(date +%s)

# ─────────────────────────────────────────────
echo "========"
echo "REDIS_connection:  $REDIS_HOST:$REDIS_PORT"
echo "SLEEP_TIME = $SLEEP_TIME"
echo "NO_TTL_FILE=$NO_TTL_FILE WITH_TTL_FILE=$WITH_TTL_FILE"
echo """file format
| size |  key  | """
echo "------"
# Clear output files before starting
> "$NO_TTL_FILE"
> "$WITH_TTL_FILE"

# Function to print progress bar with elapsed time
print_progress() {
  local current=$1
  local total_keys=$2
  local with=$3
  local mem_with=$4
  local without=$5
  local mem_without=$6

  # Calculate elapsed time
  local now=$(date +%s)
  local elapsed=$(( now - START_TIME ))
  local hours=$(( elapsed / 3600 ))
  local minutes=$(( (elapsed % 3600) / 60 ))
  local seconds=$(( elapsed % 60 ))
  local time_fmt=$(printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds")

  # Build progress bar
  local width=50
  local percent=$(( current * 100 / total_keys ))
  local filled=$(( width * percent / 100 ))
  local empty=$(( width - filled ))

  bar=$(printf "%${filled}s" | tr ' ' '#')
  bar+=$(printf "%${empty}s" | tr ' ' '.')

  printf "\r[%s] %3d%%  (TTL: %d, %.2f MB | no TTL: %d, %.2f MB)  elapsed: %s" \
         "$bar" "$percent" "$with" "$mem_with" "$without" "$mem_without" "$time_fmt"
}

# Get initial Redis stats
total_keys=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" DBSIZE)
used_memory=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" INFO memory | grep -i '^used_memory:' | cut -d':' -f2 | tr -d '\r')
maxmemory=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" INFO memory | grep -i '^maxmemory:' | cut -d':' -f2 | tr -d '\r')

# Convert memory to MB
used_memory_mb=$(bc <<< "scale=2; $used_memory / 1024 / 1024")
maxmemory_mb=$(bc <<< "scale=2; $maxmemory / 1024 / 1024")
free_memory_mb=$(bc <<< "scale=2; ($maxmemory - $used_memory) / 1024 / 1024")

echo "Redis keys total        : $total_keys"
echo "Redis memory used       : ${used_memory_mb} MB"
echo "Redis maxmemory         : ${maxmemory_mb} MB"
echo "Redis free (est) memory : ${free_memory_mb} MB"
echo "==== scan keys ======="

# Counters
count_no_ttl=0
count_with_ttl=0
total=0

# Memory counters (in bytes)
memory_no_ttl=0
memory_with_ttl=0

while read -r key; do
  ttl=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" TTL "$key")

  # Get memory usage for the key once to reuse
  usage=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" MEMORY USAGE "$key")
  # Fallback to 0 if command failed
  [[ ! "$usage" =~ ^[0-9]+$ ]] && usage=0

  if [[ "$ttl" -eq -1 ]]; then
    # First write size, then key
    echo "$usage $key" >> "$NO_TTL_FILE"
    ((count_no_ttl++))
    ((memory_no_ttl+=usage))
  elif [[ "$ttl" -gt 0 ]]; then
    echo "$usage $key" >> "$WITH_TTL_FILE"
    ((count_with_ttl++))
    ((memory_with_ttl+=usage))
  fi

  ((total++))
  if (( total % 1000 == 0 )); then
    mem_with_mb=$(bc <<< "scale=2; $memory_with_ttl / 1024 / 1024")
    mem_no_mb=$(bc <<< "scale=2; $memory_no_ttl / 1024 / 1024")
    print_progress "$total" "$total_keys" "$count_with_ttl" "$mem_with_mb" "$count_no_ttl" "$mem_no_mb"
  fi

  sleep $SLEEP_TIME
done < <(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" --scan)

# ── Sort the output files by size (numeric, descending) ─────────────
sort -nr "$NO_TTL_FILE"  -o "$NO_TTL_FILE"
sort -nr "$WITH_TTL_FILE" -o "$WITH_TTL_FILE"

# Final totals
mem_with_total=$(bc <<< "scale=2; $memory_with_ttl / 1024 / 1024")
mem_no_total=$(bc <<< "scale=2; $memory_no_ttl / 1024 / 1024")

# Ensure new line after progress bar
echo ""

# Print summary and total elapsed time
END_TIME=$(date +%s)
TOTAL_ELAPSED=$(( END_TIME - START_TIME ))
printf "Done. Total elapsed time: %02d:%02d:%02d\n" \
        $(( TOTAL_ELAPSED/3600 )) $(( (TOTAL_ELAPSED%3600)/60 )) $(( TOTAL_ELAPSED%60 ))

echo "Keys with TTL: $count_with_ttl, uses ≈ $mem_with_total MB"
echo "Keys without TTL: $count_no_ttl, uses ≈ $mem_no_total MB"
