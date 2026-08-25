[Русская версия](COST_MODEL_RU.md) · [Versión en español](COST_MODEL_ES.md) · [Version française](COST_MODEL_FR.md) · [Deutsche Version](COST_MODEL_DE.md) · [ქართული ვერსია](COST_MODEL_GE.md) · [繁體中文版](COST_MODEL_TW.md) · [日本語版](COST_MODEL_JP.md)
# EKS Cluster Cost Model: Estimation Template

[Course contents](README.md) · [Chapter 43](43/en.md) · [Glossary](GLOSSARY.md)

This is a worksheet for chapter 43: the same cost structure, presented as tables and
formulas that an engineer uses to build an estimate for their cluster. There is no new
material here.

## How to use it

- The worksheet does NOT contain prices. Rates depend on the region, change, and become
  outdated faster than the course, so the “Rate (fill in)” column is deliberately blank.
- Obtain rates from AWS Pricing Calculator for your region and enter them in the empty
  column. For actuals from an already running cluster, use the Cost and Usage Report
  (chapter 43).
- The value of the template is not the precision of the number, but the completeness of
  the list: it prevents you from missing a cost category that will appear on the bill but
  was omitted from the estimate.
- Create the estimate twice: BEFORE right-sizing and AFTER. The difference between the
  two runs is the measured effect of an engineering decision, not a promised saving.
- Keep units consistent throughout the worksheet (hours in a month, GB versus GiB),
  otherwise the rows cannot be added together.
- Run the worksheet again after changing the node purchasing model, adding an AZ,
  enabling new log types, or making any change to the egress topology.

## Cost categories

| Category | Depends on | Unit | Rate (fill in) | Chapter |
|---|---|---|---|---|
| Cluster control plane | number of clusters, uptime | cluster-hour |  | [02](02/en.md) |
| Extended support surcharge | version outside standard support | cluster-hour |  | [38](38/en.md) |
| EC2 nodes | instance type, number of nodes, purchasing model | instance-hour |  | [09](09/en.md) |
| Auto Mode management surcharge | managed instances under Auto Mode | instance-hour |  | [09](09/en.md) |
| Fargate: vCPU | Pod CapacityProvisioned, lifetime | vCPU-hour |  | [15](15/en.md) |
| Fargate: memory | Pod CapacityProvisioned, lifetime | GB-hour |  | [15](15/en.md) |
| EBS volumes | volume type, size, provisioned IOPS and throughput | GiB-month |  | [23](23/en.md) |
| EBS snapshots | amount of captured data, retention period | GiB-month |  | [23](23/en.md) |
| NAT Gateway: uptime | number of NAT gateways (one per AZ), lifetime | NAT-hour |  | [31](31/en.md) |
| NAT Gateway: processing | Pod egress, image pulls, AWS API calls | GB |  | [31](31/en.md) |
| Cross-AZ traffic | east-west traffic between zones, calls to a database in another AZ | GB |  | [31](31/en.md) |
| Internet egress | responses to clients, data sent externally | GB |  | [31](31/en.md) |
| Interface endpoints (PrivateLink) | number of endpoints, processed volume | endpoint-hour and GB |  | [31](31/en.md) |
| Logs: ingestion | volume of ingested Pod and control plane logs | GB |  | [34](34/en.md) |
| Logs: storage | volume kept for the configured retention period | GB-month |  | [34](34/en.md) |
| Load balancers (NLB, ALB) | number of load balancers, processed volume | hour and volume |  | [26](26/en.md) |

Gateway endpoints for S3 and DynamoDB do not need rows in this table: they are free, but
they move volume away from paid NAT, so they affect the “NAT Gateway: processing” row
(chapter 31).

## Generic formulas

```text
Notation: HOURS - hours in the billing month, RATE_* - rate from the table above,
all consumption values come from metrics and billing, not from design plans.

control_plane = CLUSTERS * HOURS * RATE_CP
              + CLUSTERS_EXT * HOURS * RATE_CP_EXT_DELTA
# CLUSTERS_EXT - clusters on a version in extended support: this is a SURCHARGE on the
# normal hourly cluster fee, not the same rate (chapter 38).

nodes = sum over pools P: NODES[P] * HOURS[P] * RATE_INSTANCE[P, purchasing model]
# purchasing model: On-Demand, Spot, Reserved or Savings Plans coverage (chapter 43).

auto_mode = nodes(Auto Mode pools)                         # EC2 portion
          + MANAGED_INSTANCES * HOURS * RATE_AM_MGMT       # management surcharge
# REQUIRED: Reserved Instances and Savings Plans reduce ONLY the EC2 portion.
# The Auto Mode management surcharge is NOT eligible for these discounts and appears on
# the bill as a separate line item (chapter 09). The EKS control plane hourly charge is
# also not covered by Compute Savings Plans (chapter 43).

fargate = sum over Pods: VCPU_PROV * LIFETIME_H * RATE_VCPU
        + MEM_PROV_GB * LIFETIME_H * RATE_MEM
# VCPU_PROV and MEM_PROV_GB are the provisioned combination from the CapacityProvisioned
# annotation, that is, requests rounded up, not the requests themselves (chapter 15).

commit_base = BASELINE_COMPUTE - SPOT_SUSTAINED
# Calculate BASELINE_COMPUTE AFTER right-sizing, otherwise you commit to empty capacity.
# SPOT_SUSTAINED is the consistently achievable Spot share, not the planned share: Savings
# Plans do not cover Spot, an hourly commitment does not carry between hours and unused
# commitment expires every hour, while fallback to On-Demand returns part of consumption
# under the commitment (chapters 43 and 13). Review commitments based on actual
# utilization and coverage.

nat = NAT_COUNT * HOURS * RATE_NAT_HOUR
    + PROCESSED_GB * RATE_NAT_GB
# Two independent components: payment for NAT uptime and for every processed gigabyte.

cross_az = CROSS_AZ_GB * RATE_CROSS_AZ
# Charged in both directions: CROSS_AZ_GB includes both the request and the response
# (chapter 31).

storage = sum over volumes: SIZE_GIB * RATE_VOLUME[type]
        + SNAPSHOT_GIB * RATE_SNAPSHOT
# You pay for the provisioned volume size, not the space used inside the file system.

logs = INGEST_GB * RATE_INGEST + STORED_GB * RATE_STORAGE
# INGEST_GB is the ingested volume: it is usually the main cost category (chapter 34).

total_month = control_plane + nodes + auto_mode + fargate
            + nat + cross_az + egress_internet + storage + logs
            + endpoints + load_balancers
```

## What is commonly forgotten

- **Auto Mode surcharge.** On the bill, it is a separate item on top of the EC2 rate, and
  discount models do not apply to it. Account for it explicitly when comparing Auto Mode
  with your own stack (chapter 09).
- **Extended support as a surcharge.** A cluster on an outdated version costs more per hour
  of operation, not the same amount. In an estimate, this is a separate term (chapter 38).
- **Cross-AZ in both directions.** A service in one zone that calls a database in another
  pays for the exchange, not just the request. Count both directions (chapter 31).
- **NAT charges twice.** The hourly charge applies while the NAT exists, and every
  processed gigabyte is charged independently. The second component is the one usually
  forgotten (chapter 31).
- **Logs are primarily paid for at ingestion.** Reducing retention affects only storage and
  saves little. Adjust the collection interval, log levels, and series filtering instead
  (chapter 34).
- **Forgotten volumes and snapshots.** A PVC was deleted but the volume remained;
  snapshots accumulate for years. This is a quiet leak visible only in billing (chapter 23).
- **Load balancer after a deleted service.** A Service was removed outside Kubernetes, but
  the NLB or ALB remained running and billable (chapter 26).
- **Idle capacity.** You pay for reserved requests, not used resources: the gap between
  requested and used is paid-for empty capacity, multiplied by replicas (chapter 43).

## Optimization order

1. **Right-size and bin-pack** - align requests with actual consumption and let
   consolidation pack nodes more densely (chapters 43, 14, 12).
2. **Commit to a stable baseline** - apply Savings Plans to a volume that remains stable
   for months, after reductions have already been made (chapter 43).
3. **Spot for flexible workloads** - move interruptible workloads to Spot with
   diversification across instance types and zones (chapter 13).
4. **Traffic, logs, and storage** - use gateway endpoints for S3, NAT gateways per zone,
   reduce log volume at the source, and manage volumes and snapshots (chapters 31, 34, 23).

The order is exactly this because each next step applies to the base reduced by the
previous one: committing or moving an inflated volume to Spot means locking in payment for
empty capacity.

## Template boundaries

- The worksheet does not replace AWS Pricing Calculator for forecasting or Cost and Usage
  Report for actuals: it provides the list of cost categories and formulas, while the
  numbers come from those sources.
- Application services outside the cluster (databases, queues, caches, S3 for application
  data) are not counted here, even though they are part of the product bill.
- Allocate costs by team and namespace with the allocation tool from chapter 43, not this
  table: it covers the cluster as a whole, not how much each internal consumer spent.
- The worksheet shows shared costs (control plane, system namespaces, idle) as cluster
  rows. Choose the rule for allocating them across teams separately (chapter 43).
- The worksheet does not model AWS agreement discounts or commitment application order:
  they are visible only in actual billing.
