[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 112 - Runtime: Falco, audit logs, and an immutable root filesystem

## Goal

In this CKS lab you set up runtime event monitoring on a node and audit logging for the control plane
API, and then make a workload immutable at runtime. The work is done on a single
node: the `control-plane` is also the workload node, so Falco sees the events
from the test Pods, and the kube-apiserver lives in a static Pod manifest.

## Self-check before you start

<details>
<summary>1. Why can the Kubernetes audit log not serve as a replacement for Falco in runtime detection?</summary>

The audit log records REQUEST-level events to the API server (who requested what and when via `kubectl`/the API) - this is evidence at the control plane level. Falco, on the other hand, observes SYSTEM CALLS (syscalls) inside running containers on the node - for example, opening a shell, spawning a process, writing to a file. An action like `docker exec`/`crictl exec` or a direct launch via `ctr` on the node does NOT go through the Kubernetes API at all and will not get into the audit log, but will be visible to Falco as a syscall event.
</details>

<details>
<summary>2. What is the difference between the `RequestResponse` and `Metadata` levels of an audit policy, and why must Secrets be logged specifically at the `Metadata` level?</summary>

`RequestResponse` records the full body of the request AND the response, including the content of the resource. `Metadata` records only the metadata about the request (who, when, which resource, which verb) WITHOUT the body. For `secrets` this is critical: `RequestResponse` would write the value of the secret itself (base64-encoded, but still sensitive data) into the audit log as a readable file on disk - this creates a new leak surface. `Metadata` gives a forensic trace ("who read this Secret and when") without copying the secret itself into the log.
</details>

<details>
<summary>3. Why is `readOnlyRootFilesystem: true` not equivalent to full protection against the compromise of a container at runtime?</summary>

`readOnlyRootFilesystem` blocks writes to the root filesystem of the container, which prevents an attacker from modifying the application binaries or installing persistence on the container disk. But it does NOT prevent: (a) writable volumes/emptyDir that the Pod itself explicitly mounts (for example `/tmp`), (b) actions executed in the memory of the process (RCE without writing to disk), (c) network attacks from inside the container, (d) reading Secrets/ConfigMaps that are already mounted. The immutability of the rootfs is one layer of protection, not complete isolation.
</details>

## Related Course Chapters

- [Chapter 29. Runtime behavioral analysis: Falco](../../course/29/README.md)
- [Chapter 30. Threat detection and investigation of attack phases](../../course/30/README.md)
- [Chapter 31. Container immutability at runtime](../../course/31/README.md)
- [Chapter 32. Kubernetes audit logs](../../course/32/README.md)
- [Chapter 26. Registries, signing, and artifact validation](../../course/26/README.md) - task 9 ties registry allowlist admission control to the runtime detection of a bypass (not signature verification - lab 111 checks that).

## Infrastructure

| Component | Purpose |
|---|---|
| `k8s-1` | a single-node Kubernetes `1.36.0`, containerd, and Calico; the node name is `control-plane` |
| `worker` | a work machine with `kubectl`, `check_result`, and SSH access `ssh control-plane` |
| `runtime-112` | a prepared namespace; it already has the Secret `audit-secret` |

The bootstrap deliberately does **not** install Falco and does **not** enable an audit backend. It only
prepares the directory `/etc/kubernetes/audit`, the log directory
`/var/log/kubernetes/audit`, and a Secret for a controlled API request. Do not change the CNI,
the cluster version, the Secret, or the Kubernetes manifests outside tasks 4 and 8.

## Deployment

```bash
TASK=112 make run_cks_task
```

On the work machine:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
ssh control-plane 'sudo -n true'
```

## How to work with the node

Open two terminals: **terminal 1** - `ssh control-plane`, then `sudo -i` (operations on the node:
Falco, audit, `crictl`, `/proc`), **terminal 2** - the work machine (`kubectl`, `scp`, checks).
Save the artifacts obtained on the node to a file on the `control-plane` and copy them to the work machine
with `scp` into `/var/work/tests/artifacts/<task number>/`.

## Tasks

Before containment it is useful to mentally estimate the blast radius: can the ServiceAccount
of the compromised Pod read Secrets, create workloads, or reach other
namespaces? This can and should be quickly checked with `kubectl auth can-i` as the
ServiceAccount of the Pod `falco-shell` (`--as=system:serviceaccount:runtime-112:default`); this is an additional step: it is not mandatory, does not affect the
acceptance criteria, and is not tested.

---
| **1** | **Install and run Falco on the workload node** |
| :---: | :--- |
| What to do | • On the `control-plane` install the Falco package from the official Falco repository and start the service.<br/>• Use the modern eBPF engine; do not install a kernel module by hand.<br/>• Enable the service via systemd. |
| Acceptance criteria | • `falco --version` runs<br/>• `systemctl is-active falco` returns `active`<br/>• The configuration contains `engine.kind: modern_ebpf` |

<details>
<summary>💡 Hint for task 1</summary>

The modern eBPF engine is configured via `engine.kind: modern_ebpf` in `/etc/falco/falco.yaml` or in a drop-in file in `/etc/falco/config.d/` (not via a separate kernel module driver, which is needed for the legacy engine) - if after installation Falco does not start or crashes at startup, check `journalctl -u falco-modern-bpf` (the package installs the unit `falco-modern-bpf.service`, and `falco.service` is only an alias to it: `systemctl status/restart falco` works, but `journalctl -u falco` is empty) for eBPF program loading errors, which may indicate an incompatible kernel.
</details>

---
| **2** | **Record a standard shell event in a container** |
| :---: | :--- |
| What to do | • Create a Pod `falco-shell` from `busybox:1.36` in `runtime-112`, keep it Running (`sleep 3600`) and enable `stdin: true`, `tty: true`.<br/>• Open an interactive `/bin/sh` in it and wait for the Falco rule **Terminal shell in container** to fire.<br/>• Save the matching line from the Falco journal (it is read on the `control-plane`) into a file on the node and copy it with `scp` to `/var/work/tests/artifacts/2/falco-shell.log` on the work machine. |
| Acceptance criteria | • The Pod `falco-shell` is Running<br/>• The artifact is non-empty and contains the alert line `A shell was spawned in a container with an attached terminal` (this is how the rule **Terminal shell in container** prints the event in the text output of Falco 0.45; the rule name is only in the JSON output)<br/>• The event must be received by Falco, and not written by hand |

<details>
<summary>💡 Hint for task 2</summary>

Simply creating a Pod with `stdin: true, tty: true` is not enough - you need to REALLY open an interactive session (`kubectl exec -it falco-shell -- /bin/sh`), so that Falco records exactly the spawn of a shell process inside the container. Look for the event via `journalctl -u falco-modern-bpf --no-pager | grep "shell was spawned"` on the `control-plane` (over SSH from the worker), and do not try to write the line into a file by hand - the test expects the real timestamp/format from the journal.
</details>

---
| **3** | **Add and trigger a custom Falco rule** |
| :---: | :--- |
| What to do | • On the `control-plane` add a rule named `CKS112 Custom Shell Marker` to `/etc/falco/falco_rules.local.yaml`.<br/>• It must catch a process spawned in a container if the process's `proc.cmdline` contains `CKS112_CUSTOM_EVENT`.<br/>• It must output the exact phrase `CKS112 custom shell marker` together with `container=%container.id`, `pid=%proc.pid`, `ppid=%proc.ppid`, `user=%user.name`, and `command=%proc.cmdline`.<br/>• Restart Falco.<br/>• In `falco-shell`, run any short command whose command line contains the marker, for example: `kubectl exec -n runtime-112 falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT'`.<br/>• Find the line for this alert in the Falco journal on the `control-plane` (it contains `CKS112 custom shell marker`), save it into a file on the node, and copy it with `scp` to `/var/work/tests/artifacts/3/falco-custom.log`. The line must be a real journal line; a hand-written one is not accepted. |
| Acceptance criteria | • The local rules file exists and contains the rule name, the marker condition, and the investigation identifiers<br/>• The Falco service is active<br/>• The real journal artifact contains the marker, the container ID, and the PID |

<details>
<summary>💡 Hint for task 3</summary>

A custom rule in `falco_rules.local.yaml` needs a `condition` that uses `spawned_process` (or `evt.type=execve`) together with `proc.cmdline contains "CKS112_CUSTOM_EVENT"` - without a base condition on the event type the rule may not fire at all or may fire on wrong events. After editing the file, run `systemctl restart falco` for a deterministic confirmation that the rules were applied. In current Falco an automatic reload is also possible with `watch_config_files: true` enabled, but this lab uses an explicit restart.
</details>

---
| **4** | **Enable audit logging: RequestResponse for ConfigMap, Metadata for Secret** |
| :---: | :--- |
| What to do | • On the `control-plane` create `/etc/kubernetes/audit/policy.yaml`. The policy must record `RequestResponse` **only in the namespace `runtime-112`** for the core resource `configmaps` (a controlled forensic example on a non-sensitive resource).<br/>• For the core resource `secrets` use only `Metadata`, **so that the body of the Secret does not end up in the audit log**.<br/>• Actually reduce noise with explicit `None` rules for high-volume/low-risk traffic and `omitStages: [RequestReceived]`.<br/>• Finish the policy with a safe catch-all `Metadata` rule as *fallback logging*, and not as noise suppression.<br/>• In the static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` add `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log`, and rotation (`--audit-log-maxage`, `--audit-log-maxbackup`, `--audit-log-maxsize`).<br/>• Add the necessary hostPath volume/volumeMount for the policy directory and the log directory. Wait for the API to recover.<br/>• Create a ConfigMap `audit-config` in `runtime-112`, read it (`kubectl get configmap audit-config -n runtime-112 -o json`), and save the RequestResponse event in `/var/work/tests/artifacts/4/configmap-request-response.json`.<br/>• Then read `kubectl get secret audit-secret -n runtime-112 -o json` and save its Metadata event in `/var/work/tests/artifacts/4/secret-metadata.json`. The events are taken from the audit log on the `control-plane`: save them on the node and copy them with `scp`. |
| Acceptance criteria | • Kube-apiserver is healthy<br/>• The static manifest contains both audit flags and the mounts<br/>• The policy sets `RequestResponse` for `configmaps` and `Metadata` for `secrets`<br/>• In `/var/work/tests/artifacts/4/configmap-request-response.json` there is a RequestResponse event for the ConfigMap<br/>• In `/var/work/tests/artifacts/4/secret-metadata.json` there is a `Metadata`-level Secret event **without the fields `requestObject`/`responseObject`** (the body of the Secret is not logged) |

<details>
<summary>💡 Hint for task 4</summary>

The order of the rules in an audit policy matters: Kubernetes applies the FIRST matching rule from top to bottom, so the specific rule for `configmaps`/`secrets` in `runtime-112` must come BEFORE the general catch-all `Metadata` at the end of the file - if the catch-all is first, it will "intercept" all the requests before the specific rules. After editing the static manifest, the kubelet picks up the changes itself (no `kubectl apply`/restart is needed) - but wait until `kubectl get --raw=/readyz` returns success again before continuing.
</details>

---
| **5** | **Make a Pod with a read-only root filesystem** |
| :---: | :--- |
| What to do | • Create a Pod `immutable-app` in `runtime-112`: the container `app`, the image `busybox:1.36`, `sleep 3600`.<br/>• On the container enable `securityContext.readOnlyRootFilesystem: true`.<br/>• Create an `emptyDir` `writable-tmp` and mount it at `/tmp` without `readOnly: true`. Do not use `hostPath`.<br/>• Prove that `touch /cks-112-write-denied` fails and `touch /tmp/allowed` succeeds; save the denial result in `/var/work/tests/artifacts/5/rootfs-write-denied.log`. |
| Acceptance criteria | • The Pod is Running<br/>• The root filesystem is read-only<br/>• `/tmp` is a writable `emptyDir`<br/>• The Pod has no `hostPath`<br/>• Writes to the rootfs are blocked; writes to `/tmp` are allowed<br/>• The artifact is non-empty |

<details>
<summary>💡 Hint for task 5</summary>

Save exactly the ERROR OUTPUT of the command `touch /cks-112-write-denied` (`Read-only file system` in stderr), and not merely the fact that the command exited with a non-zero exit code - the test checks the content of the log. Do not confuse `emptyDir` (ephemeral, lives with the Pod) with `hostPath` (persistent on the node, forbidden in this task) - both technically "solve" the task of a writable directory, but only the first is allowed here.
</details>

---
| **6** | **A minimal containment chain from alert to isolation** |
| :---: | :--- |
| What to do | • After enabling the audit backend, run a controlled long-lived process in `falco-shell` with `CKS112_CUSTOM_EVENT` in its command line, for example: `kubectl exec -n runtime-112 falco-shell -- sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT &`. The process lives for 10 minutes: while it is alive, its `/proc/<PID>` can be captured.<br/>• **Start the investigation with a new Falco alert**, and not with the Pod manifest. From the alert extract the short container ID and the host PID.<br/>• On the `control-plane` via `crictl ps/inspect/inspectp` match container → Pod sandbox → namespace/Pod; determine the node through the Kubernetes API. Save `crictl inspect` and `inspectp`.<br/>• While the process is alive, save `/proc/<PID>/status`, `cmdline`, `cgroup`, and the PID/PPID/user tree.<br/>• In the audit log find the `pods/exec` event for `runtime-112/falco-shell` and save it without the request/response body.<br/>• Classify the phase as `Execution`, the technique as `Container Administration Command`, compose `evidence-summary.txt`. Copy the files captured on the `control-plane` with `scp` into `/var/work/tests/artifacts/6/`.<br/>• Then apply a default-deny ingress+egress `NetworkPolicy` `incident-quarantine`, delete the compromised Pod, and save a negative check: a repeated `kubectl exec` fails.<br/>• This is a minimal containment chain: credential revocation/rotation and full remediation require a separate incident-response process. |
| Acceptance criteria | • In `/var/work/tests/artifacts/6/` there are a real Falco alert, CRI inspect/inspectp, three `/proc` artifacts, the process lineage, the Metadata audit event for `pods/exec`, the final summary, and the containment result<br/>• The Pod `falco-shell` is absent<br/>• `incident-quarantine` selects all Pods and closes ingress+egress<br/>• A repeated exec has a non-zero exit code |

<details>
<summary>💡 Hint for task 6</summary>

A strict order of actions matters for the credibility of the investigation: start with the Falco alert (this is what would really trigger incident response), and NOT with an already known Pod name - otherwise you are just confirming what you already know, and not doing a real correlation. Collect the `/proc/<PID>/*` artifacts while the process is ALIVE - as soon as you delete the Pod (the last step), `/proc` for this PID disappears forever, so the order "first evidence, then containment" is irreversible if mixed up.
</details>

---
| **7** | **Override an upstream Falco macro, add Pod/namespace evidence to the output, JSON to a file** |
| :---: | :--- |
| What to do | • The standard Falco rule **Terminal shell in container** would also fire on a legitimate CI/CD tool that routinely opens a shell in a container (for example, `kubectl debug` or a sidecar with a maintenance script). Instead of editing the rule itself, override the upstream macro intended specifically for this very rule.<br/>• In `/etc/falco/falco_rules.local.yaml` override `user_expected_terminal_shell_in_container_conditions` (by default `(never_true)` in the rule **Terminal shell in container** itself - do not confuse it with `user_shell_container_exclusions`, which belongs to the separate rule **Run shell untrusted**/"Shell spawned by untrusted binary"), so that it allows the specific Pod `ci-runner` in the namespace `runtime-112`.<br/>• Use `k8s.pod.name` and `k8s.ns.name`, and not `container.name`: `container.name` is the name of the **container** (in this task `app`), and not of the Pod, and matching by the container name will almost always give a wrong or too broad allowlist.<br/>• The standard output of the rule **Terminal shell in container** does not contain `k8s.pod.name`/`k8s.ns.name` (check the upstream `falco_rules.yaml` yourself - they are not there); without these fields correlating a specific alert with a specific Pod is not reliably possible. Using the same `override` mechanism (`output: append`), append `k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name` to the end of the rule's output.<br/>• Create a Pod `ci-runner` in `runtime-112` from `busybox:1.36` with an interactive `sh` (`stdin: true`, `tty: true`) and confirm that the alert `Terminal shell in container` is **not** generated for it, whereas for `immutable-app` from task 5 (without the exception) the alert keeps firing.<br/>• Separately, via `/etc/falco/config.d/cks112-output.yaml` enable `json_output: true` and `file_output.enabled: true` with `file_output.filename: /var/log/falco/events.log`; restart Falco.<br/>• Confirm via structured JSON (`jq .output_fields`), and not a text `grep`, that the recorded alert for `immutable-app` contains `k8s.pod.name == "immutable-app"` and `k8s.ns.name == "runtime-112"`. |
| Acceptance criteria | • `falco_rules.local.yaml` contains `macro: user_expected_terminal_shell_in_container_conditions` with a condition referring to `k8s.pod.name = "ci-runner"` and `k8s.ns.name = "runtime-112"` (not `never_true`, not `container.name`), and a separate `override: output: append` that adds `%k8s.ns.name`/`%k8s.pod.name` to the rule `Terminal shell in container`<br/>• A shell in `ci-runner` does not create an alert during the observation time, and a shell in `immutable-app` does<br/>• `config.d/cks112-output.yaml` contains `json_output: true` and `file_output: {enabled: true, filename: /var/log/falco/events.log}`<br/>• `/var/log/falco/events.log` contains a valid JSON line with `rule == "Terminal shell in container"` and `output_fields["k8s.pod.name"] == "immutable-app"`, `output_fields["k8s.ns.name"] == "runtime-112"`<br/>• The Pod `falco-shell` from task 2 has already been deleted by this point (in task 6) and is not used here |

<details>
<summary>💡 Hint for task 7</summary>

The two different override mechanisms are easy to mix up: a `macro` override changes the CONDITION of the rule's firing (whom to exclude), while an `output` override with `append` changes only the FORMAT of the output (what to print) - this task needs BOTH, in separate blocks `- macro: ...` and `- rule: ... / override: / output: append`. Check the spelling of `user_expected_terminal_shell_in_container_conditions` literally - Falco has several macros with similar names for different rules (the `user_shell_container_exclusions` mentioned in the task belongs to a DIFFERENT rule); using the wrong macro will not give a load error, but the allowlist will simply not work.
</details>

---
| **8** | **An audit webhook backend instead of / together with a local file** |
| :---: | :--- |
| What to do | • Use the HTTP receiver `audit-receiver` already prepared by the bootstrap (a Deployment + Service on port `8080`, image `ghcr.io/mendhak/http-https-echo:40`) that receives the audit events.<br/>• On the `control-plane` create `/etc/kubernetes/audit/webhook-config.yaml` in kubeconfig format with `server: http://<ClusterIP of the receiver>:8080/audit` (HTTP is acceptable for the lab; in production a webhook requires HTTPS and a client certificate - see chapter 32).<br/>• In the static manifest `kube-apiserver.yaml` add `--audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml` and `--audit-webhook-batch-max-wait=1s` (a reduced batch delay for observability in the lab), keeping the already configured `--audit-policy-file` and `--audit-log-path` from task 4 - the webhook complements, and does not replace, the local file backend.<br/>• After the API recovers, perform any audited request (for example, `kubectl get configmap audit-config -n runtime-112`) and confirm in the `audit-receiver` logs that the event was delivered. |
| Acceptance criteria | • `audit-receiver` is Running with a Service<br/>• `webhook-config.yaml` is a valid kubeconfig with `server` pointing at this Service<br/>• The kube-apiserver static manifest contains `--audit-webhook-config-file` and `--audit-webhook-batch-max-wait`, as well as the preserved file backend flags from task 4<br/>• Kube-apiserver is healthy after the change<br/>• The `audit-receiver` logs contain at least one JSON audit event (in a received request body) with the field `objectRef` |

<details>
<summary>💡 Hint for task 8</summary>

`webhook-config.yaml` is in KUBECONFIG FORMAT (with `clusters`/`users`/`contexts`), and not arbitrary YAML with a `server` field - if the structure of the file does not match the kubeconfig schema, kube-apiserver will not be able to parse it and will not start at all. Do not forget that the webhook COMPLEMENTS the file backend, and does not replace it - if you delete the flags `--audit-policy-file`/`--audit-log-path` from task 4, the tests of task 4 will stop passing.
</details>

---
| **9** | **Integration task: bypass the admission allowlist via containerd directly and detect the attempt via Falco** |
| :---: | :--- |
| What to do | • This task ties Supply Chain Security (see [lab 111](../111/README.MD) and [chapter 26](../../course/26/README.md)) to the Runtime Security of this lab. **An important difference from lab 111**: there an `ImageValidatingPolicy` checks a **cryptographic signature** (Cosign). Here the policy checks only a **registry/repository allowlist** (permitted registry, without a signature/attestor) - a simpler but equally real admission control, with the same principle: it works only on the API admission path and does not see actions that do not go through it.<br/>• The controlled abuse fixture of this task is a lab-owned local registry, and not the public Docker Hub: the bootstrap has already prepared on the `control-plane` three images with different digests in the local containerd content store and saved their names in `/etc/cks112/registry.env` (`CKS112_REGISTRY=cks112.local:5000`, `CKS112_TRUSTED_REPO=cks112/trusted`, `CKS112_UNTRUSTED_REPO=cks112/untrusted`, `CKS112_TRUSTED_IMAGE`, `CKS112_UNTRUSTED_IMAGE`, `CKS112_PREFIX_IMAGE`) - source this file at the start of the task and use only these values.<br/>• Install Kyverno (`install-kyverno`, as in lab 111) and create a `ValidatingPolicy` `require-trusted-registry-runtime-112` (native CEL, `apiVersion: policies.kyverno.io/v1`) that, via `image(c.image).registry()`/`.repository()` (the Kyverno CEL Image library), **rejects** any Pod in `runtime-112` whose image does not equal exactly `registry: $CKS112_REGISTRY` and `repository: $CKS112_TRUSTED_REPO` - not `startsWith`, so as not to let through similar names like `cks112/trusted-evil`. Give the policy a unique denial message, for example `CKS112_TRUSTED_REPO_POLICY: only $CKS112_TRUSTED_IMAGE is allowed`.<br/>• Confirm this path: apply a Pod `blocked-attempt` with the image `$CKS112_UNTRUSTED_IMAGE` (not in the allowlist) and save the admission denial output in `9/admission-deny.txt`.<br/>• Then on the `control-plane` via `cks112-run $CKS112_UNTRUSTED_IMAGE cks112-bypass-1 'echo CKS112_CTR_BYPASS; sleep 5'` (the image is already present locally from the bootstrap, a repeated pull is not needed) simulate a path that does not go through the API server and is not visible to the admission controller (the helper starts it through the CRI in detached mode itself; use a unique ID for a repeated check and afterwards delete the container via `cks112-rm <id>`).<br/>• **Before writing the Falco rule, determine the REAL observed value of the field `%container.image.repository` for the trusted `$CKS112_TRUSTED_IMAGE` on your containerd/Falco stack** - this field is formed differently in different versions (possibly with the registry hostname, possibly without it), so do not assume the format in advance: using a temporary rule with a safe marker, print the value to the log and save it as `$TRUSTED_REPO` (save the evidence in `9/observed-trusted-repo.txt`).<br/>• Add to `falco_rules.local.yaml` a custom rule `CKS112 Runtime Bypass of Admission` that catches a spawned process with `proc.cmdline` containing `CKS112_CTR_BYPASS` **and** a `container.image.repository` that is not in the allowlist, and outputs `container.image.repository` together with the process identifiers. Use an **exact** comparison `container.image.repository != "$TRUSTED_REPO"` with the observed value (not a `startswith`/prefix check: `not container.image.repository startswith "$TRUSTED_REPO"` would let through, that is, not notice, a repository like `<observed-value>-evil`, because its name simply starts with the allowed substring - the same mistake that the Kyverno policy above avoids through `==`, and not `startsWith`).<br/>• Additionally check both controlled cases: the trusted `$CKS112_TRUSTED_IMAGE` must NOT trigger the rule (by the repository criterion only - the marker `CKS112_CTR_BYPASS` itself can still be checked separately), while an image with the repository `<observed-value>-evil` MUST trigger it - this is exactly what proves that the comparison is exact, and not prefix-based.<br/>• Save the alert to `9/falco-bypass-attempt.log` (the files captured on the `control-plane` are copied with `scp` into `/var/work/tests/artifacts/9/`). |
| Acceptance criteria | • Kyverno is installed and Available<br/>• The `ValidatingPolicy require-trusted-registry-runtime-112` exists with `apiVersion: policies.kyverno.io/v1`, validation action `Deny`, uses `image(...).registry()`/`.repository()` for an exact (not `startsWith`) comparison, and its `message`/`messageExpression` contains the unique marker `CKS112_TRUSTED_REPO_POLICY`<br/>• The Pod `blocked-attempt` is not created (admission denial), `9/admission-deny.txt` contains exactly this marker (not just any generic admission error)<br/>• `9/observed-trusted-repo.txt` contains the actually observed value of `%container.image.repository` for the trusted image<br/>• `falco_rules.local.yaml` contains the rule `CKS112 Runtime Bypass of Admission` with an **exact** (not `startswith`/prefix) condition on `container.image.repository` that uses exactly this observed value<br/>• `9/falco-bypass-attempt.log` contains a non-empty alert with `CKS112_CTR_BYPASS` and an image repository outside the allowlist (the suffix `-evil` added to the observed value) - this repository is chosen specifically as a prefix trap: it must be detected despite the fact that it starts with the allowed string |

<details>
<summary>💡 Hint for task 9</summary>

The key idea of the task: `cks112-run` (a wrapper over `crictl` that creates a container directly through the CRI) goes to containerd, bypassing kube-apiserver and therefore bypassing ANY admission controller (including Kyverno) - this is a demonstration that admission control protects only the path through the Kubernetes API, not the whole node. Your Falco rule must check with `and` in a single `condition`: a container process (`container.id != host` - the launch command on the host itself also contains the marker), the marker `CKS112_CTR_BYPASS` AND a repository outside the allowlist - if you check only the marker, the rule will fire even on legitimate test processes with a similar cmdline.
</details>

---
| **10** | **Detect access to `/dev/mem` via a separate class of Falco condition and stop the workload** |
| :---: | :--- |
| What to do | • Tasks 3, 7, and 9 used a condition on `spawned_process`/`proc.cmdline` - detection by the launch of a process. Here a fundamentally different class of Falco condition is needed: detection by the **opening of a file/device**.<br/>• In `runtime-112` there is already a Deployment `mem-scanner` (2 replicas), both replicas of which periodically open `/dev/mem` from inside the container - a regular application workload has no reason to do this, and such access is a strong indicator of a dangerous configuration or an attempt to bypass container isolation. The path `/dev/mem` inside the container is a synthetic safe fixture (the backing device is in fact the host `/dev/null`, not the real physical memory of the host); for Falco this does not matter - the rule detects the `open`/`openat`/`openat2` system call itself by the file name `fd.name = /dev/mem`, regardless of which device actually stands behind it.<br/>• On the `control-plane` add to `/etc/falco/falco_rules.local.yaml` the rule `CKS112 Container access to /dev/mem` with the condition `evt.type in (open, openat, openat2) and fd.name = /dev/mem and container.id != host`, priority `CRITICAL`; the output must contain `container_id=%container.id`, `k8s_pod=%k8s.pod.name` and `k8s_ns=%k8s.ns.name`. Restart Falco.<br/>• Find the alert in the journal and through it determine the **specific** Pod (do not guess by name - use `k8s_pod` from the alert itself); from the specific alert determine which replica created the recorded event. Save the alert line on the node and copy it with `scp` to `/var/work/tests/artifacts/10/falco-devmem.log`.<br/>• Before containment, save the JSON of the detected Pod (`kubectl get pod <pod from the alert> -n runtime-112 -o json`) in `/var/work/tests/artifacts/10/detected-pod.json`.<br/>• Run `kubectl scale deployment mem-scanner -n runtime-112 --replicas=0` and save the final state (`kubectl get deployment mem-scanner -n runtime-112 -o json`) in `/var/work/tests/artifacts/10/scaled-down.json`. |
| Acceptance criteria | • `falco_rules.local.yaml` contains a rule named `CKS112 Container access to /dev/mem`, with a condition on `fd.name = /dev/mem` (not on `proc.cmdline`/spawned_process) and `container.id != host`, priority `CRITICAL`<br/>• Falco is active<br/>• `10/detected-pod.json` records the real Pod and the owner chain before containment<br/>• `10/falco-devmem.log` is a real line from the journal with this rule and a non-empty `k8s_pod`<br/>• The Deployment `mem-scanner` is scaled to `replicas: 0`<br/>• `10/scaled-down.json` confirms `spec.replicas == 0` |

<details>
<summary>💡 Hint for task 10</summary>

Do not confuse this condition with those in tasks 3/7/9 - there `spawned_process`/`execve` catches the LAUNCH of a process by its command line, while here `open`/`openat`/`openat2` catches the OPENING of a specific file/device, regardless of which process does it and with which command-line arguments. `container.id != host` cuts off the legitimate system processes on the node itself (not in a container), which may need access to `/dev/mem` for other reasons. Do not scale the Deployment before you find the alert - first detection via Falco, then containment, otherwise you will not prove that you found the Pod exactly through monitoring, and not by choosing the Pod by name in advance. First get the Falco alert and determine the specific replica that created this event only from its `k8s_pod`.
</details>

## Verification

```bash
check_result
```

The check contains Init and ten independent tests. It checks the state of Falco and
kube-apiserver over SSH, the API objects, the CRI/`/proc` evidence, the audit correlation, the containment,
and the real denial of the write to the rootfs. After
changing the static Pod manifest, do not restart the kubelet unnecessarily: the kubelet will
notice the change itself. If the API is temporarily unavailable, wait for `kubectl get --raw=/readyz`.
Keep the backup of the file `kube-apiserver.yaml` only outside `/etc/kubernetes/manifests`: the kubelet reads any file without a leading dot in this directory.

## Solution

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD).

## Deletion

```bash
TASK=112 make delete_cks_task
```
