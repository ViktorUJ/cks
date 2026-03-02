#!/bin/bash
# for loading please use :
# source k8i.sh

# Check if script is being sourced or executed directly
if ! (return 0 2>/dev/null); then
  echo "Error: This script must be sourced, not executed directly."
  echo "Usage: source $0"
  exit 1
fi

# Colors are produced inline by colorize_load(); no global constants needed

# Cache file location
CACHE_FILE="/tmp/k8s_nodes_cache.json"
# Pods cache file location
PODS_CACHE_FILE="/tmp/k8s_pods_cache.json"

# Kube context set by --context flag; empty means use current context
K8I_CONTEXT=""

# Wrapper for kubectl to apply --context when set
kc() {
  # If K8I_CONTEXT is set and non-empty, include --context arg, otherwise call kubectl as-is.
  if [ -n "$K8I_CONTEXT" ]; then
    kubectl --context "$K8I_CONTEXT" "$@"
  else
    kubectl "$@"
  fi
}

# Default color policy: enable colors by default in all shells.
# Users can disable with --color false or K8I_NO_COLOR=1.

# Debug is off by default unless K8I_DEBUG is set; no action needed here.

# Debug logging helper (disabled by default unless K8I_DEBUG is set)
log_debug() {
  if [ -n "$K8I_DEBUG" ]; then
    # Print to stderr
    printf "%s\n" "$*" >&2
  fi
}

# Function to compute human-readable age from ISO timestamp
compute_age() {
  local created="$1"
  if [ -z "$created" ] || [ "$created" = "null" ]; then
    echo "x"
    return
  fi
  local now_epoch created_epoch diff_seconds
  now_epoch=$(date +%s 2>/dev/null)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    created_epoch=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$created" +%s 2>/dev/null || date -jf "%Y-%m-%dT%T%z" "$created" +%s 2>/dev/null)
  else
    created_epoch=$(date -d "$created" +%s 2>/dev/null)
  fi
  if [ -z "$created_epoch" ] || [ -z "$now_epoch" ]; then
    echo "x"
    return
  fi
  diff_seconds=$((now_epoch - created_epoch))
  if [ "$diff_seconds" -lt 0 ]; then diff_seconds=0; fi
  local days=$((diff_seconds / 86400))
  local hours=$(( (diff_seconds % 86400) / 3600 ))
  local minutes=$(( (diff_seconds % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    echo "${days}d${hours}h"
  elif [ "$hours" -gt 0 ]; then
    echo "${hours}h${minutes}m"
  else
    echo "${minutes}m"
  fi
}

# Function to show progress bar
show_progress() {
  local current=$1
  local total=$2
  local message="$3"
  # Skip progress output when explicitly suppressed (e.g., hard no-trace)
  if [ -n "${K8I_SUPPRESS_PROGRESS-}" ]; then
    return
  fi
  local width=50
  local percentage=$((current * 100 / total))
  local completed=$((current * width / total))
  local remaining=$((width - completed))

  printf "\r%s [" "$message" >&2
  printf "%*s" $completed | tr ' ' '=' >&2
  printf "%*s" $remaining | tr ' ' '-' >&2
  printf "] %d%% (%d/%d)" $percentage $current $total >&2

  if [ $current -eq $total ]; then
    printf "\n" >&2
  fi
}

# Function to colorize load percentage
colorize_load() {
  local load=$1
  if [[ $load =~ ^[0-9]+$ ]]; then
    if [ $load -lt 10 ]; then
      load=$(printf "%02d" "$load")
    fi
    if [ -n "$K8I_NO_COLOR" ]; then
      printf "%s%%" "$load"
      return
    fi
    if [ "$load" -gt 80 ]; then
      printf "\033[0;31m%s%%\033[0m" "$load"
    elif [ "$load" -gt 60 ]; then
      printf "\033[1;33m%s%%\033[0m" "$load"
    else
      printf "\033[0;32m%s%%\033[0m" "$load"
    fi
  else
    # Non-numeric input: print as-is, no color
    printf "%s" "$load"
  fi
}

# Function to collect and cache pods data per node
cache_pods_data() {
  # Get only required pod data: node assignment and pod count using jsonpath
  show_progress 0 1 "Collecting pods data..."

  # Use jsonpath to get only nodeName - much faster than custom-columns
  kc get pods --all-namespaces --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null | \
    grep -v '^$' | sort | uniq -c | \
    awk '{print "{\"node\": \"" $2 "\", \"pods\": " $1 "}"}' | \
    jq -s '.' > "$PODS_CACHE_FILE"

  show_progress 1 1 "Collecting pods data..."
}

# Function to get ISO timestamp (compatible with both Linux and macOS)
get_iso_timestamp() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - use UTC format that works consistently
    date -u +"%Y-%m-%dT%H:%M:%SZ"
  else
    # Linux
    date -Iseconds
  fi
}

# Function to collect and cache node data
cache_node_data() {
  local label_selector="$1"

  # Suppress xtrace/verbose locally to avoid leaking assignments/echo
  local __had_xtrace_cache=0 __had_verbose_cache=0
  if [ -n "${ZSH_VERSION-}" ]; then
    if [[ -o xtrace ]]; then __had_xtrace_cache=1; fi
    if [[ -o verbose ]]; then __had_verbose_cache=1; fi
    setopt noxtrace
    setopt noverbose
  else
    case "$-" in *x*) __had_xtrace_cache=1;; esac
    case "$-" in *v*) __had_verbose_cache=1;; esac
    set +x
    set +v
  fi

  # Cache pods data once before processing nodes
  cache_pods_data

  # Get list of nodes and their status, then filter Ready ones
  local all_nodes_data

  # First, get the raw nodes data with better error handling
  log_debug "Debug: Fetching nodes data..."
  if [ ! -z "$label_selector" ]; then
    all_nodes_data=$(kc get nodes -l "$label_selector" -o json 2>/dev/null)
  else
    all_nodes_data=$(kc get nodes -o json 2>/dev/null)
  fi

  if [ -z "$all_nodes_data" ] || [ "$all_nodes_data" = "null" ]; then
    echo "Error: Failed to get nodes data from kubectl" >&2
    return 1
  fi

  # Extract Ready node names with improved jq query
  local ready_nodes
  ready_nodes=$(echo "$all_nodes_data" | jq -r '
    .items[] |
    select(
      .status.conditions[]? |
      select(.type=="Ready" and .status=="True")
    ) |
    .metadata.name' 2>/dev/null)

  # Add debugging output for raw nodes data
  if [ -n "$K8I_DEBUG" ]; then
    printf "%s\n" "Debug: Raw ready_nodes output:" >&2
    echo "$ready_nodes" | od -c >&2
    printf "%s\n" "Debug: End raw output" >&2
  fi

  # Debug output
  log_debug "Debug: Found Ready nodes:"
  if [ -n "$K8I_DEBUG" ]; then echo "$ready_nodes" >&2; fi
  local node_count
  node_count=$(echo "$ready_nodes" | grep -v '^$' | wc -l | tr -d ' ')
  log_debug "Debug: Total Ready nodes: $node_count"

  # Create array using robust while-read loop (works in bash and zsh)
  local nodes_array=()
  if [ -n "$ready_nodes" ]; then
    while IFS= read -r line; do
      if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*$ ]]; then
        nodes_array+=("$line")
      fi
    done < <(printf '%s\n' "$ready_nodes")
  fi

  local total_nodes=${#nodes_array[@]}
  log_debug "Debug: Array length: $total_nodes"
  log_debug "Debug: Array contents:"
  # Print elements safely without assuming 0-based indexing
  local __idx=1
  for __n in "${nodes_array[@]}"; do
    log_debug "Debug: nodes_array[$__idx] = '${__n}'"
    __idx=$((__idx+1))
  done

  # Additional validation: remove any remaining empty elements
  local clean_array=()
  for node in "${nodes_array[@]}"; do
    if [[ -n "$node" && ! "$node" =~ ^[[:space:]]*$ ]]; then
      clean_array+=("$node")
    fi
  done
  nodes_array=("${clean_array[@]}")

  total_nodes=${#nodes_array[@]}
  log_debug "Debug: Array length after cleaning: $total_nodes"
  log_debug "Debug: Array contents after cleaning:"
  __idx=1
  for __n in "${nodes_array[@]}"; do
    log_debug "Debug: nodes_array[$__idx] = '${__n}'"
    __idx=$((__idx+1))
  done

  # Collect all node data in batch to optimize performance
  show_progress 0 4 "Collecting cluster data..."

  # Use the same all_nodes_data we already fetched
  local all_nodes_capacity="$all_nodes_data"

  if [ -z "$all_nodes_capacity" ] || [ "$all_nodes_capacity" = "null" ]; then
    echo "Error: Failed to get nodes capacity data" >&2
    return 1
  fi

  show_progress 1 4 "Collecting cluster data..."
  local all_nodes_usage
  all_nodes_usage=$(kc top nodes --no-headers 2>/dev/null)

  # Get all pods resource requests/limits using jq instead of complex awk
  show_progress 2 4 "Collecting cluster data..."
  local all_pods_resources
  all_pods_resources=$(kc get pods --all-namespaces --field-selector=status.phase=Running -o json 2>/dev/null | \
    jq -r '[
      .items[] |
      {
        node: (.spec.nodeName // "unscheduled"),
        total_cpu_requests: ([.spec.containers[]?.resources.requests.cpu // "0"] | map(
          if test("m$") then (sub("m$"; "") | tonumber)
          elif test("^[0-9.]+$") then (tonumber * 1000)
          else 0 end
        ) | add // 0),
        total_cpu_limits: ([.spec.containers[]?.resources.limits.cpu // "0"] | map(
          if test("m$") then (sub("m$"; "") | tonumber)
          elif test("^[0-9.]+$") then (tonumber * 1000)
          else 0 end
        ) | add // 0),
        total_memory_requests: ([.spec.containers[]?.resources.requests.memory // "0"] | map(
          if test("Gi$") then (sub("Gi$"; "") | tonumber)
          elif test("Mi$") then (sub("Mi$"; "") | tonumber / 1024)
          elif test("Ki$") then (sub("Ki$"; "") | tonumber / 1048576)
          else 0 end
        ) | add // 0),
        total_memory_limits: ([.spec.containers[]?.resources.limits.memory // "0"] | map(
          if test("Gi$") then (sub("Gi$"; "") | tonumber)
          elif test("Mi$") then (sub("Mi$"; "") | tonumber / 1024)
          elif test("Ki$") then (sub("Ki$"; "") | tonumber / 1048576)
          else 0 end
        ) | add // 0)
      }
    ] |
    group_by(.node) |
    map({
      node: .[0].node,
      total_cpu_requests: (map(.total_cpu_requests) | add),
      total_cpu_limits: (map(.total_cpu_limits) | add),
      total_memory_requests: (map(.total_memory_requests) | add),
      total_memory_limits: (map(.total_memory_limits) | add)
    })')

  if [ -z "$all_pods_resources" ]; then
    echo "Warning: Failed to get pods resources data, continuing with zeros" >&2
    all_pods_resources="[]"
  fi

  show_progress 3 4 "Collecting cluster data..."

  # Fetch Karpenter nodeclaims (non-fatal if CRD doesn't exist)
  local all_nodeclaims
  all_nodeclaims=$(kc get nodeclaims.karpenter.sh -o json 2>/dev/null | \
    jq -r '[.items[] | {name: .metadata.name, nodeName: (.status.nodeName // "")}]' 2>/dev/null)
  if [ -z "$all_nodeclaims" ] || [ "$all_nodeclaims" = "null" ]; then
    all_nodeclaims="[]"
  fi

  # Start JSON structure
  echo "{" > "$CACHE_FILE"
  echo "  \"timestamp\": \"$(get_iso_timestamp)\"," >> "$CACHE_FILE"
  echo "  \"label_selector\": \"$label_selector\"," >> "$CACHE_FILE"
  echo "  \"nodes\": [" >> "$CACHE_FILE"

  local first_node=true
  local node_counter=0
  local successful_nodes=0

  # Iterate over nodes safely for both bash and zsh (value-based loop)
  local i=0
  for node in "${nodes_array[@]}"; do
    i=$((i+1))

    log_debug "Debug: Processing node $i/${#nodes_array[@]}: '$node'"

    # Skip empty node names - more robust check
    if [ -z "$node" ] || [[ "$node" =~ ^[[:space:]]*$ ]]; then
      log_debug "Debug: Skipping empty or whitespace-only node at index $i"
      continue
    fi

    node_counter=$((node_counter + 1))
    show_progress $node_counter $total_nodes "Processing nodes..."

    # Extract node capacity data for this node directly (avoid storing large JSON in a variable)
    # Validate node exists in the JSON
    if ! echo "$all_nodes_capacity" | jq -e -r ".items[] | select(.metadata.name==\"$node\") | .metadata.name" >/dev/null 2>&1; then
      log_debug "Debug: No data found for node '$node'"
      continue
    fi

    log_debug "Debug: Successfully located data for node '$node'"

    # Silence any shell xtrace output during jq/command-heavy extraction (keeps stdout for assignments)
    {
      max_pods=$(echo "$all_nodes_capacity" | jq -r ".items[] | select(.metadata.name==\"$node\") | .status.capacity.pods // \"0\"" 2>/dev/null)
      cpu_capacity_raw=$(echo "$all_nodes_capacity" | jq -r ".items[] | select(.metadata.name==\"$node\") | .status.capacity.cpu // \"0\"" 2>/dev/null)
      memory_capacity_raw=$(echo "$all_nodes_capacity" | jq -r ".items[] | select(.metadata.name==\"$node\") | .status.capacity.memory // \"0\"" 2>/dev/null)

      node_labels=$(echo "$all_nodes_capacity" | jq -r ".items[] | select(.metadata.name==\"$node\") | .metadata.labels" 2>/dev/null)
      provider_id=$(echo "$all_nodes_capacity" | jq -r ".items[] | select(.metadata.name==\"$node\") | .spec.providerID // \"\"" 2>/dev/null)

      # Try to extract EC2 instance ID from providerID (AWS, i-...)
      ec2_id=""
      if [ -n "$provider_id" ]; then
        clean_provider_id=$(printf "%s" "$provider_id" | tr -d '\n')
        ec2_id=$(printf "%s" "$clean_provider_id" | grep -o 'i-[A-Za-z0-9-]*$')
        if [ -z "$ec2_id" ]; then
          ec2_id=$(printf "%s" "$clean_provider_id" | awk -F'/' '{print $NF}' | grep '^i-')
        fi
      fi
    } 2>/dev/null

    # Extract nodeclaim and node age
    {
      # Look up nodeclaim name by matching node name in cached nodeclaims data
      nodeclaim=$(echo "$all_nodeclaims" | jq -r --arg n "$node" '
        map(select(.nodeName == $n)) | if length > 0 then .[0].name else "x" end
      ' 2>/dev/null)
      if [ -z "$nodeclaim" ] || [ "$nodeclaim" = "null" ]; then nodeclaim="x"; fi
      # Trim nodeclaim to 20 chars
      nodeclaim="${nodeclaim:0:20}"

      creation_ts=$(echo "$all_nodes_capacity" | jq -r ".items[] | select(.metadata.name==\"$node\") | .metadata.creationTimestamp // \"\"" 2>/dev/null)
      node_age=$(compute_age "$creation_ts")

      # Store epoch for numeric sorting by age
      if [ -n "$creation_ts" ] && [ "$creation_ts" != "null" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
          creation_epoch=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$creation_ts" +%s 2>/dev/null || echo "0")
        else
          creation_epoch=$(date -d "$creation_ts" +%s 2>/dev/null || echo "0")
        fi
      else
        creation_epoch="0"
      fi
    } 2>/dev/null

    log_debug "Debug: Node '$node' capacity data: pods=$max_pods, cpu=$cpu_capacity_raw, memory=$memory_capacity_raw"

    # Validate capacity data before proceeding with better validation
    if [ -z "$max_pods" ] || [ "$max_pods" = "null" ] || [ "$max_pods" = "0" ] ||
       [ -z "$cpu_capacity_raw" ] || [ "$cpu_capacity_raw" = "null" ] || [ "$cpu_capacity_raw" = "0" ] ||
       [ -z "$memory_capacity_raw" ] || [ "$memory_capacity_raw" = "null" ] || [ "$memory_capacity_raw" = "0" ]; then
      echo "Warning: Could not get capacity data for node '$node', skipping" >&2
      log_debug "Debug: max_pods=$max_pods, cpu=$cpu_capacity_raw, memory=$memory_capacity_raw"
      continue
    fi

    # Only add comma if this is not the first successful node
    if [ "$first_node" = false ]; then
      echo "," >> "$CACHE_FILE"
    fi
    first_node=false
    successful_nodes=$((successful_nodes + 1))

    log_debug "Debug: Successfully processing node '$node' ($successful_nodes total)"

    # (node_labels, provider_id and ec2_id were extracted earlier in a silenced block)
    # Use those values here; no duplicate extraction to avoid shell xtrace leaks.

    # Extract label values
    arch=$(echo "$node_labels" | jq -r '. ["kubernetes.io/arch"] // "unknown"' 2>/dev/null)
    zone=$(echo "$node_labels" | jq -r '. ["topology.kubernetes.io/zone"] // "unknown"' 2>/dev/null)
    # Extract only last 2 characters from zone (e.g. "1a" from "eu-west-1a")
    short_zone="${zone: -2}"
    instance_type=$(echo "$node_labels" | jq -r '. ["node.kubernetes.io/instance-type"] // "unknown"' 2>/dev/null)

    # Try primary and alternative Karpenter labels for capacity type
    capacity_type=$(echo "$node_labels" | jq -r '. ["karpenter.sh/capacity-type"] // "null"' 2>/dev/null)
    if [ "$capacity_type" = "null" ] || [ "$capacity_type" = "unknown" ]; then
      capacity_type=$(echo "$node_labels" | jq -r '. ["karpenter.k8s.aws/capacity-type"] // "null"' 2>/dev/null)
      if [ "$capacity_type" = "null" ] || [ "$capacity_type" = "unknown" ]; then
        # Try spotinst.io label for capacity type
        capacity_type=$(echo "$node_labels" | jq -r '. ["spotinst.io/node-lifecycle"] // "null"' 2>/dev/null)
        if [ "$capacity_type" = "null" ] || [ "$capacity_type" = "unknown" ]; then
          # Try EKS specific label for capacity type
          eks_capacity=$(echo "$node_labels" | jq -r '. ["eks.amazonaws.com/capacityType"] // "null"' 2>/dev/null)
          if [ "$eks_capacity" = "ON_DEMAND" ]; then
            capacity_type="od"
          else
            capacity_type="x"
          fi
        fi
      fi
    fi

    # Normalize capacity type - replace any variant of on-demand with od (use tr for case conversion)
    capacity_type_lower=$(echo "$capacity_type" | tr '[:upper:]' '[:lower:]')
    if [[ "$capacity_type_lower" =~ ^on-?demand$ ]] || [ "$capacity_type_lower" = "on demand" ] || [ "$capacity_type_lower" = "ondemand" ] || [ "$capacity_type" = "ON_DEMAND" ]; then
      capacity_type="od"
    fi

    # Try primary and alternative Karpenter labels for nodepool
    node_pool=$(echo "$node_labels" | jq -r '. ["karpenter.sh/nodepool"] // "null"' 2>/dev/null)
    if [ "$node_pool" = "null" ] || [ "$node_pool" = "unknown" ]; then
      node_pool=$(echo "$node_labels" | jq -r '. ["karpenter.k8s.aws/nodepool"] // "null"' 2>/dev/null)
      if [ "$node_pool" = "null" ] || [ "$node_pool" = "unknown" ]; then
        # Try spotinst.io label for nodepool
        node_pool=$(echo "$node_labels" | jq -r '. ["spotinst.io/ocean-vng-id"] // "null"' 2>/dev/null)
        if [ "$node_pool" = "null" ] || [ "$node_pool" = "unknown" ]; then
          # Try EKS nodegroup label and truncate to 15 chars
          eks_nodegroup=$(echo "$node_labels" | jq -r '. ["eks.amazonaws.com/nodegroup"] // "null"' 2>/dev/null)
          if [ "$eks_nodegroup" != "null" ] && [ "$eks_nodegroup" != "unknown" ]; then
            # Trim to 15 characters
            node_pool="${eks_nodegroup:0:15}"
          else
            node_pool="x"
          fi
        fi
      fi
    fi

    # Build node_info only from the ec2_id determined above
    node_info="${ec2_id}/${instance_type}/${capacity_type}/${arch}/${short_zone}/${node_pool}/${nodeclaim}/${node_age}"

    # Get pods count from cache
    current_pods=$(read_cached_pods_count "$node")

    # Validate capacity data
    if [ -z "$cpu_capacity_raw" ] || [ "$cpu_capacity_raw" = "null" ] || [ -z "$memory_capacity_raw" ] || [ "$memory_capacity_raw" = "null" ]; then
      echo "Warning: Could not get capacity data for $node" >&2
      continue
    fi

    # Convert capacity to standard units with error handling
    if [[ $cpu_capacity_raw =~ ^[0-9]+\.?[0-9]*$ ]]; then
      cpu_capacity_cores=$(echo "scale=0; $cpu_capacity_raw / 1" | bc 2>/dev/null)  # Round to integer
      cpu_capacity_m=$(echo "$cpu_capacity_raw * 1000" | bc 2>/dev/null | cut -d'.' -f1)
    else
      cpu_capacity_cores="0"
      cpu_capacity_m="0"
    fi

    if [[ $memory_capacity_raw == *"Ki" ]]; then
      memory_value=$(echo $memory_capacity_raw | sed 's/Ki//')
      if [[ $memory_value =~ ^[0-9]+$ ]]; then
        memory_capacity_gb=$(echo "scale=1; $memory_value / 1048576" | bc 2>/dev/null)
      else
        memory_capacity_gb="0.0"
      fi
    else
      memory_capacity_gb="0.0"
    fi

    # Get resource allocation data from batch pods resources instead of kubectl describe
    cpu_requests_m=$(echo "$all_pods_resources" | jq -r ".[] | select(.node==\"$node\") | .total_cpu_requests // 0" 2>/dev/null)
    cpu_limits_m=$(echo "$all_pods_resources" | jq -r ".[] | select(.node==\"$node\") | .total_cpu_limits // 0" 2>/dev/null)
    cpu_requests_cores=$(echo "scale=1; $cpu_requests_m / 1000" | bc 2>/dev/null)
    cpu_limits_cores=$(echo "scale=1; $cpu_limits_m / 1000" | bc 2>/dev/null)
    memory_requests_gb=$(echo "$all_pods_resources" | jq -r ".[] | select(.node==\"$node\") | .total_memory_requests // 0" 2>/dev/null)
    memory_limits_gb=$(echo "$all_pods_resources" | jq -r ".[] | select(.node==\"$node\") | .total_memory_limits // 0" 2>/dev/null)

    # Ensure we have valid numeric values with rounding to 1 decimal place
    cpu_requests_m=${cpu_requests_m:-0}
    cpu_limits_m=${cpu_limits_m:-0}
    cpu_requests_cores=$(echo "scale=1; ${cpu_requests_cores:-0} / 1" | bc 2>/dev/null)
    cpu_limits_cores=$(echo "scale=1; ${cpu_limits_cores:-0} / 1" | bc 2>/dev/null)

    # Round memory values to 1 decimal place
    memory_requests_gb=$(echo "scale=1; ${memory_requests_gb:-0} / 1" | bc 2>/dev/null)
    memory_limits_gb=$(echo "scale=1; ${memory_limits_gb:-0} / 1" | bc 2>/dev/null)

    # Extract usage data from batch
    usage_line=$(echo "$all_nodes_usage" | grep "^$node ")
    if [ ! -z "$usage_line" ]; then
      cpu_usage_raw=$(echo "$usage_line" | awk '{print $2}')
      memory_usage_raw=$(echo "$usage_line" | awk '{print $4}')

      # Convert CPU usage to cores with rounding
      if [[ $cpu_usage_raw == *"m" ]]; then
        cpu_usage_m=${cpu_usage_raw%m}
        cpu_usage_cores=$(echo "scale=1; $cpu_usage_m / 1000" | bc 2>/dev/null)
      elif [[ $cpu_usage_raw =~ ^[0-9]+\.?[0-9]*$ ]]; then
        cpu_usage_m=$(echo "$cpu_usage_raw * 1000" | bc 2>/dev/null | cut -d'.' -f1)
        cpu_usage_cores=$(echo "scale=1; $cpu_usage_raw / 1" | bc 2>/dev/null)
        if [ -z "$cpu_usage_m" ]; then
          cpu_usage_m="0"
          cpu_usage_cores="0.0"
        fi
      else
        cpu_usage_m="0"
        cpu_usage_cores="0.0"
      fi

      # Convert memory usage to GB with rounding to 1 decimal place
      if [[ $memory_usage_raw == *"Mi" ]]; then
        memory_value=${memory_usage_raw%Mi}
        if [[ $memory_value =~ ^[0-9]+\.?[0-9]*$ ]]; then
          memory_usage_gb=$(echo "scale=1; $memory_value / 1024" | bc 2>/dev/null)
          if [ -z "$memory_usage_gb" ]; then
            memory_usage_gb="0.0"
          fi
        else
          memory_usage_gb="0.0"
        fi
      elif [[ $memory_usage_raw == *"Gi" ]]; then
        memory_usage_gb=$(echo "scale=1; ${memory_usage_raw%Gi} / 1" | bc 2>/dev/null)
      elif [[ $memory_usage_raw == *"Ki" ]]; then
        memory_value=${memory_usage_raw%Ki}
        if [[ $memory_value =~ ^[0-9]+$ ]]; then
          memory_usage_gb=$(echo "scale=1; $memory_value / 1048576" | bc 2>/dev/null)
          if [ -z "$memory_usage_gb" ]; then
            memory_usage_gb="0.0"
          fi
        else
          memory_usage_gb="0.0"
        fi
      else
        memory_usage_gb="0.0"
      fi

      # Calculate load percentages with validation
      if [[ $cpu_capacity_m =~ ^[0-9]+$ ]] && [ "$cpu_capacity_m" -gt 0 ] && [[ $cpu_usage_m =~ ^[0-9]+$ ]] && [ "$cpu_usage_m" -gt 0 ]; then
        cpu_load_percent=$(echo "scale=0; $cpu_usage_m * 100 / $cpu_capacity_m" | bc 2>/dev/null)
        if [ -z "$cpu_load_percent" ]; then
          cpu_load_percent="0"
        fi
      else
        cpu_load_percent="0"
      fi

      if [[ $memory_capacity_gb =~ ^[0-9]+\.?[0-9]*$ ]] && [ "$(echo "$memory_capacity_gb > 0" | bc 2>/dev/null)" = "1" ] && [[ $memory_usage_gb =~ ^[0-9]+\.?[0-9]*$ ]] && [ "$(echo "$memory_usage_gb > 0" | bc 2>/dev/null)" = "1" ]; then
        memory_load_percent=$(echo "scale=0; $memory_usage_gb * 100 / $memory_capacity_gb" | bc 2>/dev/null)
        if [ -z "$memory_load_percent" ]; then
          memory_load_percent="0"
        fi
      else
        memory_load_percent="0"
      fi
    else
      echo "  Warning: kubectl top failed for node $node" >&2
      cpu_usage_m="0"
      cpu_usage_cores="0.0"
      memory_usage_gb="0.0"
      cpu_load_percent="0"
      memory_load_percent="0"
    fi

    # Write processed data to JSON array format - store both millicores and cores
    cat >> "$CACHE_FILE" << EOF
    {
      "name": "$node",
      "max_pods": "$max_pods",
      "current_pods": "$current_pods",
      "cpu_capacity_m": "$cpu_capacity_m",
      "cpu_capacity_cores": "$cpu_capacity_cores",
      "memory_capacity_gb": "$memory_capacity_gb",
      "cpu_requests_m": "$cpu_requests_m",
      "cpu_limits_m": "$cpu_limits_m",
      "cpu_requests_cores": "$cpu_requests_cores",
      "cpu_limits_cores": "$cpu_limits_cores",
      "memory_requests_gb": "$memory_requests_gb",
      "memory_limits_gb": "$memory_limits_gb",
      "cpu_usage_m": "$cpu_usage_m",
      "cpu_usage_cores": "$cpu_usage_cores",
      "memory_usage_gb": "$memory_usage_gb",
      "cpu_load_percent": "$cpu_load_percent",
      "memory_load_percent": "$memory_load_percent",
      "creation_epoch": "$creation_epoch",
      "node_info": "$node_info"
    }
EOF
  done

  # Ensure JSON structure is properly closed
  echo "" >> "$CACHE_FILE"
  echo "  ]" >> "$CACHE_FILE"
  echo "}" >> "$CACHE_FILE"

  show_progress 4 4 "Collecting cluster data..."

  log_debug "Debug: Successfully processed $successful_nodes out of $total_nodes nodes"

  # Check if we have any successful nodes
  if [ "$successful_nodes" -eq 0 ]; then
    echo "Error: No nodes were successfully processed" >&2
    log_debug "Debug: Total nodes found: $total_nodes"
    log_debug "Debug: Nodes with issues during processing: $((total_nodes - successful_nodes))"
    # Restore xtrace if it was enabled before this function
    if [ "$__had_xtrace_cache" -eq 1 ]; then set -x; fi
    return 1
  fi

  # Restore xtrace/verbose if they were enabled before this function
  if [ -n "${ZSH_VERSION-}" ]; then
    if [ "$__had_xtrace_cache" -eq 1 ]; then setopt xtrace; fi
    if [ "$__had_verbose_cache" -eq 1 ]; then setopt verbose; fi
  else
    if [ "$__had_xtrace_cache" -eq 1 ]; then set -x; fi
    if [ "$__had_verbose_cache" -eq 1 ]; then set -v; fi
  fi
}

# Function to show help for k8i
k8i_help() {
  cat << EOF
k8i - Kubernetes node information tool

Installation:
  To make k8i available in all terminal sessions, add this line to your shell config file:

  Linux (bash):
    echo 'source /path/to/k8i.sh' >> ~/.bashrc
    source ~/.bashrc

  macOS (Terminal.app):
    echo 'source /path/to/k8i.sh' >> ~/.bash_profile
    source ~/.bash_profile

    # For newer macOS with zsh as default:
    echo 'source /path/to/k8i.sh' >> ~/.zshrc
    source ~/.zshrc

  Examples:
    # Linux
    source ~/tools/k8i.sh
    source ~/work/infrastructure/scripts/k8s_toos/k8i.sh

    # macOS
    source ~/tools/k8i.sh
    source ~/Documents/infrastructure/scripts/k8s_toos/k8i.sh
    source /Users/username/tools/k8i.sh

Usage:
  k8i [OPTIONS]

Options:
  --context CONTEXT    Kubernetes context to use (if omitted current context will be used)
  --labels SELECTOR    Filter nodes by label selector (e.g. 'worker-type=spot')
  --filter FILTER      Filter output by node attributes (e.g. 'ec2_type=spot', 'ec2_type=od')
  --sort COLUMN=DIR    Sort by column (asc/desc). Columns: name, pods, cpu_req, cpu_lim, cpu_use, cpu_cap, cpu_load, mem_req, mem_lim, mem_use, mem_cap, mem_load, ec2_type, instance_type, arch, zone, pool, age
  --fargate            Show Fargate nodes (hidden by default)
  --color true|false   Force enable/disable ANSI colors for this run (overrides shell defaults)
  --debug true|false   Enable or disable debug output for this run
  --help              Show this help message

Examples:
  k8i                              # Show all nodes (fargate hidden)
  k8i --fargate                    # Show all nodes including fargate
  k8i --context my-cluster         # Use kube context 'my-cluster'
  k8i --labels 'worker-type=spot'  # Show only spot nodes
  k8i --filter 'ec2_type=spot'     # Show only spot instances in output
  k8i --filter 'ec2_type=od'       # Show only on-demand instances in output
  k8i --sort 'cpu_load=desc'       # Sort by CPU load descending
  k8i --sort 'mem_use=asc'         # Sort by memory usage ascending
  k8i --sort 'pods=desc'           # Sort by pod count descending
  k8i --sort 'ec2_type=asc'        # Sort by EC2 capacity type (od, spot)
  k8i --sort 'instance_type=desc'  # Sort by instance type
  k8i --sort 'zone=asc'            # Sort by availability zone
  k8i --sort 'age=asc'             # Sort by node age (youngest first)
  k8i --sort 'age=desc'            # Sort by node age (oldest first)

Combined example:
  k8i --sort 'mem_load=asc' --filter 'ec2_type=spot' --labels 'work_type=default'

  This command demonstrates using all three options together:
  1. --labels 'work_type=default'   : First, select only nodes with Kubernetes label 'work_type=default'
  2. --filter 'ec2_type=spot'       : Then, from those nodes show only spot instances in the output
  3. --sort 'mem_load=asc'          : Finally, sort the results by memory load in ascending order

  Order of operations: labels → filter → sort
  - Labels filter is applied at the Kubernetes API level during node selection
  - Filter is applied to the output data after collection
  - Sort is applied last to arrange the final results

Description:
  Displays detailed information about Kubernetes nodes including:
  - Pod usage (current/max)
  - CPU resources (requests/limits/usage/capacity)
  - Memory resources (requests/limits/usage/capacity)
  - Load percentages with color coding
  - Node metadata (instance type, capacity type, zone, etc.)

Filter format:
  --filter 'attribute=value' where attribute can be:
  - ec2_type: spot, od, x
  - instance_type: m5.large, c5.xlarge, etc.
  - arch: amd64, arm64
  - zone: 1a, 1b, etc. (last 2 characters)
  - pool: nodepool name
  - nodeclaim: Karpenter nodeclaim name

Sort format:
  --sort 'column=direction' where:
  - column: name, pods, cpu_req, cpu_lim, cpu_use, cpu_cap, cpu_load, mem_req, mem_lim, mem_use, mem_cap, mem_load, ec2_type, instance_type, arch, zone, pool, age
  - direction: asc (ascending) or desc (descending)

EOF
}

# Function to read node data from cache
read_cached_data() {
  local node_name="$1"
  local field="$2"

  if [ ! -f "$CACHE_FILE" ]; then
    echo "Cache file not found. Please run with --refresh first." >&2
    return 1
  fi

  # Use jq to extract data robustly (return default '0' if node or field is missing)
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg name "$node_name" --arg field "$field" '
      (.nodes // [])
      | (map(select(.name == $name)) | if length > 0 then (.[0][$field] // "0") else "0" end)
    ' "$CACHE_FILE" 2>/dev/null
  else
    # Fallback parsing without jq - find node block and extract field
    awk -v node="$node_name" -v field="$field" '
      BEGIN { in_node = 0; found = 0 }
      /"name": "/ && $0 ~ node { in_node = 1; next }
      in_node && /}/ { in_node = 0; next }
      in_node && $0 ~ "\"" field "\":" {
        gsub(/[",]/, "", $2);
        print $2;
        found = 1;
        exit
      }
      END { if (!found) print "0" }
    ' "$CACHE_FILE"
  fi
}

# Function to get cached node list
get_cached_nodes() {
  if [ ! -f "$CACHE_FILE" ]; then
    echo "Cache file not found." >&2
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -r '.nodes[].name' "$CACHE_FILE" 2>/dev/null
  else
    # Fallback parsing without jq
    grep '"name":' "$CACHE_FILE" | cut -d'"' -f4
  fi
}

# Function to read pods count for a node from cache
read_cached_pods_count() {
  local node_name="$1"
  if [ ! -f "$PODS_CACHE_FILE" ]; then
    echo "0"
    return
  fi
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg name "$node_name" '
      (.[0] | null) as $dummy
      | (map(select(.node == $name)) | if length > 0 then (.[0].pods // 0) else 0 end)
    ' "$PODS_CACHE_FILE" 2>/dev/null
  else
    # Fallback parsing without jq
    count=$(grep -n "\"node\": \"$node_name\"" "$PODS_CACHE_FILE" | wc -l | tr -d ' ')
    if [ "$count" = "0" ]; then
      echo "0"
    else
      grep "\"node\": \"$node_name\"" "$PODS_CACHE_FILE" -A 1 | grep '"pods":' | awk '{print $2}' | tr -d ','
    fi
  fi
}

# Function to apply filters to node data
apply_filter() {
  local filter="$1"
  local node_info="$2"

  if [ -z "$filter" ]; then
    return 0  # No filter, show all
  fi

  # Parse filter in format 'attribute=value'
  if [[ ! "$filter" =~ ^[^=]+=[^=]+$ ]]; then
    echo "Error: Filter format should be 'attribute=value'" >&2
    return 1
  fi

  local filter_attr="${filter%=*}"
  local filter_value="${filter#*=}"

  # Parse node_info: ec2_id/instance_type/capacity_type/arch/zone/pool/nodeclaim/age
  ec2_id=$(printf '%s' "$node_info" | cut -d'/' -f1)
  instance_type=$(printf '%s' "$node_info" | cut -d'/' -f2)
  capacity_type=$(printf '%s' "$node_info" | cut -d'/' -f3)
  arch=$(printf '%s' "$node_info" | cut -d'/' -f4)
  zone=$(printf '%s' "$node_info" | cut -d'/' -f5)
  pool=$(printf '%s' "$node_info" | cut -d'/' -f6)
  nodeclaim=$(printf '%s' "$node_info" | cut -d'/' -f7)

  case "$filter_attr" in
    "ec2_type")
      if [ "$filter_value" = "spot" ] && [ "$capacity_type" = "spot" ]; then
        return 0
      elif [ "$filter_value" = "od" ] && [ "$capacity_type" = "od" ]; then
        return 0
      else
        return 1
      fi
      ;;
    "instance_type")
      if [ "$instance_type" = "$filter_value" ]; then
        return 0
      else
        return 1
      fi
      ;;
    "arch")
      if [ "$arch" = "$filter_value" ]; then
        return 0
      else
        return 1
      fi
      ;;
    "zone")
      if [ "$zone" = "$filter_value" ]; then
        return 0
      else
        return 1
      fi
      ;;
    "pool")
      if [ "$pool" = "$filter_value" ]; then
        return 0
      else
        return 1
      fi
      ;;
    "nodeclaim")
      if [ "$nodeclaim" = "$filter_value" ]; then
        return 0
      else
        return 1
      fi
      ;;
    *)
      echo "Error: Unknown filter attribute '$filter_attr'" >&2
      echo "Supported attributes: ec2_type, instance_type, arch, zone, pool, nodeclaim" >&2
      return 1
      ;;
  esac
}

# Helper: jq-based sorting for numeric columns
_sort_nodes_jq_numeric() {
  local nodes_list="$1"  # space/newline separated node names
  local json_field="$2"  # field name in JSON under .nodes[]
  local direction="$3"    # asc|desc

  command -v jq >/dev/null 2>&1 || return 2

  # Build JSON array of node names
  local names_json
  names_json=$(printf '%s\n' "$nodes_list" | tr ' ' '\n' | sed '/^$/d' | jq -R -s 'split("\n") | map(select(length>0))') || return 1

  # Sort using jq and emit names only
  if [ "$direction" = "desc" ]; then
    jq -r --argjson names "$names_json" --arg f "$json_field" '
      (.nodes // [])
      | map(select(.name as $n | $names | index($n)))
      | sort_by(.[$f] | tonumber)
      | reverse
      | .[].name
    ' "$CACHE_FILE"
  else
    jq -r --argjson names "$names_json" --arg f "$json_field" '
      (.nodes // [])
      | map(select(.name as $n | $names | index($n)))
      | sort_by(.[$f] | tonumber)
      | .[].name
    ' "$CACHE_FILE"
  fi
}

# Function to sort nodes based on specified criteria
sort_nodes() {
  local nodes="$1"
  local sort_spec="$2"

  if [ -z "$sort_spec" ]; then
    echo "$nodes"
    return 0
  fi

  # Parse sort specification: column=direction
  if [[ ! "$sort_spec" =~ ^[^=]+=(asc|desc)$ ]]; then
    echo "Error: Sort format should be 'column=direction' (e.g., 'cpu_load=desc')" >&2
    return 1
  fi

  local sort_column="${sort_spec%=*}"
  local sort_direction="${sort_spec#*=}"

  # Validate sort column
  case "$sort_column" in
    name|pods|cpu_req|cpu_lim|cpu_use|cpu_cap|cpu_load|mem_req|mem_lim|mem_use|mem_cap|mem_load|ec2_type|instance_type|arch|zone|pool|age)
      ;;
    *)
      echo "Error: Unknown sort column '$sort_column'" >&2
      echo "Supported columns: name, pods, cpu_req, cpu_lim, cpu_use, cpu_cap, cpu_load, mem_req, mem_lim, mem_use, mem_cap, mem_load, ec2_type, instance_type, arch, zone, pool, age" >&2
      return 1
      ;;
  esac

  # If jq is available and sorting by numeric column, prefer jq-based sorting for robustness
  local numeric_field=""
  case "$sort_column" in
    pods) numeric_field="current_pods";;
    cpu_req) numeric_field="cpu_requests_cores";;
    cpu_lim) numeric_field="cpu_limits_cores";;
    cpu_use) numeric_field="cpu_usage_cores";;
    cpu_cap) numeric_field="cpu_capacity_cores";;
    cpu_load) numeric_field="cpu_load_percent";;
    mem_req) numeric_field="memory_requests_gb";;
    mem_lim) numeric_field="memory_limits_gb";;
    mem_use) numeric_field="memory_usage_gb";;
    mem_cap) numeric_field="memory_capacity_gb";;
    mem_load) numeric_field="memory_load_percent";;
    age) numeric_field="creation_epoch";;
  esac

  if [ -n "$numeric_field" ] && command -v jq >/dev/null 2>&1; then
    local jq_sorted
    jq_sorted=$(_sort_nodes_jq_numeric "$nodes" "$numeric_field" "$sort_direction") || jq_sorted=""
    if [ -n "$jq_sorted" ]; then
      echo "$jq_sorted"
      return 0
    fi
    # If jq sorting failed, fall back to shell sorter below
  fi

  # Fallback: shell-based sorting
  local temp_file
  temp_file=$(mktemp)
  local sorted_nodes=""

  # Collect data for each node and prepare for sorting (newline-safe)
  while IFS= read -r node; do
    [ -z "$node" ] && continue
    local max_pods
    max_pods=$(read_cached_data "$node" "max_pods")
    local current_pods
    current_pods=$(read_cached_pods_count "$node")
    local cpu_requests_cores
    cpu_requests_cores=$(read_cached_data "$node" "cpu_requests_cores")
    local cpu_limits_cores
    cpu_limits_cores=$(read_cached_data "$node" "cpu_limits_cores")
    local cpu_usage_cores
    cpu_usage_cores=$(read_cached_data "$node" "cpu_usage_cores")
    local cpu_capacity_cores
    cpu_capacity_cores=$(read_cached_data "$node" "cpu_capacity_cores")
    local memory_requests_gb
    memory_requests_gb=$(read_cached_data "$node" "memory_requests_gb")
    local memory_limits_gb
    memory_limits_gb=$(read_cached_data "$node" "memory_limits_gb")
    local memory_usage_gb
    memory_usage_gb=$(read_cached_data "$node" "memory_usage_gb")
    local memory_capacity_gb
    memory_capacity_gb=$(read_cached_data "$node" "memory_capacity_gb")
    local cpu_load_percent
    cpu_load_percent=$(read_cached_data "$node" "cpu_load_percent")
    local memory_load_percent
    memory_load_percent=$(read_cached_data "$node" "memory_load_percent")
    local node_info
    node_info=$(read_cached_data "$node" "node_info")

    # Parse node_info for text fields
    IFS='/' read -r ec2_id instance_type capacity_type arch zone pool nodeclaim node_age <<< "$node_info"

    # Format: node_name|sort_value
    case "$sort_column" in
      name)            echo "$node|$node" >> "$temp_file";;
      pods)            echo "$node|$current_pods" >> "$temp_file";;
      cpu_req)         echo "$node|$cpu_requests_cores" >> "$temp_file";;
      cpu_lim)         echo "$node|$cpu_limits_cores" >> "$temp_file";;
      cpu_use)         echo "$node|$cpu_usage_cores" >> "$temp_file";;
      cpu_cap)         echo "$node|$cpu_capacity_cores" >> "$temp_file";;
      cpu_load)        echo "$node|$cpu_load_percent" >> "$temp_file";;
      mem_req)         echo "$node|$memory_requests_gb" >> "$temp_file";;
      mem_lim)         echo "$node|$memory_limits_gb" >> "$temp_file";;
      mem_use)         echo "$node|$memory_usage_gb" >> "$temp_file";;
      mem_cap)         echo "$node|$memory_capacity_gb" >> "$temp_file";;
      mem_load)        echo "$node|$memory_load_percent" >> "$temp_file";;
      ec2_type)        echo "$node|$capacity_type" >> "$temp_file";;
      instance_type)   echo "$node|$instance_type" >> "$temp_file";;
      arch)            echo "$node|$arch" >> "$temp_file";;
      zone)            echo "$node|$zone" >> "$temp_file";;
      pool)            echo "$node|$pool" >> "$temp_file";;
      age)             echo "$node|$(read_cached_data "$node" "creation_epoch")" >> "$temp_file";;
    esac
  done < <(printf '%s\n' "$nodes")

  # Sort based on direction and extract node names
  if [ "$sort_direction" = "desc" ]; then
    if [[ "$sort_column" =~ ^(name|ec2_type|instance_type|arch|zone|pool)$ ]]; then
      sorted_nodes=$(sort -t'|' -k2,2r "$temp_file" | cut -d'|' -f1)
    else
      sorted_nodes=$(sort -t'|' -k2,2n "$temp_file" | tac | cut -d'|' -f1)
    fi
  else
    if [[ "$sort_column" =~ ^(name|ec2_type|instance_type|arch|zone|pool)$ ]]; then
      sorted_nodes=$(sort -t'|' -k2,2 "$temp_file" | cut -d'|' -f1)
    else
      sorted_nodes=$(sort -t'|' -k2,2n "$temp_file" | cut -d'|' -f1)
    fi
  fi

  rm -f "$temp_file"
  echo "$sorted_nodes"
}

# Bash completion function for k8i (only flag hints)
_k8i_completion() {
  local cur opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  opts="--context --labels --filter --sort --fargate --color --debug --help -h"

  if [[ ${cur} == -* ]]; then
    # Use mapfile to avoid word-splitting and shell warnings
    mapfile -t _tmp_comps < <(compgen -W "${opts}" -- "${cur}")
    COMPREPLY=( "${_tmp_comps[@]}" )
    unset _tmp_comps
  fi
}

# Register completion function for k8i only if complete command is available
if command -v complete >/dev/null 2>&1; then
  complete -F _k8i_completion k8i
fi

# Main function to get node information
k8i() {
  local label_selector=""
  local filter=""
  local sort_spec="pool=asc"  # Default sort by pool ascending
  local color_arg=""
  local debug_arg=""
  local show_fargate=false

  # Temporarily disable xtrace/verbose to prevent leaking variable assignments
  local __had_xtrace=0 __had_verbose=0
  if [ -n "${ZSH_VERSION-}" ]; then
    if [[ -o xtrace ]]; then __had_xtrace=1; fi
    if [[ -o verbose ]]; then __had_verbose=1; fi
    setopt noxtrace
    setopt noverbose
  else
    case "$-" in *x*) __had_xtrace=1;; esac
    case "$-" in *v*) __had_verbose=1;; esac
    set +x
    set +v
  fi

  # Optional hard suppression: skip progress and force no debug for this run
  local __hard_suppress=0
  if [ -n "${K8I_HARD_NO_TRACE-}" ] || { [ -n "${ZSH_VERSION-}" ] && [ "$__had_xtrace" -eq 1 ]; }; then
    __hard_suppress=1
    export K8I_SUPPRESS_PROGRESS=1
  fi

  # Track previous env to restore after run
  local prev_K8I_DEBUG_set=0 prev_K8I_NO_COLOR_set=0 prev_K8I_FORCE_COLOR_set=0 prev_K8I_SUPPRESS_PROGRESS_set=0 prev_K8I_CONTEXT_set=0
  local prev_K8I_DEBUG="${K8I_DEBUG-}"
  local prev_K8I_NO_COLOR="${K8I_NO_COLOR-}"
  local prev_K8I_FORCE_COLOR="${K8I_FORCE_COLOR-}"
  local prev_K8I_SUPPRESS_PROGRESS="${K8I_SUPPRESS_PROGRESS-}"
  local prev_K8I_CONTEXT="${K8I_CONTEXT-}"
  if [ "${K8I_DEBUG+x}" = x ]; then prev_K8I_DEBUG_set=1; fi
  if [ "${K8I_NO_COLOR+x}" = x ]; then prev_K8I_NO_COLOR_set=1; fi
  if [ "${K8I_FORCE_COLOR+x}" = x ]; then prev_K8I_FORCE_COLOR_set=1; fi
  if [ "${K8I_SUPPRESS_PROGRESS+x}" = x ]; then prev_K8I_SUPPRESS_PROGRESS_set=1; fi
  if [ "${K8I_CONTEXT+x}" = x ]; then prev_K8I_CONTEXT_set=1; fi

  # If hard suppression requested, disable debug for this run
  if [ "$__hard_suppress" -eq 1 ]; then
    unset K8I_DEBUG
  fi

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --context)
        if [[ -n "$2" && "$2" != --* ]]; then
          K8I_CONTEXT="$2"
          shift 2
        else
          echo "Error: --context requires a value" >&2
          return 1
        fi
        ;;
      --labels)
        if [[ -n "$2" && "$2" != --* ]]; then
          label_selector="$2"
          shift 2
        else
          echo "Error: --labels requires a value" >&2
          return 1
        fi
        ;;
      --filter)
        if [[ -n "$2" && "$2" != --* ]]; then
          filter="$2"
          shift 2
        else
          echo "Error: --filter requires a value" >&2
          return 1
        fi
        ;;
      --sort)
        if [[ -n "$2" && "$2" != --* ]]; then
          sort_spec="$2"
          shift 2
        else
          echo "Error: --sort requires a value" >&2
          return 1
        fi
        ;;
      --color)
        if [[ -n "$2" && "$2" != --* ]]; then
          color_arg="$2"
          if [[ "$color_arg" != "true" && "$color_arg" != "false" ]]; then
            echo "Error: --color expects 'true' or 'false'" >&2
            return 1
          fi
          shift 2
        else
          echo "Error: --color requires a value (true|false)" >&2
          return 1
        fi
        ;;
      --debug)
        if [[ -n "$2" && "$2" != --* ]]; then
          debug_arg="$2"
          if [[ "$debug_arg" != "true" && "$debug_arg" != "false" ]]; then
            echo "Error: --debug expects 'true' or 'false'" >&2
            return 1
          fi
          shift 2
        else
          echo "Error: --debug requires a value (true|false)" >&2
          return 1
        fi
        ;;
      --fargate)
        show_fargate=true
        shift
        ;;
      --help|-h)
        k8i_help
        return 0
        ;;
      *)
        # For backward compatibility - treat first non-option argument as label selector
        if [[ -z "$label_selector" && "$1" != --* ]]; then
          label_selector="$1"
          shift
        else
          echo "Error: Unknown option '$1'" >&2
          echo "Use 'k8i --help' for usage information" >&2
          return 1
        fi
        ;;
    esac
  done

  # Apply CLI overrides for color
  if [ -n "$color_arg" ]; then
    if [ "$color_arg" = "true" ]; then
      unset K8I_NO_COLOR
      export K8I_FORCE_COLOR=1
    else
      export K8I_NO_COLOR=1
      unset K8I_FORCE_COLOR
    fi
  fi

  # Apply CLI overrides for debug
  if [ -n "$debug_arg" ]; then
    if [ "$debug_arg" = "true" ]; then
      export K8I_DEBUG=1
    else
      unset K8I_DEBUG
    fi
  fi

  # Always refresh cache at the start
  cache_node_data "$label_selector"
  rc=$?
  if [ $rc -ne 0 ]; then
     echo "Failed to collect node data"
     # Restore previous env before returning
     if [ "$prev_K8I_DEBUG_set" -eq 1 ]; then export K8I_DEBUG="$prev_K8I_DEBUG"; else unset K8I_DEBUG; fi
     if [ "$prev_K8I_NO_COLOR_set" -eq 1 ]; then export K8I_NO_COLOR="$prev_K8I_NO_COLOR"; else unset K8I_NO_COLOR; fi
     if [ "$prev_K8I_FORCE_COLOR_set" -eq 1 ]; then export K8I_FORCE_COLOR="$prev_K8I_FORCE_COLOR"; else unset K8I_FORCE_COLOR; fi
     if [ "$prev_K8I_SUPPRESS_PROGRESS_set" -eq 1 ]; then export K8I_SUPPRESS_PROGRESS="$prev_K8I_SUPPRESS_PROGRESS"; else unset K8I_SUPPRESS_PROGRESS; fi
     if [ "$prev_K8I_CONTEXT_set" -eq 1 ]; then export K8I_CONTEXT="$prev_K8I_CONTEXT"; else unset K8I_CONTEXT; fi
     return 1
   fi

  # Read cached nodes
  local nodes
  nodes=$(get_cached_nodes)

  if [ -z "$nodes" ]; then
    echo "Node data not found."
    return 1
  fi

  # Apply filter first (newline-safe, works in bash and zsh)
  local filtered_nodes=""
  while IFS= read -r node; do
    [ -z "$node" ] && continue
    # Hide fargate nodes by default unless --fargate flag is set
    if [ "$show_fargate" = false ] && [[ "$node" == fargate-* ]]; then
      continue
    fi
    if [ -n "$filter" ]; then
      node_info=$(read_cached_data "$node" "node_info")
      if ! apply_filter "$filter" "$node_info"; then
        continue  # Skip this node if it doesn't match filter
      fi
    fi
    filtered_nodes="$filtered_nodes $node"
  done < <(printf '%s\n' "$nodes")

  # Remove leading space
  filtered_nodes=$(echo "$filtered_nodes" | sed 's/^ *//')

  # Apply sorting if specified (now always has default value)
  if [ -n "$sort_spec" ]; then
    filtered_nodes=$(sort_nodes "$filtered_nodes" "$sort_spec")
    if [ $? -ne 0 ]; then
      return 1
    fi
  fi

  # Show data collection time
  if command -v jq >/dev/null 2>&1; then
    cache_time=$(jq -r '.timestamp' "$CACHE_FILE" 2>/dev/null)
    cached_selector=$(jq -r '.label_selector' "$CACHE_FILE" 2>/dev/null)
    echo "Data collected at: $cache_time (label: $cached_selector)"
    if [ -n "$filter" ]; then
      echo "Filter applied: $filter"
    fi
    if [ -n "$sort_spec" ] && [ "$sort_spec" != "pool=asc" ]; then
      echo "Sort applied: $sort_spec"
    else
      echo "Sort applied: pool=asc (default)"
    fi
  fi
  echo ""

  # Print properly formatted two-line header with adjusted CPU LOAD spacing
  echo -e "\t\t\tNODE\t\t\tPODS     CPU cores\t   CPU        MEMORY GB\t     MEM  \t\tNode info"
  echo -e "\t\t\t\t\t     used/max  req/lim/use/total   LOAD\t  req/lim/use/total  LOAD  \tec2/type/spot/arch/zone/pool/nodeclaim/age"
  echo "========================================================================================================================================================"

  local displayed_nodes=0
  # Iterate robustly over newline-separated nodes (works in zsh and bash)
  while IFS= read -r node; do
    [ -z "$node" ] && continue
    displayed_nodes=$((displayed_nodes + 1))

    # Read all processed data from cache only - no kubectl calls
    max_pods=$(read_cached_data "$node" "max_pods")
    # Get current pods count from pods cache
    current_pods=$(read_cached_pods_count "$node")
    cpu_requests_cores=$(read_cached_data "$node" "cpu_requests_cores")
    cpu_limits_cores=$(read_cached_data "$node" "cpu_limits_cores")
    cpu_usage_cores=$(read_cached_data "$node" "cpu_usage_cores")
    cpu_capacity_cores=$(read_cached_data "$node" "cpu_capacity_cores")
    memory_requests_gb=$(read_cached_data "$node" "memory_requests_gb")
    memory_limits_gb=$(read_cached_data "$node" "memory_limits_gb")
    memory_usage_gb=$(read_cached_data "$node" "memory_usage_gb")
    memory_capacity_gb=$(read_cached_data "$node" "memory_capacity_gb")
    cpu_load_percent=$(read_cached_data "$node" "cpu_load_percent")
    memory_load_percent=$(read_cached_data "$node" "memory_load_percent")
    node_info=$(read_cached_data "$node" "node_info")

    # Defaults to avoid blank columns if something went missing
    max_pods=$(nz0 "$max_pods")
    current_pods=$(nz0 "$current_pods")
    cpu_requests_cores=$(normalize_decimal "$(nz0 "$cpu_requests_cores")")
    cpu_limits_cores=$(normalize_decimal "$(nz0 "$cpu_limits_cores")")
    cpu_usage_cores=$(normalize_decimal "$(nz0 "$cpu_usage_cores")")
    cpu_capacity_cores=$(normalize_decimal "$(nz0 "$cpu_capacity_cores")")
    memory_requests_gb=$(normalize_decimal "$(nz0 "$memory_requests_gb")")
    memory_limits_gb=$(normalize_decimal "$(nz0 "$memory_limits_gb")")
    memory_usage_gb=$(normalize_decimal "$(nz0 "$memory_usage_gb")")
    memory_capacity_gb=$(normalize_decimal "$(nz0 "$memory_capacity_gb")")
    cpu_load_percent=$(nz0 "$cpu_load_percent")
    memory_load_percent=$(nz0 "$memory_load_percent")
    # Ensure node_info is a meaningful string (not numeric 0)
    if [ -z "$node_info" ] || [ "$node_info" = "0" ]; then
      node_info="unknown/unknown/x/unknown/xx/x/x/x"
    fi

    # Apply colorization to load percentages
    cpu_load_colored=$(colorize_load $cpu_load_percent)
    memory_load_colored=$(colorize_load $memory_load_percent)

    # Format output with adjusted CPU LOAD spacing (safe inline defaults)
    pods_info="${current_pods:-0}/${max_pods:-0}"
    cpu_info="${cpu_requests_cores:-0}/${cpu_limits_cores:-0}/${cpu_usage_cores:-0}/${cpu_capacity_cores:-0}"
    memory_info="${memory_requests_gb:-0}/${memory_limits_gb:-0}/${memory_usage_gb:-0}/${memory_capacity_gb:-0}"

    # Debug assembled fields for this node (stderr)
    log_debug "Debug: OUT node='$node' pods='$pods_info' cpu='$cpu_info' cpu_load='$cpu_load_percent' mem='$memory_info' mem_load='$memory_load_percent' info='$node_info'"

    printf "%-45s\t%-7s\t%-19s %s\t  %-19s %s  %s\n" \
      "$node" "$pods_info" "$cpu_info" "$cpu_load_colored" "$memory_info" "$memory_load_colored" "$node_info"
  done < <(printf '%s\n' "$filtered_nodes" | tr ' ' '\n' | sed '/^$/d')

  if [ "$displayed_nodes" -eq 0 ] && [ -n "$filter" ]; then
    echo "No nodes match the filter: $filter"
  fi

  echo ""

  # Restore previous env overrides
  if [ "$prev_K8I_DEBUG_set" -eq 1 ]; then export K8I_DEBUG="$prev_K8I_DEBUG"; else unset K8I_DEBUG; fi
  if [ "$prev_K8I_NO_COLOR_set" -eq 1 ]; then export K8I_NO_COLOR="$prev_K8I_NO_COLOR"; else unset K8I_NO_COLOR; fi
  if [ "$prev_K8I_FORCE_COLOR_set" -eq 1 ]; then export K8I_FORCE_COLOR="$prev_K8I_FORCE_COLOR"; else unset K8I_FORCE_COLOR; fi
  if [ "$prev_K8I_SUPPRESS_PROGRESS_set" -eq 1 ]; then export K8I_SUPPRESS_PROGRESS="$prev_K8I_SUPPRESS_PROGRESS"; else unset K8I_SUPPRESS_PROGRESS; fi
  if [ "$prev_K8I_CONTEXT_set" -eq 1 ]; then export K8I_CONTEXT="$prev_K8I_CONTEXT"; else unset K8I_CONTEXT; fi

  # Restore xtrace/verbose state
  if [ -n "${ZSH_VERSION-}" ]; then
    if [ "$__had_xtrace" -eq 1 ]; then setopt xtrace; fi
    if [ "$__had_verbose" -eq 1 ]; then setopt verbose; fi
  else
    if [ "$__had_xtrace" -eq 1 ]; then set -x; fi
    if [ "$__had_verbose" -eq 1 ]; then set -v; fi
  fi
}

# Helpers to sanitize numbers for output
normalize_decimal() {
  # Ensure leading zero for fractional values like .7 -> 0.7
  local v="$1"
  case "$v" in
    .* ) echo "0$v" ;;
    * ) echo "$v" ;;
  esac
}

nz0() {
  # Return value or 0 if empty
  if [ -z "$1" ] || [ "$1" = "null" ]; then echo 0; else echo "$1"; fi
}

# Dependency check: verify required external utilities are installed when sourcing
check_dependencies() {
  echo "< k8i > utility allows real-time analysis of a Kubernetes cluster"
  # Check for required commands used by this script.
  local required=(kubectl jq bc awk sed grep sort uniq)
  local missing=()
  for cmd in "${required[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -ne 0 ]; then
    # Print missing utilities in English when sourcing.
    echo "k8i: Required utilities are missing: ${missing[*]}"
    echo "k8i: Please install them and then re-run 'source k8i.sh'"

    # Try to detect package manager and print a fitting install command
    local pkg_cmd=""
    if command -v apt-get >/dev/null 2>&1; then
      pkg_cmd="sudo apt update && sudo apt install -y ${missing[*]}"
    elif command -v dnf >/dev/null 2>&1; then
      pkg_cmd="sudo dnf install -y ${missing[*]}"
    elif command -v yum >/dev/null 2>&1; then
      pkg_cmd="sudo yum install -y ${missing[*]}"
    elif command -v pacman >/dev/null 2>&1; then
      pkg_cmd="sudo pacman -S --noconfirm ${missing[*]}"
    elif command -v brew >/dev/null 2>&1; then
      pkg_cmd="brew install ${missing[*]}"
    fi

    if [ -n "$pkg_cmd" ]; then
      echo "k8i: Example install command: ${pkg_cmd}"
    else
      echo "k8i: Could not determine package manager for an automatic install hint. Please install the utilities manually."
    fi
  else
    echo "k8i: All required utilities are present."
  fi

  # If kubectl exists, try to show current context (non-fatal)
  if command -v kubectl >/dev/null 2>&1; then
    if current_ctx=$(kubectl config current-context 2>/dev/null); then
      echo "k8i: kubectl current-context: $current_ctx"
    else
      echo "k8i: kubectl is available but could not read current-context (check KUBECONFIG)"
    fi
  fi

  # Inform user about the installed function
  echo "k8i: The 'k8i' function has been added to the current session. To view help, run: k8i --help"
}

# If this file is being sourced (not executed), run dependency check once
# Use return-check to detect sourcing in a robust way across shells.
if (return 0 2>/dev/null); then
  check_dependencies
fi