[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 109 - Encrypting Secrets in etcd and minimal access

## Goal

In this CKS lab you prove that a Kubernetes Secret without encryption at rest is stored in
etcd as readable bytes (base64 is not encryption), enable `aescbc` via
`EncryptionConfiguration`, connect it to the static `kube-apiserver`, rewrite the old
Secrets, and restrict access to the data with RBAC and `automountServiceAccountToken`.

`aescbc` is chosen here only to practice the exam mechanics of
`EncryptionConfiguration` and re-encryption. The current Kubernetes documentation considers AES-CBC
weak and does not recommend it because of the risk of padding-oracle attacks; `aesgcm` also requires
automated key rotation. For production choose a provider according to the current
documentation and your threat model; with an external key manager KMS v2 is preferred
(see [chapter 21](../../course/21/README.md)).

## Threat model

Encryption at rest protects against storage compromise: assume that an attacker obtained read-only access to an etcd snapshot or the storage layer, for example through a backup or a volume snapshot, but does not have authorized API access. Task 1 proves exactly this initial risk through a raw read of etcd.

After encryption at rest is enabled, tasks 2–4 reduce the blast radius of such access: data read directly must not reveal the Secret. This is not a universal protection and not a replacement for access control to the API.

If the attacker has legitimate API access with the right to read Secrets, encryption at rest does not protect against this threat: the API returns the value after decryption. Therefore task 5 separately restricts RBAC and automount, reducing the blast radius of a workload identity with such rights.

## Self-check before you start

<details>
<summary>1. Why is base64 in `Secret.data` not encryption?</summary>

base64 is just an encoding, reversible without a key: anyone who has access to the bytes themselves (for example, through a raw read of etcd) can decode the value instantly, without any cryptographic operations. Encryption requires a key for the reverse transformation - base64 does not have this property at all.
</details>

<details>
<summary>2. Why must the `identity` provider go LAST in the list of providers, and not first?</summary>

The providers in `EncryptionConfiguration` are tried in order for READING existing records, and the first provider is used for WRITING new data. If `identity` (that is, "no encryption") is first, all new records will be written UNencrypted, despite `aescbc` being in the list. Placing `identity` last lets you read old (not yet migrated) plaintext records while guaranteeing that all new records are encrypted by the first provider.
</details>

<details>
<summary>3. Why can't you simply delete the old encryption key right after adding a new one?</summary>

The existing records in etcd stay encrypted with the OLD key until they are explicitly rewritten (re-encryption). If you remove the old key from the active `EncryptionConfiguration` before all the records are rewritten with the new one, the API server will not be able to decrypt the remaining old records through the current provider chain - they become unreadable until the old key is put back into the configuration. Removing a key from the config does not physically destroy the key material: if the saved old key is added back into the provider chain, access is restored. Irreversible data loss occurs only if the key material itself is really lost or destroyed (for example, the key was not saved anywhere before deletion). The order: add the new key first → rewrite all Secrets → confirm that all records use the new key → keep the old key in a safe place for rollback → only then remove it from the config.
</details>

## Infrastructure

The environment is deployed by Terragrunt in AWS `eu-central-1`:

| Component | Purpose |
|---|---|
| `vpc` | VPC `10.10.0.0/16` with public subnets |
| `ssh-keys` | SSH keys for the worker and the control-plane |
| `k8s-1` | a single-node kubeadm control-plane: Kubernetes **1.36.0**, containerd, **Calico** |
| `worker` | a work machine with `kubectl`; the standard `etcdctl` 3.6.0 is installed on the control-plane (`ssh control-plane`), as in the exam |

The control-plane deliberately accepts regular Pods - a separate Kubernetes worker is not created.
Before the tasks start, the bootstrap creates the namespace `encryption-109` and a harmless
`legacy-secret`. This Secret is created **before** the EncryptionConfiguration, so it serves as a
controlled proof of the plaintext state.

Operations on the node are performed on the control-plane itself, as on the exam: log in to it
(`ssh control-plane`), work there, and exit (`exit`); `kubectl` - from the work machine. A raw etcd record
is read with the standard `etcdctl` from the Kubernetes documentation using the kubeadm certificates from
`/etc/kubernetes/pki/etcd/` (`ca.crt`, `server.crt`, `server.key`). Ready-made command examples are
in the section "Where to find examples in the documentation" of the reference solution.

## Deployment

```bash
TASK=109 make run_cks_task
```

Connect to the work machine. The context `cluster1-admin@cluster1` is already configured.

```bash
time_left
check_result
```

## Tasks

---
| **1** | **Prove that the Secret is initially stored in plaintext** |
| :---: | :--- |
| What to do | • Before enabling encryption, request the raw record `/registry/secrets/encryption-109/legacy-secret` with the standard `etcdctl get ... --print-value-only`<br/>• Log in to the control-plane (`ssh control-plane`) and work on it, as on the exam: pass the output through `strings` and save the result to a file on the control-plane (`/tmp/plaintext-proof.txt`), then copy it to the work machine with `scp` to `/var/work/109/plaintext-proof.txt` |
| Acceptance criteria | • The file contains the full `strings` output of the original raw record (matches the bootstrap snapshot, including the marker `cks-109-legacy-plaintext`) and does not contain `k8s:enc:`<br/>• A string typed by hand is not accepted<br/>• This is a proof of the initial state: `Secret.data` is base64, not encryption at rest |

<details>
<summary>💡 Hint for task 1</summary>

This task must be done FIRST, before task 2 - as soon as you enable the EncryptionConfiguration and rewrite the Secret, the plaintext proof disappears and you will not be able to record it post-hoc. The `etcdctl` command with the flags `--cacert/--cert/--key` is taken from the official Kubernetes documentation (the section "Verify that newly written data is encrypted" on the Encrypting Confidential Data at Rest page); the kubeadm certificate paths: `/etc/kubernetes/pki/etcd/ca.crt`, `server.crt`, `server.key`. The exact links are in the section "Where to find examples in the documentation" of the reference solution.
</details>

---
| **2** | **Create an EncryptionConfiguration for Secrets** |
| :---: | :--- |
| What to do | • On the control-plane create `/etc/kubernetes/enc/encryption-config.yaml`, owner `root:root`, mode `0600`<br/>• Format: `apiserver.config.k8s.io/v1`, `EncryptionConfiguration`<br/>• For `secrets` set `aescbc` as the first provider with a named base64 key of **32 random bytes**, then `identity: {}` |
| Acceptance criteria | • The file is `root:root` mode `0600` in a directory `root:root` mode `0700`<br/>• The main effective provider for `secrets` is the **first** `aescbc` with a correct named base64 key of 32 bytes<br/>• `identity` is allowed only as the last temporary fallback for legacy plaintext<br/>• A symlink to the file/directory is forbidden |

<details>
<summary>💡 Hint for task 2</summary>

Generate the key via `head -c 32 /dev/urandom | base64` - exactly 32 BYTES (not 32 characters of a base64 string, which will be longer because of the encoding). Check yourself: `echo -n "<your-base64-key>" | base64 -d | wc -c` must return exactly `32`.
</details>

---
| **3** | **Connect the config to the static kube-apiserver** |
| :---: | :--- |
| What to do | • Carefully modify `/etc/kubernetes/manifests/kube-apiserver.yaml`: add the flag `--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml`, a read-only `volumeMount` `/etc/kubernetes/enc`, and the corresponding `hostPath` volume `/etc/kubernetes/enc`<br/>• Save a backup of the manifest before editing |
| Acceptance criteria | • The running manifest contains the flag, the mount, and the hostPath<br/>• After the static Pod restarts, `kubectl get --raw='/readyz'` returns `ok` |

<details>
<summary>💡 Hint for task 3</summary>

Three separate changes are needed at the same time: the flag `--encryption-provider-config` itself, the `volumeMounts` (inside the container) AND the `volumes` (the hostPath at the level of the Pod spec) - forgetting any of the three leads either to CrashLoopBackOff (the flag points to a file that the container does not see), or to the flag simply not being passed. Save the backup **outside** `/etc/kubernetes/manifests`, for example `sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109`. The kubelet reads additional non-hidden files from the static manifests directory; a `kube-apiserver.yaml.bak` next to it may be picked up as a second static Pod and block the application of the new configuration.
</details>

---
| **4** | **Re-encrypt and prove the ciphertext** |
| :---: | :--- |
| What to do | • After the API server is ready, create in `encryption-109` a Secret `encrypted-secret` with the literal `token=cks-109-fresh-ciphertext`<br/>• Rewrite all previously existing Secrets through the API (`kubectl get secrets --all-namespaces -o json \| kubectl replace -f -`)<br/>• Check both Secrets through the API and the raw etcd<br/>• Only after this check remove the temporary `identity` fallback, restart the static kube-apiserver, and check `/readyz` again and verify that both Secrets can be read |
| Acceptance criteria | • `legacy-secret` and `encrypted-secret` are read through the API with the original values<br/>• The raw value of each starts with `k8s:enc:aescbc:v1:`<br/>• The legacy marker is no longer visible in raw etcd data<br/>• The original payload/UID of the whole bootstrap Secret corpus is preserved, all records are encrypted with the first effective key<br/>• The key from the final file is able to decrypt the ciphertext of both canary Secrets<br/>• `identity` is absent from the final configuration, the API is healthy |

<details>
<summary>💡 Hint for task 4</summary>

The order is critical: create `encrypted-secret` → rewrite ALL the existing Secrets via `kubectl replace` → check the raw etcd for BOTH (legacy and encrypted) → ONLY THEN remove `identity` from the config. If you remove `identity` before `legacy-secret` is rewritten, the API server will no longer be able to read the old plaintext record through the provider chain, and `legacy-secret` will become unavailable.
</details>

---
| **5** | **Minimize RBAC and disable automount** |
| :---: | :--- |
| What to do | • Create a ServiceAccount `secret-reader` in `encryption-109` with `automountServiceAccountToken: false`<br/>• The Role `secret-reader-109` must grant only the `get` verb and only on the Secret `encrypted-secret`<br/>• Bind it with a RoleBinding of the same name<br/>• Create a Pod `secret-reader-109` with this ServiceAccount, `automountServiceAccountToken: false`, and the image `registry.k8s.io/pause:3.10` |
| Acceptance criteria | • The effective RBAC for the ServiceAccount with its standard groups allows `get encrypted-secret` in `encryption-109` and forbids other Secret operations, including access to the Secrets of other namespaces<br/>• The Role/RoleBinding are exact<br/>• The Pod is Running with a single `pause:3.10`, without automatically or manually mounted ServiceAccount tokens or other credential-bearing sources (Secret/hostPath/CSI/PVC volumes, Secret env/envFrom)<br/>• Harmless emptyDir/ConfigMap volumes are allowed<br/>• `automountServiceAccountToken: false` in both the Pod and the ServiceAccount |

<details>
<summary>💡 Hint for task 5</summary>

Use `resourceNames: ["encrypted-secret"]` in the Role - without this field `get`/`list` on the `secrets` resource would give access to ALL Secrets in the namespace, including `legacy-secret`, which violates the least-privilege requirement. `pause:3.10` is a stub image that does not need the Kubernetes API at all, so automount is disabled at two levels (SA and Pod) without functional consequences.
</details>

## Verification

```bash
check_result
```

The check contains Init and five mandatory tests. Test 4 checks not only the presence of the
configuration file but also the real ciphertext `k8s:enc:aescbc:v1:` for both the new and the pre-existing
etcd record and the absence of the migration-only `identity` in the final configuration. Before a mass re-encryption in a real environment, a snapshot, a key
rotation plan, and a controlled window are required; this lab is not a production runbook.

## Solution

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD)

## Cleanup

```bash
TASK=109 make delete_cks_task
```

## Additional material: KMS v2 and the full key rotation lifecycle

**KMS v2 (an optional walkthrough).** An external KMS plugin is connected to the API server as the
provider `kms` in `EncryptionConfiguration`; its endpoint is a local Unix socket, and the provider key
gets a stable name, for example `kms-v2-primary`. In KMS v2 the API server receives through the plugin an encrypted seed (wrapped under an external
**KEK**) and derives from it the keys for encrypting individual objects. KMS v2
uses a seed/DEK at the API server level, and not a separate KMS call for each Secret.
What is stored in etcd is the ciphertext of the Secret and the data needed to restore the key. Thus the KEK is not stored in etcd; the availability, ACL, and backup of the KMS become
part of the security model. A minimal **illustrative** provider (the endpoint must
correspond to the installed plugin) looks like this:

```yaml
resources:
- resources: [secrets]
  providers:
  - kms:
      apiVersion: v2
      name: kms-v2-primary
      endpoint: unix:///var/run/kms-plugin/socket.sock
```

Add the provider first for new records, mount the socket into the static `kube-apiserver`,
and wait for the plugin health before re-encryption. For a real configuration use a
supported plugin and the current `kms` v2 format from the documentation of the version of
Kubernetes in use; this lab does not bring up a KMS plugin and does not provide a working socket.

**Full rotation of the provider key.** The migration of plaintext to the first
`aescbc` key performed in task 4 is not a full key rotation. For a full rotation: (1) make a protected etcd snapshot and
check that the old key is saved and available for rollback; (2) add the new key
first in `aescbc.keys`, leaving the old one second, then restart the API server; (3)
rewrite the existing Secrets through the API so that they are encrypted with the new first key;
(4) for selected and then all raw etcd records confirm the prefix
`k8s:enc:aescbc:v1:<new-key-name>:`; (5) only after the full migration, backup, and
read check, remove the old key, restart the API server, and check `/readyz`
and the Secrets again. For KMS v2 the equivalent is to first switch the primary KEK/plugin, perform
re-encryption, and only then retire the old KEK following the KMS procedure.
