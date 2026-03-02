# k8i - Kubernetes Node Information Tool

A powerful command-line utility for real-time analysis and monitoring of Kubernetes cluster nodes.

## Features

- **Comprehensive Node Metrics**: View CPU, memory, and pod usage across all nodes
- **Resource Allocation**: Track requests, limits, and actual usage
- **Color-Coded Load Indicators**: Visual feedback for resource utilization
- **Flexible Filtering**: Filter nodes by labels and attributes
- **Sorting Capabilities**: Sort by any metric (CPU, memory, pods, etc.)
- **Multi-Context Support**: Work with different Kubernetes contexts
- **Caching**: Fast performance with intelligent data caching
- **Node Metadata**: Display instance type, capacity type (spot/on-demand), architecture, zone, and node pool

## Requirements

The following utilities must be installed:
- `kubectl` - Kubernetes command-line tool
- `jq` - JSON processor
- `bc` - Basic calculator
- `awk`, `sed`, `grep`, `sort`, `uniq` - Standard Unix utilities

## Installation

### Quick Start

1. Download the script:
```bash
curl -O https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/docker/ping_pong/k8i/k8i.sh
# or
wget https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/docker/ping_pong/k8i/k8i.sh
```

2. Source the script in your current session:
```bash
source k8i.sh
```

### Permanent Installation

Add to your shell configuration file to make `k8i` available in all terminal sessions:

**Linux (bash):**
```bash
echo 'source /path/to/k8i.sh' >> ~/.bashrc
source ~/.bashrc
```

**macOS (bash):**
```bash
echo 'source /path/to/k8i.sh' >> ~/.bash_profile
source ~/.bash_profile
```

**macOS/Linux (zsh):**
```bash
echo 'source /path/to/k8i.sh' >> ~/.zshrc
source ~/.zshrc
```

## Usage

```bash
k8i [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--context CONTEXT` | Kubernetes context to use (defaults to current context) |
| `--labels SELECTOR` | Filter nodes by label selector (e.g., `worker-type=spot`) |
| `--filter FILTER` | Filter output by node attributes |
| `--sort COLUMN=DIR` | Sort by column (asc/desc) |
| `--color true\|false` | Force enable/disable ANSI colors |
| `--debug true\|false` | Enable or disable debug output |
| `--help`, `-h` | Show help message |

### Filter Attributes

Use `--filter 'attribute=value'` with:
- `ec2_type`: `spot`, `od` (on-demand), `x` (unknown)
- `instance_type`: e.g., `m5.large`, `c5.xlarge`
- `arch`: `amd64`, `arm64`
- `zone`: Last 2 characters, e.g., `1a`, `1b`
- `pool`: Node pool name

### Sort Columns

Available columns for `--sort`:
- `name` - Node name
- `pods` - Pod count
- `cpu_req`, `cpu_lim`, `cpu_use`, `cpu_cap`, `cpu_load` - CPU metrics
- `mem_req`, `mem_lim`, `mem_use`, `mem_cap`, `mem_load` - Memory metrics
- `ec2_type` - Capacity type (spot/on-demand)
- `instance_type` - EC2 instance type
- `arch` - Architecture
- `zone` - Availability zone
- `pool` - Node pool

## Examples

### Basic Usage

```bash
# Show all nodes in current context
k8i

# Use specific Kubernetes context
k8i --context my-cluster

# Show only nodes with specific label
k8i --labels 'worker-type=spot'
```

### Filtering

```bash
# Show only spot instances
k8i --filter 'ec2_type=spot'

# Show only on-demand instances
k8i --filter 'ec2_type=od'

# Show specific instance type
k8i --filter 'instance_type=m5.large'

# Show nodes in specific zone
k8i --filter 'zone=1a'
```

### Sorting

```bash
# Sort by CPU load (descending)
k8i --sort 'cpu_load=desc'

# Sort by memory usage (ascending)
k8i --sort 'mem_use=asc'

# Sort by pod count (descending)
k8i --sort 'pods=desc'

# Sort by instance type
k8i --sort 'instance_type=asc'
```

### Combined Examples

```bash
# Find spot nodes with high memory usage
k8i --filter 'ec2_type=spot' --sort 'mem_load=desc'

# Show specific node pool sorted by CPU load
k8i --labels 'karpenter.sh/nodepool=default' --sort 'cpu_load=desc'

# Complete example with all options
k8i --context prod-cluster \
    --labels 'work_type=default' \
    --filter 'ec2_type=spot' \
    --sort 'mem_load=asc'
```

## Output Format

The tool displays a table with the following columns:

```
NODE                    PODS     CPU cores          CPU        MEMORY GB           MEM      Node info
                             used/max  req/lim/use/total   LOAD    req/lim/use/total  LOAD    ec2/type/spot/arch/zone/pool
```

### Color Coding

Load percentages are color-coded for quick visual assessment:
- **Green** (0-60%): Normal load
- **Yellow** (61-80%): Moderate load
- **Red** (81-100%): High load

## Environment Variables

| Variable | Description |
|----------|-------------|
| `K8I_NO_COLOR` | Set to `1` to disable colors |
| `K8I_FORCE_COLOR` | Set to `1` to force enable colors |
| `K8I_DEBUG` | Set to `1` to enable debug output |
| `K8I_CONTEXT` | Default Kubernetes context to use |

## Performance

- Data is cached in `/tmp/k8s_nodes_cache.json` and `/tmp/k8s_pods_cache.json`
- Cache is automatically refreshed on each run
- Progress indicators show data collection status
- Optimized for large clusters with many nodes

## Troubleshooting

### Script won't run

Make sure you're sourcing the script, not executing it:
```bash
# Correct
source k8i.sh

# Incorrect
./k8i.sh
```

### Missing dependencies

Run the script to see which utilities are missing:
```bash
source k8i.sh
```

The script will display missing dependencies and suggest installation commands.

### No data displayed

Check your kubectl configuration:
```bash
kubectl config current-context
kubectl get nodes
```

Enable debug mode for more information:
```bash
k8i --debug true
```

## Supported Platforms

- Linux (bash, zsh)
- macOS (bash, zsh)
- Compatible with various Kubernetes distributions:
  - EKS (Amazon Elastic Kubernetes Service)
  - Self-managed clusters
  - Karpenter-managed node pools
  - Spot.io Ocean

## License

See the main repository LICENSE file.

## Contributing

Contributions are welcome! Please submit issues and pull requests to the main repository.
