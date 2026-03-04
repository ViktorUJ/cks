# Speaker Script: From Spot.io to Karpenter

Estimated time: 35–40 minutes + Q&A

---

## Slide 1 — Title (30 sec)

Hi everyone. My name is Viktar Mikalayeu, I'm a Tech Lead of the SRE department at Madlan. Today I'll share our real experience migrating from Spot.io Ocean to Karpenter for Kubernetes node management — what worked, what didn't, and what we learned along the way.

---

## Slide 2 — Quick Poll (1 min)

Before we begin, quick question for you
Who here uses Amazon EKS?
Great.
Who uses Karpenter for node management?
And who uses any other autoscaler — such as Cluster Autoscaler, Spot.io, CAST AI, or anything else?
Good.
Today, I'll share how we migrated to Karpenter

---

## Slide 3 — About Me & Team (1 min)

Let me say a few words about our team.
We manage  a large numbers of EKS clusters in AWS — from small dev environments to large production clusters with hundreds of nodes.

We work in a Platform Engineering model. Basically, our job is to provide product teams with a stable and predictable platform, and abstract the infrastructure complexity from them.

Node management — choosing instance types, balancing Spot and On-Demand, handling interruptions — is one of our core responsibilities.

---

## Slide 4 — Our Infrastructure (1.5 min)

We split our clusters into three main categories.

First — production.
These clusters run stateless services, APIs, queue workers, and cron jobs.
Stability and SLA are critical here.

Second — dev and staging.
These are used for development and testing.
The load is unpredictable, and short disruptions are usually acceptable.

Third — Airflow clusters.
They run batch jobs and data processing tasks.
The load goes up and down — sometimes very high, sometimes almost idle.
Sometimes they also require GPU instances.

Each category needs a different scaling approach, and that explains the decisions we made.

---

## Slide 5 — How Spot.io Was Used (1.5 min)

Before Karpenter, we used Spot.io Ocean.
At that time, the other option was Cluster Autoscaler with ASG, but it was slow, not flexible, and hard to manage when you have different types of workloads.

Spot.io solved these problems. It automatically chose instance types, provisioned nodes quickly, switched between Spot and On-Demand, and had a simple dashboard.

The pricing model was based on a percentage of savings, it was  a clear and fair model.

For some time, it worked really well.

---

## Slide 6 — Problem 1: Job Node Consolidation (2 min)

The first serious problem was with cron jobs and batch tasks.
Spot.io sometimes removed nodes while tasks were still running.

A task starts — a new node is created.
More tasks come — more nodes are created.
Then Ocean automatically reduces the number of nodes to save costs.

Tasks are interrupted and restarted.
New nodes are created again.
And the same cycle repeats.

We had a restrict-scale-down label, but sometimes it didn’t work.

As a result, we wasted compute time, and batch pipelines became unpredictable.

---

## Slide 7 — Problem 2: On-Demand Fallback & Oversizing (2 min)

The second problem was how Ocean switches to On-Demand. When Spot isn’t available, it’s fine to switch. But sometimes it doesn’t switch back, and nodes keep running On-Demand for weeks.

Another problem is big instances. A pod migh be need 1 vCPU, but Ocean starts a 64-core node just because it’s unavailable. Most of the time it  idle, and we  paying more than needed for a long time .

---

## Slide 8 — Problem 3: Pricing Model Change (1.5 min)
The final problem was that Spot.io changed their pricing model.

Instead of a savings percentage, we now pay a fixed price per vCPU per hour. For workloads like Airflow, CPU usage spikes quickly.
 
We pay for every vCPU, even if it runs just a few minutes.
  
And with the On-Demand fallback, we pay both the full On-Demand price and Spot fees. This would make our costs 2 or 3 times higher.

---

## Slide 9 — Why Karpenter? (1.5 min)

We looked at three options: Karpenter, Cluster Autoscaler with ASG, and a hybrid approach.
 CA+ASG brought back the problems we had with Spot.io.
  The hybrid approach was too complex to manage. Karpenter was the best choice: it provisions nodes in seconds, picks instances automatically, has no license cost, works natively with EKS, and gives full visibility with logs and Prometheus.

---

## Slide 10 — Karpenter Key Advantages (1 min)

It works directly with EC2 — no extra layers in between.

We can easily define different types of nodes.

It’s open source and free.

We can control how and when nodes are replaced.

Metrics are available by default.

Old nodes are replaced automatically.

And since it’s built by AWS, it works perfectly with EKS.


---

## Slide 11 — Migration Strategy (1.5 min)

We started with a two-week PoC on a separate dev cluster.
We tested the main things: how fast nodes start, how it switches between Spot and On-Demand, how consolidation works, how disruption limits behave, how cron jobs are protected, and how drift detection works.

After that, we rolled it out in four steps.

First — Dev and Staging. Low risk, just testing configuration and monitoring.
Second — Airflow clusters, where we had the biggest issues before.
Third — production but non-critical services.
And finally — critical production services with strict SLAs.

After each step, we waited one or two weeks to observe and make sure everything was stable.


---

## Slide 12 — Parallel Running (1 min)

During the migration, Spot.io and Karpenter were running in parallel in the same cluster.
We separated them using labels and taints — each controller managed only its own nodes.

When we migrated a workload, we added a nodeSelector so it would run on Karpenter nodes.
The remaining workloads continued running on Spot.io nodes.

This gave us a simple rollback option. If something went wrong, we could just switch the nodeSelector back.

During the whole migration, we had to roll back only one workload for a short time — it was a GPU edge case, and we fixed it quickly.

---

## Slide 13 — Monitoring: Before vs After (1.5 min)

Before the migration, our cost data was split between different systems.
Spot.io had its own dashboard and its own view of savings.
AWS Cost Explorer showed different numbers, and with a 24–48 hour delay.
Comparing everything was difficult and time-consuming.

After switching to Karpenter, everything goes into our standard monitoring stack.
Karpenter metrics go to Prometheus, and we visualize them in Grafana.

Now all data is in one place.
We can see cost by cluster, namespace, workload group, and the Spot vs On-Demand ratio over time.
We can create our own queries and alerts.

No more switching between different dashboards.

---

## Slide 14 — Migration Results (2 min)

License cost dropped to zero — no more Spot.io commission.

Spot usage increased from 60–70% to 80–90%.

No more “stuck” On-Demand nodes.

Oversized instances for small tasks are now rare — Karpenter chooses better instance sizes.

Provisioning time is about the same — around 1–2 minutes.

IAM setup became much simpler — no cross-account roles, no API tokens.

Configuration is easier — just Terraform and Kubernetes manifests, no external SaaS.


---

## Slide 15 — Karpenter Downsides & Solutions (2 min)

There is no built-in UI to visualize nodes — we built our own Grafana dashboards and a small console script.

Early versions didn’t support minimum node count — we used placeholder pods with podAntiAffinity as a workaround.

Spot interruption logs don’t always clearly show the instance ID — we plan to correlate events with AWS EventBridge.

There are no built-in cumulative interruption statistics — but we can collect this data ourselves via Prometheus and EventBridge.

Spot “flapping” can happen if the instance type list is too narrow — so we use at least 10–15 instance types per NodePool.

---

## Slide 16 — NodePool Cascade Strategy (1.5 min)

One of the most useful patterns for us was a NodePool cascade using weights.

Instead of one NodePool with fallback rules, we created several pools with different priorities.

Weight 100 — Spot in the preferred AZ. Best savings and less cross-zone traffic.

Weight 50 — Spot across all AZs. Bigger capacity pool.

Weight 25 — On-Demand in the preferred AZ.

Weight 10 — On-Demand in any AZ with the widest range of instance types.

Karpenter always tries the highest-priority pool first.
If there’s no capacity, it moves to the next one.

This gives us a clear and predictable fallback chain.

---

## Slide 17 — Disruption Budgets: Config (1 min)

Here’s a real example of how we manage disruptions in a NodePool.

consolidationPolicy: WhenEmptyOrUnderutilized — Karpenter can remove empty or underutilized nodes.

consolidateAfter: 5m — it waits 5 minutes before acting.

The key part is budgets:

nodes: 10% — no more than 10% of nodes can be replaced at the same time. This keeps changes gradual and safe.

And then the schedule block.

For example, Monday to Friday, 9:00–17:00 → nodes: 0.

This does not mean you must disable consolidation.
It means you can choose to disable it during specific hours if your business requires maximum stability.

In other words, consolidation is fully configurable.
You decide when optimization is allowed — and when stability has priority.

---

## Slide 18 — Disruption Management: Key Points (1 min)

The key points about managing disruptions:

PodDisruptionBudget (PDB) on your Deployment is your first protection. Karpenter respects this.

NodePool budgets control how many nodes can be replaced at the same time.

Schedules let you protect busy times from node replacements.

Affinity and Anti-Affinity help critical pods spread across different nodes, so they are not all on the same node.

Together, these tools let you control when and how nodes are replaced safely and keep critical services running.
---

## Slide 19 — 10 Tips for Migration (2 min)

Ten practical tips from our experience:

Start with a PoC on a dev cluster — two weeks now can save months later.

Document all your VNGs before migration — they become the base for NodePools.

Use the cascade strategy with weights.

Set up monitoring before migrating, not after.

Migrate in phases and watch what happens between phases.

Run old and new systems in parallel to allow safe rollback.

Use at least 10–15 instance types per NodePool.

Don’t forget PodDisruptionBudgets (PDB).

Test how Spot instances can be interrupted so you know how your system reacts.

Plan for months — this is not a weekend project.


---

## Slide 20 — Key Takeaways (1 min)

To summarize:

First, lower cost — no license fees and better instance sizing.

Second, full transparency — you can see every decision in logs and metrics. There is no black box.

Third, more flexibility — you control NodePools, disruption budgets, and weights.

Fourth, more control — everything is just Kubernetes configuration. No SaaS dependency.

And finally, fewer incidents — no stuck On-Demand nodes and no endless consolidation loops.

Karpenter is not perfect. But if your team is ready to invest time in configuration and monitoring, it can be a very powerful tool.


---

## Slide 21 — k8i: Console Node Visualization (1.5 min)

After we left Spot.io, we missed the node dashboard.

So we built our own tool — k8i.

It is a simple console tool that reads data directly from Kubernetes.

You can see per-node information: pods, CPU and memory usage, instance type, Spot or On-Demand, NodePool, and node age.

You can filter nodes, for example by NodePool.

The main difference — no caching and no delay.

You always see the real cluster state in real time.

---

## Slide 22 — k8i: Example Output (1.5 min)

Here is the full output.

Each row is one node.

On the left, you see CPU information — requests, limits, usage, total, and load.
On the right, you see memory information and full node details — instance type, Spot or On-Demand, availability zone, NodePool, and node age.

For example, one node uses 74% memory — we should watch it.
Another uses only 11% — good candidate for consolidation.

And all of this in one command.
No Grafana. No kubectl describe.
Just a clear and complete picture of the cluster.

---

## Slide 23 — Links (30 sec)

Here are the QR codes.

The first one is for this presentation and the full article with all the details.

The second one is our SRE Learning Platform on GitHub.

The third one is k8i — the node tool I just showed you.

And here is my LinkedIn — feel free to connect with me.
---

## Slide 24 — Thank You & Questions

Thank you for your attention. Happy to take questions.
